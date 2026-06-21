# frozen_string_literal: true

RSpec.describe Infisical::Client do
  it "builds successfully with the default site_url" do
    expect { described_class.new }.not_to raise_error
  end

  it "builds successfully with a valid https site_url" do
    expect { described_class.new(site_url: "https://self-hosted.example.com") }.not_to raise_error
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
