module XLSX
  # Represents a cell that exists in the XML but carries no value.
  # Distinct from Nil, which means the cell is absent from the XML entirely.
  struct Empty
    INSTANCE = new

    def to_s(io : IO) : Nil
      # intentionally empty — an empty cell has no string representation
    end

    def ==(other : Empty) : Bool
      true
    end
  end

  # The full set of values a cell can hold.
  #
  # - `String`     — text cell
  # - `Float64`    — numeric cell (Excel stores all numbers as floats)
  # - `Bool`       — boolean cell
  # - `Empty`      — cell element present in XML, but no value child
  # - `Nil`        — cell element absent from XML entirely
  alias CellValue = String | Float64 | Bool | Empty | Nil
end
