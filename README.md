# BBCrawler

BBCrawler collects pages from the WHO Blue Books site and builds a local,
searchable database from saved pages. Use it to collect new material, refresh
the database from material already on disk, or inspect and search existing
results.

The main interface is [`Crawler_Runner.ipynb`](Crawler_Runner.ipynb), a
Jupyter notebook intended for use in VS Code. You do not need to understand the
implementation to follow its guided workflow.

## Start here

Before opening the notebook, make sure you have:

- VS Code with the Python and Jupyter extensions, and a Python installation
  compatible with this project's declared requirements.
- The neighboring `BBNotebook` helper files and local reference files available
  in their expected locations. The repository's `Library` link points to local
  material; keep that link and its target intact.
- A browser and authorized BlueBooksOnline access if you plan to collect pages.
  Collection and login open a browser on your own computer; they are not a
  cloud-kernel workflow.

Then open `Crawler_Runner.ipynb`, select the project's Python kernel, and follow
its setup and task instructions from the top. The notebook helps set up the
crawler, login state, collection choices, and database work. SQL Server is
optional; SQLite supports the local refresh workflow.

## Choose a task

| I want to… | Start with |
|---|---|
| Collect or update pages from BlueBooksOnline | [`Everyday use: collect pages`](docs/everyday-use.md#collect-pages-from-the-website) |
| Refresh the SQLite database using saved pages, without logging in | [`Everyday use: refresh saved material`](docs/everyday-use.md#refresh-from-saved-material) |
| Inspect the database or search its contents | [`Everyday use: inspect and search`](docs/everyday-use.md#inspect-and-search-results) |

For a first setup, see [Getting started](docs/getting-started.md). If something
does not work, use [Troubleshooting](docs/troubleshooting.md).

## Find your way around

You can begin with the notebook and leave the rest alone until you need it.

| Folder | What you will find |
|---|---|
| [docs](docs/getting-started.md) | Setup, everyday tasks and help |
| [app](app) | The scripts the notebook runs |
| [sql](sql) | Database definitions |
| [config](config/config.example.json) | An example for first-time setup |
| [requirements](requirements) | Package installation lists |
| [tests](tests) | Checks used when maintaining the project |

Existing databases and private settings stay in their familiar local locations.
Private reference files, working exports, backups and retired material are not
part of the published repository.

## Use the material responsibly

Blue Books and reference content may be protected by copyright, subscription,
or other access terms. Use source material and derived extracts only as allowed
by the terms that apply to you. Keep saved source content, databases, and login
state private; do not publish them or commit them to version control.

## Technical details

| Guide | Use it for |
|---|---|
| [Data guide](docs/technical/data-guide.md) | Database tables, columns, provenance, and search data |
| [Reference matching](docs/technical/reference-matching.md) | Term observations, official references, candidate codes, and review |
| [Maintaining the project](docs/technical/maintaining-the-project.md) | File layout, regeneration, tests, and safe maintenance |
| [Current backlog](issues/README.md) | Deferred work and active local issue notes |
