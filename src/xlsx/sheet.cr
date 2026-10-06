module XLSX
  # One worksheet of a document. Rows are stored sparsely: only rows present
  # in the sheet XML exist. Row IDs are 1-based, as in Excel.
  class Sheet
    getter name : String

    def initialize(@name : String, @rows : Hash(Int32, Row))
    end

    # Yields each present row and its row ID, in row order.
    def each_row(& : Row, Int32 ->)
      @rows.keys.sort.each do |row_id|
        yield @rows[row_id], row_id
      end
    end

    # Returns the range from the first to last present row ID.
    # Raises `Enumerable::EmptyError` if the sheet has no rows.
    def row_span : Range(Int32, Int32)
      keys = @rows.keys
      keys.min..keys.max
    end

    # Returns the `Row` at *row_id*, or `nil` if absent.
    def row(row_id : Int32) : Row?
      @rows[row_id]?
    end

    # Returns the cell at (*row_id*, *col_id*), or `nil` if either is absent.
    def [](row_id : Int32, col_id : Int32) : CellValue
      @rows[row_id]?.try(&.[](col_id))
    end

    # Returns the number of present rows.
    def row_count : Int32
      @rows.size
    end

    def empty? : Bool
      @rows.empty?
    end
  end
end
