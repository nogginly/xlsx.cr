module XLSX
  # CSV-compatible XLSX builder. Appends rows sequentially to a single sheet.
  #
  # Usage:
  # ```
  # XLSX.build(io) do |b|
  #   b.row("name", "age")
  #   b.row("alice", 30.0)
  # end
  # ```
  class Builder
    def initialize(@io : IO)
      @rows = [] of Array(CellValue)
    end

    def row(& : Array(CellValue) ->)
      row = [] of CellValue
      yield row
      @rows << row
    end

    # Appends a row from any `Enumerable`.
    def row(values : Enumerable)
      row do |row|
        values.each do |value|
          row << value
        end
      end
    end

    # Appends a row from a splat of values.
    def row(*values : CellValue)
      row(values)
    end

    # Finalizes and writes the XLSX file to the `IO`.
    #
    # NOTE: Not yet implemented — requires the internal ZIP/XML writer.
    def close
      raise NotImplementedError.new("XLSX::Builder#close — ZIP/XML writer not yet implemented")
    end
  end
end
