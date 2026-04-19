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

    context "span-aware (with sheets:)" do
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
