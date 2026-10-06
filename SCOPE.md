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

Item IDs are stable references, not ranks: within each bucket, items are
listed worst first.

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
attributes (all currently lost). The same applies to the relationships file:
`build_rels` keeps only each relationship's `Id`, `Type` and `Target`, so an
attribute such as `TargetMode="External"` is dropped.

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

### M17. `SheetBuilder#rows` discards existing rows

Each row in the span starts as an empty `RowBuilder` and replaces whatever row
had that ID. In a template, `sheet.rows(3..10) { |row, _| row[2] = 42.0 }`
erases every other cell in rows 3 to 10, plus their style, height and other
row attributes. Filling values into a formatted template is the main reason
to use one, so this is silent template damage. The fix is to start each
`RowBuilder` from the existing row's cells and attributes, with an explicit
way to clear a row. Predicted by reading.

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
  leading and trailing spaces are not guaranteed to survive.
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

### M19. Malformed XML parts read as partial data

Every part is parsed with `XML.parse`'s defaults, which include libxml's
`RECOVER` flag. A truncated or corrupt sheet therefore yields whatever
parsed, with no error, and a template build writes that back as the sheet.
The fix is to parse without `RECOVER` (keeping `NONET`) and let `XML::Error`
propagate with the part's name. Predicted by reading.

### M15. Sheet names are not validated

Excel rejects names longer than 31 characters, names containing
`[ ] : * ? / \`, names starting or ending with `'`, and duplicates compared
case-insensitively. `XLSX.build(io, sheets: [...])` writes them anyway and
Excel offers a repair. An empty `sheets` array writes a workbook with no
sheets, which Excel also rejects. The fix is to raise `ArgumentError` at
build time.

### M18. Builders reject plain integers and `Time`

Confirmed with `crystal eval` against `Builder#row`:

- **`Int32`.** `b.row("A", 30)` fails with "ambiguous call, implicit cast of
  30 matches all of Float64, Int64". An `Int32` variable fails the same way,
  since Crystal autocasts number variables as well as literals.
- **`Time`.** `b.row("A", Time.utc)` fails with "no overload matches".

`SheetBuilder#append_row` and `RowBuilder#[]=` take the same `CellValue`
restriction, so they fail the same way. The specs and samples avoid both
forms (`30.0`, `8.to_i64`), and the README converts explicitly (`30_i64`,
`to_i64`); simplify its examples once this is fixed.

The fix is to convert at the builder boundary: any `Int` to `Int64` and a
`Time` to a date-time `DateValue`. Adding `Int32` to `CellValue` alone does
not work, since an autocast would still be ambiguous for other integer types.
Fixing it is cheap now and a breaking change later.

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

Reading uses `Compress::Zip::Reader`, which walks local file headers and
ignores the central directory. A stored (uncompressed) entry whose sizes are
only in a trailing data descriptor reads as empty, and a non-ZIP input reads
as an archive with no entries. `Compress::Zip::File` reads the central
directory, at the cost of needing a seekable `IO`.

### W7. Typed read accessors

Callers pattern-match a 10-way union for every cell. Add helpers such as
`as_s`, `as_f?` and `as_time?` on `Row`, plus an opt-in for reading integral
floats as `Int64`.

`to_s` is inconsistent across a shared formula: the master `Formula` renders
`=SUM(A1:A3)` while each `SharedFormulaRef` renders its cached value, so a
column of shared formulas prints one formula followed by numbers. Pick one
rendering, either the cached value or the formula, for both types.

### W8. Numeric edge cases

`NaN` and `Infinity` are written as text that Excel rejects. `Int64` values
beyond 2^53 lose precision silently. Raise or document, then decide.

### W9. Date edge cases

- **1900 leap-year bug.** Serials below 61 are a day off.
- **Precision.** Sub-second values are truncated on write.
- **Heuristic false positives.** `date_format_code?` treats `[Red]0.00` and
  `[$-409]` as dates; bracketed sections should be skipped like quoted ones.
- **Locale-specific built-ins.** Formats 27-36 and 50-58, used by East Asian
  editions of Excel for dates, are not recognised, so those dates read as
  numbers.

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

### W14. Built values share builder storage

`RowBuilder#build` and `SheetBuilder#build` hand their own hashes to the
`Row` and `Sheet` they return, and `Row#attrs` returns its hash directly, so
a built value changes if the builder or caller keeps going. `Builder#close`
writes a complete archive each time it is called. Neither bites through
`XLSX.build`; both can through the public builder classes. Copy on build,
freeze or document, then decide.

### W12. Strict OOXML

The `purl.oclc.org/ooxml` namespaces read as an empty workbook. After M14 this
should at least raise, and full support can come later.

### W13. Housekeeping

- **Non-ASCII trailing comments.** `StylesXML#initialize` and
  `SheetXML#formula_type_and_value` each have a trailing comment with an
  arrow. Trailing comments sit on code lines, so they are outside the
  comment-only cleanup and need their own commit.
- **Ameba baseline.** `.ameba.yml` mutes existing findings per rule and file.
  Remove each exclusion as its findings are fixed.
