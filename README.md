# xlsx

A Crystal shard for reading and writing XLSX files compatible with Excel.

> See [DISCLOSURE](./DISCLOSURE.md) for information how AI is used by this project.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     xlsx:
       github: nogginly/xlsx.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "xlsx"
```

### Creating a workbook

#### Single sheet, CSV style

```crystal
File.open("output.xlsx", "w") do |io|
  XLSX.build(io) do |b|
    b.row("Name", "Age")
    b.row("Alice", 30_i64)
    b.row("Bob", 24.5)
  end
end
```

The block receives a `Builder`. Rows are collected and written to a sheet
named "Sheet1" when the block returns. Nothing is written if the block raises.

#### Multiple sheets

```crystal
File.open("multi.xlsx", "w") do |io|
  XLSX.build(io, sheets: ["Data", "Summary"]) do |sheet|
    case sheet.name
    when "Data"
      sheet.append_row("Item", "Amount")
      1.upto(5) { |i| sheet.append_row("Item #{i}", i * 10.0) }
    when "Summary"
      sheet.append_row("Total", XLSX::Formula.new("SUM(Data!B2:B6)", 150.0))
    end
  end
end
```

The block runs once per sheet name, with a fresh `SheetBuilder` each time, so
branch on `sheet.name` to give sheets different content. Besides `append_row`,
a `SheetBuilder` can fill a span of rows and columns:

```crystal
sheet.rows(2..4) do |row, row_id|
  row[1] = "Row #{row_id}"
  row.cells(2..3) { |col_id| (row_id * col_id).to_f }
end
```

#### Writing into a template

```crystal
File.open("template.xlsx") do |template|
  File.open("filled.xlsx", "w") do |output|
    XLSX.build(output, template: template) do |sheet|
      next unless sheet.name == "Data"
      sheet.append_row("Widget", 4_i64, 9.99)
    end
  end
end
```

The output is a copy of the whole template workbook with your changes. The
block runs once per template sheet, with a `SheetBuilder` that already holds
that sheet's rows, and `append_row` adds rows after the last one. Sheets cannot
be added, removed or renamed. The template file is only read.

### Reading a workbook

```crystal
doc = XLSX::Document.open("existing.xlsx")

doc.each do |sheet|
  puts "Sheet: #{sheet.name}"
  sheet.each_row do |row, row_id|
    row.each_cell do |value, col_id|
      puts "  R#{row_id}C#{col_id}: #{value}"
    end
  end
end
```

Sheets can also be fetched by name or index, and cells by row and column, all
1-based for rows and columns:

```crystal
sheet = doc["Data"] # or doc[0]
value = sheet[2, 3] # row 2, column C; nil if there is no such cell
if row = sheet.row(2)
  puts row[3]
end
```

Rows and cells are sparse: only those present in the file exist, and iteration
skips the rest.

### Cell values

Every cell holds an `XLSX::CellValue`:

Type                    |How to construct                                 |Example                    
------------------------|-------------------------------------------------|---------------------------
`String`                |A string, stored in the shared string table      |`"Hello"`                  
`XLSX::InlineStr`       |`.new(text)`, stored in the cell itself          |`...new("inline")`         
`Int64`                 |An `Int64`; convert `Int32` with `to_i64`        |`42_i64`, `i.to_i64`       
`Float64`               |A float                                          |`3.14`                     
`Bool`                  |`true` or `false`                                |                           
`XLSX::DateValue`       |`.date_time(t)`, `.date_only(t)`, `.time_only(t)`|`...date_time(Time.utc)`   
`XLSX::Formula`         |`.new(expression, cached_value)`                 |`...new("SUM(A1:A5)", 0.0)`
`XLSX::SharedFormulaRef`|`.new(shared_index, cached_value)`               |                           
`XLSX::Empty`           |`XLSX::Empty::INSTANCE`: a cell with no value    |                           
`Nil`                   |`nil`: no cell at all                            |                           

Types can be mixed freely in a row:

```crystal
sheet.append_row("Alice", 30_i64, XLSX::DateValue.date_only(Time.utc(2024, 4, 20)))
```

When reading, numbers always come back as `Float64`, and a number is returned
as a `DateValue` when its cell's style displays a date or time. Dates are
wall-clock times returned as UTC; a time zone offset is discarded on write.

### Current limitations

- Writing into a template can produce a file that Excel offers to repair, and
  drops drawings, comments and hyperlinks from the sheets it rewrites.
- `SheetBuilder#rows` replaces whole rows. In a template, it erases the other
  cells and the formatting of every row in the span; use `append_row` to add
  rows after existing content.
- New `DateValue` cells written into a template may display with the wrong
  format.
- Rich-text strings, error values and workbooks using the 1904 date system are
  not read correctly.
- The whole workbook is held in memory.

[SCOPE](./SCOPE.md) lists these and the other known issues.

## Development

See [DEVELOPMENT](./DEVELOPMENT.md)

## Contributions, by invitation!

*With apologies*, at this time contributions are *by invitation only* and limited to people I know and see often.

These are early days for _AskElelem_ and I am busy with family and work.

At this time I want to work on this at a manageable pace.
