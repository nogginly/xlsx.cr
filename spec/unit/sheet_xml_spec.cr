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
  # InlineStr support
  # -------------------------------------------------------------------------

  describe "#parse — inlineStr cells" do
    let(inline_xml) do
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
          <row r="1">
            <c r="A1" t="inlineStr"><is><t>  hello  </t></is></c>
          </row>
        </sheetData>
      </worksheet>
      XML
    end

    it "parses as InlineStr" do
      ss = XLSX::Internal::SharedStrings.new
      sheet = subject.parse("S", inline_xml, ss)
      expect(sheet[1, 1]).to be_a(XLSX::InlineStr)
    end

    it "preserves the string value including whitespace" do
      ss = XLSX::Internal::SharedStrings.new
      sheet = subject.parse("S", inline_xml, ss)
      expect(sheet[1, 1].as(XLSX::InlineStr).value).to eq("  hello  ")
    end

    it "does not intern the string into shared strings" do
      ss = XLSX::Internal::SharedStrings.new
      sheet = subject.parse("S", inline_xml, ss)
      expect(ss.size).to eq(0)
    end
  end

  describe "#build — InlineStr cells" do
    let(ss) { XLSX::Internal::SharedStrings.new }

    it "writes InlineStr as an inlineStr cell" do
      sheet = XLSX::Sheet.new("S", {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(XLSX::InlineStr.new("  hello  ").as(XLSX::CellValue))}),
      })
      xml = subject.build(sheet, ss)
      expect(xml).to contain(%[t="inlineStr"])
      expect(xml).to contain("<is><t>  hello  </t></is>")
    end

    it "does not intern InlineStr into shared strings" do
      sheet = XLSX::Sheet.new("S", {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(XLSX::InlineStr.new("hello").as(XLSX::CellValue))}),
      })
      subject.build(sheet, ss)
      expect(ss.size).to eq(0)
    end

    it "round-trips InlineStr through parse" do
      sheet = XLSX::Sheet.new("S", {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(XLSX::InlineStr.new("  spaced  ").as(XLSX::CellValue))}),
      })
      xml = subject.build(sheet, ss)
      parsed = subject.parse("S", xml, ss)
      result = parsed[1, 1]
      expect(result).to be_a(XLSX::InlineStr)
      expect(result.as(XLSX::InlineStr).value).to eq("  spaced  ")
    end
  end

  # -------------------------------------------------------------------------
  # Int64 write support
  # -------------------------------------------------------------------------

  describe "#build — Int64 cells" do
    let(ss) { XLSX::Internal::SharedStrings.new }

    it "writes Int64 as a plain numeric cell with no decimal point" do
      sheet = XLSX::Sheet.new("S", {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(42_i64.as(XLSX::CellValue))}),
      })
      xml = subject.build(sheet, ss)
      expect(xml).to contain("<v>42</v>")
      expect(xml).not_to contain("42.0")
    end

    it "round-trips Int64 as Float64 on read (Excel stores all numbers as float)" do
      sheet = XLSX::Sheet.new("S", {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(42_i64.as(XLSX::CellValue))}),
      })
      xml = subject.build(sheet, ss)
      parsed = subject.parse("S", xml, ss)
      expect(parsed[1, 1]).to eq(42.0)
      expect(parsed[1, 1]).to be_a(Float64)
    end
  end

  # -------------------------------------------------------------------------
  # Building
  # -------------------------------------------------------------------------

  describe "#build" do
    let(ss_write) { XLSX::Internal::SharedStrings.new }

    let(sheet) do
      rows = {
        1 => XLSX::Row.new(1, {
          1 => XLSX::Cell.new("Alice".as(XLSX::CellValue)),
          2 => XLSX::Cell.new(99.0.as(XLSX::CellValue)),
        }),
        2 => XLSX::Row.new(2, {
          1 => XLSX::Cell.new(true.as(XLSX::CellValue)),
          2 => XLSX::Cell.new(XLSX::Empty::INSTANCE.as(XLSX::CellValue)),
        }),
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
      nil_sheet = XLSX::Sheet.new("N", {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(nil.as(XLSX::CellValue))}),
      })
      xml = subject.build(nil_sheet, ss_write)
      expect(xml).not_to contain("<c ")
    end
  end
end

