# frozen_string_literal: true

module Infisical
  # Value objects returned by the resource clients.
  module Models
    # Value object representing a single Infisical secret.
    #
    # @!attribute id
    #   @return [String] unique id of the secret
    # @!attribute workspace
    #   @return [String] id of the project the secret belongs to
    # @!attribute environment
    #   @return [String] environment slug the secret belongs to
    # @!attribute version
    #   @return [Integer] version number, incremented on every update
    # @!attribute type
    #   @return [String] "shared" or "personal"
    # @!attribute secret_key
    #   @return [String] the secret's name
    # @!attribute secret_value
    #   @return [String] the secret's value
    # @!attribute secret_comment
    #   @return [String, nil] comment stored with the secret
    # @!attribute secret_path
    #   @return [String, nil] folder path the secret lives at
    # @!attribute created_at
    #   @return [String, nil] ISO 8601 creation timestamp
    # @!attribute updated_at
    #   @return [String, nil] ISO 8601 last-update timestamp
    Secret = Struct.new(
      :id, :workspace, :environment, :version, :type,
      :secret_key, :secret_value, :secret_comment, :secret_path,
      :created_at, :updated_at,
      keyword_init: true
    ) do
      # Builds a Secret from an API response hash (camelCase keys).
      #
      # @api private
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
