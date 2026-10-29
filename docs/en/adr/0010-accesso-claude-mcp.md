# ADR-0010 — Claude access per project, MCP stdio, access log

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 3.14, 12, 17.10

## Context
The user wants to query the archive from Claude Desktop with their own subscription. What Claude reads is sent to Anthropic's servers: it is data leaving the Mac.

## Decision
- `iago-mcp` executable in the bundle, stdio transport only, no network port, read-only DB.
- "Available to Claude" flag per project, off by default. Rows without a project are never available.
- Every call recorded in `audit_log`, visible to the user.
- Explicit notice in the settings about content being sent to Anthropic.

## Consequences
- Granular, tracked consent.
- `iago-mcp` must access the master key through a Keychain access group: to be verified with the free Personal Team (phase 3).
