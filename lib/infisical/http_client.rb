# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "time"

require_relative "errors"

module Infisical
  # Thin wrapper around Net::HTTP that knows how to talk to the Infisical
  # API: bearer token auth, JSON (de)serialization, and retrying transient
  # failures with exponential backoff + jitter.
  class HTTPClient
    DEFAULT_TIMEOUT = 10 # seconds
    DEFAULT_MAX_RETRIES = 4
    DEFAULT_INITIAL_DELAY = 1.0 # seconds
    DEFAULT_BACKOFF_FACTOR = 2
    JITTER_RATIO = 0.2 # +/- 20%

    RETRYABLE_EXCEPTIONS = [
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Net::OpenTimeout,
      Net::ReadTimeout,
      SocketError,
      IOError
    ].freeze

    def initialize(base_url:, timeout: DEFAULT_TIMEOUT, max_retries: DEFAULT_MAX_RETRIES,
                   initial_delay: DEFAULT_INITIAL_DELAY, backoff_factor: DEFAULT_BACKOFF_FACTOR,
                   sleeper: ->(seconds) { sleep(seconds) })
      @base_url = base_url.end_with?("/") ? base_url : "#{base_url}/"
      @timeout = timeout
      @max_retries = max_retries
      @initial_delay = initial_delay
      @backoff_factor = backoff_factor
      @sleeper = sleeper
      @access_token = nil
    end

    attr_writer :access_token

    def get(path, params: {})
      request(:get, path, params: params)
    end

    def post(path, body: nil, params: {})
      request(:post, path, body: body, params: params)
    end

    def patch(path, body: nil, params: {})
      request(:patch, path, body: body, params: params)
    end

    def delete(path, body: nil, params: {})
      request(:delete, path, body: body, params: params)
    end

    # Computes the (pre-jitter) backoff delay for a given retry attempt
    # (0-indexed). Exposed for testing.
    def self.backoff_delay(attempt, initial_delay: DEFAULT_INITIAL_DELAY, backoff_factor: DEFAULT_BACKOFF_FACTOR)
      initial_delay * (backoff_factor**attempt)
    end

    private

    def request(method, path, body: nil, params: {})
      uri = build_uri(path, params)

      attempt = 0
      begin
        response = perform(method, uri, body)
        handle_response(response, method: method, uri: uri)
      rescue *RETRYABLE_EXCEPTIONS => e
        raise RequestError, "request to #{uri} failed: #{e.message}" if attempt >= @max_retries

        attempt += 1
        wait_before_retry(attempt)
        retry
      rescue RetryableAPIError => e
        raise e.api_error if attempt >= @max_retries

        attempt += 1
        wait_before_retry(attempt, override: e.retry_after)
        retry
      end
    end

    def build_uri(path, params)
      uri = URI.join(@base_url, path)
      filtered = params.compact
      uri.query = URI.encode_www_form(filtered) unless filtered.empty?
      uri
    end

    def perform(method, uri, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = build_request(method, uri, body)
      http.request(request)
    end

    def build_request(method, uri, body)
      request_class = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        patch: Net::HTTP::Patch,
        delete: Net::HTTP::Delete
      }.fetch(method)

      request = request_class.new(uri)
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{@access_token}" if @access_token

      unless body.nil?
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
      end

      request
    end

    def handle_response(response, method:, uri:)
      status = response.code.to_i
      if status == 429
        raise RetryableAPIError.new(build_api_error(response, status, method, uri),
                                    retry_after: parse_retry_after(response["Retry-After"]))
      end
      raise build_api_error(response, status, method, uri) unless (200..299).cover?(status)

      parse_body(response.body)
    end

    # Retry-After is usually an integer/float number of seconds, but per
    # RFC 9110 it may also be an HTTP-date.
    def parse_retry_after(value)
      return nil if value.nil? || value.empty?

      begin
        Float(value)
      rescue ArgumentError, TypeError
        begin
          seconds = Time.httpdate(value) - Time.now
          seconds.positive? ? seconds : nil
        rescue ArgumentError
          nil
        end
      end
    end

    def build_api_error(response, status, method, uri)
      data = parse_body(response.body)
      message = data.is_a?(Hash) ? (data["message"] || data["error"] || response.body) : response.body

      APIError.new(
        message.to_s,
        status: status,
        url: uri.to_s,
        method: method.to_s.upcase,
        request_id: response["x-request-id"]
      )
    end

    def parse_body(raw)
      return nil if raw.nil? || raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end

    def wait_before_retry(attempt, override: nil)
      if override
        @sleeper.call(override)
        return
      end

      base = self.class.backoff_delay(attempt - 1, initial_delay: @initial_delay, backoff_factor: @backoff_factor)
      jitter = base * JITTER_RATIO * ((rand * 2) - 1)
      @sleeper.call(base + jitter)
    end

    # Internal-only signal so 429s share the same retry path as network
    # errors without retrying every other 4xx/5xx status. Carries the
    # server's Retry-After hint (if any) so the wait honors it instead of
    # our own computed backoff.
    class RetryableAPIError < StandardError
      attr_reader :api_error, :retry_after

      def initialize(api_error, retry_after: nil)
        @api_error = api_error
        @retry_after = retry_after
        super(api_error.message)
      end
    end
    private_constant :RetryableAPIError
  end
end
