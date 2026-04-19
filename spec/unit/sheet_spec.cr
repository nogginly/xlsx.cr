require "../spec_helper"

Spectator.describe XLSX::Sheet do
  let(row1) do
    cells = {} of Int32 => XLSX::CellValue
    cells[1] = "A"
    cells[2] = "B"
    XLSX::Row.new(1, cells)
  end

  let(row3) do
    cells = {} of Int32 => XLSX::CellValue
    cells[1] = 42.0
    XLSX::Row.new(3, cells)
  end

  # Rows 1 and 3 are present; row 2 is absent.
  subject { XLSX::Sheet.new("Sales", {1 => row1, 3 => row3}) }

  describe "#name" do
    it "returns the sheet name" do
      expect(subject.name).to eq("Sales")
    end
  end

  describe "#row_span" do
    it "spans from the first to last present row_id" do
      expect(subject.row_span).to eq(1..3)
    end

    context "with no rows" do
      subject { XLSX::Sheet.new("Empty", {} of Int32 => XLSX::Row) }

      it "raises on an empty sheet" do
        expect { subject.row_span }.to raise_error(Enumerable::EmptyError)
      end
    end
  end

  describe "#each_row" do
    it "yields rows in ascending row_id order" do
      row_ids = [] of Int32
      subject.each_row { |_, row_id| row_ids << row_id }
      expect(row_ids).to eq([1, 3])
    end

    it "skips absent rows" do
      row_ids = [] of Int32
      subject.each_row { |_, row_id| row_ids << row_id }
      expect(row_ids).not_to contain(2)
    end
  end

  describe "#[]" do
    it "returns the cell at a present row and col" do
      expect(subject[1, 1]).to eq("A")
      expect(subject[1, 2]).to eq("B")
      expect(subject[3, 1]).to eq(42.0)
    end

    it "returns nil for an absent col in a present row" do
      expect(subject[1, 9]).to be_nil
    end

    it "returns nil for an absent row" do
      expect(subject[2, 1]).to be_nil
    end
  end

  describe "#row_count" do
    it "returns the number of present rows" do
      expect(subject.row_count).to eq(2)
    end
  end

  describe "#empty?" do
    it "is false when rows are present" do
      expect(subject.empty?).to be_false
    end

    context "with no rows" do
      subject { XLSX::Sheet.new("Empty", {} of Int32 => XLSX::Row) }

      it "is true" do
        expect(subject.empty?).to be_true
      end
    end
  end
end
