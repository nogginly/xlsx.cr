# xlsx.cr -- Session Handoff

## Repository

https://github.com/nogginly/xlsx.cr.git

Clone the repo and read files before editing. Never edit stale in-memory copies.

---

## Read these first, in the repo

1. `HANDOFF.md` -- this file: rules, state, lessons.
2. `SCOPE.md` -- the worklist. MUST FIX items are taken in order unless the
   user says otherwise. Completed items are deleted, not ticked.
3. `README.md` -- public API as users see it.
4. `DEVELOPMENT.md`, `ops.yml` and `.ameba.yml` -- how the user builds, tests
   and lints, and how the code fits together.
5. `DISCLOSURE.md` -- this is a Level 5 project: the user must understand every
   line, so explain reasoning, not just results.
6. `src/xlsx.cr` -- the three `XLSX.build` overloads, the entry points.
7. `src/xlsx/cell_value.cr` -- the `CellValue` union and its member types.
8. `src/xlsx/internal/zip.cr` -- read and write orchestration, including the
   template path where most open work lives.

Then whichever of `src/xlsx/internal/{sheet_xml,workbook_xml,shared_strings,styles_xml}.cr`
the current SCOPE item touches, and its spec under `spec/unit/`.

---

## Standing instructions

- **No toolchain installs. No compile, run, test or lint.** Write code and specs;
  the user runs `ops test` (specs, debug build and lint) and reports output. The user does all
  editing decisions, PRs, pushes and merges.
- **Read before writing.** Clone, read the relevant file, then edit. After any
  push or merge, pull before editing again. Since the user does all the real
  editing, a local working copy is scratch -- `git reset --hard` before pulling
  rather than trying to preserve it. A staged `git mv` will block a pull
  otherwise.
- **`str_replace` over full rewrites.** Full writes only for new files.
- **Verify every copy to outputs individually.** `cp a b c dest/` aborts the whole
  chain on the first failure and silently drops the rest. Loop and diff each file.
- **Renames are `git mv`**, so history follows the file. Say so when handing over
  a rename, since a moved file looks like a deletion and an addition otherwise.
- **Read failure output before writing a fix.** Never guess.
- **Formatting is checked in CI** (`crystal tool format` then
  `git diff --exit-code src`). Since the formatter cannot be run here, write code
  in its style: two-space indent, aligned `=` in consecutive constant
  assignments, aligned `then` in single-line `case` arms.
- **Specs use `spectator`**, run with `crystal spec -Dtest`. New behaviour lands
  with a spec; interop fixes land with a fixture file (see SCOPE M1).
- **Comments document the API and outcomes.** How to use it, what a type or
  method produces; inside a method, only the steps of the algorithm. No change
  history or "how we got here" -- that belongs in commits and PRs.
- **ASCII only in comments.** `->` not arrows, `--` not em-dashes. String
  literals and Markdown prose are exempt. Two trailing comments still carry
  arrows (SCOPE W13).
- **Comments describe current behaviour, limitations included**, without
  pointing at SCOPE items. A fix updates the comment that describes the
  limitation in the same commit. Comment-only changes are checked with the
  `crystal-comment-cleanup` skill's `check_unchanged.py` and committed apart
  from code changes.
- **All regexes in private named constants** inside the relevant class. Specs are
  exempt; inline regexes are the convention there. Two inline regexes remain in
  `SheetXML#build` and `WorkbookXML#patch_sheets_element`; both are slated for
  replacement by SCOPE M14.
- **Ameba** must pass, and runs in CI. `.ameba.yml` is a baseline muting
  findings that predate it, per rule and file: never add an exclusion, and
  remove one when its findings are fixed. No new `not_nil!` (one remains in
  `Zip.read_from_entries`, removed by SCOPE M13); cyclomatic complexity <= 10;
  block parameter names must be descriptive or on Ameba's allowed short list
  (`i`, `j`, `k`, `e`).
- **Small verified steps.** Split a change that alters both structure and
  behaviour into two commits.
