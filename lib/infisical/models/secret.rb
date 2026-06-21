# frozen_string_literal: true

module Infisical
  module Models
    # Immutable value object representing a single Infisical secret.
    Secret = Struct.new(
      :id, :workspace, :environment, :version, :type,
      :secret_key, :secret_value, :secret_comment, :secret_path,
      :created_at, :updated_at,
      keyword_init: true
    ) do
      def self.from_api(data)
        new(
          id: data["id"],
          workspace: data["workspace"],
          environment: data["environment"],
          version: data["version"],
          type: data["type"],
          secret_key: data["secretKey"],
          secret_value: data["secretValue"],
          secret_comment: data["secretComment"],
          secret_path: data["secretPath"],
          created_at: data["createdAt"],
          updated_at: data["updatedAt"]
        )
      end
    end
  end
end
