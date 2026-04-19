module XLSX
  # Builds a single `Sheet` by iterating a row span or appending rows.
  #
  # Can be pre-populated from an existing `Sheet` to support template-based
  # building, where existing content is preserved and new rows are appended.
  class SheetBuilder
    getter name : String

    def initialize(@name : String)
      @rows = {} of Int32 => Row
      @next_row_id = 1
    end

    private def initialize(@name : String, @rows : Hash(Int32, Row), @next_row_id : Int32)
    end

    # Pre-populates this builder from an existing `Sheet`.
    # Existing rows are carried over and `append_row` will add after them.
    def self.from_sheet(sheet : Sheet) : self
      rows = {} of Int32 => Row
      next_row_id = 1
      sheet.each_row do |row, row_id|
        rows[row_id] = row
        next_row_id = row_id + 1
      end
      new(sheet.name, rows, next_row_id)
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
        @next_row_id = row_id + 1 if row_id >= @next_row_id
      end
    end

    # Appends a row of values after the last present row.
    # Accepts a splat of `CellValue` items.
    def append_row(*values : CellValue)
      append_row(values)
    end

    # Appends a row of values after the last present row.
    # Accepts any `Enumerable`.
    def append_row(values : Enumerable)
      cells = {} of Int32 => CellValue
      values.each_with_index { |v, i| cells[i + 1] = v.as(CellValue) }
      @rows[@next_row_id] = Row.new(@next_row_id, cells)
      @next_row_id += 1
    end

    # Produces the immutable `Sheet`.
    def build : Sheet
      Sheet.new(@name, @rows)
    end
  end
end
