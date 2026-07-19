# frozen_string_literal: true

RSpec.describe Infisical::APIError do
  describe ".for_status" do
    {
      401 => Infisical::AuthenticationError,
      403 => Infisical::PermissionError,
      404 => Infisical::NotFoundError,
      429 => Infisical::RateLimitError,
      500 => Infisical::ServerError,
      503 => Infisical::ServerError
    }.each do |status, error_class|
      it "maps #{status} to #{error_class}" do
        expect(described_class.for_status(status)).to eq(error_class)
      end
    end

    it "falls back to APIError for statuses without a dedicated subclass" do
      expect(described_class.for_status(400)).to eq(described_class)
      expect(described_class.for_status(422)).to eq(described_class)
    end
  end

  it "lets every status-specific error be rescued as APIError and Infisical::Error" do
    error = Infisical::NotFoundError.new("nope", status: 404, url: "https://x", method: "GET")

    expect(error).to be_a(described_class)
    expect(error).to be_a(Infisical::Error)
  end
end
