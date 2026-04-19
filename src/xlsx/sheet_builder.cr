module XLSX
  # Builds a single `Sheet` by iterating a row span.
  class SheetBuilder
    getter name : String

    def initialize(@name : String)
      @rows = {} of Int32 => Row
    end

    # Iterates *span*, yielding a `RowBuilder` and 1-based row ID for each row.
    # The built row is collected after each block call.
    #
    # ```
    # sheet.rows(3..10) do |row, row_id|
    #   row.cells(2..5) { |col_id| value_for(row_id, col_id) }
    #   row[1] = "Boo"
    # end
    # ```
    def rows(span : Range(Int32, Int32), & : RowBuilder, Int32 ->)
      span.each do |row_id|
        rb = RowBuilder.new(row_id)
        yield rb, row_id
        @rows[row_id] = rb.build
      end
    end

    # Produces the immutable `Sheet`.
    def build : Sheet
      Sheet.new(@name, @rows)
    end
  end
end
