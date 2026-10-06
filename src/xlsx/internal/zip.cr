require "compress/zip"

require "./internal"

module XLSX
  module Internal
    # Reads a workbook archive into a `Document`, and writes a `Document` back,
    # optionally over a template's archive. Each XML part is handled by its own
    # class: `WorkbookXML`, `SharedStrings`, `StylesXML` and `SheetXML`.
    #
    # The parts involved, with sheet paths as this shard writes them (on read,
    # paths come from the workbook's relationships):
    # ```
    # [Content_Types].xml
    # _rels/.rels
    # xl/workbook.xml
    # xl/_rels/workbook.xml.rels
    # xl/sharedStrings.xml       # optional on read
    # xl/styles.xml              # optional on read
    # xl/worksheets/sheet1.xml   # one per sheet
    # ```
    class Zip
      # Reads the workbook archive in *io* into a `Document`.
      def self.read(io : IO) : Document
        read_from_entries(collect_entries(io))
      end

      # Builds a `Document` from entries already read by `.collect_entries`, so a
      # template build can read and write from one pass over the archive.
      # Raises `KeyError` if the workbook, its relationships or a sheet part is
      # missing, and `NilAssertionError` if a sheet has no relationship.
      def self.read_from_entries(entries : Hash(String, String)) : Document
        wb = WorkbookXML.new
        ss = SharedStrings.new
        sx = SheetXML.new
        styles = StylesXML.new

        wb.parse_workbook(entries["xl/workbook.xml"])
        wb.parse_rels(entries["xl/_rels/workbook.xml.rels"])

        if raw_ss = entries["xl/sharedStrings.xml"]?
          ss.parse(raw_ss)
        end

        if raw_styles = entries["xl/styles.xml"]?
          styles.parse(raw_styles)
        end

        sheets = wb.sheet_names.map do |name|
          target = wb.target_for(name).not_nil!
          xml = entries["xl/#{target}"]
          sx.parse(name, xml, ss, styles)
        end

        Document.new(sheets)
      end

      # Reads every entry of the archive in *io* into a map of filename to
      # content. Binary parts are carried as `String`s of raw bytes.
      def self.collect_entries(io : IO) : Hash(String, String)
        entries = {} of String => String
        ::Compress::Zip::Reader.open(io) do |zip|
          zip.each_entry do |entry|
            entries[entry.filename] = entry.io.gets_to_end
          end
        end
        entries
      end

      # Writes *document* to *io* as a new workbook.
      def self.write(io : IO, document : Document) : Nil
        write_impl(io, document, template_entries: nil)
      end

      # Writes *document* to *io* over the parts of a template:
      #
      # - Sheets are written as `xl/worksheets/sheetN.xml`, each patched into the
      #   template sheet of the same name.
      # - The workbook, its relationships and `[Content_Types].xml` are patched
      #   for the new sheet list; the shared string table is rebuilt.
      # - `_rels/.rels`, `xl/styles.xml` and every other part are copied
      #   unchanged, except that everything else under `xl/worksheets/`
      #   (including sheet relationships) and `xl/calcChain.xml` is dropped.
      def self.write_with_template(io : IO, document : Document,
                                   template_entries : Hash(String, String)) : Nil
        write_impl(io, document, template_entries: template_entries)
      end

      private def self.write_impl(io : IO, document : Document,
                                  template_entries : Hash(String, String)?) : Nil
        ss = SharedStrings.new
        sx = SheetXML.new

        # Template sheet names to parts, to find the XML each sheet is patched into.
        template_wb = template_entries.try do |entries|
          wb = WorkbookXML.new
          wb.parse_workbook(entries["xl/workbook.xml"]) if entries["xl/workbook.xml"]?
          wb.parse_rels(entries["xl/_rels/workbook.xml.rels"]) if entries["xl/_rels/workbook.xml.rels"]?
          wb
        end

        # Every sheet's XML is built before the shared string table is written,
        # so the table holds every string the sheets intern.
        template_styles = StylesXML.new
        if raw_styles = template_entries.try(&.["xl/styles.xml"]?)
          template_styles.parse(raw_styles)
        end

        sheet_xmls = [] of {String, String} # {sheet_name, xml}
        document.each do |sheet|
          template_sheet_xml = template_wb.try do |twb|
            twb.target_for(sheet.name).try do |target|
              template_entries.try(&.["xl/#{target}"]?)
            end
          end
          sheet_xmls << {sheet.name, sx.build(sheet, ss, template_sheet_xml, template_styles)}
        end

        sheet_names = sheet_xmls.map(&.[0])
        wb = WorkbookXML.new

        # Parts this shard writes, each replacing the template's part of the same
        # name. `_rels/.rels` and `styles.xml` are the template's own if present.
        managed = {
          "[Content_Types].xml"        => build_content_types(sheet_names, template_entries),
          "_rels/.rels"                => template_entries.try(&.["_rels/.rels"]?) || build_root_rels,
          "xl/workbook.xml"            => wb.build_workbook(sheet_names, template_entries.try(&.["xl/workbook.xml"]?)),
          "xl/_rels/workbook.xml.rels" => wb.build_rels(sheet_names, template_entries.try(&.["xl/_rels/workbook.xml.rels"]?)),
          "xl/sharedStrings.xml"       => ss.to_xml,
          "xl/styles.xml"              => template_entries.try(&.["xl/styles.xml"]?) || minimal_styles,
        }

        sheet_xmls.each_with_index do |(_, xml), i|
          managed["xl/worksheets/sheet#{i + 1}.xml"] = xml
        end

        ::Compress::Zip::Writer.open(io) do |zip|
          # Copy the template's other parts. Worksheets are skipped because they
          # are rewritten under new names. The calculation chain is skipped
          # because it would be stale against changed sheet data and Excel
          # rebuilds it on open; its relationship in the workbook is not removed.
          if template_entries
            template_entries.each do |filename, content|
              next if managed.has_key?(filename)
              next if filename.starts_with?("xl/worksheets/")
              next if filename == "xl/calcChain.xml"
              add(zip, filename, content)
            end
          end

          managed.each do |filename, content|
            add(zip, filename, content)
          end
        end
      end

      # Writes a single-sheet workbook of *rows* to *io*, each row starting at
      # column 1.
      def self.write_rows(io : IO, rows : Array(Array(CellValue)),
                          sheet_name : String = "Sheet1") : Nil
        cells_map = {} of Int32 => Row
        rows.each_with_index do |row_values, i|
          row_id = i + 1
          cells = {} of Int32 => Cell
          row_values.each_with_index do |val, j|
            cells[j + 1] = Cell.new(val)
          end
          cells_map[row_id] = Row.new(row_id, cells)
        end

        sheet = Sheet.new(sheet_name, cells_map)
        document = Document.new([sheet])
        write(io, document)
      end

      private def self.add(zip : ::Compress::Zip::Writer, filename : String, content : String) : Nil
        zip.add(filename) { |entry_io| entry_io.print content }
      end

      private def self.build_content_types(sheet_names : Array(String),
                                           template_entries : Hash(String, String)?) : String
        # Keep the template's `Override` entries for parts this shard does not
        # write. Its `Default` entries, by file extension, are not kept.
        extra_overrides = {} of String => String # PartName => ContentType

        if te = template_entries
          if raw = te["[Content_Types].xml"]?
            doc = XML.parse(raw)
            ns_map = {"ct" => CONTENT_TYPES_NS}
            doc.xpath_nodes("//ct:Types/ct:Override", ns_map).each do |node|
              part = node["PartName"]
              ctype = node["ContentType"]
              next if part == "/xl/workbook.xml"
              next if part == "/xl/sharedStrings.xml"
              next if part == "/xl/styles.xml"
              next if part.starts_with?("/xl/worksheets/")
              next if part == "/xl/calcChain.xml"
              extra_overrides[part] = ctype
            end
          end
        end

        XML.build(indent: "  ") do |xml|
          xml.element("Types", xmlns: CONTENT_TYPES_NS) do
            xml.element("Default",
              Extension: "rels",
              ContentType: RELS_CONTENT_TYPE)
            xml.element("Default",
              Extension: "xml",
              ContentType: "application/xml")
            xml.element("Override",
              PartName: "/xl/workbook.xml",
              ContentType: WORKBOOK_CONTENT_TYPE)
            xml.element("Override",
              PartName: "/xl/sharedStrings.xml",
              ContentType: SHARED_STRINGS_CONTENT_TYPE)
            xml.element("Override",
              PartName: "/xl/styles.xml",
              ContentType: STYLES_CONTENT_TYPE)
            sheet_names.each_with_index do |_, i|
              xml.element("Override",
                PartName: "/xl/worksheets/sheet#{i + 1}.xml",
                ContentType: WORKSHEET_CONTENT_TYPE)
            end
            extra_overrides.each do |part, ctype|
              xml.element("Override", PartName: part, ContentType: ctype)
            end
          end
        end
      end

      private def self.build_root_rels : String
        XML.build(indent: "  ") do |xml|
          xml.element("Relationships", xmlns: RELS_NS) do
            xml.element("Relationship",
              Id: "rId1",
              Type: OFFICE_DOCUMENT_TYPE,
              Target: "xl/workbook.xml")
          end
        end
      end

      private def self.minimal_styles : String
        XML.build(indent: "  ") do |xml|
          xml.element("styleSheet", xmlns: MAIN_NS) do
            xml.element("fonts", count: "1") do
              xml.element("font") do
                xml.element("sz", val: "11")
                xml.element("name", val: "Calibri")
              end
            end
            xml.element("fills", count: "2") do
              xml.element("fill") { xml.element("patternFill", patternType: "none") }
              xml.element("fill") { xml.element("patternFill", patternType: "gray125") }
            end
            xml.element("borders", count: "1") do
              xml.element("border") do
                ["left", "right", "top", "bottom", "diagonal"].each do |side|
                  xml.element(side)
                end
              end
            end
            xml.element("cellStyleXfs", count: "1") do
              xml.element("xf", numFmtId: "0", fontId: "0", fillId: "0", borderId: "0")
            end
            # xf 0 is General; 1, 2 and 3 are the date-only (14), time-only (20)
            # and date-time (22) styles that `DateValue`'s factories refer to.
            xml.element("cellXfs", count: "4") do
              xml.element("xf", numFmtId: "0", fontId: "0", fillId: "0", borderId: "0", xfId: "0")
              xml.element("xf", numFmtId: "14", fontId: "0", fillId: "0", borderId: "0", xfId: "0")
              xml.element("xf", numFmtId: "20", fontId: "0", fillId: "0", borderId: "0", xfId: "0")
              xml.element("xf", numFmtId: "22", fontId: "0", fillId: "0", borderId: "0", xfId: "0")
            end
          end
        end
      end
    end
  end
end
