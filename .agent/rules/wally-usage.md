---
trigger: always_on
---

# FILE: WALLY_RULES.md
# Wally Usage Rules (TradingSim)

## 0) Purpose
Wally is our dependency manager for Luau code packages.
We use it to avoid copying random ModuleScripts into src, and to keep versions pinned and reproducible.

Wally is NOT for:
- 3D models, meshes, UI assets
- plugins
- Creator Store / Toolbox assets

## 1) Non-Negotiable Wally Workflow
When adding or changing a dependency:
1) Edit wally.toml only.
2) Run `wally install` to generate/update:
   - /Packages
   - wally.lock
3) Commit BOTH:
   - wally.toml
   - wally.lock
4) Never edit wally.lock manually.

If you did not change dependencies:
- Do not touch wally.toml or wally.lock.

## 2) Where packages must appear in-game
Packages must be mapped by Rojo to:
- ReplicatedStorage.Packages  ->  /Packages

Rules:
- Require packages only via ReplicatedStorage.Packages (or a shared alias module if we add one).
- Never copy package source into src/.
- Never require from “random” folders.

## 3) Minimalism Rule (No frameworks by default)
Prefer small, focused packages over full architectures.
Do not introduce big frameworks (Knit, Fusion, Roact, etc.) unless explicitly requested.

Allowed types of packages (examples of categories):
- Signals/events
- Cleanup/maid
- Promises (if needed)
- Data structures (ring buffer)
- Serialization helpers
- Fast caching/pooling helpers
- Testing helpers (optional)

## 4) How to choose packages (Search-first rule)
Before implementing a utility yourself, do this:
1) Identify the use case precisely (one sentence).
2) Search Wally registry for an existing package.
3) If a package exists and is reputable:
   - prefer it over custom code
4) If no good package exists:
   - implement a minimal local module in src/shared/Util with clear API
   - do NOT import random GitHub modules by copy/paste

“Reputable” means:
- widely used community author
- clear README/docs
- recent maintenance or stable history
- small surface area and understandable code

## 5) Wally search targets for THIS game (use-case map)
When you encounter these needs, you MUST first look for a Wally package:

A) UI + controller architecture needs
- Signal/event bus for decoupled updates
- Cleanup/maid to avoid memory leaks from connections
- Small state container helpers (not full frameworks)

B) Charting and data handling needs
- Ring buffer / circular buffer for candle history
- Fast table utilities
- Number formatting helpers (optional)

C) Networking needs (keep server authoritative)
- Serialization helpers for compact snapshots (if needed)
- Throttling helper patterns (usually implement locally unless a tiny lib exists)

D) Performance needs
- Object/instance cache/pool for UI rows/candles if you decide to pool via modules

## 6) Wally integration rules for agent output
If you add a dependency, your response must include:
- The exact dependency line added to wally.toml
- Confirmation you ran `wally install` (and that /Packages + wally.lock changed)
- The new require() path to use in code (ReplicatedStorage.Packages.<Package>)
- A tiny proof snippet (or confirm existing proof still passes)

## 7) Commands (Windows)
Standard sequence:
- `aftman install`         (only if tools changed / first setup)
- `wally install`
- `rojo serve default.project.json`

## 8) Prohibited behaviors
- Do not edit wally.lock manually.
- Do not vendor (copy) package source into src/.
- Do not add a dependency “just because”. Every dependency must be justified by a concrete use case tied to the game.
- Do not add dependencies for assets/models.

## 9) Default preference list (when multiple options exist)
Prefer:
- smallest surface area
- clearest docs
- simplest API
- minimal runtime overhead
over “feature-rich” packages.

If you must choose between two similar packages, pick the one that is:
- better documented
- more actively maintained
- more widely adopted
and explain the choice in one sentence.
