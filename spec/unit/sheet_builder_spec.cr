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

    it "yields RowBuilder instances" do
      subject.rows(1..1) { |rb, _| expect(rb).to be_a(XLSX::RowBuilder) }
    end
  end

  describe "#build" do
    before_each do
      subject.rows(2..4) do |row, row_id|
        row.cells(1..2) { |col_id| "R#{row_id}C#{col_id}" }
      end
    end

    it "returns a Sheet" do
      expect(subject.build).to be_a(XLSX::Sheet)
    end

    it "the sheet has the correct name" do
      expect(subject.build.name).to eq("Sales")
    end

    it "the sheet contains cells built by each RowBuilder" do
      sheet = subject.build
      expect(sheet[2, 1]).to eq("R2C1")
      expect(sheet[3, 2]).to eq("R3C2")
      expect(sheet[4, 1]).to eq("R4C1")
    end

    it "row IDs match the span" do
      row_ids = [] of Int32
      subject.build.each_row { |_, row_id| row_ids << row_id }
      expect(row_ids).to eq([2, 3, 4])
    end
  end
end
