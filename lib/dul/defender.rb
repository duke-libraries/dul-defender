# frozen_string_literal: true

require_relative "defender/version"
require 'rack/attack'
require 'logger'

module Dul
  module Defender
    class Error < StandardError; end

    PROGNAME = 'DUL Defender'

    def self.disable!
      Rack::Attack.enabled = false
    end

    def self.enable!
      Rack::Attack.enabled = true
    end

    def self.enabled?
      Rack::Attack.enabled
    end

    def self.configure
      yield self

      init
    end

    def self.log_events(log_level: Logger::WARN)
      require 'active_support/notifications'

      ActiveSupport::Notifications.subscribe(/rack_attack/) do |_name, _start, _finish, _instrumenter_id, payload|
        request = payload[:request]
        data = request.env.select { |key, _val| key.start_with?('rack.attack.') }

        logger.add(log_level, "#{request.fullpath} #{data.inspect}", PROGNAME)
      end

    rescue LoadError => _e
      raise Error, "Event logging requires ActiveSupport::Notifications"
    end

    def self.init
      return if @inited

      disable! if defined?(Rails) && Rails.env.test? # disable in Rails test environment

      if enabled?
        logger.info(PROGNAME) { "#{self} is enabled." }
      else
        logger.warn(PROGNAME) { "#{self} is disabled." }
      end

      @inited = true
    end

    def self.throttle_by_ip(limit:, period:, pattern: nil, retry_after_header: true)
      pattern = Regexp.new(/\A#{pattern}\z/) if pattern.is_a?(String)

      throttle = Rack::Attack.throttle('requests by ip', limit:, period:) do |request|
        request.ip if pattern.nil? || pattern.match?(request.path)
      end

      Rack::Attack.throttled_response_retry_after_header = retry_after_header

      logger.info(PROGNAME) { "Throttle #{throttle.name}: max #{throttle.limit} requests every #{throttle.period} second(s) (pattern: #{pattern.inspect})" }
    end

    def self.safelist_okd_cluster
      Rack::Attack.safelist_ip("10.138.5.0/24")
    end

    def self.logger
      @logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
    end
  end
end
