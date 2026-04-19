require "compress/zip"
require "xml"

require "./xlsx/*"
require "./xlsx/builder/*"
require "./xlsx/internal/*"

require "compress/zip"
require "xml"

module XLSX
  # CSV-compatible build. Yields a `Builder`; calls `close` after the block.
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

  # Span-aware build across named sheets. Yields a `SheetBuilder` once per
  # sheet name, then writes the assembled workbook to *io*.
  #
  # ```
  # XLSX.build(io, sheets: ["Sheet1", "Sheet2"]) do |sheet|
  #   sheet.rows(1..5) { |row, row_id| row[1] = "data #{row_id}" }
  # end
  # ```
  #
  # NOTE: Writing is not yet implemented — raises `NotImplementedError`
  # after all sheet blocks have been evaluated.
  def self.build(io : IO, sheets : Array(String), & : SheetBuilder ->)
    built_sheets = sheets.map do |name|
      sb = SheetBuilder.new(name)
      yield sb
      sb.build
    end
    Internal::Zip.write(io, Document.new(built_sheets))
  end

  # Template-based build. Reads *template*, pre-populates one `SheetBuilder`
  # per sheet, yields each in document order, then writes the result to *io*.
  # The template IO is not modified.
  #
  # ```
  # File.open("template.xlsx") do |template|
  #   File.open("output.xlsx", "w") do |out|
  #     XLSX.build(out, template: template) do |sheet|
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
