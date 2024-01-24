# Degica Datadog

Internal library for StatsD and tracing.

## Setup

1. Grab the gem from GitHub:
    ```ruby
    gem 'degica_datadog', git: "https://github.com/degica/degica_datadog.git", branch: "main"
    ```
1. Set the `SERVICE_NAME` environment variable to the name of your service.
1. Then add this to your `config/application.rb` to enable tracing:
    ```ruby
    require "degica_datadog"

    # Config.init is optional if you don't need to set any special config.
    DegicaDatadog::Config.init(
      service_name: "hats",
      version: "1.3",
      environment: "staging",
      repository_url: "github.com/degica/not-hats"
    )
    DegicaDatadog::Tracing.init
    ```

### Custom Logging

Note that you will need to manually setup log correlation for tracing if you use a custom logging setup. This is the relevant bit from `hats`:

```ruby
structured_log.merge!({
  "dd.env" => Datadog::Tracing.correlation.env,
  "dd.service" => Datadog::Tracing.correlation.service,
  "dd.version" => Datadog::Tracing.correlation.version,
  "dd.trace_id" => Datadog::Tracing.correlation.trace_id,
  "dd.span_id" => Datadog::Tracing.correlation.span_id
}.compact)
```

### Rake Tasks

If you want to instrument rake tasks, you will need to add this snippet to your `Rakefile`:

```ruby
require "degica_datadog"
DegicaDatadog::Config.init(service_name: "hats")
DegicaDatadog::Tracing.init(rake_tasks: Rake::Task.tasks.map(&:name))
```

This is because you might not want to instrument all rake tasks, though there should be no significant overhead from doing so. Alternatively you can pass an array of strings containing the task names to instrument.

## StatsD

This library exposes various different metric types. Please see the [Datadog Handbook](https://www.notion.so/The-Datadog-Handbook-b69e58b686f54bf795b36f97746a31ea) for details.

```ruby
tags: {
    some_tag: 42,
}

DegicaDatadog::Statsd.with_timing("my_timing", tags: tags) do
    do_a_thing
end
DegicaDatadog::Statsd.count("my_count", amount: 1, tags: tags)
DegicaDatadog::Statsd.gauge("my_gauge", 4, tags: tags)
DegicaDatadog::Statsd.distribution("my_distribution", 8, tags: tags)
DegicaDatadog::Statsd.set("my_distribution", payment, tags: tags)
```

## Tracing

The setup above auto-instruments many components of the system, but you can add additional spans or span tags:

```ruby
# Create a new span.
DegicaDatadog::Tracing.span!("hats.process_payment") do
  # Process a payment.
end

# Optionally specify a resource and/or tags.
resource = webhook.provider.name
tags = {
    "merchant_uuid" => merchant.uuid,
    "merchant_name" => merchant.name,
}
DegicaDatadog::Tracing.span!("hats.send_webhook", resource: resource, tags: tags) do
  # Process a payment.
end

# Add tags to the current span.
DegicaDatadog::Tracing.span_tags!(**tags)

# Add tags to the current root span.
DegicaDatadog::Tracing.root_span_tags!(**tags)
```