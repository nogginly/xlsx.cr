require "../src/xlsx"

USAGE = "Usage: test02 <template_xlsx_file> <sheet_name> <output_xlsx_file>\nRead a template XLSX file, append a row, and write it to the output XLSX file."
template_xlsx_file = ARGV[0]? || abort(USAGE)
dest_sheet_name = ARGV[1]? || abort(USAGE)
output_xlsx_file = ARGV[2]? || abort(USAGE)

File.open(template_xlsx_file, "r") do |t_io|
  File.open(output_xlsx_file, "w") do |out_io|
    XLSX.build(out_io, t_io) do |sheet|
      next unless sheet.name == dest_sheet_name
      puts "Sheet: #{sheet.name} found"
      sheet.append_row(8, "Zeus", "All father")
    end
  end
end
