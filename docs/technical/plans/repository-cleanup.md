# A clear, welcoming BBCrawler

Status: approved for implementation.

## Goal

Someone who understands the subject but does not program should quickly find:

1. What this project does.
2. What they need before using it.
3. Which notebook to open.
4. How to collect new material, work with saved material, or inspect results.
5. Where to find help without reading implementation history.

The front page will describe the present product, not how it developed.
No release notes, version announcements, completion reports, session memories,
or historical explanations will appear in the README.

This plan covers BBCrawler. A separate redesign of BBNotebook is deferred.
Only companion references that must change to keep BBCrawler working are in
scope. No terminology algorithms, code assignments, or database structure will
be changed as part of this cleanup.

## What is wrong today

- The README is roughly 350 lines and mixes getting started with database
  internals, maintenance history, dated changes, and repeated descriptions.
- Active scripts, SQL definitions, generated documents, old reports, private
  settings, large databases, installers, and old packaged copies share the root.
- Several documents describe older behavior as if it were still current.
- Notebook instructions contain implementation details that obscure the action
  a reader should take.
- Document and notebook generators can recreate the same clutter unless their
  source text and destinations change too.

## Proposed folder layout

```text
BBCrawler/
  README.md
  Crawler_Runner.ipynb
  app/                    The working Python scripts
  sql/                    Database definitions and SQL helpers
  requirements/           Existing installation lists
  config/                 A safe settings example, not passwords
  docs/
    getting-started.md
    everyday-use.md
    troubleshooting.md
    technical/
      data-guide.md
      reference-matching.md
      maintaining-the-project.md
      plans/
        repository-cleanup.md
  issues/                 Current follow-up work
  tests/                  Checks for maintainers
  local/                  Private working files; not published
  Library/                Existing local reference collection; not published
  local_backups/          Safety copies; not published
  Archive/                Retired material; not published
```

Hidden Git, Python environment, and automatically generated cache folders will
still exist. The plan does not pretend those can all be removed permanently.

The root deliberately keeps one visible notebook beside one short README.
Do not create multiple near-identical runner notebooks, additional landing
pages, or placeholder README files in every folder.

**Safety exception:** the active database and live settings can temporarily stay
at their current paths while their users are migrated. A clean-looking root is
not worth breaking an existing connection or losing saved data.

## The replacement README

Write it from scratch. Do not shorten the current document by deleting random
paragraphs.

There is no strict line or word limit. Reveal information progressively: begin
with purpose and first steps, introduce everyday tasks next, and link to deeper
details only when the reader needs them. Use simple headings, generous spacing,
and one small navigation table.
No decorative badges, large banners, repeated warnings, or elaborate diagrams.

It should contain only:

- A brief description of the project and intended reader.
- The notebook link and a short first-use checklist.
- Three tasks: collect from the website, update from saved material without
  logging in, and inspect/search the existing results.
- A clear note that the browser/login steps run on the user's own machine.
- A short privacy/access warning: use licensed source material according to its
  terms; do not publish source content, databases, or saved login details.
- Links to the three practical guides and the detailed technical guides.

State prerequisites honestly: VS Code notebook support, a supported Python
installation, BBNotebook's required helper files, and local reference files.
SQL Server is optional where the workflow genuinely supports SQLite alone.
Do not promise unsupported Python versions or a standalone installation.
Do not invent a blanket permission to reuse copyrighted content.

Keep the README hand-maintained. Reuse notebook instructional text through the
existing generators where useful; do not generate the README from a database
report or a chronological change log.

## Writing rules for all active Markdown and notebooks

- Explain purpose before mechanics.
- Give each action its expected result and what to do if it fails.
- Use familiar language: "saved page text" rather than "corpus"; "matching
  results" rather than "parity"; "where a value came from" before "provenance."
- Explain necessary subject terminology when first used. Keep exact table,
  field, and command names where someone needs to copy them.
