require "xml"

module XLSX
  # :nodoc:
  module Internal
    MAIN_NS     = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    RELATION_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    RELS_NS     = "http://schemas.openxmlformats.org/package/2006/relationships"
    SHEET_TYPE  = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
  end
end
