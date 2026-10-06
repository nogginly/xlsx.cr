module XLSX
  # A workbook: its worksheets, in the order the workbook lists them.
  class Document
    # Reads the whole workbook at *path* into memory. See `.open(io)` for errors.
    def self.open(path : String) : self
      File.open(path, "r") do |io|
        open(io)
      end
    end

    # Reads the whole workbook from *io* into memory; *io* is not closed.
    #
    # Raises `KeyError` when a part this shard needs is missing, which is also
    # how data that is not a ZIP archive usually fails. Malformed XML inside a
    # part does not raise: the parser recovers what it can.
    def self.open(io : IO) : self
      Internal::Zip.read(io)
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

    # Returns the sheet at the 0-based *index*. Raises `IndexError` if out of range.
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
