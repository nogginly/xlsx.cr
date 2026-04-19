require "../spec_helper"

Spectator.describe XLSX::Internal::SharedStrings do
  subject { XLSX::Internal::SharedStrings.new }

  describe "#intern / #[]" do
    it "returns 0 for the first interned string" do
      expect(subject.intern("hello")).to eq(0)
    end

    it "returns incrementing indices for distinct strings" do
      subject.intern("a")
      expect(subject.intern("b")).to eq(1)
    end

    it "returns the same index for repeated values" do
      idx = subject.intern("hello")
      expect(subject.intern("hello")).to eq(idx)
    end

    it "round-trips through []" do
      idx = subject.intern("world")
      expect(subject[idx]).to eq("world")
    end

    it "raises IndexError for an out-of-bounds index" do
      expect { subject[99] }.to raise_error(IndexError)
    end
  end

  describe "#size" do
    it "is 0 initially" do
      expect(subject.size).to eq(0)
    end

    it "grows with each unique string" do
      subject.intern("a")
      subject.intern("b")
      subject.intern("a") # duplicate — should not grow
      expect(subject.size).to eq(2)
    end
  end

  describe "#parse" do
    let(xml) do
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3">
        <si><t>Alice</t></si>
        <si><t>Bob</t></si>
        <si><t>42</t></si>
      </sst>
      XML
    end

    before_each { subject.parse(xml) }

    it "populates strings by index" do
      expect(subject[0]).to eq("Alice")
      expect(subject[1]).to eq("Bob")
      expect(subject[2]).to eq("42")
    end

    it "sets size to the number of entries" do
      expect(subject.size).to eq(3)
    end
  end

  describe "#to_xml" do
    before_each do
      subject.intern("Alice")
      subject.intern("Bob")
    end

    it "produces valid XML containing all strings" do
      xml = subject.to_xml
      expect(xml).to contain("Alice")
      expect(xml).to contain("Bob")
    end

    it "round-trips through #parse" do
      xml = subject.to_xml
      fresh = XLSX::Internal::SharedStrings.new
      fresh.parse(xml)
      expect(fresh[0]).to eq("Alice")
      expect(fresh[1]).to eq("Bob")
    end
  end
end
