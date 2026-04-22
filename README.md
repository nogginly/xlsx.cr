# xlsx

A Crystal shard for reading and writing XLSX files compatible with Excel.

> See the end of this document for my AI disclosure.

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

## AI Disclosure

I worked with Claude's Sonnet 4.6 (Adaptive) via the web UI using a free plan to develop this shard. It was an iterative process. I started with a motivation + planning prompt and then worked through the design until it was ready to start implementing.

Here's the opening prompt we started from:

> I would like to implement a Crystal shard / library for reading and writing Excel XLSX documents. I want to be able to do the following when using this library:
>
> 1. Read and write the same content that I would with a CSV file.
> 2. Define an API model that looks and feels like the CSV module in Crystal's standard library: https://crystal-lang.org/api/1.20.0/CSV.html
> 3. Open an existing XLSX document and use it as a template to write more data into.
> 4. Manage worksheets so that I can in turn select and use individual worksheets when reading and writing data.
> I have no interest in using the API to create or consume charts, macros, pivots or any features of Excel beyond the ability to read and write contents of worksheets. Before starting to write any code, please explain to me (briefly) how the format works, and then propose an API. Let me decide when it's time to begin an implementation.

Through the design discussion, I was opinionated about what I wanted the API to feel like, while I also didn't know how XLSX files (ZIPs of XML, hurrah!) were structured.

We didn't start implementing a single file until we were clear about the following:

- Usage pattern for the API, both to make fresh XLSX document and to be able to use a template.
- File / folder structure, keeping internals isolated, and well separated from the main components
- Testing (using `spectator`) from the beginning, which Claude had to learn about

It took several days and many stops and starts because I'm using the free plan and ran out of my "free messages" often. In hindsight this turned out to be a good thing.

While I was already keeping up with the generated code and making sure I understood it because of the (you might call it pedantic) pace at which we were working, the waiting time between usage credits (usually five hours from when I run out) gave me time to think about
- progress so far,
- what I wanted to do next, and
- if I wanted to revisit or change anything.

At least three times I came back from the break with a request to refactor a recent implementation or revisit a design decision. I honestly believe I wouldn't have made these changes without _my own thinking time_.

In hindsight, I always had breaks between working sessions, some during the work day and some when I stopped to go home and spend time with my family. I've noticed the same benefits working that way, and it makes sense to me that I should actively incorporate _waiting and thinking time_ into all my future use of AI tools.
