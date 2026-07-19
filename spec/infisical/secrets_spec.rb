# frozen_string_literal: true

RSpec.describe Infisical::Secrets do
  let(:base_url) { "https://app.infisical.com" }
  let(:http_client) { Infisical::HTTPClient.new(base_url: base_url, sleeper: ->(_seconds) {}) }
  let(:secrets) { described_class.new(http_client) }

  def secret_payload(key, value: "v", path: "/")
    { id: key.downcase, secretKey: key, secretValue: value, secretPath: path, version: 1, type: "shared" }
  end

  describe "#list" do
    it "lists secrets for a project/environment, sorted by key" do
      stub_request(:get, "#{base_url}/api/v4/secrets")
        .with(query: hash_including("projectId" => "proj-1", "environment" => "dev",
                                    "includeImports" => "true", "recursive" => "false"))
        .to_return(
          status: 200,
          body: { secrets: [secret_payload("FOO", value: "bar"), secret_payload("BAR")] }.to_json
        )

      result = secrets.list(project_id: "proj-1", environment: "dev")

      expect(result.map(&:secret_key)).to eq(%w[BAR FOO])
      expect(result).to all(be_a(Infisical::Models::Secret))
      expect(result.last.secret_value).to eq("bar")
    end

    it "does not send expandSecretReferences (the v4 API defaults it to true)" do
      stub = stub_request(:get, "#{base_url}/api/v4/secrets")
             .with(query: hash_excluding("expandSecretReferences"))
             .to_return(status: 200, body: { secrets: [] }.to_json)

      secrets.list(project_id: "proj-1", environment: "dev")

      expect(stub).to have_been_requested
    end

    context "when recursive" do
      it "collapses duplicate keys from different paths, keeping the last occurrence" do
        stub_request(:get, "#{base_url}/api/v4/secrets")
          .with(query: hash_including("recursive" => "true"))
          .to_return(
            status: 200,
            body: { secrets: [secret_payload("FOO", value: "root", path: "/"),
                              secret_payload("FOO", value: "nested", path: "/app"),
                              secret_payload("BAR")] }.to_json
          )

        result = secrets.list(project_id: "proj-1", environment: "dev", recursive: true)

        expect(result.map(&:secret_key)).to eq(%w[BAR FOO])
        expect(result.last.secret_value).to eq("nested")
      end

      it "keeps same-named secrets from different paths with skip_unique_validation" do
        stub_request(:get, "#{base_url}/api/v4/secrets")
          .with(query: hash_including("recursive" => "true"))
          .to_return(
            status: 200,
            body: { secrets: [secret_payload("FOO", value: "root", path: "/"),
                              secret_payload("FOO", value: "nested", path: "/app")] }.to_json
          )

        result = secrets.list(project_id: "proj-1", environment: "dev",
                              recursive: true, skip_unique_validation: true)

        expect(result.map(&:secret_value)).to contain_exactly("root", "nested")
      end
    end

    context "when attach_to_process_env" do
      around do |example|
        ENV.delete("E2E_ATTACH_NEW")
        ENV["E2E_ATTACH_TAKEN"] = "pre-existing"
        example.run
      ensure
        ENV.delete("E2E_ATTACH_NEW")
        ENV.delete("E2E_ATTACH_TAKEN")
      end

      it "exports secrets into ENV without overriding existing variables" do
        stub_request(:get, "#{base_url}/api/v4/secrets")
          .with(query: hash_including("projectId" => "proj-1"))
          .to_return(
            status: 200,
            body: { secrets: [secret_payload("E2E_ATTACH_NEW", value: "from-infisical"),
                              secret_payload("E2E_ATTACH_TAKEN", value: "from-infisical")] }.to_json
          )

        secrets.list(project_id: "proj-1", environment: "dev", attach_to_process_env: true)

        expect(ENV.fetch("E2E_ATTACH_NEW")).to eq("from-infisical")
        expect(ENV.fetch("E2E_ATTACH_TAKEN")).to eq("pre-existing")
      end
    end

    context "when include_imports" do
      it "appends imported secrets, with direct secrets taking precedence on key conflicts" do
        stub_request(:get, "#{base_url}/api/v4/secrets")
          .with(query: hash_including("includeImports" => "true"))
          .to_return(
            status: 200,
            body: {
              secrets: [secret_payload("FOO", value: "direct")],
              imports: [
                { secretPath: "/shared", environment: "dev",
                  secrets: [secret_payload("FOO", value: "imported"), secret_payload("DB_URL")] },
                { secretPath: "/other", environment: "dev",
                  secrets: [secret_payload("DB_URL", value: "later-import")] }
              ]
            }.to_json
          )

        result = secrets.list(project_id: "proj-1", environment: "dev", include_imports: true)

        expect(result.map(&:secret_key)).to eq(%w[DB_URL FOO])
        expect(result.find { |s| s.secret_key == "FOO" }.secret_value).to eq("direct")
        expect(result.find { |s| s.secret_key == "DB_URL" }.secret_value).to eq("v")
      end
    end
  end

  describe "#get" do
    it "fetches a single secret by name" do
      stub_request(:get, "#{base_url}/api/v4/secrets/FOO")
        .with(query: hash_including("projectId" => "proj-1", "environment" => "dev"))
        .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO", secretValue: "bar" } }.to_json)

      secret = secrets.get("FOO", project_id: "proj-1", environment: "dev")

      expect(secret.secret_key).to eq("FOO")
      expect(secret.secret_value).to eq("bar")
    end

    it "parses metadata and tags into value objects" do
      stub_request(:get, "#{base_url}/api/v4/secrets/FOO")
        .with(query: hash_including("projectId" => "proj-1"))
        .to_return(
          status: 200,
          body: {
            secret: {
              id: "1", secretKey: "FOO", secretValue: "bar",
              secretMetadata: [{ key: "owner", value: "platform-team" }],
              tags: [{ id: "t1", slug: "prod", name: "Production", color: "#ff0000" }]
            }
          }.to_json
        )

      secret = secrets.get("FOO", project_id: "proj-1", environment: "dev")

      expect(secret.metadata).to eq([Infisical::Models::SecretMetadata.new(key: "owner", value: "platform-team")])
      expect(secret.tags.map(&:slug)).to eq(["prod"])
      expect(secret.tags.first.color).to eq("#ff0000")
    end

    it "defaults metadata and tags to empty arrays when the API omits them" do
      stub_request(:get, "#{base_url}/api/v4/secrets/FOO")
        .with(query: hash_including("projectId" => "proj-1"))
        .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO" } }.to_json)

      secret = secrets.get("FOO", project_id: "proj-1", environment: "dev")

      expect(secret.metadata).to eq([])
      expect(secret.tags).to eq([])
    end

    it "URL-encodes secret names containing reserved characters" do
      stub = stub_request(:get, "#{base_url}/api/v4/secrets/FOO%2FBAR")
             .with(query: hash_including("projectId" => "proj-1"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO/BAR" } }.to_json)

      secrets.get("FOO/BAR", project_id: "proj-1", environment: "dev")

      expect(stub).to have_been_requested
    end
  end

  describe "#create" do
    it "creates a secret with the given value" do
      stub = stub_request(:post, "#{base_url}/api/v4/secrets/FOO")
             .with(body: hash_including("projectId" => "proj-1", "environment" => "dev", "secretValue" => "bar"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO", secretValue: "bar" } }.to_json)

      secret = secrets.create("FOO", "bar", project_id: "proj-1", environment: "dev")

      expect(stub).to have_been_requested
      expect(secret.secret_value).to eq("bar")
    end

    it "sends skipMultilineEncoding when given, and omits it by default" do
      with_flag = stub_request(:post, "#{base_url}/api/v4/secrets/FOO")
                  .with(body: hash_including("skipMultilineEncoding" => true))
                  .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO" } }.to_json)

      secrets.create("FOO", "a\nb", project_id: "proj-1", environment: "dev", skip_multiline_encoding: true)
      expect(with_flag).to have_been_requested

      without_flag = stub_request(:post, "#{base_url}/api/v4/secrets/BAR")
                     .with { |request| !JSON.parse(request.body).key?("skipMultilineEncoding") }
                     .to_return(status: 200, body: { secret: { id: "2", secretKey: "BAR" } }.to_json)

      secrets.create("BAR", "baz", project_id: "proj-1", environment: "dev")
      expect(without_flag).to have_been_requested
    end
  end

  describe "#update" do
    it "updates a secret's value" do
      stub = stub_request(:patch, "#{base_url}/api/v4/secrets/FOO")
             .with(body: hash_including("projectId" => "proj-1", "secretValue" => "new-val"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO", secretValue: "new-val" } }.to_json)

      secret = secrets.update("FOO", project_id: "proj-1", environment: "dev", secret_value: "new-val")

      expect(stub).to have_been_requested
      expect(secret.secret_value).to eq("new-val")
    end

    it "supports renaming via new_secret_name" do
      stub = stub_request(:patch, "#{base_url}/api/v4/secrets/FOO")
             .with(body: hash_including("newSecretName" => "BAR"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "BAR" } }.to_json)

      secrets.update("FOO", project_id: "proj-1", environment: "dev", new_secret_name: "BAR")

      expect(stub).to have_been_requested
    end

    it "sends skipMultilineEncoding when given" do
      stub = stub_request(:patch, "#{base_url}/api/v4/secrets/FOO")
             .with(body: hash_including("secretValue" => "a\nb", "skipMultilineEncoding" => true))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO" } }.to_json)

      secrets.update("FOO", project_id: "proj-1", environment: "dev",
                            secret_value: "a\nb", skip_multiline_encoding: true)

      expect(stub).to have_been_requested
    end

    it "raises ArgumentError when neither secret_value nor new_secret_name is given" do
      expect { secrets.update("FOO", project_id: "proj-1", environment: "dev") }
        .to raise_error(ArgumentError, /requires at least one of/)
    end
  end

  describe "#delete" do
    it "deletes a secret by name" do
      stub = stub_request(:delete, "#{base_url}/api/v4/secrets/FOO")
             .with(body: hash_including("projectId" => "proj-1", "environment" => "dev"))
             .to_return(status: 200, body: { secret: { id: "1", secretKey: "FOO" } }.to_json)

      secret = secrets.delete("FOO", project_id: "proj-1", environment: "dev")

      expect(stub).to have_been_requested
      expect(secret.secret_key).to eq("FOO")
    end
  end
end
