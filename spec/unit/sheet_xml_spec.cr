require "../spec_helper"

Spectator.describe XLSX::Internal::SheetXML do
  subject { XLSX::Internal::SheetXML.new }

  let(shared_strings) do
    ss = XLSX::Internal::SharedStrings.new
    ss.intern("Alice") # index 0
    ss.intern("Bob")   # index 1
    ss
  end

  let(sheet_xml) do
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <sheetData>
        <row r="1">
          <c r="A1" t="s"><v>0</v></c>
          <c r="B1"><v>42.5</v></c>
          <c r="C1" t="b"><v>1</v></c>
          <c r="D1"/>
        </row>
        <row r="3">
          <c r="A3" t="s"><v>1</v></c>
        </row>
      </sheetData>
    </worksheet>
    XML
  end

  # -------------------------------------------------------------------------
  # Cell reference helpers
  # -------------------------------------------------------------------------

  describe "#col_index" do
    it "converts single letters" do
      expect(subject.col_index("A")).to eq(1)
      expect(subject.col_index("Z")).to eq(26)
    end

    it "converts double letters" do
      expect(subject.col_index("AA")).to eq(27)
      expect(subject.col_index("AZ")).to eq(52)
    end

    it "is case-insensitive" do
      expect(subject.col_index("a")).to eq(1)
      expect(subject.col_index("aa")).to eq(27)
    end
  end

  describe "#col_letters" do
    it "converts single-letter columns" do
      expect(subject.col_letters(1)).to eq("A")
      expect(subject.col_letters(26)).to eq("Z")
    end

    it "converts double-letter columns" do
      expect(subject.col_letters(27)).to eq("AA")
      expect(subject.col_letters(52)).to eq("AZ")
    end

    it "round-trips with #col_index" do
      [1, 26, 27, 52, 702].each do |n|
        expect(subject.col_index(subject.col_letters(n))).to eq(n)
      end
    end
  end

  describe "#col_from_ref" do
    it "extracts the column from a cell reference" do
      expect(subject.col_from_ref("A1")).to eq(1)
      expect(subject.col_from_ref("B3")).to eq(2)
      expect(subject.col_from_ref("AA10")).to eq(27)
    end
  end

  describe "#cell_ref" do
    it "builds a cell reference from row and col" do
      expect(subject.cell_ref(1, 1)).to eq("A1")
      expect(subject.cell_ref(3, 2)).to eq("B3")
      expect(subject.cell_ref(10, 27)).to eq("AA10")
    end
  end

  # -------------------------------------------------------------------------
  # Parsing
  # -------------------------------------------------------------------------

  describe "#parse" do
    let(sheet) { subject.parse("Data", sheet_xml, shared_strings) }

    it "returns a Sheet with the given name" do
      expect(sheet.name).to eq("Data")
    end

    it "resolves shared string cells" do
      expect(sheet[1, 1]).to eq("Alice")
    end

    it "parses numeric cells as Float64" do
      expect(sheet[1, 2]).to eq(42.5)
    end

    it "parses boolean true cells" do
      expect(sheet[1, 3]).to eq(true)
    end

    it "parses empty cells as XLSX::Empty" do
      expect(sheet[1, 4]).to eq(XLSX::Empty::INSTANCE)
    end

    it "skips absent rows — row 2 is nil" do
      expect(sheet[2, 1]).to be_nil
    end

    it "parses cells in non-contiguous rows" do
      expect(sheet[3, 1]).to eq("Bob")
    end

    it "row_span reflects only present rows" do
      expect(sheet.row_span).to eq(1..3)
    end
  end

  describe "#parse with boolean false" do
    let(false_xml) do
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
          <row r="1">
            <c r="A1" t="b"><v>0</v></c>
          </row>
        </sheetData>
      </worksheet>
      XML
    end

    it "parses boolean false cells" do
      ss = XLSX::Internal::SharedStrings.new
      sheet = subject.parse("S", false_xml, ss)
      expect(sheet[1, 1]).to eq(false)
    end
  end

  # -------------------------------------------------------------------------
  # Building
  # -------------------------------------------------------------------------

  describe "#build" do
    let(ss_write) { XLSX::Internal::SharedStrings.new }

    let(sheet) do
      cells1 = {1 => "Alice".as(XLSX::CellValue), 2 => 99.0.as(XLSX::CellValue)}
      cells2 = {1 => true.as(XLSX::CellValue), 2 => XLSX::Empty::INSTANCE.as(XLSX::CellValue)}
      rows = {
        1 => XLSX::Row.new(1, cells1),
        2 => XLSX::Row.new(2, cells2),
      }
      XLSX::Sheet.new("Out", rows)
    end

    it "produces XML that round-trips through #parse" do
      xml = subject.build(sheet, ss_write)
      parsed = subject.parse("Out", xml, ss_write)

      expect(parsed[1, 1]).to eq("Alice")
      expect(parsed[1, 2]).to eq(99.0)
      expect(parsed[2, 1]).to eq(true)
      expect(parsed[2, 2]).to eq(XLSX::Empty::INSTANCE)
    end

    it "interns strings into the shared string table" do
      subject.build(sheet, ss_write)
      expect(ss_write.size).to eq(1) # only "Alice"
    end

    it "does not write nil cells" do
      cells = {1 => nil.as(XLSX::CellValue)}
      rows = {1 => XLSX::Row.new(1, cells)}
      nil_sheet = XLSX::Sheet.new("N", rows)
      xml = subject.build(nil_sheet, ss_write)
      expect(xml).not_to contain("<c ")
    end
  end
end
