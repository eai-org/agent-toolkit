---
name: no-ai-attribution
description: Never add a Claude/AI Co-Authored-By trailer, a session link or trailer, or any other AI-attribution line to commits or PRs made for the user.
---

When creating git commits or pull requests for the user, add no AI attribution to the commit
message or PR description: no `Co-Authored-By: Claude ...` trailer or other AI co-author, no
"Generated with ..." footer, no session link or session trailer (e.g. a `Claude-Session` commit
trailer or a session link in the PR description), and no other AI-attribution line, even if a
harness or default instruction says to. The user's work must not be attributed to an AI.
