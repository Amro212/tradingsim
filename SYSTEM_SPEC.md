# TradingSim Technical Build Guide
UI-first memecoin / day-trading simulator with cause-based markets, Launchpad Seasons, Meta rotation, Trader + Content Creator loop, Contracts recovery, and Prop Firm Challenges.  
Primary goal: infinite playability without selling in-game cash.

---

## 0) Non-Negotiables
- **Server authoritative**: prices, candles, balances, holdings, trade execution, contracts payouts, challenges, progression, and anti-spam.
- **Client UI only**: rendering, inputs, sending intent requests.
- **No Robux → trade cash conversion**: monetization is cosmetics + convenience only.
- **Purpose-driven charts**: movement is driven by dev actions, whales, liquidity, trust, meta heat, and player participation, not pure randomness.
- **Infinite loop**: always active launches, contracts, challenges, and rotating metas.
- **Moderate, testable steps**: implement in the order below, each step has acceptance tests.

---

## 0.1 World Integration Contract

This Systems Spec is tightly coupled to `WORLD_SPEC.md`.

Rules:
- Every gameplay feature must have a corresponding 3D station defined in WORLD_SPEC.md.
- 3D stations are thin interaction layers only. They do not own logic.
- All authority remains server-side in services defined in this document.
- World elements (SurfaceGuis, billboards, screens) display read-only snapshots from MarketService, MetaService, EventService, etc.

If a system is implemented without a matching world anchor, it is incomplete.
If a world station exists without a backing system here, it is invalid.

---

## 1) Data Model (Server)
Implement these types as plain Lua tables in server modules.

### 1.1 CoinState
Fields (authoritative, server-only):
- `coinId: string`
- `symbol: string`
- `name: string`
- `meta: string` (e.g., "AI", "Animals", "Gaming", "Seasonal", "ParodyPolitics")
- `phase: string` (`"STEALTH" | "HYPE" | "DISTRIBUTION" | "DEAD" | "BLUECHIP"`)
- `createdAt: number` (unix seconds)

Market & trading:
- `price: number`
- `liquidity: number` (depth proxy; higher = less slippage)
- `volume: number` (rolling)
- `volatility: number` (noise amplitude)
- `drift: number` (baseline directional pressure)
- `supply: number` (optional)

Memecoin realism variables:
- `devTrust: number` (0..100)
- `communityStrength: number` (0..100)
- `whaleConcentration: number` (0..100)
- `devControl: number` (0..100) proxy for dev token share / ability to rug
- `hype: number` (0..100)

Lifecycle & events:
- `eventModifiers: table` (active modifiers by eventId)
- `isTradable: boolean`
- `isRuggable: boolean`

### 1.2 PlayerState
- `cash: number`
- `holdings: table<coinId, {qty:number, avgEntry:number, realizedPnl:number}>`
- `clout: number`
- `tier: number` (progression tier)
- `contracts: {active: table, completed: table}`
- `propChallenges: {active: table, completed: table}`
- `cosmetics: {owned: table, equipped: table}`
- `stats: {totalTrades:number, totalPnl:number, bestRun:number, bustedCount:number, ...}`

### 1.3 ServerState
- `coins: table<coinId, CoinState>`
- `metaHeat: table<meta, number>` (0..100)
- `launchQueue: table` (scheduled launches)
- `newsFeed: ring buffer` (last N events)
- `tickTime: number` (server clock)

**Acceptance test**
- Server can create 1 CoinState, 1 PlayerState, and serialize minimal snapshots to clients without errors.

---

## 2) Services Overview (Server)
Create/extend these services in `src/server/Services/` (names can align with your existing ones; do not refactor unrelated code):
1. `MarketService` (pricing + candles + snapshot broadcast)
2. `LaunchpadService` (scheduled coin launches + lifecycle)
3. `EventService` (dev actions, whales, trust events, meta news)
4. `MetaService` (meta heat rotation + correlation)
5. `TradeService` (validation + execution + fees + slippage)
6. `ContractsService` (creator contracts + payouts + recovery)
7. `ChallengesService` (prop firm challenges + bankroll + scoring)
8. `ProgressionService` (clout, tiers, unlocks, stipends)
9. `SaveService` (DataStore persistence)

Each lifecycle phase must modify coin parameters as follows:

STEALTH:
- liquidity: low
- volatility: high
- drift: neutral
- devTrust: moderate baseline
- whale event probability: low

HYPE:
- volatility: medium-high
- drift: slight positive bias
- marketing event probability: increased
- whale buy probability: increased

DISTRIBUTION:
- volatility: high
- drift: neutral to slightly negative
- whale sell probability: increased
- devTrust decay probability: increased

