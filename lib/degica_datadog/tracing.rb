# frozen_string_literal: true

require "datadog"

module DegicaDatadog
  # Tracing related functionality.
  module Tracing
    class << self
      # Initialize Datadog tracing. Call this in from config/application.rb.
      def init(rake_tasks: [])
        return unless Config.enabled?

        require "datadog/auto_instrument"

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

          # Enabling additional settings for these instrumentations.
          c.tracing.instrument :rails, request_queueing: true
          c.tracing.instrument :rack, request_queueing: true
          c.tracing.instrument :sidekiq, distributed_tracing: true, tag_args: true
          c.tracing.instrument :active_support, cache_service: Config.service
          c.tracing.instrument :active_record, service_name: Config.service
          c.tracing.instrument(:mysql2, service_name: "#{Config.service}-#{Config.environment}",
                                        comment_propagation: "full")
          c.tracing.instrument :elasticsearch, service_name: Config.service

          # If initialised with rake tasks, instrument those.
          c.tracing.instrument(:rake, service_name: Config.service, tasks: rake_tasks) if rake_tasks

          # All of these are HTTP clients.
          c.tracing.instrument :ethon, split_by_domain: true
          c.tracing.instrument :faraday, split_by_domain: true
          c.tracing.instrument :http, split_by_domain: true
          c.tracing.instrument :httpclient, split_by_domain: true
          c.tracing.instrument :httprb, split_by_domain: true
        end

        # This block is called before traces are sent to the agent, and allows
        # us to modify or filter them.
        Datadog::Tracing.before_flush(
          # Filter out health check spans.
          Datadog::Tracing::Pipeline::SpanFilter.new do |span|
            span.name == "rack.request" && span.get_tag("http.url")&.start_with?("/health_check")
          end,
          # Filter out static assets.
          Datadog::Tracing::Pipeline::SpanFilter.new do |span|
            span.name == "rack.request" &&
              (span.get_tag("http.url")&.start_with?("/assets") ||
               span.get_tag("http.url")&.start_with?("/packs"))
          end,
          # Filter out NewRelic reporter.
          Datadog::Tracing::Pipeline::SpanFilter.new do |span|
            span.service == "collector.newrelic.com"
          end,
          # Group subdomains in service tags together.
          Datadog::Tracing::Pipeline::SpanProcessor.new do |span|
            span.service = "myshopify.com" if span.service.end_with?("myshopify.com")
            span.service = "ngrok.io" if span.service.end_with?("ngrok.io")
            span.service = "ngrok-free.app" if span.service.end_with?("ngrok-free.app")
          end,
          # Set service tags for AWS services.
          Datadog::Tracing::Pipeline::SpanProcessor.new do |span|
            span.service = "aws" if %w[169.254.169.254 169.254.170.2].include?(span.get_tag("peer.hostname"))
          end,
          # Use method + path as the resource name for outbound HTTP requests.
          Datadog::Tracing::Pipeline::SpanProcessor.new do |span|
            if %w[ethon faraday net/http httpclient httprb].include?(span.get_tag("component"))
              # The path group is normally generated in the agent, later on. We
              # don't want to use the raw path in the resource name, as that
              # would create a lot of resources for any path that contains an
              # ID. The logic seems to be at least vaguely to replace any path
              # segment that contains a digit with a ?, so we're reproducing
              # that here.
              path_group = DegicaDatadog::Util.path_group(span.get_tag("http.url"))
              span.resource = "#{span.get_tag("http.method")} #{path_group}"
            end
          end
        )
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
      def flatten_hash_for_span(hsh, key = nil)
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
          "git.repository_url" => Config.repository_url,
          "component" => "degica_datadog",
          "span.kind" => "internal",
          "operation" => "custom_span"
        }
      end
    end
  end
end
