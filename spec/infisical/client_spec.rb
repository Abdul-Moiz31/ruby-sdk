# frozen_string_literal: true

RSpec.describe Infisical::Client do
  it "builds successfully with the default site_url" do
    expect { described_class.new }.not_to raise_error
  end

  it "builds successfully with a valid https site_url" do
    expect { described_class.new(site_url: "https://self-hosted.example.com") }.not_to raise_error
  end

  describe "site_url normalization" do
    ["https://host.example.com",
     "https://host.example.com/",
     "https://host.example.com/api",
     "https://host.example.com/api/"].each do |site_url|
      it "requests the same endpoint for site_url #{site_url.inspect}" do
        stub = stub_request(:get, "https://host.example.com/api/v4/secrets")
               .with(query: hash_including("projectId" => "proj-1"))
               .to_return(status: 200, body: { secrets: [] }.to_json)

        client = described_class.new(site_url: site_url)
        client.secrets.list(project_id: "proj-1", environment: "dev")

        expect(stub).to have_been_requested
      end
    end
  end

  it "rejects a non-http(s) scheme" do
    expect { described_class.new(site_url: "file:///etc/passwd") }
      .to raise_error(ArgumentError, /must be an http\(s\) URL/)
  end

  it "rejects a malformed URL" do
    expect { described_class.new(site_url: "not a url") }
      .to raise_error(ArgumentError, /not a valid URL/)
  end
end
