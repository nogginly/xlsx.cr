require "../spec_helper"

Spectator.describe XLSX::Empty do
  subject { XLSX::Empty::INSTANCE }

  it "is a singleton" do
    expect(XLSX::Empty::INSTANCE).to be(XLSX::Empty::INSTANCE)
  end

  it "is not nil" do
    expect(subject).not_to be_nil
  end

  it "converts to an empty string" do
    expect(subject.to_s).to eq("")
  end

  it "equals another Empty instance" do
    expect(subject).to eq(XLSX::Empty.new)
  end
end

Spectator.describe "XLSX::CellValue" do
  sample [
    {"string", "hello".as(XLSX::CellValue)},
    {"float", 3.14.as(XLSX::CellValue)},
    {"bool", true.as(XLSX::CellValue)},
    {"Empty", XLSX::Empty::INSTANCE.as(XLSX::CellValue)},
    {"nil", nil.as(XLSX::CellValue)},
  ] do |label, value|
    it "accepts #{label} values" do
      cell : XLSX::CellValue = value
      expect(cell).to eq(value)
    end
  end

  it "distinguishes Empty from nil" do
    empty : XLSX::CellValue = XLSX::Empty::INSTANCE
    null : XLSX::CellValue = nil
    expect(empty).not_to be_nil
    expect(null).to be_nil
  end
end
