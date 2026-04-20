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

  # A cell containing a formula and its last cached result.
  #
  # - `expression`    — the formula string without the leading `=` (e.g. `"SUM(A1:A5)"`)
  # - `cached_value`  — the last value Excel calculated for this cell
  # - `shared_index`  — `si` attribute if this cell is part of a shared formula group
  # - `shared_ref`    — `ref` span attribute if this cell is the master of a shared group
  class Formula
    getter expression : String
    getter cached_value : CellValue
    getter shared_index : Int32?
    getter shared_ref : String?

    def initialize(@expression : String, @cached_value : CellValue,
                   @shared_index : Int32? = nil, @shared_ref : String? = nil)
    end

    def to_s(io : IO) : Nil
      io << "=" << @expression
    end

    def ==(other : Formula) : Bool
      @expression == other.expression &&
        @cached_value == other.cached_value &&
        @shared_index == other.shared_index &&
        @shared_ref == other.shared_ref
    end
  end

  # A satellite cell that belongs to a shared formula group.
  #
  # The formula expression lives on the master cell (`Formula` with matching
  # `shared_index`). This cell carries only the group index and its cached value.
  class SharedFormulaRef
    getter shared_index : Int32
    getter cached_value : CellValue

    def initialize(@shared_index : Int32, @cached_value : CellValue)
    end

    def to_s(io : IO) : Nil
      io << cached_value
    end

    def ==(other : SharedFormulaRef) : Bool
      @shared_index == other.shared_index &&
        @cached_value == other.cached_value
    end
  end

  # A cell value paired with its preserved XML attributes (e.g. style index `s`).
  #
  # `attrs` contains all `<c>` element attributes except `r` (the cell reference),
  # which is always derived from position.
  record Cell, value : CellValue, attrs : Hash(String, String) do
    # Convenience — most callers only need the value.
    def self.new(value : CellValue)
      new(value, {} of String => String)
    end
  end
  # The full set of values a cell can hold.
  #
  # - `String`           — text cell
  # - `Int64`            — integer numeric cell (write convenience; Excel stores as float)
  # - `Float64`          — floating point numeric cell
  # - `Bool`             — boolean cell
  # - `Formula`          — formula cell with cached result
  # - `SharedFormulaRef` — satellite cell in a shared formula group
  # - `Empty`            — cell element present in XML, but no value child
  # - `Nil`              — cell element absent from XML entirely
  alias CellValue = String | Int64 | Float64 | Bool | Formula | SharedFormulaRef | Empty | Nil
end