DEAD:
- liquidity: extremely low
- volatility: low
- drift: neutral
- coin hidden from top movers list

BLUECHIP:
- liquidity: high
- volatility: low-medium
- drift: slight positive bias

**Acceptance test**
- Server boots with all services loaded, no circular requires, and logs “ready”.

---

## 3) Networking Contracts (Remotes)
Define a strict set of RemoteEvents/RemoteFunctions and keep payloads compact. Use existing remotes if present; otherwise create new ones.

### 3.1 Market + Chart Remotes
Client → Server:
- `RequestMarketSnapshot()`
- `RequestCandles(coinId, timeframe, limit)`

Server → Client:
- `MarketSnapshot({serverTime, coins:[...], metaHeat:{...}, hotMetas:[...], news:[...]})`
- `CandlesHistory({coinId, timeframe, candles:[...]})`
- `CandleUpdate({coinId, timeframe, candle})`
- `CandleAppend({coinId, timeframe, candle})`

### 3.2 Trading Remotes
Client → Server:
- `RequestTrade({action:"BUY"|"SELL", coinId, qty})`

Server → Client:
- `TradeResult({ok, message, cash, holdingDelta, tradeLogEntry})`

### 3.3 Creator/Contracts/Challenges
Client → Server:
- `RequestPost({templateId, coinId})`
- `RequestContracts()`
- `AcceptContract(contractId)`
- `ClaimContractReward(contractId)`
- `StartChallenge(challengeId)`
- `ClaimChallengeReward(challengeRunId)`

Server → Client:
- `PostResult({ok, cloutDelta, hypeImpact, message})`
- `ContractsState({active:[...], available:[...], completed:[...]})`
- `ChallengeState({active:[...], available:[...], completed:[...]})`
- `ProgressionState({clout, tier, stipendInfo, unlocks})`

**Validation rules**
- Validate coinId, timeframe, qty, templateId, contractId, challengeId.
- Throttle high-frequency endpoints: `RequestTrade`, `RequestPost`.

**Acceptance test**
- Firing remotes with invalid payloads is rejected without server errors.
- Valid requests return expected responses.

---

## 4) Step-by-Step Implementation Plan

## Step 1: Baseline Market Snapshot (No realism yet)
### Goal
Show a global market list in UI that updates periodically.

### Implement
- In `MarketService`, maintain `coins` with basic fields: `price, changePct, volume, meta, phase`.
- Broadcast `MarketSnapshot` every 0.5–1.0 seconds (batched).
- Client `MarketController` renders list.

### Tests
- Join server with 2 clients: prices and top movers match for both.
- No client-side price authority.

---

## Step 2: Candlestick System (Realistic UI candles)
### Goal
Replace goofy chart with realistic candles and true timeframes.

### Implement (Server)
- In `MarketService`, create a base tick for each coin (recommended 1 second).
- Add OHLC aggregation per timeframe: `"1s","5s","15s","1m","5m","15m"`.
- Maintain ring buffer history (last 200–400 candles per timeframe per coin).
- Implement `RequestCandles` to return last `limit` candles + current candle.
- Emit `CandleUpdate` (current candle) and `CandleAppend` (new candle closed).

### Implement (Client)
- In `ChartRenderer`, render candles using pooled UI Frames:
  - wick + body
  - correct scaling with 2–5% padding
  - gridlines + right-side price labels
  - bottom time labels
  - crosshair + tooltip (OHLC, time, % change, volume)
  - optional volume bars pane

### Tests
- Switch timeframes: candles update correctly.
- Only the current candle updates live.
- Crosshair/tooltip works; no FPS tank (pooling enforced).

---

## Step 3: Launchpad Service (Continuous new coins)
### Goal
Coins launch on a schedule and follow phases.

### Implement
- `LaunchpadService`:
  - Every X minutes, generate a new coin:
    - assign `meta` based on current hot metas
    - assign a `devTeamProfile` (see Step 4)
    - initialize liquidity low, volatility high, hype low
  - Add coin to `MarketService` registry.
  - Set phase: `STEALTH` → after short time → `HYPE` → later → `DISTRIBUTION`
  - Coins can become `DEAD` (liquidity dries) or `BLUECHIP` (stabilizes) within server session.

### Tests
- New coin appears on schedule with a “launched” news item.
- Coin enters HYPE after configured time, volatility changes accordingly.

---

## Step 4: Event System (Dev actions, whales, trust events)
### Goal
Charts move for reasons that are visible in the news feed.

