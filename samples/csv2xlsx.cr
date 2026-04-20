require "csv"

require "../src/xlsx"

USAGE = "Usage: csv2xlsx <csv_file> <output_xlsx_file>\nRead a CSV file and export it as an XLSX file."
csv_file = ARGV[0]? || abort(USAGE)
output_xlsx_file = ARGV[1]? || abort(USAGE)

count = 0
count_ints = 0
count_floats = 0

File.open(csv_file, "r") do |csv_io|
  File.open(output_xlsx_file, "w") do |out_io|
    XLSX.build(out_io) do |builder|
      CSV.each_row(csv_io) do |csv_row|
        cells = [] of XLSX::CellValue
        csv_row.each do |value|
          if ["true", "false"].includes?(value)
            cells << value == "true" ? true : false
          elsif i64 = value.to_i64?
            count_ints += 1
            cells << i64
          elsif f64 = value.to_f64?
            count_floats += 1
            cells << f64
          else
            cells << value
          end
        end
        builder.row(cells)
        count += 1
      end
    end
  end
end

puts "Converted #{count} rows."
puts "  - Found #{count_ints} incoming integers"
puts "  - Found #{count_floats} incoming floats"
