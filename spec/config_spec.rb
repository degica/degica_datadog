# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe DegicaDatadog::Config do
  describe ".enabled?" do
    it "is true on production" do
      allow(ENV).to receive(:fetch) { |key|
        { "RAILS_ENV" => "production" }.fetch(key, nil)
      }
      expect(!described_class.enabled?.nil?).to be(true)
    end

    it "is true on staging" do
      allow(ENV).to receive(:fetch) { |key|
        { "RAILS_ENV" => "staging" }.fetch(key, nil)
      }
      expect(!described_class.enabled?.nil?).to be(true)
    end

    it "is false on development" do
      allow(ENV).to receive(:fetch) { |key|
        { "RAILS_ENV" => "development" }.fetch(key, nil)
      }
      expect(!described_class.enabled?.nil?).to be(false)
    end

    it "is true if DD_AGENT_URI is set" do
      allow(ENV).to receive(:fetch) { |key|
        {
          "RAILS_ENV" => "development",
          "DD_AGENT_URI" => "some-uri"
        }.fetch(key, nil)
      }
      expect(!described_class.enabled?.nil?).to be(true)
    end

    it "is false when the env var flag is set" do
      allow(described_class).to receive(:disable_env_var_flag).and_return(true)
      expect(described_class.enabled?).to eq(false)
    end
  end

  describe ".datadog_agent_uri" do
    it "returns nil if described_class is disabled" do
      allow(described_class).to receive(:enabled?).and_return(false)
      expect(described_class.datadog_agent_uri).to be(nil)
    end

    it "returns the ECS IP + port 9126 on ECS" do
      allow(described_class).to receive(:enabled?).and_return(true)
      allow(ENV).to receive(:fetch) { |key|
        { "ECS_CONTAINER_METADATA_FILE" => "/somewhere" }.fetch(key, nil)
      }
      allow(File).to receive(:read).and_return('{"HostPrivateIPv4Address":"127.0.0.1"}')
      expect(described_class.datadog_agent_uri).to eq(URI.parse("http://127.0.0.1:9126"))
    end

    it "returns the URI from DD_AGENT_URI" do
      allow(described_class).to receive(:enabled?).and_return(true)
      allow(ENV).to receive(:fetch) { |key|
        { "DD_AGENT_URI" => "http://127.0.0.1:9126" }.fetch(key, nil)
      }
      expect(described_class.datadog_agent_uri).to eq(URI.parse("http://127.0.0.1:9126"))
    end

    it "prefers ECS settings over env vars" do
      allow(described_class).to receive(:enabled?).and_return(true)
      allow(ENV).to receive(:fetch) { |key|
        {
          "ECS_CONTAINER_METADATA_FILE" => "/somewhere",
          "DD_AGENT_URI" => "http://somewhere:1234"
        }.fetch(key, nil)
      }
      allow(File).to receive(:read).and_return('{"HostPrivateIPv4Address":"127.0.0.1"}')
      expect(described_class.datadog_agent_uri).to eq(URI.parse("http://127.0.0.1:9126"))
    end
  end

  describe ".datadog_agent_host" do
    it "defaults to localhst" do
      expect(described_class.datadog_agent_host).to eq("localhost")
    end

    it "uses the hsot from the URI" do
      allow(described_class).to receive(:datadog_agent_uri) { URI.parse("http://somewhere:1234") }
      expect(described_class.datadog_agent_host).to eq("somewhere")
    end
  end

  describe ".statsd_port" do
    it "defaults to 8125" do
      expect(described_class.statsd_port).to eq(8125)
    end

    it "uses the port one below the one from the URI" do
      allow(described_class).to receive(:datadog_agent_uri) { URI.parse("http://localhost:1234") }
      expect(described_class.statsd_port).to eq(1233)
    end
  end

  describe ".tracing_port" do
    it "defaults to 8126" do
      expect(described_class.tracing_port).to eq(8126)
    end

    it "uses the port from the URI" do
      allow(described_class).to receive(:datadog_agent_uri) { URI.parse("http://localhost:1234") }
      expect(described_class.tracing_port).to eq(1234)
    end
  end
end
# rubocop:enable Metrics/BlockLength
