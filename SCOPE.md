# Scope

Outstanding work, tracked in two buckets. **Completed items are deleted, not
ticked** — this file is a worklist, not a changelog. It should grow through the
early phases and dissolve as the design settles.

- **MUST FIX** — blocks progress, or is cheap now and expensive later.
- **WILL FIX** — real, but deliberately not now.

Anything settled belongs in code comments or design documentation; anything
outstanding belongs here, because nobody greps a codebase for open questions.

The target is reasonably complete reading and writing of worksheet *contents*
(values, formulas, dates) for files produced by Excel, LibreOffice, Google
Sheets and common libraries, including writing into an incoming template
without Excel offering to "repair" the result. Charts, pivots and macros stay
out of scope, but a template that contains them must survive untouched.

---

## MUST FIX

### M1. Interop fixtures and an external validity check

Every spec round-trips through this shard's own writer, so a mistake made
symmetrically on read and write passes. Add a `spec/fixtures/` set of real files
(Excel, LibreOffice, Google Sheets, openpyxl), each with hidden sheets,
comments, a hyperlink, an image, a table and rich text. Add specs that read
them and that write through each as a template. Add a validity check outside
the shard, e.g. a LibreOffice headless conversion in CI, plus a manual
open-in-Excel checklist. All items below should land with a fixture that
reproduces them.

### M2. Namespaced attributes lose their prefix

`SheetXML#node_attrs` stores `attr.name`, which is the libxml local name. A row
read from an Excel template with `x14ac:dyDescent="0.25"` is written back as
`dyDescent="0.25"`, an attribute the schema does not allow on `<row>`. Excel
writes this on nearly every row, so this is the prime suspect for "We found a
problem with some content". The fix is to keep prefix and namespace when
capturing `Row` and `Cell` attrs, and to emit them with the prefix declared on
the template's root.

### M3. Sheet relationship IDs disagree between `workbook.xml` and its rels

`build_sheets_fragment` and the from-scratch `build_workbook` always write
`r:id="rId{n}"`. `build_rels` instead probes for free IDs around preserved
relationships. Two cases break:

1. LibreOffice templates use `rId1` for styles, so sheet 1 points at
   `styles.xml`.
2. From-scratch builds reserve `rId10` and `rId11`, so a tenth sheet points at
   `sharedStrings.xml`.

The fix is to compute sheet rIds once and use them for both parts. For a
template, patch the existing `<sheet>` elements rather than rebuilding them,
which also keeps `state="hidden"`, the original `sheetId` and any other
attributes (all currently lost).

### M4. Sheet-level parts and relationships are dropped

The writer skips everything under `xl/worksheets/`, including
`xl/worksheets/_rels/sheetN.xml.rels`, and renames sheets to `sheet1..N.xml`.
The preserved sheet XML still contains `<drawing r:id>`, `<legacyDrawing>`,
`<hyperlink r:id>`, `<tableParts>` and `<pageSetup r:id>`, now pointing at
nothing. The fix is to keep each template sheet's original path and carry its
rels file through. Renumber only sheets that are new.

### M5. `[Content_Types].xml` drops `Default` entries

Only `Override` elements are copied from the template. A template with an image
loses `<Default Extension="png" …/>`, and one with comments loses the `vml` and
`bin` defaults, which makes the package invalid. The fix is to carry every
template `Default` through and only replace the overrides this shard manages.

### M6. `calcChain.xml` is removed but still referenced

The part is excluded on write, but its relationship in
`xl/_rels/workbook.xml.rels` and its override are kept, so the package has a
dangling reference. The fix is to drop the relationship too. Also set
`<calcPr fullCalcOnLoad="1"/>` whenever a template is modified, because
formulas over appended rows would otherwise show stale cached values.

### M7. Rich-text shared strings shift every later index

`SharedStrings#parse` matches only `si/t`. An `<si>` built from runs (`si/r/t`,
e.g. "**Total** due") adds several entries or none, so later string cells read
the wrong text. The fix is one entry per `<si>`, concatenating the `t` of each
run and ignoring phonetic `rPh`.

### M8. Cell types `n`, `e`, `d` and plain `str` are mishandled

- **Explicit `t="n"`.** Allowed by the spec and emitted by some writers, it
  reads as a `String`, and on a template write the number becomes a shared
  string.
- **Errors (`t="e"`, e.g. `#N/A`).** Read as `String` and rewritten as text.
- **ISO dates (`t="d"`).** Read as raw `String`.

The fix is to map `n` to a number, add an `ErrorValue` (or a decided
equivalent) that round-trips, and parse `d` to `DateValue`.

### M9. XML escaping and whitespace on write

- **Unescaped cached text.** A formula's cached string goes into `<v>`
  unescaped, so `A & B` produces malformed XML.
- **Missing `xml:space="preserve"`.** Shared and inline `<t>` lack it, so
  leading and trailing spaces are not guaranteed to survive. The `InlineStr`
  doc comment currently promises they do.
- **Control characters.** Characters such as `\u0001` are invalid in XML 1.0
  and must be written as `_x0001_`. On read, the reverse decoding applies.

### M10. `DateValue` factories use style indices that only exist in `minimal_styles`

`DEFAULT_DATE_STYLE = 1` means "date" only in the stylesheet this shard
generates. In a template's `styles.xml`, xf 1 can be anything, so a new
`DateValue.date_only` cell may render as currency or as a bare serial number.
`styles.xml` has to become a managed, patched part: find or append `cellXfs`
entries for numFmt 14, 20 and 22, and resolve factory-made dates to those
indices at write time.

