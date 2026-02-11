---
trigger: always_on
---

# FILE: AGENT_RULES.md
# TradingSim Workspace Agent Rules (Read every time)

## 0) Prime Directive
Preserve momentum. This repo is already working.
- Do not restructure folders.
- Do not rename/move existing files.
- Do not introduce frameworks unless explicitly requested.
- Make the smallest change that achieves the task.

If a request seems to require refactors, stop and propose a minimal alternative first.

## 1) Workspace Structure Is Fixed
Current structure must remain intact:
- /src/client (Controllers, init.client.luau, etc.)
- /src/server (Services, init.server.luau, etc.)
- /src/shared (Config, Coins, Formatting, etc.)
- default.project.json already exists and maps the game
- aftman.toml already exists
- sourcemap.json exists

Allowed additions:
- New ModuleScripts under existing folders (src/shared, src/server/Services, src/client/Controllers)
- New folders only if they are strictly additive and obviously scoped (example: src/shared/Util)
Not allowed:
- Moving files between client/server/shared
- Renaming init scripts
- Replacing the project layout

## 2) Server Authority Rules (Non-Negotiable)
This is a trading sim with exploit risk. Always keep these on the server:
- market simulation state and price truth
- balances, holdings, PnL truth
- trade validation + execution
- anti-spam throttles
- save/load logic

Client is UI only:
- render market snapshots
- render charts
- send trade intents (BUY/SELL) with coinId + qty only

Never trust client values for price, balance, holdings, or timestamps.

## 3) Remotes and Data Contracts
- Client -> Server: send intent only (action, coinId, qty).
- Server validates coinId, qty, limits, balance/holdings, rate limits.
- Server -> Client: send market snapshots, coin history, trade results, news events, player state.

Rules:
- Validate every remote payload.
- Rate-limit trade remote calls.
- Keep payloads compact. Batch updates when possible.
- Never allow the client to “set” state.

## 4) Performance Rules
- Do not redraw charts every frame. Update on tick/new data only.
- Pool UI objects (candles, rows) instead of destroying/creating repeatedly.
- Cap visible candles (typical 60–180). Cap history stored client-side.
- Avoid heavy loops in RenderStepped. Prefer event-driven updates.

## 5) Coding Style + Module Boundaries
- Controllers: orchestrate UI, subscribe to state updates, route inputs to services/remotes.
- Services (server): own authority, state updates, persistence, validation.
- Shared modules: configs, constants, formatting, shared helpers.

Rules:
- No “god scripts”. If a file grows too big, split into focused modules.
- Prefer pure functions for formatting/calcs.
- Avoid circular requires.
- Use clear names. Keep public APIs narrow.

## 6) Safety and Hygiene
- No hidden scripts in assets.
- No dynamic remote names.
- Never store authoritative values in ReplicatedStorage except read-only snapshots.
- Never store secrets in the repo.

## 7) Output Expectations (How you report changes)
For every task, output:
- Summary of what changed (1–3 bullets)
- Files changed (paths)
- If behavior changed, include how to test quickly
- If anything is risky, flag it explicitly

## 8) Tooling Guardrails (Rojo + Aftman + Wally)
- Keep aftman.toml pins stable.
- Keep default.project.json stable. Only additive mappings when requested.
- Never delete or rewrite core config files unless asked.

If you touch dependency tooling (Aftman/Wally/Rojo):
- Provide exact Windows commands to reproduce
- Provide exact file diffs or full file content if small
- Confirm the game still runs

## 9) “Stop Conditions” (When you must pause and ask)
Stop and ask before proceeding if:
- A request implies moving many files or reorganizing folders
- A change would break server authority boundaries
- A dependency/framework is being introduced without explicit approval
- You cannot preserve backward compatibility with existing modules
