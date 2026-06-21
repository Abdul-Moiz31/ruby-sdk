# frozen_string_literal: true

RSpec.describe Infisical::Auth do
  let(:base_url) { "https://app.infisical.com" }
  let(:http_client) { Infisical::HTTPClient.new(base_url: base_url, sleeper: ->(_seconds) {}) }
  let(:auth) { described_class.new(http_client) }

  describe "#universal_auth_login" do
    it "logs in with client id/secret and returns the access token" do
      stub_request(:post, "#{base_url}/api/v1/auth/universal-auth/login")
        .with(body: hash_including("clientId" => "id-1", "clientSecret" => "secret-1"))
        .to_return(status: 200, body: '{"accessToken":"tok-abc","expiresIn":3600}')

      expect(auth.universal_auth_login(client_id: "id-1", client_secret: "secret-1")).to eq("tok-abc")
    end

    it "authenticates the shared HTTP client so subsequent requests carry the token" do
      stub_request(:post, "#{base_url}/api/v1/auth/universal-auth/login")
        .to_return(status: 200, body: '{"accessToken":"tok-abc"}')
      secrets_stub = stub_request(:get, "#{base_url}/api/v3/secrets/raw")
                     .with(headers: { "Authorization" => "Bearer tok-abc" })
                     .to_return(status: 200, body: "{}")

      auth.universal_auth_login(client_id: "id-1", client_secret: "secret-1")
      http_client.get("api/v3/secrets/raw")

      expect(secrets_stub).to have_been_requested
    end
  end

  describe "#access_token" do
    it "authenticates the shared HTTP client without an HTTP request" do
      secrets_stub = stub_request(:get, "#{base_url}/api/v3/secrets/raw")
                     .with(headers: { "Authorization" => "Bearer manual-token" })
                     .to_return(status: 200, body: "{}")

      auth.access_token("manual-token")
      http_client.get("api/v3/secrets/raw")

      expect(secrets_stub).to have_been_requested
    end
  end
end
