require "compress/zip"
require "xml"

require "./xlsx/*"
require "./xlsx/builder/*"
require "./xlsx/internal/*"

module XLSX
  # Writes a single-sheet workbook, named "Sheet1", to *io*. Yields a
  # `Builder` that collects rows in the style of `CSV.build`, and writes them
  # when the block returns. Nothing is written if the block raises.
  #
  # ```
  # XLSX.build(io) do |b|
  #   b.row("name", "age")
  #   b.row("alice", 30.0)
  # end
  # ```
  def self.build(io : IO, & : Builder ->)
    builder = Builder.new(io)
    yield builder
    builder.close
  end

  # Writes a workbook with one sheet per name in *sheets*, in that order, to
  # *io*. Yields a fresh `SheetBuilder` for each name, so a block that treats
  # sheets differently branches on `SheetBuilder#name`. Nothing is written if
  # the block raises.
  #
  # ```
  # XLSX.build(io, sheets: ["Sheet1", "Sheet2"]) do |sheet|
  #   sheet.rows(1..5) { |row, row_id| row[1] = "data #{row_id}" }
  # end
  # ```
  def self.build(io : IO, sheets : Array(String), & : SheetBuilder ->)
    built_sheets = sheets.map do |name|
      sb = SheetBuilder.new(name)
      yield sb
      sb.build
    end
    Internal::Zip.write(io, Document.new(built_sheets))
  end

  # Writes a copy of the workbook in *template* to *io*, with changes. Yields
  # a `SheetBuilder` pre-populated from each template sheet, in workbook order;
  # a block that changes one sheet branches on `SheetBuilder#name`. Sheets
  # cannot be added, removed or renamed. *template* is read whole and is not
  # modified or closed.
  #
  # ```
  # File.open("template.xlsx") do |template|
  #   File.open("output.xlsx", "w") do |output|
  #     XLSX.build(output, template: template) do |sheet|
  #       sheet.append_row("2026-04-19", 99.5, "USD")
  #     end
  #   end
  # end
  # ```
  def self.build(io : IO, template : IO, & : SheetBuilder ->)
    entries = Internal::Zip.collect_entries(template)
    source = Internal::Zip.read_from_entries(entries)
    built_sheets = source.sheet_names.map do |name|
      sb = SheetBuilder.from_sheet(source[name])
      yield sb
      sb.build
    end
    Internal::Zip.write_with_template(io, Document.new(built_sheets), entries)
  end
end
