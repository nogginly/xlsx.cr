require "../spec_helper"

Spectator.describe XLSX::Internal::Zip do
  def round_trip(document : XLSX::Document) : XLSX::Document
    io = IO::Memory.new
    XLSX::Internal::Zip.write(io, document)
    io.rewind
    XLSX::Internal::Zip.read(io)
  end

  describe ".write / .read round-trip" do
    context "with a single sheet and mixed cell types" do
      let(sheet) do
        XLSX::Sheet.new("Data", {
          1 => XLSX::Row.new(1, {
            1 => XLSX::Cell.new("Alice".as(XLSX::CellValue)),
            2 => XLSX::Cell.new(42.0.as(XLSX::CellValue)),
            3 => XLSX::Cell.new(true.as(XLSX::CellValue)),
            4 => XLSX::Cell.new(XLSX::Empty::INSTANCE.as(XLSX::CellValue)),
          }),
          3 => XLSX::Row.new(3, {
            1 => XLSX::Cell.new("Bob".as(XLSX::CellValue)),
            2 => XLSX::Cell.new(false.as(XLSX::CellValue)),
          }),
        })
      end

      let(result) { round_trip(XLSX::Document.new([sheet])) }

      it "preserves the sheet name" do
        expect(result[0].name).to eq("Data")
      end

      it "preserves string cells" do
        expect(result[0][1, 1]).to eq("Alice")
        expect(result[0][3, 1]).to eq("Bob")
      end

      it "preserves numeric cells" do
        expect(result[0][1, 2]).to eq(42.0)
      end

      it "preserves boolean true" do
        expect(result[0][1, 3]).to eq(true)
      end

      it "preserves boolean false" do
        expect(result[0][3, 2]).to eq(false)
      end

      it "preserves Empty cells" do
        expect(result[0][1, 4]).to eq(XLSX::Empty::INSTANCE)
      end

      it "preserves absent rows as nil" do
        expect(result[0][2, 1]).to be_nil
      end
    end

    context "with multiple sheets" do
      let(sheet1) do
        XLSX::Sheet.new("Sales", {
          1 => XLSX::Row.new(1, {1 => XLSX::Cell.new("revenue".as(XLSX::CellValue))}),
        })
      end

      let(sheet2) do
        XLSX::Sheet.new("Summary", {
          1 => XLSX::Row.new(1, {1 => XLSX::Cell.new(99.0.as(XLSX::CellValue))}),
        })
      end

      let(result) { round_trip(XLSX::Document.new([sheet1, sheet2])) }

      it "preserves sheet count" do
        expect(result.size).to eq(2)
      end

      it "preserves sheet names in order" do
        expect(result.sheet_names).to eq(["Sales", "Summary"])
      end

      it "preserves data in each sheet" do
        expect(result["Sales"][1, 1]).to eq("revenue")
        expect(result["Summary"][1, 1]).to eq(99.0)
      end
    end

    context "with an empty sheet" do
      let(result) do
        round_trip(XLSX::Document.new([XLSX::Sheet.new("Empty", {} of Int32 => XLSX::Row)]))
      end

      it "round-trips without error" do
        expect(result[0].name).to eq("Empty")
        expect(result[0].empty?).to be_true
      end
    end
  end

  describe ".write_rows" do
    it "round-trips CSV-style rows" do
      rows = [
        ["name".as(XLSX::CellValue), "score".as(XLSX::CellValue)],
        ["alice".as(XLSX::CellValue), 95.0.as(XLSX::CellValue)],
      ]
      io = IO::Memory.new
      XLSX::Internal::Zip.write_rows(io, rows)
      io.rewind
      doc = XLSX::Internal::Zip.read(io)

      expect(doc[0].name).to eq("Sheet1")
      expect(doc[0][1, 1]).to eq("name")
      expect(doc[0][2, 2]).to eq(95.0)
    end

    it "accepts a custom sheet name" do
      io = IO::Memory.new
      XLSX::Internal::Zip.write_rows(io, [] of Array(XLSX::CellValue), sheet_name: "MySheet")
      io.rewind
      doc = XLSX::Internal::Zip.read(io)
      expect(doc[0].name).to eq("MySheet")
    end
  end
end
