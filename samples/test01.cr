require "../src/xlsx"

USAGE = "Usage: test01 <xlsx_file>\nRead an XLSX file and print contents to console."
xlsx_file = ARGV[0]? || abort(USAGE)

xlsx = XLSX::Document.open(xlsx_file)
xlsx.each do |sheet|
  puts "Sheet: #{sheet.name} --------"
  sheet.each_row do |row, _row_id|
    row.each_cell do |cell, _col_id|
      print "#{cell}\t"
    end
    puts
  end
  puts
end
