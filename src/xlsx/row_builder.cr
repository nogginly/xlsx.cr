module XLSX
  # Builds a single `Row` by populating cells via a column span or direct assignment.
  class RowBuilder
    getter row_id : Int32

    def initialize(@row_id : Int32)
      @cells = {} of Int32 => CellValue
    end

    # Populates cells in *span* by calling the block with each column ID.
    # The block's return value becomes the cell value.
    #
    # ```
    # row.cells(2..5) { |col_id| "R#{row_id}C#{col_id}" }
    # ```
    def cells(span : Range(Int32, Int32), & : Int32 -> CellValue)
      span.each do |col_id|
        @cells[col_id] = yield col_id
      end
    end

    # Sets a single cell directly. Overwrites any value already at *col_id*.
    def []=(col_id : Int32, value : CellValue)
      @cells[col_id] = value
    end

    # Produces the immutable `Row`.
    def build : Row
      Row.new(@row_id, @cells)
    end
  end
end
