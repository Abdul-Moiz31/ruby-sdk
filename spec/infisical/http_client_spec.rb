# frozen_string_literal: true

RSpec.describe Infisical::HTTPClient do
  let(:base_url) { "https://app.infisical.com" }
  let(:client) { described_class.new(base_url: base_url, max_retries: 2, sleeper: ->(_seconds) {}) }
  let(:url) { "#{base_url}/api/v3/secrets/raw" }

  describe "#get" do
    it "performs a GET request and parses the JSON response" do
      stub_request(:get, url).to_return(status: 200, body: '{"secrets":[]}',
                                        headers: { "Content-Type" => "application/json" })

      expect(client.get("api/v3/secrets/raw")).to eq({ "secrets" => [] })
    end

    it "attaches the bearer token once access_token is set" do
      client.access_token = "tok-123"
      stub = stub_request(:get, url).with(headers: { "Authorization" => "Bearer tok-123" })
                                    .to_return(status: 200, body: "{}")

      client.get("api/v3/secrets/raw")

      expect(stub).to have_been_requested
    end

    it "sends query params, dropping nil values" do
      stub = stub_request(:get, url).with(query: { "environment" => "dev" })
                                    .to_return(status: 200, body: "{}")

      client.get("api/v3/secrets/raw", params: { environment: "dev", secretPath: nil })

      expect(stub).to have_been_requested
    end
  end

  describe "error handling" do
    it "raises Infisical::APIError with status/url/method context on a non-2xx, non-429 response" do
      stub_request(:get, url).to_return(status: 404, body: '{"message":"secret not found"}')

      expect { client.get("api/v3/secrets/raw") }.to raise_error(Infisical::APIError) do |error|
        expect(error.status).to eq(404)
        expect(error.method).to eq("GET")
        expect(error.url).to eq(url)
        expect(error.message).to include("secret not found")
      end
    end

    it "does not retry non-429 error responses" do
      stub = stub_request(:get, url).to_return(status: 500, body: '{"message":"boom"}')

      expect { client.get("api/v3/secrets/raw") }.to raise_error(Infisical::APIError)
      expect(stub).to have_been_requested.times(1)
    end
  end

  describe "retries" do
    it "retries on 429 and succeeds once the server recovers" do
      stub = stub_request(:get, url).to_return(
        { status: 429, body: '{"message":"rate limited"}' },
        { status: 200, body: '{"secrets":[]}' }
      )

      expect(client.get("api/v3/secrets/raw")).to eq({ "secrets" => [] })
      expect(stub).to have_been_requested.times(2)
    end

    it "raises Infisical::APIError after exhausting retries on persistent 429s" do
      stub = stub_request(:get, url).to_return(status: 429, body: '{"message":"rate limited"}')

      expect { client.get("api/v3/secrets/raw") }.to raise_error(Infisical::APIError) do |error|
        expect(error.status).to eq(429)
      end
      expect(stub).to have_been_requested.times(3) # 1 initial + 2 retries
    end

    it "retries network errors and raises Infisical::RequestError after exhausting retries" do
      stub = stub_request(:get, url).to_raise(Net::OpenTimeout)

      expect { client.get("api/v3/secrets/raw") }.to raise_error(Infisical::RequestError)
      expect(stub).to have_been_requested.times(3) # 1 initial + 2 retries
    end

    it "retries a transient network error and succeeds on the next attempt" do
      stub = stub_request(:get, url).to_raise(Net::OpenTimeout).then.to_return(status: 200, body: '{"secrets":[]}')

      expect(client.get("api/v3/secrets/raw")).to eq({ "secrets" => [] })
      expect(stub).to have_been_requested.times(2)
    end
  end

  describe ".backoff_delay" do
    it "grows exponentially with the attempt number" do
      expect(described_class.backoff_delay(0, initial_delay: 1.0, backoff_factor: 2)).to eq(1.0)
      expect(described_class.backoff_delay(1, initial_delay: 1.0, backoff_factor: 2)).to eq(2.0)
      expect(described_class.backoff_delay(2, initial_delay: 1.0, backoff_factor: 2)).to eq(4.0)
    end

    it "honors custom initial_delay and backoff_factor" do
      expect(described_class.backoff_delay(2, initial_delay: 0.5, backoff_factor: 3)).to eq(4.5)
    end
  end
end
