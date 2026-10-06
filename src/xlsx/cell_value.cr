module XLSX
  # A cell that is present in the sheet XML but holds no value, such as a
  # styled blank. `nil` instead means there is no cell element at all.
  struct Empty
    INSTANCE = new

    # Writes nothing: an empty cell renders as an empty string.
    def to_s(io : IO) : Nil
    end

    def ==(other : Empty) : Bool
      true
    end
  end

  # A formula cell: its expression and the value last calculated for it.
  #
  # - `expression`: the formula without its leading `=`, e.g. `"SUM(A1:A5)"`.
  # - `cached_value`: the value shown until Excel recalculates, written as the
  #   cell's `<v>`. A `Formula`, `SharedFormulaRef`, `Empty` or `nil` writes none.
  # - `shared_index`: the `si` of the shared-formula group this cell is the
  #   master of, if any.
  # - `shared_ref`: the range that group covers, from the master's `ref`.
  #
  # `to_s` renders `=` followed by the expression.
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

  # A non-master cell of a shared-formula group. The expression lives on the
  # group's master, the `Formula` with the same `shared_index`; this cell holds
  # only the group index and its own cached value, which `to_s` renders.
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

  # A cell value and the attributes of its `<c>` element other than `r`, such
  # as the style index `s`. The cell reference is always derived from position.
  # On write, `t` is derived from `value`, and a `DateValue` writes its own
  # `style_index` in place of `s`.
  record Cell, value : CellValue, attrs : Hash(String, String) do
    # Creates a cell with no attributes.
    def self.new(value : CellValue)
      new(value, {} of String => String)
    end
  end
  # A string written inline in its cell rather than to the shared string
  # table, and so a different type from `String`. Reading keeps leading and
  # trailing whitespace; writing does not mark it `xml:space="preserve"`, so
  # other readers may trim it.
  record InlineStr, value : String do
    delegate to_s, size, includes?, starts_with?, ends_with?, strip, to: @value

    def [](index : Int32) : Char
      @value[index]
    end

    def ==(other : String) : Bool
      @value == other
    end
  end

  # A date, time or date-time: a `Time` and the index of the `cellXfs` style
  # that tells Excel how to display it.
  #
  # Values read from a file keep their original style. New values come from
  # the factories, whose indices refer to the stylesheet this shard writes for
  # a new workbook; in a template the same index may name an unrelated style.
  #
  # Times are wall-clock: the offset is discarded on write, whole seconds are
  # the finest unit kept, and reading returns UTC.
  struct DateValue
    getter value : Time
    getter style_index : Int32

    protected def initialize(@value : Time, @style_index : Int32)
    end

    # Creates a date-only value, displayed with built-in format 14 (short date).
    def self.date_only(time : Time) : self
      new(time, Internal::StylesXML::DEFAULT_DATE_STYLE)
    end

    # Creates a time-only value, displayed with built-in format 20 (`h:mm`).
    def self.time_only(time : Time) : self
      new(time, Internal::StylesXML::DEFAULT_TIME_STYLE)
    end

    # Creates a date-time value, displayed with built-in format 22 (`m/d/yy h:mm`).
    def self.date_time(time : Time) : self
      new(time, Internal::StylesXML::DEFAULT_DATE_TIME_STYLE)
    end

    def to_s(io : IO) : Nil
      io << @value
    end

    def ==(other : DateValue) : Bool
      @value == other.value && @style_index == other.style_index
    end
  end

  # Every value a cell can hold.
  #
  # - `String`: a shared-string cell. Reading also returns the raw text of cell
  #   types not modelled here: errors (`e`), ISO dates (`d`), plain strings
  #   (`str`) and numbers marked `t="n"`.
  # - `InlineStr`: an inline-string cell.
  # - `Int64`: an integer, written as a number. Reading never returns one, since
  #   the format stores every number as floating point.
  # - `Float64`: a number.
  # - `Bool`: a boolean.
  # - `DateValue`: a number styled as a date or time.
  # - `Formula`: a formula and its cached result.
  # - `SharedFormulaRef`: a non-master cell of a shared formula.
  # - `Empty`: a cell element with no value.
  # - `Nil`: no cell element; writing one emits nothing.
  alias CellValue = String | InlineStr | Int64 | Float64 | Bool | DateValue | Formula | SharedFormulaRef | Empty | Nil
end