### M11. The 1904 date system is never detected

`StylesXML.new` defaults `date1904` to false, and nothing reads
`<workbookPr date1904="1"/>` from `workbook.xml`. Dates in legacy Mac workbooks
read four years and a day early, and are written the same way.

### M12. Readers assume every `<row>` and `<c>` has an `r` attribute

The `r` attribute is optional in the schema, and some generators omit it.
`row_node["r"]` raises `KeyError`. The fix is to infer the reference from
position: the previous row or column plus one.

### M13. Part paths are assumed rather than resolved

- **Workbook location.** It is hard-coded as `xl/workbook.xml` instead of being
  read from `_rels/.rels`.
- **Rels targets.** `"xl/#{target}"` breaks on absolute targets
  (`/xl/worksheets/sheet1.xml`, emitted by several libraries) and on `../`
  segments.
- **Silent failure on reads.** A missing part raises `KeyError` with no
  context, or yields nil via `not_nil!`.

The fix is a small path resolver that handles relative and absolute targets
and reports which part is missing.

### M14. Regex patching fails silently on unexpected markup

`<sheetData>…</sheetData>` and `<sheets>…</sheets>` are replaced by regex.
Markup like `<x:sheetData>` (Open XML SDK), `<sheetData >` or a strict-OOXML
namespace does not match. The template's rows are then written unchanged and
appended rows vanish without an error. At minimum, raise when the pattern does
not match exactly once. Better, locate the element by parsing and splice by
byte offset.

### M15. Sheet names are not validated

Excel rejects names longer than 31 characters, names containing
`[ ] : * ? / \`, names starting or ending with `'`, and duplicates compared
case-insensitively. `XLSX.build(io, sheets: [...])` writes them anyway and
Excel offers a repair. The fix is to raise `ArgumentError` at build time.

### M16. `csv2xlsx` writes booleans as text

`cells << value == "true" ? true : false` parses as
`(cells << value) == "true" …` because `<<` binds tighter than `==`, so the
string is appended. The fix is `cells << (value == "true")`.

---

## WILL FIX

### W1. Rich text is flattened on round-trip

After M7, reads are correct but formatting runs are lost when a template string
is rewritten. Preserving them needs either a `RichText` value or passing
unchanged `<si>` XML through by index.

### W2. Array and data-table formulas

`<f t="array" ref="B2:B9">` and `t="dataTable"` are parsed and then written as
plain `<f>`. This changes semantics for dynamic-array and legacy CSE formulas.

### W3. Derived ranges go stale when rows are appended

The `<dimension ref>`, row `spans`, table refs in `xl/tables/*.xml`,
`definedName` ranges (print areas, named ranges), conditional formatting and
data validation ranges are not extended. Excel tolerates most of this, but a
table that doesn't grow to cover appended rows is a visible defect.

### W4. No way to style new cells

Appended rows have no `s` attribute. Options include an explicit style handle
from the template or a "copy styles from row N" helper. Either way it depends
on M10's managed `styles.xml`.

### W5. Template and multi-sheet build API

The template build cannot add, remove, rename or reorder sheets. Both
multi-sheet overloads yield every sheet to one block, which forces
`next unless sheet.name == …`. A form that takes a sheet name, or yields a
workbook-level builder, would read better.

### W6. Memory and binary handling

The whole archive is read into a `Hash(String, String)` and every sheet is
parsed as a DOM. Images and `vbaProject.bin` live in `String`s, which works by
accident. Store entries as `Bytes`, stream sheet XML with `XML::Reader` on
read, and stream rows on write for large files.

### W7. Typed read accessors

Callers pattern-match a 10-way union for every cell. Add helpers such as
`as_s`, `as_f?` and `as_time?` on `Row`, plus an opt-in for reading integral
floats as `Int64`.

### W8. Numeric edge cases

`NaN` and `Infinity` are written as text that Excel rejects. `Int64` values
beyond 2^53 lose precision silently. Raise or document, then decide.

### W9. Date edge cases

- **1900 leap-year bug.** Serials below 61 are a day off.
- **Precision.** Sub-second values are truncated on write.
- **Heuristic false positives.** `date_format_code?` treats `[Red]0.00` and
  `[$-409]` as dates; bracketed sections should be skipped like quoted ones.

### W10. Package tidiness

- **String counts.** `sharedStrings.xml` reports `count` equal to
  `uniqueCount`; `count` should be total references.
- **Entry order.** `[Content_Types].xml` is not written first, which some
  strict readers expect.
- **Stale metadata.** `docProps/app.xml` (`TitlesOfParts`) goes stale once
  sheets can change (W5).

### W11. Workbook content type for `.xlsm` and `.xltx` templates

The workbook override is always written as `sheet.main+xml`. An `.xltx`
template becoming an `.xlsx` is the desired outcome. An `.xlsm` template keeps
`vbaProject.bin` under a non-macro content type and will not open. Decide
whether to preserve the original type or refuse macro-enabled templates.

### W12. Strict OOXML

The `purl.oclc.org/ooxml` namespaces read as an empty workbook. After M14 this
should at least raise, and full support can come later.

### W13. Housekeeping

- **Stale doc comments.** `XLSX.build(sheets:)` still mentions
  `NotImplementedError`, `SheetXML#build` documents a nonexistent
  `template_row_ids`, and `DEFAULT_*_STYLE` describes xf indices as `numFmtId`s.
- **README.** Section numbering starts at 2, and example 2.2 leaks a `File`.
- **CI.** `ameba` is disabled.
