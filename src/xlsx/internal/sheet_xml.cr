require "./internal"

module XLSX
  module Internal
    # Reads and writes one worksheet part, `xl/worksheets/sheetN.xml`, using
    # `SharedStrings` to resolve and intern string values.
    #
    # Writing builds every row and cell from the `Sheet`. With a template's
    # sheet XML, only its `<sheetData>` is replaced, so everything else, such as
    # `<sheetViews>` (freeze panes), `<cols>` and `<pageMargins>`, is kept.
    class SheetXML
      NS_MAP = {"ns" => MAIN_NS}

      # Parses worksheet *xml* into a `Sheet` named *name*. *shared_strings*
      # resolves `t="s"` cells, and *styles*, if given, marks which numbers are
      # dates. Raises `KeyError` for a row or cell without an `r` attribute.
      def parse(name : String, xml : String, shared_strings : SharedStrings,
                styles : StylesXML? = nil) : Sheet
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
            style_idx = cell_node["s"]?.try(&.to_i)

            value : CellValue = if f_node
              parse_formula(f_node, v_node, type, shared_strings)
            elsif type == "inlineStr"
              t = cell_node.xpath_node("ns:is/ns:t", NS_MAP)
              t ? InlineStr.new(t.content) : Empty::INSTANCE
            elsif v_node.nil?
              Empty::INSTANCE
            elsif type == "s"
              shared_strings[v_node.content.to_i]
            elsif type == "b"
              v_node.content == "1"
            else
              raw = v_node.content
              if type.nil?
                num = raw.to_f64
                if style_idx && styles && styles.date_format?(style_idx)
                  DateValue.new(styles.serial_to_time(num), style_idx)
                else
                  num
                end
              else
                raw
              end
            end

            cells[col_id] = Cell.new(value, cell_attrs)
          end

          rows[row_id] = Row.new(row_id, cells, attrs)
        end

        Sheet.new(name, rows)
      end

      # Returns *sheet* as worksheet XML. Given *template_xml*, returns it with
      # its `<sheetData>` replaced, or unchanged if no `<sheetData>` element is
      # matched (for example, one with a namespace prefix). *styles* converts
      # dates to serial numbers.
      def build(sheet : Sheet, shared_strings : SharedStrings,
                template_xml : String? = nil,
                styles : StylesXML? = nil) : String
        sheet_data = build_sheet_data(sheet, shared_strings, styles)

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

      # Cell reference helpers, public so specs can call them directly.

      # Returns the 1-based column number for *letters*: "A" is 1, "AB" is 28.
      def col_index(letters : String) : Int32
        letters.upcase.chars.reduce(0) do |acc, ch|
          acc * 26 + (ch.ord - 'A'.ord + 1)
        end
      end

      # Returns the column letters for 1-based *col*: 28 is "AB".
      def col_letters(col : Int32) : String
        result = ""
        n = col
        while n > 0
          n, remainder = (n - 1).divmod(26)
          result = ('A'.ord + remainder).chr.to_s + result
        end
        result
      end

      # Returns the column number of a cell reference: "AB12" is 28.
      def col_from_ref(ref : String) : Int32
        col_index(ref.chars.take_while(&.letter?).join)
      end

      # Returns the cell reference for *row* and *col*: 12 and 28 are "AB12".
      def cell_ref(row : Int32, col : Int32) : String
        "#{col_letters(col)}#{row}"
      end

      # Returns the `<sheetData>` element for *sheet*. Row and cell attributes
      # from the model are written back, except that a cell's `t` comes from its
      # value and a `DateValue` supplies its own `s`.
      private def build_sheet_data(sheet : Sheet, ss : SharedStrings,
                                   styles : StylesXML? = nil) : String
        String.build do |s|
          s << "<sheetData>"
          sheet.each_row do |row, row_id|
            s << "<row r=\"#{row_id}\""
            row.attrs.each { |k, v| s << " #{k}=\"#{HTML.escape(v)}\"" }
            s << ">"
            row.each_cell_full do |cell, col_id|
              ref = cell_ref(row_id, col_id)
              s << emit_cell_string(ref, cell, ss, styles)
            end
            s << "</row>"
          end
          s << "</sheetData>"
        end
      end

      private def emit_cell_string(ref : String, cell : Cell, ss : SharedStrings,
                                   styles : StylesXML? = nil) : String
        extra = cell.attrs.reject("t").map { |k, v| " #{k}=\"#{HTML.escape(v)}\"" }.join
        value = cell.value
        case value
        in String
          idx = ss.intern(value)
          %(<c r="#{ref}" t="s"#{extra}><v>#{idx}</v></c>)
        in InlineStr
          %(<c r="#{ref}" t="inlineStr"#{extra}><is><t>#{HTML.escape(value.value)}</t></is></c>)
        in Int64
          %(<c r="#{ref}"#{extra}><v>#{value}</v></c>)
        in Float64
          %(<c r="#{ref}"#{extra}><v>#{value}</v></c>)
        in DateValue
          serial = (styles || StylesXML.new).time_to_serial(value.value)
          extra_no_s = cell.attrs.reject("t").reject("s").map { |k, v| " #{k}=\"#{HTML.escape(v)}\"" }.join
          %(<c r="#{ref}" s="#{value.style_index}"#{extra_no_s}><v>#{serial}</v></c>)
        in Bool
          %(<c r="#{ref}" t="b"#{extra}><v>#{value ? "1" : "0"}</v></c>)
        in Formula
          emit_formula_string(ref, value, cell.attrs.reject("t"), ss, styles)
        in SharedFormulaRef
          emit_shared_ref_string(ref, value, cell.attrs.reject("t"), ss, styles)
        in Empty
          %(<c r="#{ref}"#{extra}/>)
        in Nil
          ""
        end
      end

      private def emit_formula_string(ref : String, formula : Formula,
                                      extra_attrs : Hash(String, String),
                                      ss : SharedStrings,
                                      styles : StylesXML? = nil) : String
        extra = extra_attrs.map { |k, v| " #{k}=\"#{HTML.escape(v)}\"" }.join
        cached = formula.cached_value
        t_attr, v_content = formula_type_and_value(cached, styles)
        t_str = t_attr ? " t=\"#{t_attr}\"" : ""
        f_str = emit_f_string(formula)
        v_str = v_content ? "<v>#{v_content}</v>" : ""
        %(<c r="#{ref}"#{t_str}#{extra}>#{f_str}#{v_str}</c>)
      end

      private def emit_shared_ref_string(ref : String, sfr : SharedFormulaRef,
                                         extra_attrs : Hash(String, String),
                                         ss : SharedStrings,
                                         styles : StylesXML? = nil) : String
        extra = extra_attrs.map { |k, v| " #{k}=\"#{HTML.escape(v)}\"" }.join
        t_attr, v_content = formula_type_and_value(sfr.cached_value, styles)
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

      # Returns the `t` attribute and `<v>` text for a formula's cached value,
      # either of which may be absent. String text is returned unescaped.
      private def formula_type_and_value(cached : CellValue,
                                         styles : StylesXML? = nil) : {String?, String?}
        case cached
        in String                                then {"str", cached}       # t="str" → value direct in <v>, not interned
        in InlineStr                             then {"str", cached.value} # same
        in Int64                                 then {nil, cached.to_s}
        in Float64                               then {nil, cached.to_s}
        in Bool                                  then {"b", cached ? "1" : "0"}
        in DateValue                             then {nil, (styles || StylesXML.new).time_to_serial(cached.value).to_s}
        in Formula, SharedFormulaRef, Empty, Nil then {nil, nil}
        end
      end

      # Returns *node*'s attributes, other than *except*, by local name: a
      # namespace prefix such as `x14ac:` is lost.
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
