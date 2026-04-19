require "./xlsx/*"

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
    sheets.each do |name|
      sb = SheetBuilder.new(name)
      yield sb
    end
    raise NotImplementedError.new("XLSX.build: ZIP/XML writer not yet implemented")
  end
end
