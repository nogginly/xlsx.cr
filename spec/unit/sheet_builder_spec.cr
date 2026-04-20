require "../spec_helper"

Spectator.describe XLSX::SheetBuilder do
  subject { XLSX::SheetBuilder.new("Sales") }

  describe "#name" do
    it "returns the sheet name" do
      expect(subject.name).to eq("Sales")
    end
  end

  describe "#rows" do
    it "yields a RowBuilder and 1-based row_id for each row in the span" do
      seen = [] of Int32
      subject.rows(3..5) { |_, row_id| seen << row_id }
      expect(seen).to eq([3, 4, 5])
    end

    it "advances next_row_id past the span" do
      subject.rows(1..3) { |_, _| }
      subject.append_row("after")
      sheet = subject.build
      row_ids = [] of Int32
      sheet.each_row { |_, id| row_ids << id }
      expect(row_ids).to contain(4)
    end
  end

  describe "#append_row" do
    context "splat form" do
      it "appends a row starting at row 1 on a blank builder" do
        subject.append_row("a", "b")
        sheet = subject.build
        expect(sheet[1, 1]).to eq("a")
        expect(sheet[1, 2]).to eq("b")
      end

      it "appends successive rows with incrementing row IDs" do
        subject.append_row("first")
        subject.append_row("second")
        sheet = subject.build
        expect(sheet[1, 1]).to eq("first")
        expect(sheet[2, 1]).to eq("second")
      end
    end

    context "enumerable form" do
      it "appends a row from an array" do
        subject.append_row(["x", 1.0] of XLSX::CellValue)
        sheet = subject.build
        expect(sheet[1, 1]).to eq("x")
        expect(sheet[1, 2]).to eq(1.0)
      end
    end
  end

  describe ".from_sheet" do
    let(existing_sheet) do
      rows = {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new("header".as(XLSX::CellValue))}),
        2 => XLSX::Row.new(2, {1 => XLSX::Cell.new("data".as(XLSX::CellValue))}),
      }
      XLSX::Sheet.new("Data", rows)
    end

    subject { XLSX::SheetBuilder.from_sheet(existing_sheet) }

    it "preserves the sheet name" do
      expect(subject.name).to eq("Data")
    end

    it "carries over existing rows" do
      sheet = subject.build
      expect(sheet[1, 1]).to eq("header")
      expect(sheet[2, 1]).to eq("data")
    end

    it "appends new rows after the last existing row" do
      subject.append_row("new")
      sheet = subject.build
      expect(sheet[3, 1]).to eq("new")
    end

    context "from an empty sheet" do
      subject { XLSX::SheetBuilder.from_sheet(XLSX::Sheet.new("Empty", {} of Int32 => XLSX::Row)) }

      it "appends starting at row 1" do
        subject.append_row("first")
        expect(subject.build[1, 1]).to eq("first")
      end
    end
  end

  describe "#build" do
    before_each do
      subject.rows(2..4) do |row, row_id|
        row.cells(1..2) { |col_id| "R#{row_id}C#{col_id}" }
      end
    end

    it "returns a Sheet with the correct name" do
      expect(subject.build.name).to eq("Sales")
    end

    it "contains cells built by each RowBuilder" do
      sheet = subject.build
      expect(sheet[2, 1]).to eq("R2C1")
      expect(sheet[3, 2]).to eq("R3C2")
    end
  end
end
