require "./internal"

require "html"

module XLSX
  module Internal
    # Parses and builds `xl/workbook.xml` and `xl/_rels/workbook.xml.rels`.
    #
    # When a template is provided, both files are patched rather than
    # regenerated — preserving all non-sheet content (namespaces, calcPr,
    # bookViews, extLst, non-worksheet relationships, etc.)
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
        doc.xpath_nodes("//wb:workbook/wb:sheets/wb:sheet", WB_NS_MAP).each do |node|
          name = node["name"]
          rid = node["r:id"]? || node["id"]
          @sheet_refs << SheetRef.new(name: name, rid: rid)
        end
      end

      # Parses `xl/_rels/workbook.xml.rels`.
      def parse_rels(xml : String) : Nil
        doc = XML.parse(xml)
        doc.xpath_nodes("//pr:Relationships/pr:Relationship", RELS_NS_MAP).each do |node|
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

      # Builds `xl/workbook.xml`.
      # When *template_xml* is given, only the `<sheets>` element is replaced;
      # all other content (namespaces, calcPr, bookViews, extLst, etc.) is
      # preserved verbatim via string substitution.
      def build_workbook(sheet_names : Array(String),
                         template_xml : String? = nil) : String
        if raw = template_xml
          patch_sheets_element(raw, build_sheets_fragment(sheet_names))
        else
          XML.build(indent: "  ") do |xml|
            xml.element("workbook", xmlns: MAIN_NS, "xmlns:r": RELATION_NS) do
              xml.element("sheets") do
                sheet_names.each_with_index do |name, i|
                  n = i + 1
                  xml.element("sheet", name: name, sheetId: n.to_s, "r:id": "rId#{n}")
                end
              end
            end
          end
        end
      end

      # Builds `xl/_rels/workbook.xml.rels`.
      # When *template_xml* is given, non-worksheet relationships are preserved;
      # only the worksheet `Relationship` entries are replaced.
      def build_rels(sheet_names : Array(String),
                     template_xml : String? = nil) : String
        # Collect non-worksheet relationships from the template.
        preserved = [] of {String, String, String} # {Id, Type, Target}
        if raw = template_xml
          doc = XML.parse(raw)
          doc.xpath_nodes("//pr:Relationships/pr:Relationship", RELS_NS_MAP).each do |node|
            next if node["Type"]? == SHEET_TYPE
            preserved << {node["Id"], node["Type"], node["Target"]}
          end
        else
          # From-scratch: always include the standard non-worksheet relationships.
          preserved << {"rId10", SHARED_STRINGS_TYPE, "sharedStrings.xml"}
          preserved << {"rId11", STYLES_TYPE, "styles.xml"}
        end

        # Assign new rIds for worksheets, avoiding collisions with preserved ones.
        used_ids = preserved.map(&.[0]).to_set
        sheet_rels = sheet_names.each_with_index.map do |_, i|
          rid = next_rid(used_ids, i + 1)
          used_ids << rid
          {rid, SHEET_TYPE, "worksheets/sheet#{i + 1}.xml"}
        end.to_a

        XML.build(indent: "  ") do |xml|
          xml.element("Relationships", xmlns: RELS_NS) do
            (preserved + sheet_rels).each do |(id, type, target)|
              xml.element("Relationship", Id: id, Type: type, Target: target)
            end
          end
        end
      end

      private def build_sheets_fragment(sheet_names : Array(String)) : String
        String.build do |s|
          s << "<sheets>"
          sheet_names.each_with_index do |name, i|
            n = i + 1
            s << %(<sheet name="#{HTML.escape(name)}" sheetId="#{n}" r:id="rId#{n}"/>)
          end
          s << "</sheets>"
        end
      end

      # Replaces the <sheets>...</sheets> content in *xml* with *sheets_xml*.
      # Uses a simple regex since the sheets block is self-contained.
      private def patch_sheets_element(xml : String, sheets_xml : String) : String
        xml.gsub(/<sheets>.*?<\/sheets>/m, sheets_xml)
      end

      # Returns an rId string that doesn't collide with *used*.
      # Starts probing from *hint*.
      private def next_rid(used : Set(String), hint : Int32) : String
        n = hint
        loop do
          candidate = "rId#{n}"
          return candidate unless used.includes?(candidate)
          n += 1
        end
      end
    end
  end
end
