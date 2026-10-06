module XLSX
  # Builds one `Sheet` from row spans and appended rows. Built from an existing
  # sheet with `.from_sheet`, it keeps that sheet's rows and appends after them.
  class SheetBuilder
    getter name : String

    def initialize(@name : String)
      @rows = {} of Int32 => Row
      @next_row_id = 1
    end

    private def initialize(@name : String, @rows : Hash(Int32, Row), @next_row_id : Int32)
    end

    # Creates a builder holding *sheet*'s rows, so `append_row` continues after
    # its last row.
    def self.from_sheet(sheet : Sheet) : self
      rows = {} of Int32 => Row
      next_row_id = 1
      sheet.each_row do |row, row_id|
        rows[row_id] = row
        next_row_id = row_id + 1
      end
      new(sheet.name, rows, next_row_id)
    end

    # Builds each row in *span*, yielding a `RowBuilder` and the row ID. Each
    # row starts empty and replaces any existing row with that ID, so in a
    # template the row's previous cells and attributes are discarded.
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

    # Appends a row of values in columns 1 onwards, after the highest row ID
    # written so far.
    def append_row(*values : CellValue)
      append_row(values)
    end

    # Like `append_row(*values)`, but takes any `Enumerable` of `CellValue`.
    def append_row(values : Enumerable)
      cells = {} of Int32 => Cell
      values.each_with_index { |v, i| cells[i + 1] = Cell.new(v.as(CellValue)) }
      @rows[@next_row_id] = Row.new(@next_row_id, cells)
      @next_row_id += 1
    end

    # Returns the `Sheet`. It shares this builder's storage, so later changes to
    # the builder also change the sheet.
    def build : Sheet
      Sheet.new(@name, @rows)
    end
  end
end
