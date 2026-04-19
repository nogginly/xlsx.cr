require "../spec_helper"

module XLSX
  Spectator.describe XLSX do
    describe ".build" do
      let(io) { IO::Memory.new }

      context "CSV-compatible (no sheets:)" do
        it "yields a Builder" do
          XLSX.build(io) { |b| expect(b).to be_a(XLSX::Builder) }
        rescue NotImplementedError
          # expected: close raises until writer is implemented
        end
      end

      context "span-aware (with sheets:)" do
        it "yields a SheetBuilder once per sheet name, in order" do
          seen = [] of String
          begin
            XLSX.build(io, sheets: ["Sheet1", "Sheet2"]) { |sb| seen << sb.name }
          rescue NotImplementedError
            # expected: write raises until writer is implemented
          end
          expect(seen).to eq(["Sheet1", "Sheet2"])
        end

        it "yields SheetBuilder instances" do
          begin
            XLSX.build(io, sheets: ["Data"]) { |sb| expect(sb).to be_a(XLSX::SheetBuilder) }
          rescue NotImplementedError
          end
        end
      end
    end
  end
end
