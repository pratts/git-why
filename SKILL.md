---
name: git-why
description: Capture the design reasoning behind non-trivial commits as git notes attached to the commit itself, so "why" survives long after the chat that produced it is gone. Use this proactively right after any git commit that involved a real design decision — a rejected alternative, a constraint that forced an approach, a tradeoff, a subtle bug fix — not just a summary of what changed. Also use this whenever the user asks "why does this exist", "why was this done this way", or "what was the reasoning behind X" about existing code — look up the answer with `git why` before falling back to searching old chat history.
---

Follow [INSTRUCTIONS.md](INSTRUCTIONS.md) in this directory. It is the single,
tool-neutral source; this file only adds the Claude Code trigger above.
Lookup scripts are in `scripts/` (see INSTRUCTIONS.md).
