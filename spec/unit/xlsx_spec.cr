require "../spec_helper"

Spectator.describe XLSX do
  describe ".build" do
    let(io) { IO::Memory.new }

    context "CSV-compatible (no sheets:)" do
      it "yields a Builder" do
        builder_seen = false
        XLSX.build(io) do |b|
          builder_seen = true
          expect(b).to be_a(XLSX::Builder)
        end
        expect(builder_seen).to be_true
      end

      it "writes a readable XLSX file" do
        XLSX.build(io) { |b| b.row("x", "y") }
        io.rewind
        doc = XLSX::Document.open(io)
        expect(doc[0][1, 1]).to eq("x")
      end
    end

    context "template-based (with template: IO)" do
      # Build a template document in memory to use as input.
      let(template_io) do
        io = IO::Memory.new
        XLSX::Internal::Zip.write(io, XLSX::Document.new([
          XLSX::Sheet.new("Data", {
            1 => XLSX::Row.new(1, {
              1 => XLSX::Cell.new("header".as(XLSX::CellValue)),
              2 => XLSX::Cell.new("value".as(XLSX::CellValue)),
            }),
          }),
        ]))
        io.rewind
        io
      end

      it "preserves existing sheet names" do
        XLSX.build(io, template: template_io) { }
        io.rewind
        doc = XLSX::Document.open(io)
        expect(doc.sheet_names).to eq(["Data"])
      end

      it "preserves existing template content" do
        XLSX.build(io, template: template_io) { }
        io.rewind
        doc = XLSX::Document.open(io)
        expect(doc["Data"][1, 1]).to eq("header")
      end

      it "appends new rows after existing template content" do
        XLSX.build(io, template: template_io) do |sheet|
          sheet.append_row("new", 42.0)
        end
        io.rewind
        doc = XLSX::Document.open(io)
        expect(doc["Data"][2, 1]).to eq("new")
        expect(doc["Data"][2, 2]).to eq(42.0)
      end

      it "yields a SheetBuilder for each sheet in the template" do
        names = [] of String
        XLSX.build(io, template: template_io) { |sb| names << sb.name }
        expect(names).to eq(["Data"])
      end

      it "yields a SheetBuilder once per sheet name, in order" do
        seen = [] of String
        XLSX.build(io, sheets: ["Sheet1", "Sheet2"]) { |sb| seen << sb.name }
        expect(seen).to eq(["Sheet1", "Sheet2"])
      end

      it "writes a readable XLSX file with named sheets" do
        XLSX.build(io, sheets: ["Alpha"]) do |sb|
          sb.rows(1..1) { |row, _| row[1] = "data" }
        end
        io.rewind
        doc = XLSX::Document.open(io)
        expect(doc["Alpha"][1, 1]).to eq("data")
      end
    end
  end
end
