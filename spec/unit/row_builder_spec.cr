require "../spec_helper"

Spectator.describe XLSX::RowBuilder do
  subject { XLSX::RowBuilder.new(3) }

  describe "#row_id" do
    it "returns the 1-based row id" do
      expect(subject.row_id).to eq(3)
    end
  end

  describe "#cells" do
    it "populates cells from block return values" do
      subject.cells(1..3) { |col_id| (col_id * 10).to_f }
      row = subject.build
      expect(row[1]).to eq(10.0)
      expect(row[2]).to eq(20.0)
      expect(row[3]).to eq(30.0)
    end

    it "yields 1-based column IDs matching the span" do
      seen = [] of Int32
      subject.cells(2..4) { |col_id| seen << col_id; nil }
      expect(seen).to eq([2, 3, 4])
    end
  end

  describe "#[]=" do
    it "sets a cell at a given col_id" do
      subject[2] = "hello"
      expect(subject.build[2]).to eq("hello")
    end

    it "overwrites a value previously set by #cells" do
      subject.cells(1..3) { |_| "default" }
      subject[2] = "overridden"
      expect(subject.build[2]).to eq("overridden")
    end
  end

  describe "#build" do
    it "returns a Row with the correct row_id" do
      expect(subject.build.row_id).to eq(3)
    end

    it "returns a Row containing all assigned cells" do
      subject[1] = "A"
      subject[3] = "B"
      row = subject.build
      expect(row[1]).to eq("A")
      expect(row[3]).to eq("B")
      expect(row[2]).to be_nil
    end

    it "returns an empty Row when nothing was assigned" do
      expect(subject.build.empty?).to be_true
    end
  end
end
