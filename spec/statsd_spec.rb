# frozen_string_literal: true

RSpec.describe DegicaDatadog::Statsd do
  let(:stub_client) { double }

  before do
    allow(DegicaDatadog::Config).to receive(:statsd_client) { stub_client }
  end

  describe ".with_timing" do
    context "when o11y is disabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(false)
      end

      it "returns the block's return value" do
        expect(described_class.with_timing("test") { 42 }).to eq(42)
      end
    end

    context "when o11y is enabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(true)
      end

      it "returns the block's return value" do
        expect(stub_client).to receive(:histogram)
        expect(described_class.with_timing("test") { 42 }).to eq(42)
      end

      it "still reports if the block raises an exception" do
        expect(stub_client).to receive(:histogram)
        expect do
          described_class.with_timing("test") { raise StandardError, "test" }
        end.to(raise_exception { |e| expect(e.to_s).to eq("test") })
      end
    end
  end

  describe ".count" do
    context "when o11y is disabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(false)
      end

      it "doesn't do anything" do
        described_class.count("test")
      end
    end

    context "when o11y is enabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(true)
      end

      it "records a metric" do
        expect(stub_client).to receive(:count)
        described_class.count("test")
      end
    end
  end

  describe ".gauge" do
    context "when o11y is disabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(false)
      end

      it "doesn't do anything" do
        described_class.gauge("test", 42)
      end
    end

    context "when o11y is enabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(true)
      end

      it "records a metric" do
        expect(stub_client).to receive(:gauge)
        described_class.gauge("test", 42)
      end
    end
  end

  describe ".distribution" do
    context "when o11y is disabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(false)
      end

      it "doesn't do anything" do
        described_class.distribution("test", 42)
      end
    end

    context "when o11y is enabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(true)
      end

      it "records a metric" do
        expect(stub_client).to receive(:distribution)
        described_class.distribution("test", 42)
      end
    end
  end

  describe ".set" do
    context "when o11y is disabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(false)
      end

      it "doesn't do anything" do
        described_class.set("test", 42)
      end
    end

    context "when o11y is enabled" do
      before do
        allow(DegicaDatadog::Config).to receive(:enabled?).and_return(true)
      end

      it "records a metric" do
        expect(stub_client).to receive(:set)
        described_class.set("test", 42)
      end
    end
  end
end
