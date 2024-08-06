# frozen_string_literal: true

module DegicaDatadog
  # StatsD related functionality.
  module Statsd
    class << self
      # Record a timing for the supplied block. Creates a series of
      # metrics:
      # - <name>.count
      # - <name>.max
      # - <name>.median
      # - <name>.avg
      # - <name>.95percentile
      #
      # The reported time is in milliseconds.
      def with_timing(name, tags: {})
        if Config.enabled?
          start = Time.now.to_f
          begin
            yield
          ensure
            finish = Time.now.to_f
            client.histogram(name, (finish - start) * 1_000, tags: format_tags(tags))
          end
        else
          yield
        end
      end

      # Record a count of something (e.g. a payment going through). Use
      # the amount parameter to register several of a thing, or to
      # decrement the counter with a negative amount. All recorded amounts
      # are summed together to calculate the metric.
      def count(name, amount: 1, tags: {})
        return unless Config.enabled?

        client.count(name, amount, tags: format_tags(tags))
      end

      # Record the current value of something (e.g. the depth of a queue).
      # The metric equals the last recorded value.
      def gauge(name, value, tags: {})
        return unless Config.enabled?

        client.gauge(name, value, tags: format_tags(tags))
      end

      # Record a value of something for a distribution (e.g. the size of a
      # file or a fraud risk score). This will create a metric that has
      # various percentiles enabled.
      def distribution(name, value, tags: {})
        return unless Config.enabled?

        client.distribution(name, value, tags: format_tags(tags))
      end

      # Record an item for a set size metric. This will create a
      # gauge-type metric that shows the count of unique set items over
      # time (but not the individual items).
      def set(name, item, tags: {})
        return unless Config.enabled?

        client.set(name, item, tags: format_tags(tags))
      end

      def client
        Config.statsd_client
      end

      def default_tags
        {
          "service" => Config.service,
          "env" => Config.environment,
          "version" => Config.version,
          # These are specifically for source code linking.
          "git.commit.sha" => Config.version,
          "git.repository_url" => Config.repository_url
        }
      end

      # Add in default tags and transform:
      #
      # { "foo" => 42, "bar" => 23 } => ["foo:42", "bar:23"]
      #
      # Default tags take precedence, to avoid messing up metrics because
      # of name clashes.
      def format_tags(tags)
        tags.merge(default_tags).map { |k, v| "#{k}:#{v}" }
      end
    end
  end
end
