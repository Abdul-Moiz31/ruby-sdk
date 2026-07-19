# frozen_string_literal: true

module Infisical
  # Base class for all errors raised by this SDK. Rescue this to catch
  # anything Infisical-related.
  class Error < StandardError; end

  # Raised when the Infisical API responds with a non-2xx status. Well-known
  # statuses raise a subclass ({AuthenticationError}, {PermissionError},
  # {NotFoundError}, {RateLimitError}, {ServerError}); rescuing this class
  # catches them all.
  class APIError < Error
    # @return [Integer] HTTP status code of the failed response
    attr_reader :status

    # @return [String] full URL the failed request was sent to
    attr_reader :url

    # @return [String] uppercase HTTP method of the failed request, e.g. "GET"
    attr_reader :http_method

    # @return [String, nil] server-assigned request id, when the response carried one
    attr_reader :request_id

    # Returns the error class that best matches an HTTP status, falling back
    # to {APIError} itself. Constants are resolved at call time, so the
    # subclasses defined below are visible here.
    #
    # @param status [Integer] HTTP status code
    # @return [Class<APIError>]
    def self.for_status(status)
      case status
      when 401 then AuthenticationError
      when 403 then PermissionError
      when 404 then NotFoundError
      when 429 then RateLimitError
      when 500..599 then ServerError
      else self
      end
    end

    # @param message [String] human-readable error detail from the API
    # @param status [Integer] HTTP status code
    # @param url [String] full URL the request was sent to
    # @param http_method [String] HTTP method of the request
    # @param request_id [String, nil] server-assigned request id, if any
    def initialize(message, status:, url:, http_method:, request_id: nil)
      @status = status
      @url = url
      @http_method = http_method
      @request_id = request_id

      context = "[Method=#{http_method}] [URL=#{url}] [StatusCode=#{status}]"
      context += " [RequestId=#{request_id}]" if request_id

      super("#{context} #{message}")
    end
  end

  # Raised on HTTP 401: missing, expired, or invalid credentials.
  class AuthenticationError < APIError; end

  # Raised on HTTP 403: the authenticated identity lacks permission for the
  # requested resource or action.
  class PermissionError < APIError; end

  # Raised on HTTP 404: the secret, project, environment, or path does not
  # exist (or is not visible to the authenticated identity).
  class NotFoundError < APIError; end

  # Raised on HTTP 429, after the client has exhausted its automatic retries.
  class RateLimitError < APIError; end

  # Raised on HTTP 5xx: the Infisical server failed to process the request.
  class ServerError < APIError; end

  # Raised when the request itself fails (network/timeout) before a
  # response is received. Always raised from inside a `rescue` for the
  # underlying network exception, so Ruby's built-in `Exception#cause`
  # already carries it through; no need to track it ourselves.
  class RequestError < Error; end
end
