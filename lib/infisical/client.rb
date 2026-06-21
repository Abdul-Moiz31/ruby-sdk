# frozen_string_literal: true

require_relative "http_client"
require_relative "auth"
require_relative "secrets"

module Infisical
  # Entry point for the SDK. Construct one, authenticate via `auth`, then
  # use `secrets` (and future resource clients) to talk to Infisical.
  class Client
    DEFAULT_SITE_URL = "https://app.infisical.com"

    def initialize(site_url: DEFAULT_SITE_URL, timeout: HTTPClient::DEFAULT_TIMEOUT)
      @http_client = HTTPClient.new(base_url: site_url, timeout: timeout)
    end

    def auth
      @auth ||= Auth.new(@http_client)
    end

    def secrets
      @secrets ||= Secrets.new(@http_client)
    end
  end
end
