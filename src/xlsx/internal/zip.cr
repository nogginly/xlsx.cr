require "compress/zip"

require "./internal"

module XLSX
  module Internal
    # Reads and writes XLSX ZIP archives.
    #
    # Orchestrates `SharedStrings`, `WorkbookXML`, and `SheetXML` to
    # assemble a `Document` from an IO source, and serialise a `Document`
    # back to an IO destination.
    #
    # An XLSX file is a ZIP archive with this structure:
    # ```
    # [Content_Types].xml
    # _rels/.rels
    # xl/workbook.xml
    # xl/_rels/workbook.xml.rels
    # xl/sharedStrings.xml
    # xl/styles.xml
    # xl/worksheets/sheet1.xml
    # xl/worksheets/sheet2.xml  # one per sheet
    # ```
    class Zip
      # Reads an XLSX file from *io* and returns a `Document`.
      def self.read(io : IO) : Document
        entries = collect_entries(io)

        wb = WorkbookXML.new
        ss = SharedStrings.new
        sx = SheetXML.new

        wb.parse_workbook(entries["xl/workbook.xml"])
        wb.parse_rels(entries["xl/_rels/workbook.xml.rels"])

        if raw_ss = entries["xl/sharedStrings.xml"]?
          ss.parse(raw_ss)
        end

        sheets = wb.sheet_names.map do |name|
          target = wb.target_for(name).not_nil!
          xml = entries["xl/#{target}"]
          sx.parse(name, xml, ss)
        end

        Document.new(sheets)
      end

      # Writes *document* as an XLSX file to *io*.
      def self.write(io : IO, document : Document) : Nil
        ss = SharedStrings.new
        sx = SheetXML.new

        # Pre-build all sheet XML so strings are interned before we write
        # the shared string table.
        sheet_xmls = [] of {String, String} # {sheet_name, xml}
        document.each do |sheet|
          sheet_xmls << {sheet.name, sx.build(sheet, ss)}
        end

        sheet_names = sheet_xmls.map(&.[0])

        wb = WorkbookXML.new

        Compress::Zip::Writer.open(io) do |zip|
          add(zip, "[Content_Types].xml", build_content_types(sheet_names))
          add(zip, "_rels/.rels", build_root_rels)
          add(zip, "xl/workbook.xml", wb.build_workbook(sheet_names))
          add(zip, "xl/_rels/workbook.xml.rels", wb.build_rels(sheet_names))
          add(zip, "xl/sharedStrings.xml", ss.to_xml)
          add(zip, "xl/styles.xml", minimal_styles)

          sheet_xmls.each_with_index do |(_, xml), i|
            add(zip, "xl/worksheets/sheet#{i + 1}.xml", xml)
          end
        end
      end

      # ------------------------------------------------------------------
      # Convenience: write from a flat rows array (CSV-compatible Builder)
      # ------------------------------------------------------------------

      # Writes a single-sheet XLSX from *rows* to *io*.
      # *sheet_name* defaults to "Sheet1".
      def self.write_rows(io : IO, rows : Array(Array(CellValue)),
                          sheet_name : String = "Sheet1") : Nil
        cells_map = {} of Int32 => Row
        rows.each_with_index do |row_values, i|
          row_id = i + 1
          cells = {} of Int32 => CellValue
          row_values.each_with_index do |val, j|
            cells[j + 1] = val
          end
          cells_map[row_id] = Row.new(row_id, cells)
        end

        sheet = Sheet.new(sheet_name, cells_map)
        document = Document.new([sheet])
        write(io, document)
      end

      # ------------------------------------------------------------------
      private def self.collect_entries(io : IO) : Hash(String, String)
        entries = {} of String => String
        Compress::Zip::Reader.open(io) do |zip|
          zip.each_entry do |entry|
            entries[entry.filename] = entry.io.gets_to_end
          end
        end
        entries
      end

      private def self.add(zip : Compress::Zip::Writer, filename : String, content : String) : Nil
        zip.add(filename) { |entry_io| entry_io.print content }
      end

      private def self.build_content_types(sheet_names : Array(String)) : String
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
            xml.element("cellXfs", count: "1") do
              xml.element("xf", numFmtId: "0", fontId: "0", fillId: "0", borderId: "0", xfId: "0")
            end
          end
        end
      end
    end
  end
end
