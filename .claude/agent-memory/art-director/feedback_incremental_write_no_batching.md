---
name: feedback-incremental-write-no-batching
description: when dispatched as a subagent (no live human turn-by-turn in the thread), write a skeleton file with all section placeholders immediately, then Write/Edit each section to disk the moment it's drafted — never hold multiple sections in your head before writing any of them
metadata:
  type: feedback
---

For any multi-section deliverable (a spec doc, an art bible section, an asset
list), create the target file first with all section headers + a "待撰寫"
placeholder body, then draft and write ONE section at a time, committing each to
disk via Write/Edit before starting the next section's draft.

**Why:** This project has a registered incident of a specialist drafting an
entire multi-item deliverable in-conversation before writing any of it, then
losing all of it when the session/process was interrupted — the coordinator
explicitly cited this as "本專案登記過有專家正是這樣整批歸零" when correcting a
2026-09-17 art-director session that had done exactly that (four defect analyses
fully reasoned in conversation, zero bytes on disk, session interrupted, had to
restart from nothing). The file is the durable state; the conversation is not.

**How to apply:** This is a stronger, session-specific instance of the general
"incremental file writing" rule already in `.claude/docs/context-management.md`
— but note that rule assumes a live human granting per-section approval
("Write each section to the file as soon as it's approved"). When operating as a
Task-dispatched subagent with no live back-and-forth human in the thread (the
"user" turns are actually a coordinator relaying dispatch briefs and mid-task
corrections), there is no one to say "yes" per section in real time. In that
mode, put the full "為什麼" reasoning INTO the document itself (so a human
reviewing later can audit the decision), narrate the decision briefly in your
response as you go, and write immediately — do not block waiting for a reply
that will not come turn-by-turn. If a task instead comes as a live chat with an
actual creative director, the normal "may I write this section" approval gate
still applies in full.
