---
name: fetch-ticket
description: Fetch a ticket/issue from its tracker (Azure DevOps, Jira, GitHub, …) and save it as a self-contained markdown ticket file. Fetch only — no analysis or planning.
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.0"
---

# Ticket Fetcher

**Fetch only** — no analysis, requirements, or planning. Output is a self-contained `.TICKET.md`.

## Source & access

Identify the tracker from the input (URL host, or id shape) and fetch through the matching MCP
server — e.g. **Azure DevOps MCP** for ADO work items, **Atlassian MCP** for Jira issues, **GitHub
MCP / `gh`** for GitHub issues. Use whichever equivalent tools are connected; tool name prefixes
vary by config. Resolve once any handle the MCP needs (e.g. Atlassian `cloudId`, ADO project) and
reuse it. If the input is ambiguous, or no matching MCP is connected, ask the user / stop — don't
guess.

## Your task

1. **Resolve the input.** Accept a full ticket URL or a bare id/key; extract the identifier. If the
   tracker uses a key prefix (e.g. `XX-1234`), keep it; otherwise use the bare number. If the input
   is unrecognizable, ask.
2. **Fetch the ticket.** Get the work item/issue with its full field set, comments inline, and
   related links/relations expanded. Capture **everything** the ticket carries — don't pre-filter to
   a fixed set of fields. Convert whatever rich-text form you get (HTML, ADF, …) to clean Markdown.
3. **Pick a slug.** Short kebab-case slug, 3–5 words, from the title/summary — greppable, don't
   overthink it.
4. **Decide the output directory.** A project-relative `<id>-<slug>/` subdirectory inside the
   project's **planning directory** (e.g. `.claude/plans/`) — follow the project's/user's convention
   for where plans live; if none is defined, ask the user. Never guess. If it already exists,
   suggest `<id>-<slug>-v2`, `-v3`, etc. — **never overwrite** an existing plan directory; history
   per re-fetch is kept on purpose.
5. **Write the ticket file** at `<output-dir>/<id>-<slug>.TICKET.md`.
6. **Download attachments** into the output directory; warn on any that fail (see Attachments).
7. **Print the result** — project-relative paths and the next-step line (see Next step).

## Ticket file structure

Must stand on its own: a complete, readable version of the ticket with enough metadata that a fresh
session can identify the source without re-fetching.

### Header

Plain markdown header with source metadata; omit any line whose value is absent. Include whatever
the tracker provides. Example:

```markdown
# <title / summary>

> **Source** [<id>](<url>)
> **Type** {type}
> **Status** {status}
> **Assignee** {display name or "—"}
> **Reporter / Created by** {display name}
> **Labels / Tags** {joined or "—"}
> **Fetched** {today YYYY-MM-DD}
```

### Body sections

Emit in this order, **only if present and non-empty**:

1. `## Description`
2. `## Acceptance criteria` — if the tracker has a dedicated AC field populated
3. `## <Other fields>` — one section per other populated field carrying real content (technical
   notes, custom fields, …), headed by the field's display name. Capture everything the ticket
   holds.
4. `## Comments` — oldest first, each `### <author> — <date>` then the body. Best-effort: if
   comments aren't returned, note it briefly or omit the section.
5. `## Related tickets` — see below
6. `## Attachments` — see below

Preserve heading hierarchy, bullet structure, emphasis, and code blocks; map in-field subheadings to
`####`. Omit empty sections. Quote user-facing strings, code identifiers, file paths, i18n keys, and
URLs **verbatim** — never alter or translate them.

### Related tickets

From the response's links/relations (and any remote-link tool), for each unique linked ticket
(excluding this one) fetch **only** title + status + type via a cheap call — **not** the full body.
The main goal is that there is a trace of all related tickets, so they can be fetched later if
needed. One bullet each, with the relationship if available:

```markdown
- [<id>](<url>) — (<type>, <status>) <title>
```

For non-ticket remote links (e.g. a wiki/Confluence page), emit the title and URL as a plain bullet.
If a fetch fails, list the link with `(unable to fetch)` rather than failing the whole run.

### Attachments

Identify every attachment **and** every inline image referenced in the description/fields, numbered
`attachment-<N>.<ext>` in order of first appearance, keeping the original extension. `<N>` runs
across both combined.

Try to download each into the output directory — via the MCP's attachment tool, or `curl` on the
content URL (trackers often expose a URL usable with the same auth the MCP uses; if a plain fetch
401s, retry with the tracker's bearer token if you can obtain one). Then, per file:

- **Downloaded** → reference the local file.
- **Not downloaded** (no attachment tool, auth failure, etc.) → still reference the local file and
  the source URL, and add it to the list to warn about. Don't block — the ticket is usable either
  way.

Image → embed; non-image (PDF, .docx, …) → link instead:

```markdown
### Attachment 1

![attachment-1](attachment-1.png)
_Original filename: image.png_

### Attachment 2

[attachment-2.pdf](attachment-2.pdf) — _Original filename: design-spec.pdf_
```

For a file that couldn't be downloaded, append its source so the user can fetch it manually: `— not
downloaded; get it from <url> and save here as attachment-<N>.<ext>`.

## Boundaries

- **Do not** analyze, plan, or read source files for context.
- **Do not** modify the ticket in its tracker — fetching is **read-only** (no comments, transitions,
  edits, worklogs).
- The only files you create: the `.TICKET.md` and its attachments.

## Next step

State clearly when done, using **project-relative paths** (never absolute): the output directory,
the ticket file, and any attachments. If any attachment could not be downloaded, **first emit a
clear warning** listing each missing `attachment-<N>.<ext>` and its source URL, instructing the user
to download it and save it under that exact name so the embeds resolve. Then end with this exact
copy-pasteable line:

```
Next step: /refine-ticket <output-dir>/<id>-<slug>.TICKET.md
```
