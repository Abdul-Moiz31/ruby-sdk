# frozen_string_literal: true

require "uri"

require_relative "models/secret"

module Infisical
  # CRUD operations against Infisical's v4 secrets API.
  class Secrets
    # @api private
    BASE_PATH = "api/v4/secrets"

    # @api private Obtain instances via {Client#secrets} instead.
    def initialize(http_client)
      @http_client = http_client
    end

    # Lists the secrets in a project environment, sorted by key.
    #
    # @param project_id [String] id of the project to read from
    # @param environment [String] environment slug, e.g. "dev"
    # @param secret_path [String] folder path to list from
    # @param include_imports [Boolean] fold in secrets from imported folders;
    #   direct secrets win over imports on key conflicts, and earlier import
    #   blocks win over later ones
    # @param recursive [Boolean] also list secrets from sub-folders
    # @param skip_unique_validation [Boolean] in recursive mode, duplicate keys
    #   across folders are collapsed to one secret per key (last occurrence
    #   wins) unless this is true, in which case all of them are kept
    # @param attach_to_process_env [Boolean] export each fetched secret into
    #   the process environment (ENV), without overriding variables that are
    #   already set
    # @return [Array<Models::Secret>]
    # @raise [APIError] if the API rejects the request
    def list(project_id:, environment:, secret_path: "/", include_imports: true, recursive: false,
             skip_unique_validation: false, attach_to_process_env: false)
      response = @http_client.get(
        BASE_PATH,
        params: {
          projectId: project_id,
          environment: environment,
          secretPath: secret_path,
          includeImports: include_imports,
          recursive: recursive
        }
      )

      secrets = Array(response["secrets"]).map { |secret| Models::Secret.from_api(secret) }
      secrets = ensure_unique_secrets_by_key(secrets, skip_unique_validation) if recursive
      secrets = merge_imported_secrets(secrets, response["imports"]) if include_imports
      secrets = secrets.sort_by(&:secret_key)
      attach_to_env(secrets) if attach_to_process_env
      secrets
    end

    # Fetches a single secret by name.
    #
    # @param secret_name [String] key of the secret to fetch
    # @param project_id [String] id of the project to read from
    # @param environment [String] environment slug, e.g. "dev"
    # @param secret_path [String] folder path the secret lives at
    # @param include_imports [Boolean] also look through imported folders when
    #   the secret is not found at the path itself
    # @return [Models::Secret]
    # @raise [NotFoundError] if no such secret exists
    def get(secret_name, project_id:, environment:, secret_path: "/", include_imports: true)
      response = @http_client.get(
        secret_path_for(secret_name),
        params: {
          projectId: project_id,
          environment: environment,
          secretPath: secret_path,
          includeImports: include_imports
        }
      )

      Models::Secret.from_api(response["secret"])
    end

    # Creates a new secret.
    #
    # @param secret_name [String] key of the secret to create
    # @param secret_value [String] value of the secret
    # @param project_id [String] id of the project to write to
    # @param environment [String] environment slug, e.g. "dev"
    # @param secret_path [String] folder path to create the secret at
    # @param secret_comment [String, nil] optional comment stored with the secret
    # @param skip_multiline_encoding [Boolean, nil] disable the API's encoding
    #   of multi-line values; omitted from the request when nil
    # @return [Models::Secret] the created secret
    # @raise [APIError] if the API rejects the request, e.g. the name is taken
    def create(secret_name, secret_value, project_id:, environment:, secret_path: "/", secret_comment: nil,
               skip_multiline_encoding: nil)
      response = @http_client.post(
        secret_path_for(secret_name),
        body: {
          projectId: project_id,
          environment: environment,
          secretPath: secret_path,
          secretValue: secret_value,
          secretComment: secret_comment,
          skipMultilineEncoding: skip_multiline_encoding
        }.compact
      )

      Models::Secret.from_api(response["secret"])
    end

    # Updates a secret's value, name, or both.
    #
    # @param secret_name [String] key of the secret to update
    # @param project_id [String] id of the project to write to
    # @param environment [String] environment slug, e.g. "dev"
    # @param secret_value [String, nil] new value, if changing it
    # @param new_secret_name [String, nil] new key, if renaming
    # @param secret_path [String] folder path the secret lives at
    # @param skip_multiline_encoding [Boolean, nil] disable the API's encoding
    #   of multi-line values; omitted from the request when nil
    # @return [Models::Secret] the updated secret
    # @raise [ArgumentError] if neither secret_value nor new_secret_name is given
    # @raise [NotFoundError] if no such secret exists
    def update(secret_name, project_id:, environment:, secret_value: nil, new_secret_name: nil, secret_path: "/",
               skip_multiline_encoding: nil)
      if secret_value.nil? && new_secret_name.nil?
        raise ArgumentError, "update requires at least one of secret_value: or new_secret_name:"
      end

      response = @http_client.patch(
        secret_path_for(secret_name),
        body: {
          projectId: project_id,
          environment: environment,
          secretPath: secret_path,
          secretValue: secret_value,
          newSecretName: new_secret_name,
          skipMultilineEncoding: skip_multiline_encoding
        }.compact
      )

      Models::Secret.from_api(response["secret"])
    end

    # Deletes a secret.
    #
    # @param secret_name [String] key of the secret to delete
    # @param project_id [String] id of the project to write to
    # @param environment [String] environment slug, e.g. "dev"
    # @param secret_path [String] folder path the secret lives at
    # @return [Models::Secret] the deleted secret
    # @raise [NotFoundError] if no such secret exists
    def delete(secret_name, project_id:, environment:, secret_path: "/")
      response = @http_client.delete(
        secret_path_for(secret_name),
        body: {
          projectId: project_id,
          environment: environment,
          secretPath: secret_path
        }
      )

      Models::Secret.from_api(response["secret"])
    end

    private

    # In recursive mode the same key can exist at several paths; collapse to
    # one secret per key (the last occurrence wins). With
    # skip_unique_validation, secrets are instead kept unique per
    # path+key, so same-named secrets at different paths all survive.
    def ensure_unique_secrets_by_key(secrets, skip_unique_validation)
      secrets.each_with_object({}) do |secret, by_key|
        key = skip_unique_validation ? "#{secret.secret_path}:#{secret.secret_key}" : secret.secret_key
        by_key[key] = secret
      end.values
    end

    # Folds secrets from import blocks into the main list. Secrets already
    # present win over imports, and earlier import blocks win over later
    # ones.
    def merge_imported_secrets(secrets, import_blocks)
      merged = secrets.dup
      seen = merged.to_h { |secret| [secret.secret_key, true] }

      Array(import_blocks).each do |block|
        Array(block["secrets"]).each do |data|
          secret = Models::Secret.from_api(data)
          next if seen[secret.secret_key]

          seen[secret.secret_key] = true
          merged << secret
        end
      end

      merged
    end

    # Exports secrets into the process environment. A variable that already
    # has a non-empty value is left untouched; an empty value counts as
    # unset, matching the Go SDK.
    def attach_to_env(secrets)
      secrets.each do |secret|
        ENV[secret.secret_key] = secret.secret_value if ENV[secret.secret_key].to_s.empty?
      end
    end

    # Escapes a secret name for safe use as a single URI path segment, so
    # names containing "/", "?", "#", or "%" can't be misread as path
    # separators or query-string tokens.
    def secret_path_for(secret_name)
      "#{BASE_PATH}/#{URI::DEFAULT_PARSER.escape(secret_name.to_s, /[^A-Za-z0-9\-._~]/)}"
    end
  end
end
