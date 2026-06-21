<h1 align="center">Infisical Ruby SDK</h1>

<h4 align="center">
  <a href="https://infisical.com/docs/sdks/languages/ruby">Documentation</a> |
  <a href="https://www.infisical.com">Website</a> |
  <a href="https://infisical.com/slack">Slack</a>
</h4>

## Introduction

**[Infisical](https://infisical.com)** is the open source secret management platform that teams use to centralize their secrets like API keys, database credentials, and configurations.

This is the official native Ruby SDK — it talks directly to the Infisical REST API and has no Rust/FFI dependency. It replaces the deprecated `infisical-sdk` gem that was built on Infisical's legacy cross-language architecture, so it is **not** a drop-in replacement: the public API differs from the old gem.

## Installation

```ruby
gem "infisical-sdk"
```

## Quick start

```ruby
require "infisical"

client = Infisical::Client.new

client.auth.universal_auth_login(
  client_id: ENV.fetch("INFISICAL_CLIENT_ID"),
  client_secret: ENV.fetch("INFISICAL_CLIENT_SECRET")
)

secrets = client.secrets.list(
  project_id: "<your-project-id>",
  environment: "dev"
)

secrets.each { |secret| puts "#{secret.secret_key}=#{secret.secret_value}" }
```

### Authentication

```ruby
# Universal Auth (machine identity client id/secret)
client.auth.universal_auth_login(client_id: "...", client_secret: "...")

# Or use a token you already have
client.auth.access_token("existing-access-token")
```

### Secrets

```ruby
client.secrets.list(project_id: "...", environment: "dev", secret_path: "/")
client.secrets.get("DATABASE_URL", project_id: "...", environment: "dev")
client.secrets.create("DATABASE_URL", "postgres://...", project_id: "...", environment: "dev")
client.secrets.update("DATABASE_URL", project_id: "...", environment: "dev", secret_value: "postgres://...")
client.secrets.delete("DATABASE_URL", project_id: "...", environment: "dev")
```

### Self-hosted instances

```ruby
client = Infisical::Client.new(site_url: "https://your-infisical-instance.com")
```

## Documentation

You can find the documentation for the Ruby SDK on our [SDK documentation page](https://infisical.com/docs/sdks/languages/ruby).

## Development

```bash
bin/setup        # bundle install
bundle exec rspec
bundle exec rubocop
```

## Security

Please do not file GitHub issues or post on our public forum for security vulnerabilities, as they are public!

Infisical takes security issues very seriously. If you have any concerns about Infisical or believe you have uncovered a vulnerability, please get in touch via the e-mail address security@infisical.com. In the message, try to provide a description of the issue and ideally a way of reproducing it. The security team will get back to you as soon as possible.

Note that this security address should be used only for undisclosed vulnerabilities. Please report any security problems to us before disclosing it publicly.
