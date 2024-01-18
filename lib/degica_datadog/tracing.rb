# frozen_string_literal: true

require "ddtrace"
require "rails"

module DegicaDatadog
  # Tracing related functionality.
  module Tracing
    class << self
      # Initialize Datadog tracing. Call this in from config/application.rb.
      def init # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        return unless Config.enabled?

        require "ddtrace/auto_instrument"

        Datadog.configure do |c|
          c.service = Config.service
          c.env = Config.environment
          c.version = Config.version
          # These are for source code linking.
          c.tags = {
            "git.commit.sha" => Config.version,
            "git.repository_url" => Config.repository_url
          }

          c.agent.host = Config.datadog_agent_host
          c.agent.port = Config.tracing_port

          c.runtime_metrics.enabled = true
          c.runtime_metrics.statsd = Statsd.client

          c.tracing.partial_flush.enabled = true
          c.tracing.partial_flush.min_spans_threshold = 2_000

          c.tracing.instrument :rails,
                               service_name: Config.service,
                               request_queueing: true
          c.tracing.instrument :sidekiq, { tag_args: true }
        end
      end

      # Start a new span.
      def span!(name, **options, &block)
        enrich_span_options!(options)
        Datadog::Tracing.trace(name, **options, &block)
      end

      # Set tags on the current tracing span.
      def span_tags!(**tags)
        return unless Config.enabled?

        current_span = Datadog::Tracing.active_span
        tags.each do |k, v|
          current_span&.set_tag(k.to_s, v)
        end
      end

      # Please don't use this. It's just a temporary thing until we can get the
      # statsd agent installed
      def root_span_tags!(**tags)
        return unless Config.enabled?

        # forgive me my friends
        root_span = Datadog::Tracing.active_trace.instance_variable_get(:@root_span)
        tags.each do |k, v|
          root_span&.set_tag(k.to_s, v)
        end
      end

      # To pass in nested data to DD we need to pass keys separated with a "."
      # eg, "outer.inner". This method takes a nested hash and flattens it by
      # creating DD compatible key names.
      def flatten_hash_for_span(hsh, key = nil) # rubocop:disable Metrics/MethodLength
        flattened_hash = {}
        hsh.each do |k, v|
          flattened_key = [key, k].compact.join(".")

          if v.is_a? Hash
            flattened_sub_hash = flatten_hash_for_span(v, flattened_key)
            flattened_hash.merge! flattened_sub_hash
          else
            flattened_hash.merge! "#{flattened_key}": v
          end
        end

        flattened_hash
      end

      # Merge in default tags and service name.
      def enrich_span_options!(options)
        options[:service] = Config.service

        if options[:tags]
          options[:tags].merge!(default_span_tags)
        else
          options[:tags] = default_span_tags
        end
      end

      def default_span_tags
        {
          "env" => Config.environment,
          "version" => Config.version,
          "service" => Config.service,
          "git.commit.sha" => Config.version,
          "git.repository_url" => Config.repository_url
        }
      end
    end
  end
end