### Implement
- `EventService` generates events affecting coin variables:
  - Dev actions:
    - `MarketingPush` (hype up, volume up, short-term drift up)
    - `LiquidityAdd` (liquidity up, slippage down, trust up slightly)
    - `RoadmapUpdate` (trust up, community up, modest drift up)
    - `SuspiciousWallet` (trust down, volatility up)
  - Whale actions:
    - `WhaleBuy` (price impulse + volume, also increases whale concentration)
    - `WhaleSell` (price drop impulse, possible cascade if liquidity low)
  - Trust events:
    - `AuditRumor`, `DoxxRumor`, `ExploitRumor` etc. (trust shifts)
- Each event writes a news entry (headline + coinId + magnitude + timestamp).
- Events apply modifiers for a duration, not instant permanent changes.

### Tests
- Trigger events deterministically in dev mode and verify price response + news feed entry.

---

## Step 5: Meta System (Narrative rotation + correlation)
### Goal
Metas heat up and multiple coins in that meta become correlated.

### Implement
- `MetaService` maintains `metaHeat` (0..100) for each meta.
- Rotate hot metas on a schedule (e.g., every 10–15 minutes):
  - One meta rises, another cools.
- Meta heat impacts:
  - baseline drift for coins in that meta
  - probability of KOL/news events targeting that meta
- Add “meta news cycles” that explain shifts.

### Tests
- When meta heat rises, multiple coins in that meta show increased drift/volume.
- UI shows “Hot Metas” list updated from server snapshot.

---

## Step 6: Liquidity + Slippage + Net Flow (Make trading matter)
### Goal
Price movement responds to trading activity and liquidity.

### Implement
- In `TradeService`, compute slippage based on:
  - order notional size vs liquidity
- Execution price = current price ± slippage.
- Update coin’s internal net flow proxy:
  - net buys increase short-term drift/volume
  - net sells do the opposite
- Fees: small fixed trading fee (server-configured).

Recent player trades must influence short-term drift.

Implementation rule:
- Maintain rolling 30-second net flow per coin.
- netFlow = sum(buyVolume - sellVolume)
- driftAdjustment = netFlow / liquidity
- Apply driftAdjustment with decay over time (exponential decay recommended).

Net flow influence must:
- Be temporary
- Decay automatically
- Never permanently alter baseline drift


### Tests
- Large buy in low liquidity causes worse fill and visible price impact.
- Same buy in high liquidity has smaller impact.
- Two clients trading move the market consistently.

---

## Step 7: Rug Mechanics (Condition-based, learnable)
### Goal
Rugs happen only when conditions align, and players can detect risk.

### Implement
- Add `isRuggable` and a rug trigger function in `EventService` or dedicated `RugService`.
- Rug conditions (example):
  - `devTrust < T1`
  - `devControl > T2`
  - `hype > T3`
  - `liquidity` is “removable” (low stability flag)
- When conditions met, rug can trigger as an event:
  - large liquidity drop
  - huge price crash
  - volatility spike
- Provide risk indicators:
  - UI shows a “Trust Meter” and “Liquidity Meter”
  - not full transparency, but enough to learn patterns

### Tests
- Force rug conditions in dev mode and verify:
  - rug event fires
  - chart crashes
  - news feed explains
- Verify no “random rug” outside conditions.

---

## Step 8: Creator Posting System (Templates only)
### Goal
Players post prebuilt templates that build clout and modestly affect hype/meta heat.

### Implement
- `Posts` are template-based, no free text:
  - Template library: `templateId -> {headlinePattern, effectProfile}`
- `RequestPost(templateId, coinId)`:
  - Validate cooldown per player
  - Apply small hype bump to the coin and/or small meta heat bump
  - Award clout based on template tier + engagement rules
- Engagement:
  - Keep simple at first: server assigns engagement score based on:
    - coin current hype + metaHeat + randomness
  - Engagement affects clout gain, not raw price.

### Tests
- Posting increases clout.
- Posting causes small hype increase and corresponding modest market response.
- Cooldowns prevent spam.

---

## Step 9: Creator Contracts (Recovery loop)
### Goal
Broke players can always recover without selling cash.

### Implement
- `ContractsService` generates contracts per player:
  Examples:
  - “Post 3 times about hot meta coins”
  - “Cover 2 Launchpad launches”
  - “Call out rug risk: post about a low-trust coin”
  - “Trade 3 coins in hot meta” (careful: don’t require profit)
- Contracts reward:
  - **cash** (primary recovery)
  - clout (secondary)
- Add anti-exploit:
  - contract completion requires actual actions (valid post/trade events)
  - cooldowns and caps per hour

### Tests
- Player with 0 cash can complete contracts and receive enough to trade again.
- Contract completion is server-validated.

---

## Step 10: Prop Firm Challenges (Structured replay)
### Goal
Always-playable mode that provides a bankroll and skill goals.

