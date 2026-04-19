require "./internal"

module XLSX
  module Internal
    # Parses and builds `xl/workbook.xml` and `xl/_rels/workbook.xml.rels`.
    #
    # `workbook.xml` lists sheets by name and relationship ID (`r:id`).
    # `workbook.xml.rels` maps each `r:id` to a target file path
    # (e.g. `worksheets/sheet1.xml`).
    #
    # Together they let us resolve: sheet name → sheet XML file path.
    class WorkbookXML
      # Ordered list of {name, r:id} pairs as declared in workbook.xml.
      record SheetRef, name : String, rid : String

      getter sheet_refs : Array(SheetRef)

      # Maps r:id → relative file path within xl/ (e.g. "worksheets/sheet1.xml").
      getter rid_to_target : Hash(String, String)

      def initialize
        @sheet_refs = Array(SheetRef).new
        @rid_to_target = Hash(String, String).new
      end

      # Parses `xl/workbook.xml`.
      def parse_workbook(xml : String) : Nil
        doc = XML.parse(xml)
        doc.xpath_nodes("//ms:sheets/ms:sheet",
          namespaces: {"ms" => MAIN_NS, "r" => RELATION_NS}
        ).each do |node|
          name = node["name"]
          rid = node["r:id"]? || node["id"]
          @sheet_refs << SheetRef.new(name: name, rid: rid)
        end
      end

      # Parses `xl/_rels/workbook.xml.rels`.
      def parse_rels(xml : String) : Nil
        doc = XML.parse(xml)
        doc.xpath_nodes("//pr:Relationship",
          namespaces: {"pr" => RELS_NS}
        ).each do |node|
          next unless node["Type"]? == SHEET_TYPE
          @rid_to_target[node["Id"]] = node["Target"]
        end
      end

      # Resolves a sheet name to its target path within `xl/`.
      # Returns `nil` if the name is unknown or has no relationship entry.
      def target_for(name : String) : String?
        ref = @sheet_refs.find { |r| r.name == name }
        return nil unless ref
        @rid_to_target[ref.rid]?
      end

      # Ordered sheet names as declared in `workbook.xml`.
      def sheet_names : Array(String)
        @sheet_refs.map(&.name)
      end

      # Serialises `xl/workbook.xml` for a given list of sheet names.
      def build_workbook(sheet_names : Array(String)) : String
        XML.build(indent: "  ") do |xml|
          xml.element("workbook",
            xmlns: MAIN_NS,
            "xmlns:r": RELATION_NS
          ) do
            xml.element("sheets") do
              sheet_names.each_with_index do |name, i|
                rid = "rId#{i + 1}"
                xml.element("sheet",
                  name: name,
                  sheetId: (i + 1).to_s,
                  "r:id": rid
                )
              end
            end
          end
        end
      end

      # Serialises `xl/_rels/workbook.xml.rels` for a given list of sheet names.
      def build_rels(sheet_names : Array(String)) : String
        XML.build(indent: "  ") do |xml|
          xml.element("Relationships", xmlns: RELS_NS) do
            sheet_names.each_with_index do |_, i|
              n = i + 1
              xml.element("Relationship",
                Id: "rId#{n}",
                Type: SHEET_TYPE,
                Target: "worksheets/sheet#{n}.xml"
              )
            end
          end
        end
      end
    end
  end
end
