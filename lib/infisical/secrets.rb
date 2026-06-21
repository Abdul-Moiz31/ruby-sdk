# frozen_string_literal: true

require "uri"

require_relative "models/secret"

module Infisical
  # CRUD operations against Infisical's raw secrets API.
  class Secrets
    BASE_PATH = "api/v3/secrets/raw"

    def initialize(http_client)
      @http_client = http_client
    end

    def list(project_id:, environment:, secret_path: "/", expand_secret_references: true,
             include_imports: false, recursive: false)
      response = @http_client.get(
        BASE_PATH,
        params: {
          workspaceId: project_id,
          environment: environment,
          secretPath: secret_path,
          expandSecretReferences: expand_secret_references,
          includeImports: include_imports,
          recursive: recursive
        }
      )

      Array(response["secrets"]).map { |secret| Models::Secret.from_api(secret) }
    end

    def get(secret_name, project_id:, environment:, secret_path: "/",
            expand_secret_references: true, include_imports: false)
      response = @http_client.get(
        secret_path_for(secret_name),
        params: {
          workspaceId: project_id,
          environment: environment,
          secretPath: secret_path,
          expandSecretReferences: expand_secret_references,
          includeImports: include_imports
        }
      )

      Models::Secret.from_api(response["secret"])
    end

    def create(secret_name, secret_value, project_id:, environment:, secret_path: "/", secret_comment: nil)
      response = @http_client.post(
        secret_path_for(secret_name),
        body: {
          workspaceId: project_id,
          environment: environment,
          secretPath: secret_path,
          secretValue: secret_value,
          secretComment: secret_comment
        }.compact
      )

      Models::Secret.from_api(response["secret"])
    end

    def update(secret_name, project_id:, environment:, secret_value: nil, new_secret_name: nil, secret_path: "/")
      if secret_value.nil? && new_secret_name.nil?
        raise ArgumentError, "update requires at least one of secret_value: or new_secret_name:"
      end

      response = @http_client.patch(
        secret_path_for(secret_name),
        body: {
          workspaceId: project_id,
          environment: environment,
          secretPath: secret_path,
          secretValue: secret_value,
          newSecretName: new_secret_name
        }.compact
      )

      Models::Secret.from_api(response["secret"])
    end

    def delete(secret_name, project_id:, environment:, secret_path: "/")
      response = @http_client.delete(
        secret_path_for(secret_name),
        body: {
          workspaceId: project_id,
          environment: environment,
          secretPath: secret_path
        }
      )

      Models::Secret.from_api(response["secret"])
    end

    private

    # Escapes a secret name for safe use as a single URI path segment, so
    # names containing "/", "?", "#", or "%" can't be misread as path
    # separators or query-string tokens.
    def secret_path_for(secret_name)
      "#{BASE_PATH}/#{URI::DEFAULT_PARSER.escape(secret_name.to_s, /[^A-Za-z0-9\-._~]/)}"
    end
  end
end
