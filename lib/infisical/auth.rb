# frozen_string_literal: true

module Infisical
  # Authenticates the underlying HTTP client. Every other resource client
  # shares that same HTTP client, so a successful login here authenticates
  # the whole `Client` instance.
  class Auth
    UNIVERSAL_AUTH_LOGIN_PATH = "api/v1/auth/universal-auth/login"

    def initialize(http_client)
      @http_client = http_client
    end

    # Logs in with Universal Auth (machine identity client id/secret) and
    # returns the resulting access token.
    def universal_auth_login(client_id:, client_secret:)
      response = @http_client.post(
        UNIVERSAL_AUTH_LOGIN_PATH,
        body: { clientId: client_id, clientSecret: client_secret }
      )

      access_token(response["accessToken"])
    end

    # Authenticates with an access token obtained out-of-band, skipping
    # the login request entirely.
    def access_token(token)
      @http_client.access_token = token
      token
    end
  end
end
