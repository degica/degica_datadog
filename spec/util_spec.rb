# frozen_string_literal: true

RSpec.describe DegicaDatadog::Util do
  describe ".path_group" do
    it "returns nil for non-strings" do
      expect(described_class.path_group(nil)).to be_nil
      expect(described_class.path_group(42)).to be_nil
      expect(described_class.path_group([])).to be_nil
    end

    it "returns '/' for empty strings" do
      expect(described_class.path_group("")).to eq("/")
    end

    it "returns the path for strings without numbers" do
      expect(described_class.path_group("/foo/bar")).to eq("/foo/bar")
    end

    it "returns the path with segments containing digits replaced with ?" do
      expect(described_class.path_group("/foo/42")).to eq("/foo/?")
      expect(described_class.path_group("/foo/42/bar")).to eq("/foo/?/bar")
      expect(described_class.path_group("/foo/v42uuid/bar")).to eq("/foo/?/bar")
    end

    it "keeps segments that look like API versioning" do
      expect(described_class.path_group("/api/v1/foo")).to eq("/api/v1/foo")
      expect(described_class.path_group("/api/v1/foo/42")).to eq("/api/v1/foo/?")
    end
  end
end
