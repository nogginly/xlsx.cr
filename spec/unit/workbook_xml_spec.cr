require "../spec_helper"

Spectator.describe XLSX::Internal::WorkbookXML do
  subject { XLSX::Internal::WorkbookXML.new }

  let(workbook_xml) do
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
              xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="Sales" sheetId="1" r:id="rId1"/>
        <sheet name="Summary" sheetId="2" r:id="rId2"/>
      </sheets>
    </workbook>
    XML
  end

  let(rels_xml) do
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1"
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
        Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2"
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
        Target="worksheets/sheet2.xml"/>
    </Relationships>
    XML
  end

  describe "#parse_workbook" do
    before_each { subject.parse_workbook(workbook_xml) }

    it "extracts sheet names in order" do
      expect(subject.sheet_names).to eq(["Sales", "Summary"])
    end

    it "extracts sheet refs with correct r:ids" do
      expect(subject.sheet_refs[0].rid).to eq("rId1")
      expect(subject.sheet_refs[1].rid).to eq("rId2")
    end
  end

  describe "#parse_rels" do
    before_each { subject.parse_rels(rels_xml) }

    it "maps r:ids to target paths" do
      expect(subject.rid_to_target["rId1"]).to eq("worksheets/sheet1.xml")
      expect(subject.rid_to_target["rId2"]).to eq("worksheets/sheet2.xml")
    end

    it "ignores non-worksheet relationships" do
      rels_with_extra = rels_xml.sub("</Relationships>", <<-EXTRA
        <Relationship Id="rId3"
          Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"
          Target="sharedStrings.xml"/>
        </Relationships>
        EXTRA
      )
      fresh = XLSX::Internal::WorkbookXML.new
      fresh.parse_rels(rels_with_extra)
      expect(fresh.rid_to_target.has_key?("rId3")).to be_false
    end
  end

  describe "#target_for" do
    before_each do
      subject.parse_workbook(workbook_xml)
      subject.parse_rels(rels_xml)
    end

    it "resolves a sheet name to its file path" do
      expect(subject.target_for("Sales")).to eq("worksheets/sheet1.xml")
      expect(subject.target_for("Summary")).to eq("worksheets/sheet2.xml")
    end

    it "returns nil for an unknown sheet name" do
      expect(subject.target_for("Missing")).to be_nil
    end
  end

  describe "#build_workbook" do
    it "produces XML that round-trips through #parse_workbook" do
      xml = subject.build_workbook(["Alpha", "Beta"])
      fresh = XLSX::Internal::WorkbookXML.new
      fresh.parse_workbook(xml)
      expect(fresh.sheet_names).to eq(["Alpha", "Beta"])
    end

    it "assigns sequential r:ids starting at rId1" do
      xml = subject.build_workbook(["Alpha", "Beta"])
      fresh = XLSX::Internal::WorkbookXML.new
      fresh.parse_workbook(xml)
      expect(fresh.sheet_refs[0].rid).to eq("rId1")
      expect(fresh.sheet_refs[1].rid).to eq("rId2")
    end
  end

  describe "#build_rels" do
    it "produces XML that round-trips through #parse_rels" do
      xml = subject.build_rels(["Alpha", "Beta"])
      fresh = XLSX::Internal::WorkbookXML.new
      fresh.parse_rels(xml)
      expect(fresh.rid_to_target["rId1"]).to eq("worksheets/sheet1.xml")
      expect(fresh.rid_to_target["rId2"]).to eq("worksheets/sheet2.xml")
    end
  end
end