Spectator.describe "XLSX::Internal::SheetXML formula handling" do
  subject { XLSX::Internal::SheetXML.new }

  let(ss) { XLSX::Internal::SharedStrings.new }

  describe "#parse — plain formula" do
    let(xml) do
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
          <row r="1">
            <c r="A1"><f>SUM(B1:B5)</f><v>42.0</v></c>
          </row>
        </sheetData>
      </worksheet>
      XML
    end

    it "parses as Formula with correct expression" do
      sheet = subject.parse("S", xml, ss)
      cell = sheet[1, 1]
      expect(cell).to be_a(XLSX::Formula)
      formula = cell.as(XLSX::Formula)
      expect(formula.expression).to eq("SUM(B1:B5)")
    end

    it "parses the cached numeric value" do
      sheet = subject.parse("S", xml, ss)
      formula = sheet[1, 1].as(XLSX::Formula)
      expect(formula.cached_value).to eq(42.0)
    end

    it "has no shared_index" do
      sheet = subject.parse("S", xml, ss)
      formula = sheet[1, 1].as(XLSX::Formula)
      expect(formula.shared_index).to be_nil
    end
  end

  describe "#parse — shared formula master" do
    let(xml) do
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
          <row r="1">
            <c r="B1"><f t="shared" ref="B1:B3" si="0">A1*2</f><v>10.0</v></c>
          </row>
          <row r="2">
            <c r="B2"><f t="shared" si="0"/><v>20.0</v></c>
          </row>
          <row r="3">
            <c r="B3"><f t="shared" si="0"/><v>30.0</v></c>
          </row>
        </sheetData>
      </worksheet>
      XML
    end

    it "parses master as Formula with shared_index and shared_ref" do
      sheet = subject.parse("S", xml, ss)
      master = sheet[1, 2].as(XLSX::Formula)
      expect(master.expression).to eq("A1*2")
      expect(master.shared_index).to eq(0)
      expect(master.shared_ref).to eq("B1:B3")
    end

    it "parses satellites as SharedFormulaRef" do
      sheet = subject.parse("S", xml, ss)
      expect(sheet[2, 2]).to be_a(XLSX::SharedFormulaRef)
      expect(sheet[3, 2]).to be_a(XLSX::SharedFormulaRef)
    end

    it "preserves cached values on satellites" do
      sheet = subject.parse("S", xml, ss)
      sfr = sheet[2, 2].as(XLSX::SharedFormulaRef)
      expect(sfr.cached_value).to eq(20.0)
      expect(sfr.shared_index).to eq(0)
    end
  end

  describe "#build — round-trips formulas" do
    it "round-trips a plain formula" do
      formula = XLSX::Formula.new("SUM(B1:B5)", 42.0.as(XLSX::CellValue))
      sheet = XLSX::Sheet.new("S", {
        1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(formula.as(XLSX::CellValue))}),
      })
      xml = subject.build(sheet, ss)
      parsed = subject.parse("S", xml, ss)
      result = parsed[1, 1].as(XLSX::Formula)
      expect(result.expression).to eq("SUM(B1:B5)")
      expect(result.cached_value).to eq(42.0)
    end

    it "round-trips a shared formula master and satellite" do
      master = XLSX::Formula.new("A1*2", 10.0.as(XLSX::CellValue),
        shared_index: 0, shared_ref: "B1:B2")
      satellite = XLSX::SharedFormulaRef.new(0, 20.0.as(XLSX::CellValue))
      sheet = XLSX::Sheet.new("S", {
        1 => XLSX::Row.new(1, {2 => XLSX::Cell.new(master.as(XLSX::CellValue))}),
        2 => XLSX::Row.new(2, {2 => XLSX::Cell.new(satellite.as(XLSX::CellValue))}),
      })
      xml = subject.build(sheet, ss)
      parsed = subject.parse("S", xml, ss)

      m = parsed[1, 2].as(XLSX::Formula)
      expect(m.expression).to eq("A1*2")
      expect(m.shared_index).to eq(0)
      expect(m.shared_ref).to eq("B1:B2")

      sfr = parsed[2, 2].as(XLSX::SharedFormulaRef)
      expect(sfr.shared_index).to eq(0)
      expect(sfr.cached_value).to eq(20.0)
    end
  end
end

Spectator.describe "XLSX::Internal::SheetXML template preservation" do
  subject { XLSX::Internal::SheetXML.new }

  let(ss) { XLSX::Internal::SharedStrings.new }

  let(template_xml) do
    <<-XML
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <sheetViews>
        <sheetView workbookViewId="0">
          <pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>
        </sheetView>
      </sheetViews>
      <sheetData>
        <row r="1" s="1" customFormat="1">
          <c r="A1" s="1" t="s"><v>0</v></c>
        </row>
      </sheetData>
      <pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>
    </worksheet>
    XML
  end

  describe "#parse — preserves row and cell attrs" do
    it "stores row-level attrs" do
      ss.intern("Header")
      sheet = subject.parse("S", template_xml, ss)
      row = sheet.row(1)
      expect(row).not_to be_nil
      expect(row.not_nil!.attrs["s"]).to eq("1")
      expect(row.not_nil!.attrs["customFormat"]).to eq("1")
    end

    it "stores cell-level attrs" do
      ss.intern("Header")
      sheet = subject.parse("S", template_xml, ss)
      cell = sheet.row(1).not_nil!.cell(1)
      expect(cell).not_to be_nil
      expect(cell.not_nil!.attrs["s"]).to eq("1")
    end
  end

  describe "#build with template_xml" do
    it "preserves sheetViews (freeze pane)" do
      ss.intern("Header")
      sheet = subject.parse("S", template_xml, ss)
      output = subject.build(sheet, ss, template_xml)
      expect(output).to contain("frozen")
      expect(output).to contain("sheetViews")
    end

    it "preserves pageMargins" do
      ss.intern("Header")
      sheet = subject.parse("S", template_xml, ss)
      output = subject.build(sheet, ss, template_xml)
      expect(output).to contain("pageMargins")
    end

    it "re-emits row style attrs" do
      ss.intern("Header")
      sheet = subject.parse("S", template_xml, ss)
      output = subject.build(sheet, ss, template_xml)
      expect(output).to contain("customFormat")
    end

    it "re-emits cell style attrs" do
      ss.intern("Header")
      sheet = subject.parse("S", template_xml, ss)
      output = subject.build(sheet, ss, template_xml)
      expect(output).to match(/c r="A1"[^>]*s="1"/)
    end
  end
end
