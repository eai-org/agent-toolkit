---
name: attach-to-ticket
description: Attach pasted images, files or URLs to a fetched ticket, saved beside its ticket file and referenced from it, or fill an attachment the fetch could not download. Local only — never queries or edits the tracker.
license: MIT
metadata:
  version: "0.2"
---

# Attach to ticket

Save assets — pasted images, local files, URLs — into a ticket's planning directory and reference
them from its ticket file, so a fresh session picks them up. **Local only** — never query or modify
the tracker (no API calls, no re-fetch, no comments or edits); downloading an asset URL the user
supplies or a not-downloaded entry names is fine, tracker-hosted or not. Edit nothing in the
documents beyond the entries below and the REQUIREMENTS line of step 6.

## Your task

1. **Collect the assets.** The images pasted with the invocation, plus paths and URLs in its text;
   images pasted earlier only when the user points at them. Nothing pasted or pointed at → ask
   which, listing the images seen in the session. Done when every supplied asset is collected or
   dropped by the user.
2. **Resolve the ticket.** Named in the argument or already in the session (fetched, read,
   discussed) → proceed. Otherwise guess (branch name, latest planning directory) and confirm
   before writing; nothing to guess from → ask. No `<id>-*` directory, ticket file or REQUIREMENTS
   file under the project's planning directory (the one its governing docs name or already in use,
   default `.agents/plans/`) → stop and point to fetch-ticket; don't create one.
3. **Pick the document** — unless the user names one: the ticket file, latest `-vN` (file or
   directory) when re-fetched, the `<id>-` one in a shared directory; the REQUIREMENTS file when no
   ticket file exists. Several candidates left → ask.
4. **Map assets to entries.** Descriptions map to assets in paste order; "image 2 is …" overrides.
   If the document has entries whose file is missing (attachments or design references, marked
   not downloaded or not), propose which asset fills which — by original filename or design name
   and what the image shows — and confirm, unless the user's text already says. An asset with no
   description → ask what it shows, recommending a caption read off the image; never write one
   silently.
5. **Save to disk** — see Sources; never route bytes through the model (output caps truncate base64
   silently). Filling an entry → its filename when that is a bare name (no `/`, `\`, `..`, `:`),
   else ask; else the next `attachment-<N>.<ext>` after the highest N in the document or on disk
   (`<id>-attachment-<N>` in a shared directory). Either way the extension follows the actual file
   type; a symlink at the target, dangling included → ask; never overwrite a valid file. Verify:
   non-empty; type trailer present where the format has one (PNG `IEND`, JPEG `FFD9`, PDF `%%EOF`),
   else detected type matches the extension (e.g. `file '<path>'`); images and PDFs also viewed to
   confirm they are the asset given.
6. **Write the entries.** Filling an entry: keep it, drop any not-downloaded note, add or rewrite
   its reference to match the saved file (image → embed, else link; its extension), add the
   template's caption line — one entry per file, never a second.
   Else append to `## Attachments` (create it when missing — last, or before
   `## Design references`):

   ```markdown
   ### Attachment 3

   ![attachment-3](attachment-3.png)
   _<description> — added by hand YYYY-MM-DD_
   ```

   Non-image → `[attachment-3.pdf](attachment-3.pdf) — _<description> — added by hand YYYY-MM-DD_`.
   `attachment-3` stands for the saved filename, `<id>-` prefix included. When the document is a
   ticket file and a REQUIREMENTS file exists for it (its base with `.TICKET` → `.REQUIREMENTS`;
   for a `-vN` re-fetch with none, the ticket's latest), also append one line per asset — the same
   embed or link, its path relative to the REQUIREMENTS file when that sits in another directory,
   plus the caption — at the end of its **Context** part; no new section, nothing else changed.
7. **Report** project-relative paths: the document, the REQUIREMENTS file when it got a line — its
   requirements predate the asset; re-running `/refine-ticket` on the ticket, when installed,
   updates them in place — then one line per asset with its caption. When the document is a
   ticket file with no REQUIREMENTS file yet and `/refine-ticket` is installed, hand off with one
   copy-pasteable launch command in the agent tool's syntax (e.g.
   `claude --name refine-<slug> "/refine-ticket <document>"`), then the alternative, the tool's
   clear command (e.g. `/clear`) followed by `/refine-ticket <document>`.

## Sources

Escape paths and URLs from user or ticket text in every command for the shell running it (POSIX
`'` → `'\''`, PowerShell `'` → `''`), and again for a nested language (AppleScript, PowerShell).

- **Pasted image** — the path the agent tool reports for the paste; else its per-session paste
  cache when it keeps one (e.g. Claude Code's `~/.claude/image-cache/$CLAUDE_CODE_SESSION_ID/<N>.png`,
  `<N>` the image's number in the session); else the OS clipboard, see [clipboard.md](clipboard.md).
  None works → ask the user to save the image and paste its path.
- **Local path** — copy the file.
- **URL** — HTTP(S) only, redirects included (`curl.exe` on Windows):
  `curl -fSL --proto '=http,https' --proto-redir '=http,https' -o '<file>' -- '<url>'`; no auth
  flows here — on failure or a login page, ask the user to download the file and paste its path.
