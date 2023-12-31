# frozen_string_literal: true

require "datadog/statsd"
require "json"
require "uri"

module DegicaDatadog
  # Configuration for the Datadog agent.
  module Config
    class << self
      def enabled?
        %w[production staging].include?(environment) || ENV.fetch("DD_AGENT_URI", nil)
      end

      def statsd_client
        @statsd_client ||= Datadog::Statsd.new(datadog_agent_host, statsd_port)
      end

      def service
        ENV.fetch("SERVICE_NAME", nil)
      end

      def version
        ENV.fetch("_GIT_REVISION", nil)
      end

      def environment
        ENV.fetch("RAILS_ENV", nil)
      end

      # URI including http:// prefix & port for the tracing endpoint, or nil.
      def datadog_agent_uri
        return unless enabled?

        ecs_meta_file = ENV.fetch("ECS_CONTAINER_METADATA_FILE", nil)
        if ecs_meta_file
          host_ip = JSON.parse(File.read(ecs_meta_file))&.dig("HostPrivateIPv4Address")
          return URI.parse(format("http://%s:9126", host_ip)) if host_ip
        end

        env_uri = ENV.fetch("DD_AGENT_URI", nil)
        URI.parse(env_uri) unless env_uri.nil?
      end

      def datadog_agent_host
        datadog_agent_uri&.host || "localhost"
      end

      def statsd_port
        tracing_port - 1
      end

      def tracing_port
        datadog_agent_uri&.port || 8126
      end
    end
  end
end
