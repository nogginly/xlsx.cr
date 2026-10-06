module XLSX
  # One row of a worksheet. Cells are stored sparsely: only cells present in
  # the sheet XML exist. Column IDs are 1-based, so column A is 1.
  #
  # `attrs` holds the attributes of the `<row>` element other than `r`, such as
  # style, height and outline level, and writing emits them unchanged.
  # Namespaced attributes lose their prefix when read.
  class Row
    getter row_id : Int32
    getter attrs : Hash(String, String)

    def initialize(@row_id : Int32, @cells : Hash(Int32, Cell),
                   @attrs : Hash(String, String) = {} of String => String)
    end

    # Yields each present cell's value and its column ID, in column order.
    def each_cell(& : CellValue, Int32 ->)
      @cells.keys.sort.each do |col_id|
        yield @cells[col_id].value, col_id
      end
    end

    # Like `each_cell`, but yields the whole `Cell`, attributes included.
    def each_cell_full(& : Cell, Int32 ->)
      @cells.keys.sort.each do |col_id|
        yield @cells[col_id], col_id
      end
    end

    # Returns the range from the first to last present column ID.
    # Raises `Enumerable::EmptyError` if the row has no cells.
    def col_span : Range(Int32, Int32)
      keys = @cells.keys
      keys.min..keys.max
    end

    # Returns the cell value at *col_id*, or `nil` if the cell is absent.
    def [](col_id : Int32) : CellValue
      @cells[col_id]?.try(&.value)
    end

    # Returns the full `Cell` at *col_id*, or `nil` if absent.
    def cell(col_id : Int32) : Cell?
      @cells[col_id]?
    end

    # Returns the number of present cells.
    def size : Int32
      @cells.size
    end

    def empty? : Bool
      @cells.empty?
    end
  end
end
