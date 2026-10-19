# Example app definitions

RacerX's **Add App → Examples** installs these files. Each is a complete
Forms app: its schema, its builders-only "How this app is built" report, a
sample report shown in the app, and optional sample rows (`sampleData`:
`{ tableId: [row, ...] }`). `team-chat.json` is the **Chat** example (renamed
2026-10-19; the file keeps its name so older RacerX builds still find it).

`chinook-reports.json` and `sakila-reports.json` hold only reports
(`{ pages: [...] }`): RacerX adds them to the Chinook and Sakila examples,
which are imported from the SQLite files in release v1.0.0. Each starts with
an owners-only "About this database" carrying the dataset's source and
license, which the licenses require.

RacerX downloads them from the **latest release** of this repo
(`releases/latest/download/<file>.json`), so you can update an example
without a RacerX release.

## To update an example

1. Edit the file in `examples/` and commit.
2. Publish a new release that attaches **all six** files (the latest
   release must always contain every example):

       gh release create vX.Y.Z examples/crm.json examples/issue-tracker.json \
         examples/wedding-planner.json examples/team-chat.json \
         examples/chinook-reports.json examples/sakila-reports.json \
         --title "Examples vX.Y.Z" --notes "What changed"

Apps already created keep the version they were created from.

## Rules RacerX enforces

- Table and field ids: letters, digits and underscores, starting with a letter.
- A table shown as a conversation (`display: "conversation"`) may only have
  its message field, plus its thread lookup when threaded.
- SQL widgets in reports (```` ```report ```` blocks) use table and field ids,
  not labels, and are read-only.
