module XLSX
  # Builds a single `Row` by populating cells via a column span or direct assignment.
  class RowBuilder
    getter row_id : Int32

    def initialize(@row_id : Int32)
      @cells = {} of Int32 => Cell
      @attrs = {} of String => String
    end

    # Populates cells in *span* by calling the block with each column ID.
    # The block's return value becomes the cell value.
    def cells(span : Range(Int32, Int32), & : Int32 -> CellValue)
      span.each do |col_id|
        @cells[col_id] = Cell.new(yield col_id)
      end
    end

    # Sets a single cell directly. Overwrites any value already at *col_id*.
    def []=(col_id : Int32, value : CellValue)
      existing_attrs = @cells[col_id]?.try(&.attrs) || {} of String => String
      @cells[col_id] = Cell.new(value, existing_attrs)
    end

    # Produces the immutable `Row`.
    def build : Row
      Row.new(@row_id, @cells, @attrs)
    end
  end
end