- **Diagrams are Mermaid only**, offered as standalone `.mermaid` files.
- **Number any decision questions**, so the user can answer by number.
- **Keep `SCOPE.md` and this file current.** Delete finished SCOPE items, add new
  ones as found, and update "Where things stand" before a session ends.

### Working rhythm

Propose an approach and its alternatives before writing code on anything
non-trivial; the user decides. Then: edit, hand the files over, hand over to run.
On green, provide a one-line commit message. PR descriptions have `What?` and
`Why?` and omit anything evident from the diff -- they are for recording the
alternatives that were rejected and the reasoning that the code cannot show.

---

## Where things stand

- Version 0.2.0 (`shard.yml`). Work is on the branch
  `cleaning-up-the-comments-and-docs`, not yet merged to `main`.
- The comment cleanup of `src/` is done: every comment describes current
  behaviour, checked against the source and Crystal's stdlib. README and
  DEVELOPMENT were brought into line afterwards; README examples avoid
  `Int32` and `Time` values (SCOPE M18) and name no variable `out`.
- No behaviour has changed since the baseline. All known defects are in
  `SCOPE.md`, predicted by reading; only M2 is confirmed against stdlib source.
- The specs only round-trip through this shard's own writer, so they do not
  prove compatibility with Excel or other producers.

### Open work

See `SCOPE.md` for the full list. Next, in order:

1. **Confirm M18** from the repo root; each should fail with "no overload
   matches":

   ```sh
   crystal eval 'require "./src/xlsx"; XLSX.build(IO::Memory.new) { |b| b.row("A", 30) }'
   crystal eval 'require "./src/xlsx"; i = 3; XLSX.build(IO::Memory.new) { |b| b.row("A", i) }'
   crystal eval 'require "./src/xlsx"; XLSX.build(IO::Memory.new) { |b| b.row("A", Time.utc) }'
   ```
2. **SCOPE M1** -- fixtures and an external validity check, so every later fix
   lands with a reproduction. Needs real files from the user, ideally the
   template that showed the original problem.
3. **Then M2 to M6 and M17**, the template-write integrity group.
4. **Decisions pending from the user**, which shape M8, M10 and the scope
   boundary:
   1. Add an `ErrorValue` member to `CellValue` (widens the union), or represent
      errors differently?
   2. Make `styles.xml` a managed, patched part now (the proper M10 fix), or
      raise on `DateValue` written into a template as a stopgap?
   3. Do merged cells and hyperlinks count as "contents" to expose on read?

---

## Lessons carried forward

- **Stale files are the main source of confusion.** Pull at the start of every
  session and after every merge.
- **`out` is a Crystal keyword.** So are `begin`, `end`, `next`, `select`, `case`,
  `in` -- all plausible spec variable names. The tell: the parse error points at
  the line *after* the offending one, because Crystal reads `out` as starting an
  out-parameter and complains about whatever follows. A parse error on an
  obviously correct line means looking one line up.
- **`<<` binds tighter than `==` in Crystal.** `a << b == c ? x : y` appends `b`
  and discards the comparison, which is the `csv2xlsx` boolean bug (SCOPE M16).
  Parenthesise the value being appended.
- **Crystal's `XML` drops namespace prefixes from names.** Attribute and element
  `#name` return the libxml local name. Anything captured for re-emission must
  keep `#namespace` alongside the name, or the output loses the prefix.
- **Self-round-trip specs hide symmetric bugs.** A misreading on parse and a
  matching mistake on write cancel out. Compatibility claims need fixtures
  produced by other software.
- **Deleting a banner comment can leave two blank lines in a row.**
  `crystal tool format` collapses them, so CI's format check fails. Remove the
  extra blank in the same commit; the comment checker ignores blank lines.
- **Specs that dodge a natural call are a hint.** Every spec wrote `30.0` or
  `8.to_i64`, never `30`, which is how M18 surfaced. When tests avoid the
  obvious form, find out why.
