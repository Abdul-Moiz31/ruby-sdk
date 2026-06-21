# frozen_string_literal: true

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
        "#{BASE_PATH}/#{secret_name}",
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
        "#{BASE_PATH}/#{secret_name}",
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
      response = @http_client.patch(
        "#{BASE_PATH}/#{secret_name}",
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
        "#{BASE_PATH}/#{secret_name}",
        body: {
          workspaceId: project_id,
          environment: environment,
          secretPath: secret_path
        }
      )

      Models::Secret.from_api(response["secret"])
    end
  end
end
