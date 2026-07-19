# frozen_string_literal: true

require "uri"

require_relative "http_client"
require_relative "auth"
require_relative "secrets"

module Infisical
  # Entry point for the SDK. Construct one, authenticate via {#auth}, then
  # use {#secrets} (and future resource clients) to talk to Infisical.
  #
  # @example Fetch a secret
  #   client = Infisical::Client.new
  #   client.auth.universal_auth_login(client_id: "...", client_secret: "...")
  #   secret = client.secrets.get("DATABASE_URL", project_id: "...", environment: "dev")
  #   secret.secret_value # => "postgres://..."
  class Client
    DEFAULT_SITE_URL = "https://app.infisical.com"
    ALLOWED_SCHEMES = %w[http https].freeze

    # @param site_url [String] base URL of the Infisical instance; defaults to
    #   Infisical Cloud, so only self-hosted deployments need to set it
    # @param timeout [Numeric] open/read timeout in seconds for each request
    # @raise [ArgumentError] if site_url is not an http(s) URL
    def initialize(site_url: DEFAULT_SITE_URL, timeout: HTTPClient::DEFAULT_TIMEOUT)
      validate_site_url!(site_url)
      @http_client = HTTPClient.new(base_url: site_url, timeout: timeout)
    end

    # Authentication operations. Logging in through this authenticates the
    # whole client, since all resource clients share one HTTP client.
    #
    # @return [Auth]
    def auth
      @auth ||= Auth.new(@http_client)
    end

    # Secret CRUD operations.
    #
    # @return [Secrets]
    def secrets
      @secrets ||= Secrets.new(@http_client)
    end

    private

    def validate_site_url!(site_url)
      uri = URI.parse(site_url)
      return if ALLOWED_SCHEMES.include?(uri.scheme) && uri.host

      raise ArgumentError, "site_url must be an http(s) URL, got: #{site_url.inspect}"
    rescue URI::InvalidURIError
      raise ArgumentError, "site_url is not a valid URL: #{site_url.inspect}"
    end
  end
end
