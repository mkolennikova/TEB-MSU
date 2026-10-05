# TEB-MSU Documentation Rules

Short rules for `docs/` and `README.md`: the purpose of each document, the file
format, cross-references, the marking of code changes and the checks to run before a
commit. They record the conventions already used in the repository; if you have to
deviate, explain why in the commit message.

> Code state: commit `91308a7` (2026-09-22), branch `MV_devs`.

---

## 1. Documents and their scope

| file | content | must not contain |
| --- | --- | --- |
| `README.md` (repository root) | short model description, build and run instructions, repository layout, links to the documents | scheme details |
| `TEB_MSU_variables_description.md` (+ `.xlsx`) | namelist entries and output columns (English) | physics and formula derivations |
| `TEB_MSU_cbs_scheme_T_CAN_reformulation.md` | the **current** state of the cbs scheme: concept, mathematics, implementation, properties, limitations, invariants | history, versions, rejected variants, run numbers |
| `TEB_MSU_garden_diagnostic_scheme.md` | the **current** state of the diagnostic garden scheme (same structure) | the same |
| `TEB_MSU_source_defects.md` | defects of the **original** model only (D1–D7) | defects of the driver, of the benches, of our own changes, open candidates |
| `TEB_MSU_change_history.md` | commit-referenced history (registry `№1…№N`), rejected variants, measurement protocols, defects outside the original model (I1–I4), numerical defects of our own changes (N1–N2), open items (C1–C5) | the description of the current scheme |
| `TEB_MSU_documentation_rules.md` | this file (English); the scheme, history and defect documents are in Russian | — |

---

## 2. Keep "current" and "historical" apart

* The scheme documents describe the **current state only**. They must not contain:
  version history (`v1.1`, "previously it was"), rejected variants, dates, commit
  numbers in the body text (except for the single "code state" header line), run
  tables, or phrases such as "fixed in §…".
* Everything that is not current goes to `TEB_MSU_change_history.md`, with the commit
  record number (`№N`) and, when useful, the section of the scheme document it
  refers to.
* **Measurements.** A scheme document keeps only guaranteed numbers (identities and
  tolerances, e.g. "residual ≤ 1e-11 W/m²") and the commands that reproduce them.
  Effect tables and run protocols live in Appendix A of the change history.
* **Defects.** A defect of the original model goes to `TEB_MSU_source_defects.md`
  (label `Dn`). A defect of the driver, of the forcing reader or of a bench goes to
  the change history (label `In`); a numerical defect of our own change is `Nn` (`N1`, `N2`); a
  known but unfixed item is `Cn`.
* Documents must not duplicate each other: reference the section instead of copying it.

---

## 3. File format

* Encoding **UTF-8 without BOM**, line endings **CRLF** (as in every file in `docs/`
  and in `README.md`).
* A single first-level heading (`#`) per file; sections are `## N. Title` with
  contiguous numbering (no gaps); subsections are `### N.M`.
* In-text references to a section use `§N.M`; a section of another file is referred to
  as `§N.M of <file>.md`.
* Tables are used for parameters, modes, registries and checks; code blocks carry a
  language tag (`fortran`) or no tag when they contain formulas or pseudocode.
* Language: the scheme, history and defect documents are in **Russian**;
  `README.md`, `TEB_MSU_variables_description.md` and this rules file are in
  **English**. Code names and identifiers are written as in the source
  (`proxy_phu_gdn`, `PAC_GARDEN`, `TEB_output.csv`).
* The header of a scheme document lists the related documents and carries the code
  state line, e.g. `> Состояние кода: коммит <sha> (дата), ветка MV_devs`.
* Values and units follow the model: `W/m²`, `kg/m²`, `m/s`, `K`; decimal point in
  formulas, the same number of digits as in the source of the number.

---

## 4. Links and traceability

