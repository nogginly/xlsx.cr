require "../spec_helper"

Spectator.describe XLSX::Cell do
  describe ".new with value only" do
    subject { XLSX::Cell.new("hello".as(XLSX::CellValue)) }

    it "stores the value" do
      expect(subject.value).to eq("hello")
    end

    it "has empty attrs" do
      expect(subject.attrs).to be_empty
    end
  end

  describe ".new with value and attrs" do
    subject { XLSX::Cell.new(42.0.as(XLSX::CellValue), {"s" => "1"}) }

    it "stores the value" do
      expect(subject.value).to eq(42.0)
    end

    it "stores the attrs" do
      expect(subject.attrs["s"]).to eq("1")
    end
  end
end

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

Spectator.describe XLSX::Formula do
  let(cached) { 42.0.as(XLSX::CellValue) }
  subject { XLSX::Formula.new("SUM(A1:A5)", cached) }

  it "stores the expression without leading =" do
    expect(subject.expression).to eq("SUM(A1:A5)")
  end

  it "stores the cached value" do
    expect(subject.cached_value).to eq(42.0)
  end

  it "converts to string with leading =" do
    expect(subject.to_s).to eq("=SUM(A1:A5)")
  end

  it "has nil shared_index by default" do
    expect(subject.shared_index).to be_nil
  end

  it "has nil shared_ref by default" do
    expect(subject.shared_ref).to be_nil
  end

  context "as a shared formula master" do
    subject { XLSX::Formula.new("A1*2", 10.0.as(XLSX::CellValue), shared_index: 0, shared_ref: "B1:B10") }

    it "stores shared_index" do
      expect(subject.shared_index).to eq(0)
    end

    it "stores shared_ref" do
      expect(subject.shared_ref).to eq("B1:B10")
    end
  end

  it "equals another Formula with same fields" do
    other = XLSX::Formula.new("SUM(A1:A5)", cached)
    expect(subject).to eq(other)
  end
end

Spectator.describe XLSX::SharedFormulaRef do
  let(cached) { 20.0.as(XLSX::CellValue) }
  subject { XLSX::SharedFormulaRef.new(0, cached) }

  it "stores the shared_index" do
    expect(subject.shared_index).to eq(0)
  end

  it "stores the cached value" do
    expect(subject.cached_value).to eq(20.0)
  end

  it "converts to string via cached value" do
    expect(subject.to_s).to eq("20.0")
  end

  it "equals another SharedFormulaRef with same fields" do
    expect(subject).to eq(XLSX::SharedFormulaRef.new(0, cached))
  end
end

Spectator.describe "XLSX::CellValue" do
  it "distinguishes Empty from nil" do
    empty : XLSX::CellValue = XLSX::Empty::INSTANCE
    null : XLSX::CellValue = nil
    expect(empty).not_to be_nil
    expect(null).to be_nil
  end

  it "accepts String values" do
    cell : XLSX::CellValue = "hello"
    expect(cell).to eq("hello")
  end

  it "accepts InlineStr values" do
    cell : XLSX::CellValue = XLSX::InlineStr.new("hello")
    expect(cell).to be_a(XLSX::InlineStr)
  end

  it "accepts Int64 values" do
    cell : XLSX::CellValue = 42_i64
    expect(cell).to eq(42_i64)
  end

  it "accepts Float64 values" do
    cell : XLSX::CellValue = 3.14
    expect(cell).to eq(3.14)
  end

  it "accepts Bool values" do
    cell : XLSX::CellValue = true
    expect(cell).to eq(true)
  end

  it "accepts Empty values" do
    cell : XLSX::CellValue = XLSX::Empty::INSTANCE
    expect(cell).to eq(XLSX::Empty::INSTANCE)
  end

  it "accepts Formula values" do
    cell : XLSX::CellValue = XLSX::Formula.new("A1+1", 2.0.as(XLSX::CellValue))
    expect(cell).to be_a(XLSX::Formula)
  end

  it "accepts SharedFormulaRef values" do
    cell : XLSX::CellValue = XLSX::SharedFormulaRef.new(0, 5.0.as(XLSX::CellValue))
    expect(cell).to be_a(XLSX::SharedFormulaRef)
  end

  it "accepts nil" do
    cell : XLSX::CellValue = nil
    expect(cell).to be_nil
  end
end
