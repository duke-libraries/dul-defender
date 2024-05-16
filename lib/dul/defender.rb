# frozen_string_literal: true

require_relative "defender/version"
require 'rack/attack'
require 'logger'

module Dul
  module Defender
    class Error < StandardError; end

    PROGNAME = 'DUL Defender'

    OKD_CLUSTER = "10.138.5.0/24"

    def self.enabled=(bool)
      Rack::Attack.enabled = bool
    end

    # Disables rack-attack
    def self.disable!
      self.enabled = false

      logger.warn(PROGNAME) { "Dul::Defender is disabled." }
    end

    # Enables rack-attack
    def self.enable!
      self.enabled = true

      logger.info(PROGNAME) { "Dul::Defender is enabled." }
    end

    # Is rack-attack enabled?
    def self.enabled?
      Rack::Attack.enabled
    end

    # Clears rack-attack configuration and returns to defaults
    def self.clear!
      Rack::Attack.clear_configuration
    end

    # Syntactic sugar for config block with init
    def self.configure
      yield self

      disable! if defined?(Rails) && Rails.env.test? # disable in Rails test environment

      log_events if enabled?
    end

    # Sets the severity level of logging
    def self.log_level=(severity)
      if severity.is_a?(Integer)
        @log_level = severity
      else
        case severity.to_s.downcase
        when 'debug'
          @log_level = Logger::DEBUG
        when 'info'
          @log_level = Logger::INFO
        when 'warn'
          @log_level = Logger::WARN
        when 'error'
          @log_level = Logger::ERROR
        when 'fatal'
          @log_level = Logger::FATAL
        when 'unknown'
          @log_level = Logger::UNKNOWN
        else
          raise ArgumentError, "invalid log level: #{severity}"
        end
      end
    end

    def self.log_level
      @log_level ||= Logger::INFO
    end

    def self.log_events
      return unless Rack::Attack.notifier # nothing to log!

      Rack::Attack.notifier.subscribe(/rack_attack/) do |_name, _start, _finish, _instrumenter_id, payload|
        request = payload[:request]
        rack_attack_info = request.env.select { |key, _val| key.start_with?('rack.attack.') }
        request_info = %w[request_method path query_string referer user_agent].map { |meth| [meth, request.send(meth)] }.to_h
        request_info.merge! rack_attack_info

        logger.add(log_level, "#{request_info.inspect}", PROGNAME)
      end
    end

    def self.throttle_by_ip(limit:, period:, pattern: nil)
      pattern = Regexp.new(/\A#{pattern}\z/) if pattern.is_a?(String)

      limit, period = limit.to_i, period.to_i

      throttle = Rack::Attack.throttle('requests by ip', limit:, period:) do |request|
        request.ip if pattern.nil? || pattern.match?(request.path)
      end

      Rack::Attack.throttled_response_retry_after_header = true

      logger.info(PROGNAME) { "Throttling #{throttle.name}: max #{throttle.limit} requests every #{throttle.period} second(s) (pattern: #{pattern.inspect})" }
    end

    def self.safelist_okd_cluster
      Rack::Attack.safelist_ip(OKD_CLUSTER)

      logger.info(PROGNAME) { "Safelisted OKD cluster: #{OKD_CLUSTER}" }
    end

    def self.logger
      @logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
    end
  end
end
