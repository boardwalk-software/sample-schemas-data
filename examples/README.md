# Example app definitions

RacerX's **Add App → Examples** installs these files. Each is a complete
Forms app: its schema, its builders-only "How this app is built" report, and
optional sample rows (`sampleData`: `{ tableId: [row, ...] }`).

RacerX downloads them from the **latest release** of this repo
(`releases/latest/download/<file>.json`), so you can update an example
without a RacerX release.

## To update an example

1. Edit the file in `examples/` and commit.
2. Publish a new release that attaches **all four** files (the latest
   release must always contain every example):

       gh release create vX.Y.Z examples/crm.json examples/issue-tracker.json \
         examples/wedding-planner.json examples/team-chat.json \
         --title "Examples vX.Y.Z" --notes "What changed"

Apps already created keep the version they were created from.

## Rules RacerX enforces

- Table and field ids: letters, digits and underscores, starting with a letter.
- A table shown as a conversation (`display: "conversation"`) may only have
  its message field, plus its thread lookup when threaded.
- SQL widgets in reports (```` ```report ```` blocks) use table and field ids,
  not labels, and are read-only.
