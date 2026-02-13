# FILE: WORLD_SPEC.md
# TradingSim World Spec (3D Map + UI Stations)

This document defines the playable 3D environment and how it hooks into the systems in `SYSTEMS_SPEC.md`.  
The world is a **hub** that players loop through forever. 3D is for immersion + navigation; all authority remains server-side.

---

## 0) World Design Goals
- Make the loop obvious: **Trade → Launchpad → Post → Contracts → Challenges → back to Trade**
- Use 3D stations as “portals” to the correct UI screens.
- Show key market info in-world via **SurfaceGui** on screens (read-only).
- Keep the map small, readable, and optimized. Prefer indoor hub + a few themed rooms.

---

## 1) Hub Layout (Stations)
Layout is a central atrium with spokes/rooms. 5 core stations + 1 optional.

### Station A: Trading Terminal Row (core)
**Purpose:** primary trading entry point and “market floor” vibe.  
**3D Elements:**
- 6–12 terminals/desks with monitors
- Big ticker strip above (scrolling top movers)
- Ambient NPC/props optional

**Interaction:**
- ProximityPrompt or ClickDetector on any terminal: opens Trading UI.

**World UI (SurfaceGui):**
- Terminal screens show:
  - top movers
  - hot metas
  - latest news headline
- Ticker strip shows top movers and rugs warnings

**Hooks to Systems**
- `MarketService` snapshot feed → in-world screens
- Trading UI opens:
  - Market list, chart, order panel, portfolio
  - Risk meters (trust/liquidity) per `Rug Mechanics`

**Acceptance test**
- Clicking a terminal opens correct UI.
- Terminal screens update from server snapshot (read-only).

---

### Station B: Launchpad Stage (core)
**Purpose:** new coins are born here, creates urgency and narrative.  
**3D Elements:**
- Stage with giant launch countdown screen
- Coin “hologram” display pedestal
- Meta tag light panels (AI/Animals/etc.)

**Interaction:**
- Interact with stage: opens Launchpad UI.
- Optional: interact with current coin hologram: deep-link to that coin in Trading UI.

**World UI (SurfaceGui):**
- Countdown to next launch
- Recently launched coin info (symbol, dev badge, meta)
- “Launch event” headlines

**Hooks to Systems**
- `LaunchpadService` schedules → countdown display
- `EventService` launch events → stage news and effects
- Trading UI deep-link:
  - open coin page with chart + order panel selected

**Acceptance test**
- Countdown is accurate.
- When new coin launches, stage updates and hologram changes.
- Interacting deep-links to the correct coin.

---

### Station C: Creator Studio (core)
**Purpose:** posting templates and clout progression.  
**3D Elements:**
- Studio room with camera props, ring light, screens showing “trending”
- A “posting kiosk” terminal

**Interaction:**
- Interact with kiosk: opens Creator UI (templates + clout).

**World UI (SurfaceGui):**
- Trending meta board (hot metas)
- Top “callers” (optional leaderboard)
- Recent posts feed (template-based entries)

**Hooks to Systems**
- `PostsService`: template posting, cooldowns, clout gain
- `MetaService`: meta heat display
- `ProgressionService`: tier/clout display

**Acceptance test**
- Posting from UI increases clout and triggers a visible “post result”.
- Trending board reflects server meta heat.

---

### Station D: Contract Board (core)
**Purpose:** recovery and grind loop without pay-to-win.  
**3D Elements:**
- Large mission board with rotating cards
- “Claim rewards” counter

**Interaction:**
- Interact with board: opens Contracts UI.

**World UI (SurfaceGui):**
- A few top available contracts preview (titles only)
- “Broke? Get back in” callout panel

**Hooks to Systems**
- `ContractsService`: list, accept, progress, claim payouts
- `ProgressionService`: payout caps, tier affects availability

**Acceptance test**
- A broke player can accept/complete a contract and receive cash.
- Board preview updates when contracts refresh.

---

### Station E: Prop Firm Office (core)
**Purpose:** structured replay, always playable with provided bankroll.  
**3D Elements:**
- Office lobby, challenge board wall
- Reception desk, “Start Run” kiosk

**Interaction:**
- Interact with kiosk: opens Challenges UI and can start a run.

**World UI (SurfaceGui):**
- Featured challenge of the hour
- “Top runs today” (optional)

**Hooks to Systems**
- `ChallengesService`: start run, bankroll, drawdown rules, completion
- `ProgressionService`: tiers unlock harder challenges

**Acceptance test**
- Player with 0 career cash can start a challenge run.
- Challenge completion grants rewards.

---

### Station F: Meta Billboard (optional but recommended)
**Purpose:** ties everything together visually.  
**3D Elements:**
- Giant billboard in hub atrium
**Displays:**
- hot metas
- top movers
- latest major event (rug, whale, dev action)
**Hooks:** `MarketService`, `MetaService`, `EventService`

---

## 2) How the Player Loops Forever (Physical + UI Loop)
1) Spawn in atrium facing Meta Billboard and Trading Terminals
2) Trade at terminals
3) Walk to Launchpad when countdown is close or alerts trigger
4) Walk to Creator Studio to post templates and gain clout
5) If busted, walk to Contract Board to recover cash
6) For structured gameplay, walk to Prop Firm Office and run challenges
7) Repeat

---

## 3) World Alerts (Lightweight, not spammy)
- Launch alerts: subtle UI popup + optional beacon light at Launchpad
- Rug warning: red flashing icon on ticker strip + terminal screen message
- Meta shift: billboard animation or color shift

All alerts are driven by server snapshot/news feed.

---

## 4) Implementation Notes (for engineering)
- Each station uses:
  - `ProximityPrompt` (recommended)
  - A small local controller to open the correct ScreenGui panel
- World screens use:
  - `SurfaceGui` with TextLabels and small icons
  - updated from a replicated “read-only snapshot” or remote event updates

**Do not** make world screens authoritative.

---

## 5) Acceptance: World Integration
- Every station opens the correct UI and that UI is powered by the matching service.
- All in-world displays mirror the same global server market state.
- Player can play even if they never touch stations (UI fallback), but stations are the intended loop.
