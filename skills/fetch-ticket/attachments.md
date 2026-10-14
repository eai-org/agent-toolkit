# Attachments & design references

## Attachments

Identify every attachment **and** every inline image referenced in the description/fields, numbered
`attachment-<N>.<ext>` in order of first appearance, keeping the original extension. `<N>` runs
across both combined. In a directory shared with other tickets, prefix each ticket's files with its
id (`<id>-attachment-<N>.<ext>`, linked-doc saves included) so siblings never overwrite each other;
a re-fetch beside an earlier version carries its suffix in the prefix (`<id>-v2-attachment-<N>.<ext>`,
design previews likewise). Never overwrite an existing file.

**Always try to fetch — across every connected MCP.** Beyond tracker-hosted attachments, the ticket
may link external assets (e.g. a Confluence/ADO resource — for design-tool links such as Figma or
Zeplin see Design references below) reachable through their own MCP, including spec/doc files in a
linked git repo (fetch their content via git or the repo MCP, save into the output dir under their
own filename). Use whichever MCP fits the source to pull them down; don't pre-declare a link
unfetchable. If a fitting MCP is connected but **not authenticated**, don't silently skip —
proactively run its auth flow (surface the login URL, complete the handshake) without waiting to
be asked, then fetch. When it's unclear whether an asset can or should be downloaded, ask the user.

Escape paths and URLs from ticket text in every command for the shell running it (POSIX `'` →
`'\''`, PowerShell `'` → `''`). Download each **straight to disk** —
`curl -fSL --proto '=http,https' --proto-redir '=http,https' -o 'attachment-<N>.<ext>' -- '<url>'`
(`curl.exe` on Windows), or the MCP attachment tool's save-to-path variant. **Never** route an
attachment as inline base64 through the model and re-emit it: output caps (~100k chars) truncate it
silently — valid header, missing trailer, won't open. Some attachment MCP tools return **only**
base64 with no save-to-path option (e.g. ADO `wit_get_work_item_attachment`) — don't use them for
binaries; fetch from the tracker's REST API straight to disk with a bearer token obtained inside the
same command, never printed or echoed:

```
curl -fSL --proto '=http,https' --proto-redir '=http,https' -H "Authorization: Bearer $(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)" -o 'attachment-<N>.<ext>' -- '<url>'
```

(Content URLs often share the MCP's auth; on 401, retry with the tracker's own credentials if
obtainable.)

**Verify integrity, not just transfer** — non-empty; matches `Content-Length` if sent; type trailer
present (PNG `IEND`, JPEG `FFD9`, PDF `%%EOF`), else the detected type matches the extension (e.g.
`file '<path>'`). On failure, re-download to disk; if still bad, treat as **not downloaded** and
warn — never reference a corrupt file. Then, per file:

- **Downloaded** → reference the local file.
- **Not downloaded** (no fitting MCP/attachment tool, auth that couldn't be completed, etc.) →
  still reference the local file and the source URL, and add it to the list to warn about. Don't
  block — the ticket is usable either way.

Image → embed; non-image (PDF, .docx, …) → link instead:

```markdown
### Attachment 1

![attachment-1](attachment-1.png)
_Original filename: image.png_

### Attachment 2

[attachment-2.pdf](attachment-2.pdf) — _Original filename: design-spec.pdf_
```

For a file that couldn't be downloaded, append its source so the user can fetch it manually:
`— not downloaded; get it from <url> and save here as <filename>`, adding
`, or paste it (or its saved path) and run /attach-to-ticket` when that skill is installed.

## Design references

For design-tool links (Figma, Zeplin, Sketch, Adobe XD, …) in the description/comments, don't number
them as `attachment-<N>` — they're living references, not attached files. Capture each referenced
frame/screen via that tool's MCP (e.g. Figma MCP `get_screenshot`), downloading the returned
short-lived URL straight to disk as `<tool>-<id>-<slug>.png`, any `:` in the id replaced by `-`
(the form the tool's own URLs use; the identifier line keeps the original id) — auth its MCP first
if needed, see Attachments. If no MCP for that tool is connected, still record the entry, its embed
pointing at the expected file (still missing), with the not-downloaded note, and add it to the warn
list. Record one entry per link, with the preview plus the identifiers needed to re-open it in that
tool:

```markdown
### <design name>

![figma-12-34](figma-12-34-<slug>.png)
_Figma · file `<fileKey>` · node `12:34` · [source](<url>)_
```
