# frozen_string_literal: true

RSpec.describe Infisical::Secrets do
  let(:base_url) { "https://app.infisical.com" }
  let(:http_client) { Infisical::HTTPClient.new(base_url: base_url, sleeper: ->(_seconds) {}) }
  let(:secrets) { described_class.new(http_client) }

  describe "#list" do
    it "lists secrets for a project/environment" do
      stub_request(:get, "#{base_url}/api/v3/secrets/raw")
        .with(query: hash_including("workspaceId" => "proj-1", "environment" => "dev"))
        .to_return(
          status: 200,
          body: { secrets: [{ id: "1", workspace: "proj-1", environment: "dev", secretKey: "FOO",
                              secretValue: "bar", secretPath: "/", version: 1, type: "shared" }] }.to_json
        )

      result = secrets.list(project_id: "proj-1", environment: "dev")

      expect(result.size).to eq(1)
      expect(result.first).to be_a(Infisical::Models::Secret)
      expect(result.first.secret_key).to eq("FOO")
      expect(result.first.secret_value).to eq("bar")
    end
  end

  describe "#get" do
    it "fetches a single secret by name" do
      stub_request(:get, "#{base_url}/api/v3/secrets/raw/FOO")
        .with(query: hash_including("workspaceId" => "proj-1", "environment" => "dev"))
        .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO", secretValue: "bar" } }.to_json)

      secret = secrets.get("FOO", project_id: "proj-1", environment: "dev")

      expect(secret.secret_key).to eq("FOO")
      expect(secret.secret_value).to eq("bar")
    end

    it "URL-encodes secret names containing reserved characters" do
      stub = stub_request(:get, "#{base_url}/api/v3/secrets/raw/FOO%2FBAR")
             .with(query: hash_including("workspaceId" => "proj-1"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO/BAR" } }.to_json)

      secrets.get("FOO/BAR", project_id: "proj-1", environment: "dev")

      expect(stub).to have_been_requested
    end
  end

  describe "#create" do
    it "creates a secret with the given value" do
      stub = stub_request(:post, "#{base_url}/api/v3/secrets/raw/FOO")
             .with(body: hash_including("workspaceId" => "proj-1", "environment" => "dev", "secretValue" => "bar"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO", secretValue: "bar" } }.to_json)

      secret = secrets.create("FOO", "bar", project_id: "proj-1", environment: "dev")

      expect(stub).to have_been_requested
      expect(secret.secret_value).to eq("bar")
    end
  end

  describe "#update" do
    it "updates a secret's value" do
      stub = stub_request(:patch, "#{base_url}/api/v3/secrets/raw/FOO")
             .with(body: hash_including("secretValue" => "new-val"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO", secretValue: "new-val" } }.to_json)

      secret = secrets.update("FOO", project_id: "proj-1", environment: "dev", secret_value: "new-val")

      expect(stub).to have_been_requested
      expect(secret.secret_value).to eq("new-val")
    end

    it "supports renaming via new_secret_name" do
      stub = stub_request(:patch, "#{base_url}/api/v3/secrets/raw/FOO")
             .with(body: hash_including("newSecretName" => "BAR"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "BAR" } }.to_json)

      secrets.update("FOO", project_id: "proj-1", environment: "dev", new_secret_name: "BAR")

      expect(stub).to have_been_requested
    end

    it "raises ArgumentError when neither secret_value nor new_secret_name is given" do
      expect { secrets.update("FOO", project_id: "proj-1", environment: "dev") }
        .to raise_error(ArgumentError, /requires at least one of/)
    end
  end

  describe "#delete" do
    it "deletes a secret by name" do
      stub = stub_request(:delete, "#{base_url}/api/v3/secrets/raw/FOO")
             .with(body: hash_including("workspaceId" => "proj-1", "environment" => "dev"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO" } }.to_json)

      secret = secrets.delete("FOO", project_id: "proj-1", environment: "dev")

      expect(stub).to have_been_requested
      expect(secret.secret_key).to eq("FOO")
    end
  end
end
