module XLSX
  # A single row of cells from a worksheet.
  #
  # Cells are stored sparsely: only cells present in the XML exist here.
  # Column IDs are 1-based, matching Excel's column numbering (A=1, B=2, …).
  class Row
    getter row_id : Int32

    def initialize(@row_id : Int32, @cells : Hash(Int32, CellValue))
    end

    # Yields each present cell and its 1-based column ID, in column order.
    # Absent columns are skipped.
    def each_cell(& : CellValue, Int32 ->)
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

    # Returns the cell value at *col_id*, or `nil` if absent.
    def [](col_id : Int32) : CellValue
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
