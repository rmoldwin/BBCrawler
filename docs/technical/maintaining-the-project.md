# Maintaining the project

This guide is for maintainers changing BBCrawler code, database structures, or
documentation. Keep the user workflow simple in the README and practical
guides; put implementation contracts here and in
[Reference matching](reference-matching.md) and the [Data guide](data-guide.md).

## Repository layout and active paths

| Path | Purpose |
|---|---|
| `Crawler_Runner.ipynb` | Root-level guided collection, refresh, and inspection notebook |
| `app\` | Python scripts and notebook/documentation helpers |
| `sql\` | SQLite and SQL Server schema definitions and SQL helpers |
| `requirements\` | Python dependency requirement files |
| `config\config.example.json` | Safe example settings; not the live settings file |
| `config.json` | Active root-level local configuration retained for compatibility |
| `auth_state.json` | Active root-level private website login state |
| `bluebooks.db` | Active root-level SQLite database retained for compatibility |
| `Library` | Existing local link to reference files; preserve the link and target |
| sibling `BBNotebook` | Companion helpers, query notebooks, and local workbook inputs |
| sibling `CancerPathCHART` | Additional ICD-O-3.2 reference inputs used by matching |
| `docs\` and `issues\` | User guides, technical references, and local backlog |
| `tests\` | Standard-library unittest suite |

Run root-relative commands from the repository root unless an entry point
explicitly supports another working directory. The local SQLite refresh starts
with:

```powershell
python app\bluebooks_local.py --sqlite bluebooks.db
```

The companion `local_pipeline.py` bridge is maintained in `BBNotebook` and
delegates to the application code under `app\`. Keep its import and path
behavior aligned with the application entry points.

## Path and companion-file contracts

When changing file locations or imports, inspect all consumers before editing.
At minimum, verify:

- `bluebooks_local.py` locates the repository, SQL files, live settings, the
  active database, and `BBNotebook` helpers independently of the shell's
  current directory.
- `term_pipeline.py` resolves both the neighboring `BBNotebook` references and
  the sibling `CancerPathCHART` ICD-O-3.2 reference directory.
- `term_recovery.py` retains any still-active alias, compatibility, or
  regression-fixture responsibilities and accesses the local recovery manifest
  correctly.
- Crawler scripts find SQL schemas; notebook generators find configs, SQL,
  output notebooks, and subprocess working directories.
- Documentation generation writes the schema-derived
  `docs\technical\table-columns.md`, not the hand-maintained
  `docs\technical\data-guide.md`.
- Validators, tests, and the `BBNotebook\local_pipeline.py` bridge import the
  intended application code from supported working directories.
- Live root `config.json`, `auth_state.json`, and `bluebooks.db` remain usable;
  only the safe example moves to `config\config.example.json`.

Do not infer that a helper or manifest is obsolete from its filename. Confirm
imports, notebook use, tests, and compatibility entry points before retiring
it. Do not move or recreate the `Library` link or reorganize the neighboring
companion repositories as part of a BBCrawler change.

## Database and refresh safety

The SQLite workflow is the local canonical producer. The optional SQL Server
mirror receives the prepared SQLite data; it must not independently recompute
term extraction or matching. Keep source assignments, candidate mappings,
manual curation, and append-only review history distinct.

Before a change that writes or restructures a user database:

1. Identify the exact inputs and target database. Confirm the local reference
   files and their expected edition/revision.
2. Make and verify a restorable backup using the repository's established
   safeguards.
3. Close applications and notebook kernels that are using the database.
4. Apply changes transactionally where supported; stop on stale source,
   reference, or curation conflicts instead of overwriting them.
5. Verify key source assignments, review history, search documents, and
   SQLite/SQL Server parity where the change affects the mirror.

Never manually delete SQLite WAL/SHM files. Do not treat a mirror or a backup
as permission to move the active `bluebooks.db`; its root location is retained
for compatibility. Database changes should be driven by the shared producer,
not ad hoc updates to one engine.

## Schema and documentation

Schema definitions and SQL helpers live in `sql\`. If changing a table, view,
trigger, or normalization rule, update the appropriate schema sources, code,
tests, and technical contract together.

`docs\technical\data-guide.md` is hand-maintained: it explains the meaning and
safe interpretation of current data. `app\build_local_docs.py` generates
`docs\technical\table-columns.md` from the schema/database metadata. Regenerate
that detailed reference after schema changes and inspect it for complete
column, key, default, relationship, and index coverage. Do not let generation
replace the narrative data guide.

The README is also hand-maintained. Notebook instructional text is sourced by
`app\build_runner.py` and `app\notebook_local.py`; update the instructional
source before regenerating `Crawler_Runner.ipynb`. Review generated output to
ensure it preserves the root notebook and does not restore obsolete paths or
historical passages.

```powershell
python app\build_runner.py
python app\build_local_docs.py
```

The first command backs up the runner before replacing managed cells. Reader
cells and saved collection/search choices are retained. The second generates
only the detailed column reference. Schema snapshots require explicit
`--schema`; writing the neighboring SQLite schema also requires explicit
`--companion-schema`. Updating companion notebook instructions is opt-in through
`python app\notebook_local.py --companions`.

Live settings stay at the root. All five settings-based commands resolve their
default `config.json` from the project location; relative paths within a chosen
settings file resolve beside that file. Explicit command-line paths are still
interpreted relative to the terminal in the usual way.

## Tests and checks

Run the standard unittest suite from the repository root:

```powershell
.venv\Scripts\python.exe -m unittest discover -s tests
```

For a focused change, run the relevant test file first, then the full suite
when practical. Path changes should be checked from the repository root and
from an unrelated working directory. Documentation changes should be checked
for valid relative links and for references to files that are active in the
cleaned layout; do not link a current guide to ignored or archived material.

Do not run a live crawl as a cosmetic documentation or path-validation test.
Use read-only inspection or fixtures when validating workflow wiring.

## Private and licensed material

Treat `config.json`, `auth_state.json`, `bluebooks.db`, backups, local workbook
references, and saved page content as private local material. Keep them out of
Git commits and published artifacts. The safe config example must contain no
credentials. Follow the access and reuse terms that apply to source/reference
content; do not assume a blanket license or redistribution permission.

## Backlog and deferred behavior

Track deferred work in [`issues/README.md`](../../issues/README.md), with one
issue note per investigation where useful. Keep completed work separate from
unfinished extensions, and preserve the issue's active technical references
when an implementation plan is archived. The subtitle audit remains deferred;
see the [reference-matching contract](reference-matching.md) and
[subtitle issue](../../issues/subtitle-capture-audit.md).
