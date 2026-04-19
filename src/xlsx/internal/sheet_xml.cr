require "./internal"

module XLSX
  module Internal
    # Parses and builds individual worksheet XML files (`xl/worksheets/sheetN.xml`).
    #
    # Depends on `SharedStrings` for resolving and interning string cell values.
    class SheetXML
      # Parses a worksheet XML string into a `Sheet`.
      #
      # *name*           — the sheet name (from workbook.xml)
      # *xml*            — content of the worksheet XML file
      # *shared_strings* — the shared string table for the workbook
      def parse(name : String, xml : String, shared_strings : SharedStrings) : Sheet
        rows = Hash(Int32, Row).new
        doc = XML.parse(xml)

        doc.xpath_nodes("//ns:worksheet/ns:sheetData/ns:row", MAIN_NS_MAP).each do |row_node|
          row_id = row_node["r"].to_i
          cells = Hash(Int32, CellValue).new

          row_node.xpath_nodes("ns:c", MAIN_NS_MAP).each do |cell_node|
            ref = cell_node["r"] # e.g. "B3"
            col_id = col_from_ref(ref)
            type = cell_node["t"]?
            v_node = cell_node.xpath_node("ns:v", MAIN_NS_MAP)

            value : CellValue = if v_node.nil?
              Empty::INSTANCE
            elsif type == "s"
              shared_strings[v_node.content.to_i]
            elsif type == "b"
              v_node.content == "1"
            elsif type == "inlineStr"
              t = cell_node.xpath_node("ns:is/ns:t", MAIN_NS_MAP)
              t ? t.content : Empty::INSTANCE
            else
              # no type attr -> number; type "str" or "e" -> treat as string
              if type.nil?
                v_node.content.to_f64
              else
                v_node.content
              end
            end

            cells[col_id] = value
          end

          rows[row_id] = Row.new(row_id, cells)
        end

        Sheet.new(name, rows)
      end

      # Serialises a `Sheet` to worksheet XML.
      #
      # Strings are interned into *shared_strings* during serialisation.
      def build(sheet : Sheet, shared_strings : SharedStrings) : String
        XML.build(indent: "  ") do |xml|
          xml.element("worksheet", xmlns: MAIN_NS) do
            xml.element("sheetData") do
              sheet.each_row do |row, row_id|
                xml.element("row", r: row_id) do
                  row.each_cell do |value, col_id|
                    ref = cell_ref(row_id, col_id)
                    emit_cell(xml, ref, value, shared_strings)
                  end
                end
              end
            end
          end
        end
      end

      # -----------------------------------------------------------------------
      # Cell reference helpers (public for testability)
      # -----------------------------------------------------------------------

      # Converts a column letter string to a 1-based integer.
      # "A" -> 1, "Z" -> 26, "AA" -> 27
      def col_index(letters : String) : Int32
        letters.upcase.chars.reduce(0) do |acc, ch|
          acc * 26 + (ch.ord - 'A'.ord + 1)
        end
      end

      # Converts a 1-based column integer to a letter string.
      # 1 -> "A", 26 -> "Z", 27 -> "AA"
      def col_letters(col : Int32) : String
        result = ""
        n = col
        while n > 0
          n, remainder = (n - 1).divmod(26)
          result = ('A'.ord + remainder).chr.to_s + result
        end
        result
      end

      # Parses a cell reference (e.g. "B3") into a 1-based column index.
      def col_from_ref(ref : String) : Int32
        col_index(ref.chars.take_while(&.letter?).join)
      end

      # Produces a cell reference string from 1-based row and col integers.
      def cell_ref(row : Int32, col : Int32) : String
        "#{col_letters(col)}#{row}"
      end

      private def emit_cell(xml : XML::Builder, ref : String, value : CellValue, ss : SharedStrings)
        case value
        in String
          idx = ss.intern(value)
          xml.element("c", r: ref, t: "s") { xml.element("v") { xml.text idx.to_s } }
        in Float64
          xml.element("c", r: ref) { xml.element("v") { xml.text value.to_s } }
        in Bool
          xml.element("c", r: ref, t: "b") { xml.element("v") { xml.text value ? "1" : "0" } }
        in Empty
          xml.element("c", r: ref)
        in Nil
          # absent cells are not written
        end
      end
    end
  end
end
