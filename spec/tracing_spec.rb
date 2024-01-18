# frozen_string_literal: true

RSpec.describe DegicaDatadog::Tracing do
  describe ".enrich_span_options!" do
    it "adds the service name" do
      options = {}
      described_class.enrich_span_options!(options)
      expect(options[:service]).to eq(DegicaDatadog::Config.service)
    end

    it "adds the default tags if none are present" do
      options = {}
      described_class.enrich_span_options!(options)
      expect(options[:tags]).to eq(DegicaDatadog::Tracing.default_span_tags)
    end

    it "merges the default tags with the provided tags" do
      options = { tags: { "foo" => "bar" } }
      described_class.enrich_span_options!(options)
      expect(options[:tags]).to eq(DegicaDatadog::Tracing.default_span_tags.merge("foo" => "bar"))
    end

    it "overrides the provided tags with default tags" do
      options = { tags: { "env" => "test" } }
      described_class.enrich_span_options!(options)
      expect(options[:tags]).to eq(DegicaDatadog::Tracing.default_span_tags)
    end
  end
end
