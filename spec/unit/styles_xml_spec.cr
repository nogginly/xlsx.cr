require "../spec_helper"

Spectator.describe XLSX::Internal::StylesXML do
  subject { XLSX::Internal::StylesXML.new }

  let(styles_xml) do
    <<-XML
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <numFmts count="2">
        <numFmt numFmtId="164" formatCode="yyyy-mm-dd"/>
        <numFmt numFmtId="165" formatCode="#,##0.00"/>
      </numFmts>
      <cellXfs count="4">
        <xf numFmtId="0"/>
        <xf numFmtId="14"/>
        <xf numFmtId="164"/>
        <xf numFmtId="165"/>
      </cellXfs>
    </styleSheet>
    XML
  end

  before_each { subject.parse(styles_xml) }

  describe "#date_format?" do
    it "returns false for xf 0 (general format)" do
      expect(subject.date_format?(0)).to be_false
    end

    it "returns true for xf 1 (built-in date format 14)" do
      expect(subject.date_format?(1)).to be_true
    end

    it "returns true for xf 2 (custom date format)" do
      expect(subject.date_format?(2)).to be_true
    end

    it "returns false for xf 3 (custom numeric format)" do
      expect(subject.date_format?(3)).to be_false
    end
  end

  describe "#serial_to_time" do
    it "converts a whole-day serial to midnight UTC" do
      # 2026-04-20 = serial 46132 in 1900 system
      t = subject.serial_to_time(46132.0)
      expect(t.year).to eq(2026)
      expect(t.month).to eq(4)
      expect(t.day).to eq(20)
      expect(t.hour).to eq(0)
      expect(t.minute).to eq(0)
    end

    it "converts fractional serial to correct time of day" do
      # 0.5 = noon
      t = subject.serial_to_time(46132.5)
      expect(t.hour).to eq(12)
      expect(t.minute).to eq(0)
    end
  end

  describe "#time_to_serial" do
    it "converts a UTC time to a serial number" do
      t = Time.utc(2026, 4, 20, 0, 0, 0)
      expect(subject.time_to_serial(t)).to be_close(46132.0, 0.0001)
    end

    it "uses wall-clock value regardless of timezone offset" do
      utc = Time.utc(2026, 4, 20, 9, 30, 0)
      local = Time.local(2026, 4, 20, 9, 30, 0)
      expect(subject.time_to_serial(utc)).to be_close(subject.time_to_serial(local), 0.0001)
    end

    it "round-trips through serial_to_time" do
      original = Time.utc(2026, 4, 20, 14, 30, 0)
      serial = subject.time_to_serial(original)
      result = subject.serial_to_time(serial)
      expect(result.year).to eq(2026)
      expect(result.month).to eq(4)
      expect(result.day).to eq(20)
      expect(result.hour).to eq(14)
      expect(result.minute).to eq(30)
    end
  end

  describe "1904 date system" do
    subject { XLSX::Internal::StylesXML.new(date1904: true) }

    it "adjusts epoch for 1904 system" do
      # Day 1 in 1904 system = 1904-01-01
      t = subject.serial_to_time(1.0)
      expect(t.year).to eq(1904)
      expect(t.month).to eq(1)
      expect(t.day).to eq(2)
    end
  end
end
