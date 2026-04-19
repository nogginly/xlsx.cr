require "./internal"

module XLSX
  module Internal
    # Manages the shared string table (`xl/sharedStrings.xml`).
    #
    # In XLSX, all string cell values are stored here rather than inline.
    # A cell with `t="s"` holds an integer index into this table.
    #
    # On read:  parse the XML once, look up strings by index.
    # On write: intern strings as they are encountered, emit XML at the end.
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

      # Interns *value*, returning its index.
      # Repeated calls with the same value return the same index.
      def intern(value : String) : Int32
        @index.fetch(value) do
          idx = @strings.size
          @strings << value
          @index[value] = idx
        end
      end

      # Returns the total number of unique strings.
      def size : Int32
        @strings.size
      end

      # Parses a `sharedStrings.xml` document into this table.
      def parse(xml : String) : Nil
        doc = XML.parse(xml)
        doc.xpath_nodes("//ns:sst/ns:si/ns:t", MAIN_NS_MAP).each do |elem_t|
          # <t> holds the value; preserve whitespace via xml:space if present
          @strings << (elem_t ? elem_t.content : "")
        end
        @strings.each_with_index { |s, i| @index[s] = i }
      end

      # Serialises the table to `sharedStrings.xml` content.
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
