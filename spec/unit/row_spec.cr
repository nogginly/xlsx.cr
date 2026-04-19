require "../spec_helper"

Spectator.describe XLSX::Row do
  # A sparse row: cols 1, 3, 5 are present; 2 and 4 are absent.
  let(cells) do
    cells = {} of Int32 => XLSX::CellValue
    cells[1] = "Alice"
    cells[3] = 42.0
    cells[5] = true
    cells
  end

  subject { XLSX::Row.new(2, cells) }

  describe "#row_id" do
    it "returns the 1-based row id" do
      expect(subject.row_id).to eq(2)
    end
  end

  describe "#[]" do
    it "returns the value at a present col_id" do
      expect(subject[1]).to eq("Alice")
      expect(subject[3]).to eq(42.0)
      expect(subject[5]).to eq(true)
    end

    it "returns nil for an absent col_id" do
      expect(subject[2]).to be_nil
      expect(subject[4]).to be_nil
      expect(subject[99]).to be_nil
    end
  end

  describe "#col_span" do
    it "spans from the first to last present col_id" do
      expect(subject.col_span).to eq(1..5)
    end

    context "with a single cell" do
      subject { XLSX::Row.new(1, {4 => "only".as(XLSX::CellValue)}) }

      it "returns a unit range" do
        expect(subject.col_span).to eq(4..4)
      end
    end

    context "with no cells" do
      subject { XLSX::Row.new(1, {} of Int32 => XLSX::CellValue) }

      it "raises on an empty row" do
        expect { subject.col_span }.to raise_error(Enumerable::EmptyError)
      end
    end
  end

  describe "#each_cell" do
    it "yields cells in ascending col_id order" do
      col_ids = [] of Int32
      subject.each_cell { |_, col_id| col_ids << col_id }
      expect(col_ids).to eq([1, 3, 5])
    end

    it "yields the correct value with each col_id" do
      results = [] of {XLSX::CellValue, Int32}
      subject.each_cell { |cell, col_id| results << {cell, col_id} }
      expect(results).to eq([{"Alice", 1}, {42.0, 3}, {true, 5}])
    end

    it "skips absent columns" do
      col_ids = [] of Int32
      subject.each_cell { |_, col_id| col_ids << col_id }
      expect(col_ids).not_to contain(2)
      expect(col_ids).not_to contain(4)
    end
  end

  describe "#size" do
    it "returns the count of present cells" do
      expect(subject.size).to eq(3)
    end
  end

  describe "#empty?" do
    it "is false when cells are present" do
      expect(subject.empty?).to be_false
    end

    context "with no cells" do
      subject { XLSX::Row.new(1, {} of Int32 => XLSX::CellValue) }

      it "is true" do
        expect(subject.empty?).to be_true
      end
    end
  end
end