- Explain an official code versus a suggested code in ordinary language.
- Technical guides may be detailed, but must also use understandable prose.
- Remove session commentary, conversational fragments, stale counts, duplicated
  sections, and update narratives from active guides.
- Preserve useful troubleshooting and compatibility advice as current guidance,
  not as a story of the original incident.

Archived snapshots retain their original contents. They are not current guides
and will not be linked from the front-page user journey.

## Documentation decisions

| Existing material | Intended destination |
|---|---|
| Current README | Preserve a local snapshot in Archive; replace the root README |
| Session fix log and database completion report | Archive after extracting any still-useful instructions |
| Completed harvesting implementation plan | Archive after preserving current maintenance requirements |
| Data dictionary | Rewrite/consolidate into the detailed data guide |
| Terminology-kind and subtype explanations | Fold current field meanings into the data guide; archive replaced originals |
| Clean2 before/after report | Archive the dated comparison; explain current text matching in the reference guide |
| SQL Server connection notes | Plain-language troubleshooting plus necessary technical details |
| ISSUES.md and issues folder | One current backlog under issues; preserve unresolved tasks |

Review each backlog item against the actual implementation. For example, loading
the September morphology workbook and implementing its annexes are different
tasks; do not discard unfinished annex work or leave completed loading work
marked unstarted.

The subtitle issue remains open and deferred. Rewrite its plan link when the
harvesting plan is archived; it must not point at a missing or ignored file.

Do not call a script obsolete solely because its name sounds historical.
For example, active helpers still used from `term_recovery.py` must be retained
or deliberately moved to an appropriate active module before that file retires.

## Notebook redesign

Keep one runner with a short introduction and a visible choice of tasks.
Do not require someone updating saved data to run login or website-collection
cells.

Each section has:

1. What this step does.
2. Whether it changes files or databases.
3. The small number of settings the reader must choose.
4. The action to run.
5. A readable success message and a clear failure instruction.

Separate read-only inspection from updates. Require deliberate confirmation
before website collection or database replacement; do not introduce silent
actions merely to make the notebook shorter.

Keep implementation explanations in the technical guides. Clear saved private
outputs before publication. Preserve user-authored cells and settings when
regenerating existing notebooks.

Update both `build_notebook.py` and `notebook_local.py`, not only their generated
notebook. Regenerating the notebook must preserve the new organization and text.

## Safe relocation of working code

**Changed after the rubber-duck review:** file moves require an explicit path
inventory, not a blanket search-and-replace.

Introduce one shared way to find the project, settings, SQL definitions, local
files, and neighboring references. Anchor it to the installed project location,
not the terminal's current folder. Keep existing flat helper imports working
inside app, with one tested notebook bootstrap.

Before moving code, account for all of these:

- `bluebooks_local.py`: project root and neighboring BBNotebook helpers.
- `term_pipeline.py`: project root, BBNotebook references, and the separate
  CancerPathCHART ICD-O-3.2 reference directory.
- `term_recovery.py`: local Library manifest access still needed by any active
  tests/adapters.
- `bluebooks_books.py` and `bluebooks_crawl.py`: schema file locations.
- `clean_term2.py`: its SQL function definition location.
- Notebook generators: settings, SQL files, subprocess working directories,
  notebook output locations, and documentation links.
- Documentation generator: SQL snapshots, guides, and companion output paths.
- Validators, tests, and companion importers: script/notebook discovery and
  imports.
- All five CLI entry points: their current bare `config.json` defaults.

The initial move leaves live `config.json`, login state, and active database at
their existing locations. `config/` initially contains only the example.
Support existing-user paths explicitly; do not silently stop finding settings.

For the later local-file move, support explicit paths and a documented migration
from the old defaults. Relative database/login paths must have one consistent
base, not depend on whichever directory the notebook happens to use.

