require "xml"

module XLSX
  # :nodoc:
  module Internal
    # XML namespaces
    MAIN_NS          = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    RELATION_NS      = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    RELS_NS          = "http://schemas.openxmlformats.org/package/2006/relationships"
    CONTENT_TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"

    # Relationship types
    SHEET_TYPE           = "#{RELATION_NS}/worksheet"
    OFFICE_DOCUMENT_TYPE = "#{RELATION_NS}/officeDocument"
    SHARED_STRINGS_TYPE  = "#{RELATION_NS}/sharedStrings"
    STYLES_TYPE          = "#{RELATION_NS}/styles"

    # Part content types
    RELS_CONTENT_TYPE           = "application/vnd.openxmlformats-package.relationships+xml"
    WORKBOOK_CONTENT_TYPE       = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"
    SHARED_STRINGS_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"
    STYLES_CONTENT_TYPE         = "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"
    WORKSHEET_CONTENT_TYPE      = "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"

    # Reusable XPath namespace maps
    MAIN_NS_MAP = {"ns" => MAIN_NS}
    WB_NS_MAP   = {"wb" => MAIN_NS, "r" => RELATION_NS}
    RELS_NS_MAP = {"pr" => RELS_NS}
  end
end
