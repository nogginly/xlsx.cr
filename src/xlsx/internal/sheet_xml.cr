require "./internal"

module XLSX
  module Internal
    # Parses and builds individual worksheet XML files (`xl/worksheets/sheetN.xml`).
    #
    # Depends on `SharedStrings` for resolving and interning string cell values.
    #
    # When a *template_xml* is supplied to `build`, the worksheet XML is patched
    # rather than regenerated — preserving `<sheetViews>` (freeze panes),
    # `<sheetFormatPr>`, `<pageMargins>`, and all other non-data elements.
    # Existing rows retain their original XML (including style attributes);
    # only newly appended rows are generated fresh.
    class SheetXML
      NS_MAP = {"ns" => MAIN_NS}

      # Parses a worksheet XML string into a `Sheet`.
      #
      # *name*           — the sheet name (from workbook.xml)
      # *xml*            — content of the worksheet XML file
      # *shared_strings* — the shared string table for the workbook
      def parse(name : String, xml : String, shared_strings : SharedStrings) : Sheet
        rows = Hash(Int32, Row).new
        doc = XML.parse(xml)

        doc.xpath_nodes("//ns:worksheet/ns:sheetData/ns:row", NS_MAP).each do |row_node|
          row_id = row_node["r"].to_i
          cells = Hash(Int32, Cell).new
          attrs = node_attrs(row_node, except: "r")

          row_node.xpath_nodes("ns:c", NS_MAP).each do |cell_node|
            ref = cell_node["r"]
            col_id = col_from_ref(ref)
            type = cell_node["t"]?
            v_node = cell_node.xpath_node("ns:v", NS_MAP)
            f_node = cell_node.xpath_node("ns:f", NS_MAP)
            cell_attrs = node_attrs(cell_node, except: "r")

            value : CellValue = if f_node
              parse_formula(f_node, v_node, type, shared_strings)
            elsif v_node.nil?
              Empty::INSTANCE
            elsif type == "s"
              shared_strings[v_node.content.to_i]
            elsif type == "b"
              v_node.content == "1"
            elsif type == "inlineStr"
              t = cell_node.xpath_node("ns:is/ns:t", NS_MAP)
              t ? t.content : Empty::INSTANCE
            else
              if type.nil?
                v_node.content.to_f64
              else
                v_node.content
              end
            end

            cells[col_id] = Cell.new(value, cell_attrs)
          end

          rows[row_id] = Row.new(row_id, cells, attrs)
        end

        Sheet.new(name, rows)
      end

      # Serialises a `Sheet` to worksheet XML.
      #
      # When *template_xml* is given, only `<sheetData>` is replaced; all other
      # worksheet elements are preserved verbatim. Existing rows use their
      # original stored attributes; new rows (not present in the template) are
      # generated fresh.
      #
      # When *template_row_ids* is supplied, row IDs in that set are treated as
      # existing and their stored attrs are emitted; others are treated as new.
      def build(sheet : Sheet, shared_strings : SharedStrings,
                template_xml : String? = nil) : String
        sheet_data = build_sheet_data(sheet, shared_strings)

        if raw = template_xml
          raw.gsub(/<sheetData>.*?<\/sheetData>|<sheetData\/>/m, sheet_data)
        else
          String.build do |s|
            s << %[<?xml version="1.0" encoding="UTF-8"?>]
            s << %[<worksheet xmlns="#{MAIN_NS}">]
            s << sheet_data
            s << "</worksheet>"
          end
        end
      end

      # -----------------------------------------------------------------------
      # Cell reference helpers (public for testability)
      # -----------------------------------------------------------------------

      def col_index(letters : String) : Int32
        letters.upcase.chars.reduce(0) do |acc, ch|
          acc * 26 + (ch.ord - 'A'.ord + 1)
        end
      end

      def col_letters(col : Int32) : String
        result = ""
        n = col
        while n > 0
          n, remainder = (n - 1).divmod(26)
          result = ('A'.ord + remainder).chr.to_s + result
        end
        result
      end

      def col_from_ref(ref : String) : Int32
        col_index(ref.chars.take_while(&.letter?).join)
      end

      def cell_ref(row : Int32, col : Int32) : String
        "#{col_letters(col)}#{row}"
      end

      # -----------------------------------------------------------------------

      # Builds the `<sheetData>...</sheetData>` string for *sheet*.
      # Row and cell attrs stored on the model are re-emitted verbatim.
      private def build_sheet_data(sheet : Sheet, ss : SharedStrings) : String
        String.build do |s|
          s << "<sheetData>"
          sheet.each_row do |row, row_id|
            s << "<row r=\"#{row_id}\""
            row.attrs.each { |k, v| s << " #{k}=\"#{HTML.escape(v)}\"" }
            s << ">"
            row.each_cell_full do |cell, col_id|
              ref = cell_ref(row_id, col_id)
              s << emit_cell_string(ref, cell, ss)
            end
            s << "</row>"
          end
          s << "</sheetData>"
        end
      end

      private def emit_cell_string(ref : String, cell : Cell, ss : SharedStrings) : String
        extra = cell.attrs.reject("t").map { |k, v| " #{k}=\"#{HTML.escape(v)}\"" }.join
        value = cell.value
        case value
        in String
          idx = ss.intern(value)
          %(<c r="#{ref}" t="s"#{extra}><v>#{idx}</v></c>)
        in Int64
          %(<c r="#{ref}"#{extra}><v>#{value}</v></c>)
        in Float64
          %(<c r="#{ref}"#{extra}><v>#{value}</v></c>)
        in Bool
          %(<c r="#{ref}" t="b"#{extra}><v>#{value ? "1" : "0"}</v></c>)
        in Formula
          emit_formula_string(ref, value, cell.attrs.reject("t"), ss)
        in SharedFormulaRef
          emit_shared_ref_string(ref, value, cell.attrs.reject("t"), ss)
        in Empty
          %(<c r="#{ref}"#{extra}/>)
        in Nil
          ""
        end
      end

      private def emit_formula_string(ref : String, formula : Formula,
                                      extra_attrs : Hash(String, String),
                                      ss : SharedStrings) : String
        extra = extra_attrs.map { |k, v| " #{k}=\"#{HTML.escape(v)}\"" }.join
        cached = formula.cached_value
        t_attr, v_content = formula_type_and_value(cached, ss)
        t_str = t_attr ? " t=\"#{t_attr}\"" : ""
        f_str = emit_f_string(formula)
        v_str = v_content ? "<v>#{v_content}</v>" : ""
        %(<c r="#{ref}"#{t_str}#{extra}>#{f_str}#{v_str}</c>)
      end

      private def emit_shared_ref_string(ref : String, sfr : SharedFormulaRef,
                                         extra_attrs : Hash(String, String),
                                         ss : SharedStrings) : String
        extra = extra_attrs.map { |k, v| " #{k}=\"#{HTML.escape(v)}\"" }.join
        t_attr, v_content = formula_type_and_value(sfr.cached_value, ss)
        t_str = t_attr ? " t=\"#{t_attr}\"" : ""
        f_str = %(<f t="shared" si="#{sfr.shared_index}"/>)
        v_str = v_content ? "<v>#{v_content}</v>" : ""
        %(<c r="#{ref}"#{t_str}#{extra}>#{f_str}#{v_str}</c>)
      end

      private def emit_f_string(formula : Formula) : String
        expr = HTML.escape(formula.expression)
        if si = formula.shared_index
          ref_attr = formula.shared_ref ? " ref=\"#{formula.shared_ref}\"" : ""
          %(<f t="shared" si="#{si}"#{ref_attr}>#{expr}</f>)
        else
          %(<f>#{expr}</f>)
        end
      end

      # Returns {t_attribute, v_content} for a formula's cached value.
      private def formula_type_and_value(cached : CellValue,
                                         ss : SharedStrings) : {String?, String?}
        case cached
        in String                                then {"str", ss.intern(cached).to_s}
        in Int64                                 then {nil, cached.to_s}
        in Float64                               then {nil, cached.to_s}
        in Bool                                  then {"b", cached ? "1" : "0"}
        in Formula, SharedFormulaRef, Empty, Nil then {nil, nil}
        end
      end

      # Collects all attributes from *node* except *except* into a Hash.
      private def node_attrs(node : XML::Node, except : String) : Hash(String, String)
        attrs = {} of String => String
        node.attributes.each do |attr|
          next if attr.name == except
          attrs[attr.name] = attr.content
        end
        attrs
      end

      private def parse_formula(f_node : XML::Node, v_node : XML::Node?,
                                type : String?,
                                shared_strings : SharedStrings) : CellValue
        cached = parse_cached_value(v_node, type, shared_strings)
        si_str = f_node["si"]?

        if si_str
          si = si_str.to_i
          expr = f_node.content.strip
          if expr.empty?
            SharedFormulaRef.new(si, cached)
          else
            Formula.new(expr, cached,
              shared_index: si,
              shared_ref: f_node["ref"]?)
          end
        else
          Formula.new(f_node.content.strip, cached)
        end
      end

      private def parse_cached_value(v_node : XML::Node?, type : String?,
                                     shared_strings : SharedStrings) : CellValue
        return Empty::INSTANCE if v_node.nil?
        case type
        when "s"        then shared_strings[v_node.content.to_i]
        when "b"        then v_node.content == "1"
        when "str", "e" then v_node.content
        else                 v_node.content.to_f64
        end
      end
    end
  end
end