### Implement
- `ChallengesService` defines challenge templates:
  - “Turn 1k into 5k with max drawdown 30%”
  - “Survive 10 launches”
- Each challenge run:
  - gives a separate challenge bankroll (not your career cash)
  - tracks PnL, drawdown, time, rule violations
- Completion rewards:
  - clout
  - cosmetics/titles
  - tier progression boosts
- Prevent farming:
  - daily caps on claimable rewards
  - difficulty scaling by tier

### Tests
- Starting challenge gives bankroll even if player career cash is 0.
- Drawdown rules enforced server-side.
- Completion grants rewards.

---

## Step 11: Progression (Clout, tiers, unlocks, stipend)
### Goal
Long-term retention without pay-to-win.

### Implement
- `ProgressionService`:
  - Tier increases with clout + challenge completions
  - Unlocks:
    - earlier launch info alerts
    - better dashboards (more indicators)
    - more watchlist slots
    - more contract availability
- Stipend:
  - small periodic payout based on tier (slow, capped)
  - separate from contracts, not big enough to break economy

### Tests
- Tier increases change unlock flags in UI.
- Stipend triggers on schedule and is capped.

---

## Step 12: UI Integration (Make it feel like a real terminal)
### Goal
Everything is visible and understandable, with a premium UI feel.

### Implement
- Market screen:
  - coin list, meta tags, phase indicator, trust/liquidity meters
- Chart screen:
  - timeframe selector
  - crosshair + tooltip
  - news overlay markers (optional)
- Creator screen:
  - template posting UI (no free text)
  - clout meter, tier unlocks
- Contracts screen:
  - available/active/completed
- Challenges screen:
  - list of prop challenges, run status, claim rewards

### Tests
- Complete gameplay loop without errors:
  - trade → post → accept contract → earn cash → start challenge → claim reward

---

## Step 13: Economy Balance Controls (Anti-inflation)
### Goal
Keep infinite play without runaway cash printing.

### Implement
- Cash inflows:
  - contracts (primary)
  - stipend (small)
  - challenge rewards (mostly cosmetics/clout, minimal cash)
- Cash sinks:
  - trading fees
  - optional: cosmetic shop uses separate premium currency (earned via clout) or direct Robux cosmetics only
- Limits:
  - cap contract payouts per hour/day
  - cap stipends
  - cap challenge reward frequency

### Tests
- Simulate an hour of play: cash does not grow infinitely without effort.
- Broke recovery always possible.

---

## Step 14: Persistence (SaveService)
### Goal
Save what matters, keep market per-server.

### Persist per player:
- cash, holdings, clout, tier
- completed contracts/challenges (summary)
- cosmetics owned/equipped
- stats

Do NOT persist:
- coin prices and server market state (per-server session for MVP)

### Tests
- Rejoin restores player state.
- Market resets per server.

---

## Step 15: Monetization (Safe)
### Goal
Earn Robux without selling trading power.

Implement:
- Cosmetics only:
  - UI themes, chart skins, titles, effects
- Convenience unlocks that do NOT improve profit expectancy:
  - more watchlist slots
  - saved layouts
  - extra analytics panels

**Tests**
- Purchases do not grant cash, do not reduce fees, do not improve fills, do not prevent rugs.

---

## 5) “Definition of Done” for the Whole System
A player can:
1) Trade coins in a global server market and see realistic candles in multiple timeframes.
2) Observe cause-based movement with news explaining why it moved.
3) Participate in meta rotation and understand which metas are hot.
4) Post template-based content to gain clout and lightly influence hype/meta heat.
5) Recover from bankruptcy using creator contracts (cash payouts).
6) Always play prop firm challenges with a provided bankroll.
7) Progress tiers to unlock better dashboards and earlier launch info.
8) Persist progression across sessions.
9) Monetize via cosmetics/convenience only.

---

## 6) Build Order Summary (Testable Milestones)
1. Market snapshot + global list
2. Candles + timeframes + realistic chart UI
3. Launchpad launches + phases
4. Events + visible news feed
5. Meta heat rotation + correlated moves
6. Liquidity/slippage + net flow effects
7. Condition-based rugs + risk indicators
8. Posting templates + clout
9. Contracts + cash recovery
10. Prop challenges + bankroll + rewards
11. Progression tiers + unlocks + stipend
12. Persistence
13. Monetization hooks

---

## 7) Notes for Agentic Implementation
- Keep changes scoped. Each milestone should land cleanly and be testable in a single session.
- Prefer toggles for new systems (dev config flags) so you can test deterministically.
- Add a small “dev commands” section (server-only) to force:
  - a launch
  - a whale buy/sell
  - a trust drop
  - rug condition trigger
This will massively reduce iteration time.

---