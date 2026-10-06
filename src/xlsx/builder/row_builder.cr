module XLSX
  # Builds one `Row`, starting empty, from a column span or single cells.
  class RowBuilder
    getter row_id : Int32

    def initialize(@row_id : Int32)
      @cells = {} of Int32 => Cell
      @attrs = {} of String => String
    end

    # Sets each cell in *span* to the block's result for that column ID.
    def cells(span : Range(Int32, Int32), & : Int32 -> CellValue)
      span.each do |col_id|
        @cells[col_id] = Cell.new(yield col_id)
      end
    end

    # Sets the cell at *col_id*, replacing any value already there.
    def []=(col_id : Int32, value : CellValue)
      existing_attrs = @cells[col_id]?.try(&.attrs) || {} of String => String
      @cells[col_id] = Cell.new(value, existing_attrs)
    end

    # Returns the `Row`. It shares this builder's storage, so later changes to
    # the builder also change the row.
    def build : Row
      Row.new(@row_id, @cells, @attrs)
    end
  end
end
