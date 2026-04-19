require "../spec_helper"

module XLSX
  class Builder
    def rows
      @rows
    end
  end
end

Spectator.describe XLSX::Builder do
  let(io) { IO::Memory.new }

  subject { XLSX::Builder.new(io) }

  describe "#row" do
    context "splat form" do
      it "accepts string values" do
        expect { subject.row("name", "age") }.not_to raise_error
      end

      it "accepts mixed CellValue types" do
        expect { subject.row("alice", 30.0, true, XLSX::Empty::INSTANCE, nil) }.not_to raise_error
      end
    end

    context "enumerable form" do
      it "accepts an array of values" do
        values = ["name", "age"] of XLSX::CellValue
        expect { subject.row(values) }.not_to raise_error
      end
    end

    it "accumulates rows in order" do
      subject.row("a", "b")
      subject.row("c", "d")
      rows = subject.rows
      expect(rows.size).to eq(2)
      expect(rows[0]).to eq(["a", "b"] of XLSX::CellValue)
      expect(rows[1]).to eq(["c", "d"] of XLSX::CellValue)
    end
  end

  describe "#close" do
    it "raises NotImplementedError until the ZIP writer is implemented" do
      expect { subject.close }.to raise_error(NotImplementedError)
    end
  end
end
