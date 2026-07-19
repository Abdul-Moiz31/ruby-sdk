# frozen_string_literal: true

module Infisical
  module Models
    # Credential material issued by a machine identity login. Exposes the
    # token's lifetime so callers can build their own refresh logic.
    #
    # @!attribute access_token
    #   @return [String] bearer token used to authenticate API requests
    # @!attribute expires_in
    #   @return [Integer] seconds until the token expires, from issue time
    # @!attribute access_token_max_ttl
    #   @return [Integer] hard ceiling in seconds on the token's total
    #     lifetime across renewals
    # @!attribute token_type
    #   @return [String] token scheme, e.g. "Bearer"
    MachineIdentityCredential = Struct.new(
      :access_token, :expires_in, :access_token_max_ttl, :token_type,
      keyword_init: true
    ) do
      # Builds a credential from an API response hash (camelCase keys).
      #
      # @api private
      def self.from_api(data)
        new(
          access_token: data["accessToken"],
          expires_in: data["expiresIn"],
          access_token_max_ttl: data["accessTokenMaxTTL"],
          token_type: data["tokenType"]
        )
      end
    end
  end
end
