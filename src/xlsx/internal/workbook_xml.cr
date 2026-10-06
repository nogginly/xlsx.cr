require "./internal"

require "html"

module XLSX
  module Internal
    # Reads and writes `xl/workbook.xml` and `xl/_rels/workbook.xml.rels`.
    #
    # With a template, the workbook keeps everything but its `<sheets>`
    # element (namespaces, `calcPr`, `bookViews`, `definedNames`, `extLst`), and
    # the relationships keep every non-worksheet entry's Id, Type and Target.
    class WorkbookXML
      # A sheet's name and relationship ID, as listed in `workbook.xml`.
      record SheetRef, name : String, rid : String

      getter sheet_refs : Array(SheetRef)

      # Worksheet relationship IDs to their targets, normally relative to `xl/`,
      # e.g. "worksheets/sheet1.xml".
      getter rid_to_target : Hash(String, String)

      def initialize
        @sheet_refs = Array(SheetRef).new
        @rid_to_target = Hash(String, String).new
      end

      # Reads the sheet list, in order, from `xl/workbook.xml`.
      def parse_workbook(xml : String) : Nil
        doc = XML.parse(xml)
        doc.xpath_nodes("//wb:workbook/wb:sheets/wb:sheet", WB_NS_MAP).each do |node|
          name = node["name"]
          rid = node["r:id"]? || node["id"]
          @sheet_refs << SheetRef.new(name: name, rid: rid)
        end
      end

      # Reads the worksheet relationships from `xl/_rels/workbook.xml.rels`,
      # ignoring all others.
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

      # Returns the sheet names in workbook order.
      def sheet_names : Array(String)
        @sheet_refs.map(&.name)
      end

      # Returns `xl/workbook.xml` listing *sheet_names*. Sheet *n* gets
      # `sheetId` *n* and `r:id` `rId`*n*, which can differ from the ID
      # `build_rels` assigns it. Given *template_xml*, returns it with its
      # `<sheets>` element replaced; other attributes of the template's sheets,
      # such as `state="hidden"`, are not kept.
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

      # Returns `xl/_rels/workbook.xml.rels` relating *sheet_names*, in order, to
      # `worksheets/sheetN.xml`. Given *template_xml*, its non-worksheet
      # relationships are kept and worksheet IDs are chosen around them.
      def build_rels(sheet_names : Array(String),
                     template_xml : String? = nil) : String
        # Non-worksheet relationships to keep.
        preserved = [] of {String, String, String} # {Id, Type, Target}
        if raw = template_xml
          doc = XML.parse(raw)
          doc.xpath_nodes("//pr:Relationships/pr:Relationship", RELS_NS_MAP).each do |node|
            next if node["Type"]? == SHEET_TYPE
            preserved << {node["Id"], node["Type"], node["Target"]}
          end
        else
          # A new workbook relates its shared strings and styles as rId10 and rId11.
          preserved << {"rId10", SHARED_STRINGS_TYPE, "sharedStrings.xml"}
          preserved << {"rId11", STYLES_TYPE, "styles.xml"}
        end

        # Worksheet IDs, probing upward from rId1 past any already in use.
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

      # Returns *xml* with its `<sheets>...</sheets>` replaced by *sheets_xml*,
      # or unchanged if that exact markup is absent, as with a namespace prefix
      # or an empty `<sheets/>`.
      private def patch_sheets_element(xml : String, sheets_xml : String) : String
        xml.gsub(/<sheets>.*?<\/sheets>/m, sheets_xml)
      end

      # Returns the first of `rId`*hint*, `rId`*hint+1*, ... not in *used*.
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
