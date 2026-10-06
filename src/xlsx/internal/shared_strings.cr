require "./internal"

module XLSX
  module Internal
    # The shared string table, `xl/sharedStrings.xml`: each distinct string once,
    # referred to by index from cells with `t="s"`. Reading parses the table
    # once and looks strings up by index; writing interns strings as sheets are
    # built and emits the table last.
    class SharedStrings
      def initialize
        @strings = Array(String).new
        @index = Hash(String, Int32).new
      end

      # Returns the string at *index*.
      # Raises `IndexError` if out of bounds.
      def [](index : Int32) : String
        @strings[index]
      end

      # Returns the index of *value*, adding it to the table if it is new.
      def intern(value : String) : Int32
        @index.fetch(value) do
          idx = @strings.size
          @strings << value
          @index[value] = idx
        end
      end

      # Returns the number of distinct strings.
      def size : Int32
        @strings.size
      end

      # Appends the strings of a `sharedStrings.xml` document to this table.
      # Only an `<si>`'s direct `<t>` is read: a rich-text entry made of runs
      # (`<r>`) adds nothing, so every later index is off.
      def parse(xml : String) : Nil
        doc = XML.parse(xml)
        doc.xpath_nodes("//ns:sst/ns:si/ns:t", MAIN_NS_MAP).each do |elem_t|
          # Whitespace is kept as written; `xml:space` is not consulted.
          @strings << (elem_t ? elem_t.content : "")
        end
        @strings.each_with_index { |s, i| @index[s] = i }
      end

      # Returns the table as `sharedStrings.xml` content.
      def to_xml : String
        XML.build(indent: "  ") do |xml|
          xml.element("sst",
            xmlns: MAIN_NS,
            count: @strings.size,
            uniqueCount: @strings.size
          ) do
            @strings.each do |s|
              xml.element("si") do
                xml.element("t") { xml.text s }
              end
            end
          end
        end
      end
    end
  end
end
