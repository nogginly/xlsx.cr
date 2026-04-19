module XLSX
  # An XLSX document containing one or more worksheets.
  class Document
    # Opens an XLSX document from a file path.
    def self.open(path : String) : self
      File.open(path, "r") do |io|
        open(io)
      end
    end

    # Opens an XLSX document from an `IO` source.
    #
    # NOTE: Not yet implemented — requires the internal ZIP/XML parser.
    def self.open(io : IO) : self
      raise NotImplementedError.new("XLSX::Document.open — ZIP/XML parser not yet implemented")
    end

    def initialize(@sheets : Array(Sheet))
    end

    # Yields each sheet in document order.
    def each(& : Sheet ->)
      @sheets.each { |sheet| yield sheet }
    end

    # Returns the sheet with the given *name*.
    # Raises `KeyError` if not found.
    def [](name : String) : Sheet
      @sheets.find { |s| s.name == name } ||
        raise KeyError.new("No sheet named #{name.inspect}")
    end

    # Returns the sheet at the given 0-based *index*.
    def [](index : Int32) : Sheet
      @sheets[index]
    end

    # Returns all sheet names in document order.
    def sheet_names : Array(String)
      @sheets.map(&.name)
    end

    # Returns the number of sheets.
    def size : Int32
      @sheets.size
    end
  end
end