* A commit is referenced as
  ``[`<sha>`](https://github.com/mkolennikova/TEB-MSU/commit/<sha>)``; the full SHAs are
  listed in the history registry. A commit not pushed to `origin` is marked
  **(local)** — otherwise its link does not open.
* A scheme document refers to the history by section or record ("see §5.7 of
  `TEB_MSU_change_history.md`"), and the history refers back to the section of the
  scheme document. The link must work in both directions.
* Labels (do not change without a reason):

| entity | label |
| --- | --- |
| commits (history registry) | `№1…№N`, contiguous, in `git log` order |
| cbs scheme versions | `v1`, `v1.1`, `v1.2`, `v1.2.1`, `v1.3`, `v1.3.1`, `v1.4` |
| garden scheme versions | `G1`, `G2`, `G3`, `G4` |
| defects of the original model | `D1…D7` |
| defects of the driver, the forcing reader, the benches | `I1…I4` |
| numerical defects of our own changes | `N1`, `N2` |
| known but unfixed items | `C1…C6` |
| bench checks | `B1…B6`, `Z1…Z4`, `S1…S4`, `T1…T5`, `T-a…T-f`, `G1…G14`, `H1…H6`, `I1…I9` |

* Every version and every mode in the table "version / mode → commits" must have a
  commit. A new mode without a history entry is a documentation error.

---

## 5. Marking changes in the code and in the variables description

* Source blocks that belong to a change are tagged

```
!MV<YYYYMM> <short feature name>
```

  with the same tag in every file of that change (for example
  `!MV202609 cbs scheme of the road` — 40+ places in `src/`). A change without code
  tags cannot be found by search and cannot be traced.
* In `TEB_MSU_variables_description.md` the related sections and table rows carry the
  same tag as an HTML comment: `<!-- MV202609 <name> -->`.
* Find every place of a change with:

```
Select-String -Path src/**/*.F90 -Pattern 'MV202609'
Select-String -Path docs/*.md      -Pattern 'MV202609'
```

---

## 6. Commits and history entries

* Commit subject: `<type>(<scope>): <subject>`.
  `type`: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`;
  `scope`: `urban`, `garden`, `output`, `driver`, `forcing`, `python`, `repo`, `data`.
  The body states **what was done**, **how it was verified** (benches, criteria) and
  **which documentation sections were changed**.
* History entry: a heading
  `### №N · <sha> · <date> · <subject>`, followed by the blocks **What was done**,
  **Documentation**, **Measurements**, **Not included / rejected** (empty blocks may be
  omitted). Dates are the author dates of the commits.
* The commit registry, the version tables and the lists of documentation sections are
  updated in the same commit as the change itself.
* Editor checkpoint commits (`cline checkpoint session=…`) are not listed in the
  history; the gaps in the hash sequence between entries are exactly those.
* Material outside the repository (bench scripts and data, e.g.
  `D:\TEB_work\Moscow\…`) is mentioned only as the source of numbers and is marked as
  external; where possible, point to the `python_tests/` script that reproduces it.

---

## 7. Checks before committing documentation

1. **Scope.** `git status --short`, `git diff --stat` — only the expected files have
   changed (`docs/**`, plus `README.md` when relevant).
2. **Format.** A single first-level heading per file, balanced code fences, contiguous
   section numbering.
3. **Placeholders.** No service markers (`<!-- END -->` and the like) left in the text.
4. **Files.** Every referenced file exists in the repository or is explicitly marked as
   external (bench scripts and sandboxes).
5. **Historical leftovers in the scheme documents.** Search for `v1.[0-9]`, `R-A`,
   `R-B`, `R-C`, `AB2`, `AB3`, `часть IV`, `D:\TEB_work`, `раньше`, `было` — these are
   allowed only in the reproduction section and in the change history.
6. **References.** Every `§…` points to an existing heading; after renumbering, the
   references are updated in **all** files (search for the section number).
7. **Encoding and line endings.** UTF-8 without BOM, CRLF.
8. **Commits.** The hashes used in links exist (`git show <sha> -s`); unpublished
   commits are marked local; the `№N` numbers in the history are unique and match the
   registry.

```powershell
git status --short; git diff --stat                      # 1
Get-ChildItem docs/*.md | ForEach-Object {               # 2, 3
  $t = [System.IO.File]::ReadAllLines($_.FullName, [Text.Encoding]::UTF8)
  '{0}: H1={1} fences={2} end={3}' -f $_.Name,
    ($t | Where-Object { $_ -match '^# ' }).Count,
    ($t | Where-Object { $_ -match '^```' }).Count,
    ($t | Where-Object { $_ -match '<!-- END -->' }).Count }
Select-String -Path docs/TEB_MSU_cbs_scheme_T_CAN_reformulation.md,`
  docs/TEB_MSU_garden_diagnostic_scheme.md -Pattern 'v1\.[0-9]|R-A|R-B|R-C|часть IV'   # 5
```

---

## 8. Keeping the documentation up to date

* A change of a scheme, a mode or a parameter **without** the matching edit of the
  scheme document and an entry in the history counts as unfinished work.
* A change of the documentation set (a new file, a rename, a removal) is reflected in
  `README.md` (repository layout table) and in the headers of the scheme documents.
* After renumbering sections, the references from every document and from `README.md`
  are checked.
* Obsolete documents are never removed silently: the reason is recorded in a history
  entry.
