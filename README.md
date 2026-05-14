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

### 2. Creating a workbook

#### 2.1. Simple CSV‑style builder

```crystal
File.open("output.xlsx", "w") do | io |
  XLSX.build(io) do |b|
    b.row("Name", "Age")
    b.row("Alice", 30)
    b.row("Bob", 24.5)
  end
end
```

The block receives a `Builder` that accumulates rows and writes to the file.

#### 2.2. Multiple sheets with a span

```crystal
XLSX.build(File.open("multi.xlsx", "w"),
           sheets: ["Data", "Summary"]) do |sheet|
  # `sheet` is a `SheetBuilder`
  sheet.append_row("Header A", "Header B")
  1.upto(5) do |i|
    sheet.append_row("Row #{i}A", i)
  end
end
```

#### 2.3. Template‑based build

```crystal
File.open("template.xlsx") do |template|
  File.open("filled.xlsx", "w") do |out|
    XLSX.build(out, template: template) do |sheet|
      # `sheet` starts with template content
      sheet.append_row("Date", Time.utc)
    end
  end
end
```

The template file is read but not modified; only the new sheet(s) are written to *out*.

### 3. Reading an existing workbook

```crystal
doc = XLSX::Document.open("existing.xlsx")

# Iterate sheets
doc.each do |sheet|
  puts "Sheet: #{sheet.name}"
  sheet.each_row do |row, row_id|
    row.each_cell do |value, col_id|
      puts "  R#{row_id}C#{col_id}: #{value}"
    end
  end
end
```

You can also fetch a sheet by name:

```crystal
sheet = doc["Data"]
row = sheet.row(2) # row 2 if present
value = row[3]   # cell at column 3
```

### 4. Working with different cell types

|Type                    |How to construct                                 |Example                   |
|------------------------|-------------------------------------------------|--------------------------|
|`String`                |Plain string                                     |`"Hello"`                 |
|`XLSX::InlineStr`       |`#new("text")`                                   |`...new("inline")`        |
|`Int64` / `Float64`     |Integer or float literals                        |`42`, `3.14`              |
|`Bool`                  |`true` / `false`                                 |                          |
|`XLSX::DateValue`       |`#date_time(t)`, `#date_only(t)`, `#time_only(t)`|`...date_time(Time.utc)`  |
|`XLSX::Formula`         |`#new(formula, pre_calc_value)`                  |`...new("SUM(A1:A5)", 42)`|
|`XLSX::SharedFormulaRef`|`#new(index, pre_calc_value)`                    |                          |
|`XLSX::Empty`           |`INSTANCE` (singleton constant )                 |                          |

When appending rows you can mix types freely:

```crystal
builder.append_row("Alice", 30, XLSX::DateValue.date_only(Time.new(2024, 4, 20)))
```

## Development

See [DEVELOPMENT](./DEVELOPMENT.md)

## Contributions, by invitation!

*With apologies*, at this time contributions are *by invitation only* and limited to people I know and see often.

These are early days for _AskElelem_ and I am busy with family and work.

At this time I want to work on this at a manageable pace.
