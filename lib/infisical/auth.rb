# frozen_string_literal: true

require_relative "models/machine_identity_credential"

module Infisical
  # Authenticates the underlying HTTP client. Every other resource client
  # shares that same HTTP client, so a successful login here authenticates
  # the whole {Client} instance.
  class Auth
    UNIVERSAL_AUTH_LOGIN_PATH = "api/v1/auth/universal-auth/login"

    # @api private Obtain instances via {Client#auth} instead.
    def initialize(http_client)
      @http_client = http_client
    end

    # Logs in with Universal Auth (machine identity client id/secret) and
    # authenticates this client with the resulting access token. The full
    # credential is returned so callers can track `expires_in` and re-login
    # (or renew) before the token lapses.
    #
    # @param client_id [String] machine identity client id
    # @param client_secret [String] machine identity client secret
    # @return [Models::MachineIdentityCredential] the credential now used by
    #   this client
    # @raise [AuthenticationError] if the credentials are rejected
    def universal_auth_login(client_id:, client_secret:)
      # auth: false keeps any previously stored (possibly expired) bearer
      # token off the login request; the API breaks on stale tokens there.
      response = @http_client.post(
        UNIVERSAL_AUTH_LOGIN_PATH,
        body: { clientId: client_id, clientSecret: client_secret },
        auth: false
      )

      access_token(response["accessToken"])
      Models::MachineIdentityCredential.from_api(response)
    end

    # Authenticates with an access token obtained out-of-band, skipping
    # the login request entirely.
    #
    # @param token [String] a valid Infisical access token
    # @return [String] the token, now used by this client
    def access_token(token)
      @http_client.access_token = token
      token
    end
  end
end
