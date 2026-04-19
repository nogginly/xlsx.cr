require "../spec_helper"

Spectator.describe XLSX::Document do
  let(sheet1) { XLSX::Sheet.new("Sheet1", {} of Int32 => XLSX::Row) }
  let(sheet2) { XLSX::Sheet.new("Sheet2", {} of Int32 => XLSX::Row) }

  subject { XLSX::Document.new([sheet1, sheet2]) }

  describe "#each" do
    it "yields all sheets in order" do
      names = [] of String
      subject.each { |sheet| names << sheet.name }
      expect(names).to eq(["Sheet1", "Sheet2"])
    end
  end

  describe "#[]" do
    context "by name" do
      it "returns the sheet with that name" do
        expect(subject["Sheet1"].name).to eq("Sheet1")
        expect(subject["Sheet2"].name).to eq("Sheet2")
      end

      it "raises KeyError for an unknown name" do
        expect { subject["Missing"] }.to raise_error(KeyError)
      end
    end

    context "by 0-based index" do
      it "returns the sheet at that position" do
        expect(subject[0].name).to eq("Sheet1")
        expect(subject[1].name).to eq("Sheet2")
      end
    end
  end

  describe "#sheet_names" do
    it "returns all sheet names in document order" do
      expect(subject.sheet_names).to eq(["Sheet1", "Sheet2"])
    end
  end

  describe "#size" do
    it "returns the number of sheets" do
      expect(subject.size).to eq(2)
    end
  end

  describe ".open" do
    context "from IO" do
      it "raises NotImplementedError until the parser is implemented" do
        io = IO::Memory.new
        expect { XLSX::Document.open(io) }.to raise_error(NotImplementedError)
      end
    end
  end
end
