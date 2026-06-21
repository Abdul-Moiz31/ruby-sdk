# frozen_string_literal: true

module Infisical
  # Base class for all errors raised by this SDK.
  class Error < StandardError; end

  # Raised when the Infisical API responds with a non-2xx status.
  class APIError < Error
    attr_reader :status, :url, :method, :request_id

    def initialize(message, status:, url:, method:, request_id: nil)
      @status = status
      @url = url
      @method = method
      @request_id = request_id

      context = "[Method=#{method}] [URL=#{url}] [StatusCode=#{status}]"
      context += " [RequestId=#{request_id}]" if request_id

      super("#{context} #{message}")
    end
  end

  # Raised when the request itself fails (network/timeout) before a
  # response is received.
  class RequestError < Error
    def initialize(message, cause: nil)
      super(message)
      @cause = cause if cause
    end
  end
end
