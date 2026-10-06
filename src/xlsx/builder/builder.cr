module XLSX
  # Collects rows for a single-sheet workbook and writes them on `close`.
  # Usually obtained from `XLSX.build(io)`, which calls `close` itself.
  #
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

    # Appends a row built by the block, which receives an empty array to fill.
    def row(& : Array(CellValue) ->)
      row = [] of CellValue
      yield row
      @rows << row
    end

    # Appends a row from any `Enumerable` of `CellValue`.
    def row(values : Enumerable)
      row do |row|
        values.each do |value|
          row << value
        end
      end
    end

    # Appends a row from the given values.
    def row(*values : CellValue)
      row(values)
    end

    # Writes the workbook to the `IO`, which is left open. Call it once: each
    # call writes a complete archive.
    def close
      Internal::Zip.write_rows(@io, @rows)
    end
  end
end
