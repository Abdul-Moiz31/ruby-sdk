# frozen_string_literal: true

require "uri"

require_relative "http_client"
require_relative "auth"
require_relative "secrets"

module Infisical
  # Entry point for the SDK. Construct one, authenticate via `auth`, then
  # use `secrets` (and future resource clients) to talk to Infisical.
  class Client
    DEFAULT_SITE_URL = "https://app.infisical.com"
    ALLOWED_SCHEMES = %w[http https].freeze

    def initialize(site_url: DEFAULT_SITE_URL, timeout: HTTPClient::DEFAULT_TIMEOUT)
      validate_site_url!(site_url)
      @http_client = HTTPClient.new(base_url: site_url, timeout: timeout)
    end

    def auth
      @auth ||= Auth.new(@http_client)
    end

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