Use one test-entry setup appropriate to the existing unittest runner, rather
than adding pytest or leaving a different path workaround in every test.
No new package manager or packaging system is required solely for this cleanup.

## Private files and Archive

- Move old backup databases into local_backups using an explicit file inventory.
- Move outdated installer/package copies and retired reports into Archive.
- Move current validation reports and exports under local when their producers
  and consumers have been updated.
- Preserve the existing Library link and its target. Do not recursively move or
  delete the collection it points to.
- Do not delete old files merely because they are untracked or large.
- Never stage private settings, login sessions, reference content, databases,
  or backup files.
- Retiring tracked files means removing them from the active tracked tree while
  keeping their local copies in ignored Archive. Git retains their old history.

Relocating the active database is a separate checkpoint:

1. Back up and verify it.
2. Close notebook kernels and database clients that use it.
3. Confirm connections are closed; complete any necessary SQLite checkpoint and
   clean close. Do not manually delete journal/sidecar files.
4. Move the database and associated application metadata as a consistent unit.
5. Update every known connection and freshness/reference-path record.
6. Verify integrity, unchanged data, and both workflows before retiring the old
   path.

If an external client cannot yet be migrated, leave the active database in
place and record the exception. Do not make a second ambiguous working database.
Moving a reference file must not invalidate its evidence identity or falsify
where earlier evidence was obtained.

## Implementation sequence

1. Record clean/dirty worktree state, make a baseline commit/tag for the cleanup,
   and back up before any database-related move.
2. Write the new README and practical guides; extract current instructions from
   old reports and identify genuinely retired files.
3. Rewrite notebook instructional sources and generate the revised runner.
4. Centralize paths and move active scripts, SQL, and installation lists in a
   coherent change; update tests and affected companion references.
5. Consolidate technical guides, relocate the current plan and issue links, and
   archive superseded documentation.
6. Organize local artifacts; relocate active data only after the separate safety
   checkpoint passes.
7. Validate usability and behavior, update this plan with actual exceptions,
   then commit the completed cleanup. Push BBCrawler only if its target remote
   is configured and verified.

No independent BBNotebook overhaul or remote publication is included.

## Acceptance checks

- The root's tracked files are the README, the runner, and necessary hidden
  project files; all other tracked material is in clearly named folders.
- README contains no history, update/version narrative, completion report, or
  implementation dump. Information builds progressively without a length quota.
- A reader can identify the appropriate task and its prerequisites from the
  README without reading a technical guide. Validate this with a brief user
  walkthrough when available; do not claim user-tested success without it.
- Practical guides and notebook instructions define necessary technical words.
- All active Markdown links resolve; no link relies on an ignored Archive file.
- Notebook regeneration retains the new text and preserves user cells.
- Existing unittest checks pass from the documented location; add tests for
  path resolution, relocation, and generation.
- Imports and SQL/reference discovery work from both the repository root and
  an unrelated working directory, using the documented entry commands.
- Run safe read-only notebook inspection against SQLite and SQL Server.
  Validate update/collection wiring with fixtures; do not run a live crawl as a
  cosmetic-cleanup test.
- Before/after data checks confirm unchanged source assignments and review
  decisions. Full database reprocessing is not required just to move documents.
- Both BBNotebook and CancerPathCHART reference inputs still resolve.
- Git staging contains no private outputs, copyrighted reference contents,
  database files, or Archive/local_backups material.

## Rubber-duck review outcome

The review identified path breakage as the main risk, not visual presentation.
The plan now explicitly covers:

- The additional CancerPathCHART reference dependency.
- Independent file-location calculations in each affected module.
- Existing live settings compatibility.
- Markdown and issue cross-links.
- The existing unittest import setup.
- A guarded, separately validated active-database move.
- Generator ownership, so regeneration cannot restore the old clutter.

These amendments are included above. Implementation follows this reviewed plan,
with the user's progressive-introduction requirement replacing the length cap.
