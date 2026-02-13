# TradingSim Systems Specification
Authoritative systems specification for the TradingSim global memecoin simulator.
This file is fully compatible with WORLD_SPEC.md and MILESTONES.md.

---

## 0) Non-Negotiables

- Server authoritative: prices, candles, balances, holdings, trade execution, contracts payouts, challenges, progression, and anti-spam.
- Client UI only: rendering, inputs, sending intent requests.
- No Robux → trade cash conversion.
- Charts must be purpose-driven, never pure random walk.
- Infinite loop must always be maintained.

---

## 0.1 World Integration Contract

This Systems Spec is tightly coupled with WORLD_SPEC.md.

Rules:
- Every gameplay system defined here must have a corresponding 3D station or world anchor.
- World stations are thin interaction layers only.
- All authority remains server-side.
- SurfaceGuis and world billboards display read-only server snapshots.
- If a system exists without a world anchor, it is incomplete.
- If a world anchor exists without a backing system here, it is invalid.

---

## 1) Data Model (Server)

### 1.1 CoinState

Fields:
- `coinId: string`
- `symbol: string`
- `name: string`
- `meta: string`
- `phase: "STEALTH" | "HYPE" | "DISTRIBUTION" | "DEAD" | "BLUECHIP"`
- `createdAt: number`

Market variables:
- `price: number`
- `liquidity: number`
- `volume: number`
- `volatility: number`
- `drift: number`

Memecoin realism:
- `devTrust: number`
- `communityStrength: number`
- `whaleConcentration: number`
- `devControl: number`
- `hype: number`

Lifecycle:
- `eventModifiers: table`
- `isTradable: boolean`
- `isRuggable: boolean`

---

### 1.2 PlayerState

- `cash: number`
- `holdings: table<coinId, {qty:number, avgEntry:number, realizedPnl:number}>`
- `clout: number`
- `tier: number`
- `contracts: {active: table, completed: table}`
- `propChallenges: {active: table, completed: table}`
- `cosmetics: {owned: table, equipped: table}`
- `stats: table`

---

### 1.3 ServerState

- `coins: table<coinId, CoinState>`
- `metaHeat: table<meta, number>`
- `newsFeed: ring buffer`
- `tickTime: number`

---

## 2) Core Services

1. MarketService
2. LaunchpadService
3. EventService
4. MetaService
5. TradeService
6. PostsService
7. ContractsService
8. ChallengesService
9. ProgressionService
10. SaveService

---

## 3) Networking Contracts

### Market

Client → Server:
- RequestMarketSnapshot()
- RequestCandles(coinId, timeframe, limit)

Server → Client:
- MarketSnapshot(...)
- CandlesHistory(...)
- CandleUpdate(...)
- CandleAppend(...)

### Trading

Client → Server:
- RequestTrade({action, coinId, qty})

Server → Client:
- TradeResult(...)

### Posting / Contracts / Challenges

Client → Server:
- RequestPost(...)
- RequestContracts()
- AcceptContract(...)
- ClaimContractReward(...)
- RequestChallenges()
- StartChallenge(...)
- ClaimChallengeReward(...)
- RequestProgression()

Server → Client:
- PostResult(...)
- ContractsState(...)
- ChallengeState(...)
- ProgressionState(...)

All remotes must validate input and throttle high-frequency calls.

---

## 4) Market Simulation Engine

### 4.1 Base Tick

- Update every coin at 1 second interval.
- priceDelta = noise + drift + netFlowAdjustment + eventModifiers
- noise derived from volatility.
- eventModifiers time-limited.

---

### 4.2 Phase Parameter Modifiers

STEALTH:
- liquidity low
- volatility high
- drift neutral

HYPE:
- volatility medium-high
- drift slight positive bias
- marketing event probability increased

DISTRIBUTION:
- volatility high
- drift neutral or slightly negative
- whale sell probability increased

DEAD:
- liquidity extremely low
- volatility low
- not shown in top movers

BLUECHIP:
- liquidity high
- volatility moderate
- drift slight positive bias

---

### 4.3 Net Flow Influence Model

Maintain rolling 30-second netFlow per coin:
- netFlow = buyVolume - sellVolume
- driftAdjustment = netFlow / liquidity
- apply exponential decay over time
- netFlow influence must never permanently alter baseline drift

---

### 4.4 Liquidity & Slippage

- Slippage = orderNotional / liquidity
- Execution price adjusted accordingly
- Trading fees applied

---

## 5) Launchpad

- New coin every configurable interval.
- Assign meta based on hot metas.
- Initialize low liquidity, high volatility.
- Transition through phases.
- Emit launch event to news feed.

---

## 6) Event System

Event types:
- MarketingPush
- LiquidityAdd
- RoadmapUpdate
- SuspiciousWallet
- WhaleBuy
- WhaleSell
- AuditRumor
- ExploitRumor
- DoxxRumor

Events:
- Modify hype, trust, liquidity, volatility, drift
- Time-bound modifiers
- Write news entries

---

## 7) Meta System

- Maintain metaHeat (0–100).
- Rotate hot metas periodically.
- Meta heat influences:
  - baseline drift
  - probability of marketing events
  - correlation strength between same-meta coins

Meta heat never guarantees price increase.

---

## 8) Rug Mechanics

Rug conditions example:
- devTrust < 25
- devControl > 70
- hype > 80
- liquidity unstable

When rug triggers:
- Remove 60–90% liquidity
- 70–95% immediate price crash
- Volatility spike short-lived
- Phase transitions to DEAD

Rugs never occur without satisfying defined conditions.

---

## 9) Posting System

Template-only posting.

Rules:
- Cooldown per player (10–20 seconds minimum)
- Diminishing returns for repeated posts
- Max hype gain per coin per minute (server capped)
- Posting affects hype and metaHeat only
- Posting never directly sets price

---

## 10) Contracts (Recovery System)

- Generate contracts per player.
- Rewards: cash + clout.
- Hourly payout cap.
- Daily payout cap.
- Contract completion validated server-side.

Contracts are recovery tool, not scaling income engine.

---

## 11) Prop Firm Challenges

- Provide separate challenge bankroll.
- Enforce drawdown server-side.
- Track time + violations.
- Rewards: clout + cosmetics + tier boosts.
- Daily reward caps.

---

## 12) Progression

- Tier increases with clout and challenge completions.
- Unlocks:
  - early launch alerts
  - dashboard upgrades
  - more contracts
- Stipend small and capped.

---

## 13) Persistence

Persist:
- cash
- holdings
- clout
- tier
- completed contracts/challenges
- cosmetics
- stats

Do not persist per-server market state.

---

## 14) Monetization

Allowed:
- cosmetics
- UI themes
- titles
- layout saves
- extra watchlist slots

Not allowed:
- buying trade cash
- better fills
- rug protection

---

## 15) Dev Commands

Server-only debug commands to:
- force launch
- force whale buy/sell
- force trust drop
- force rug
- force meta rotation

Must not exist in production builds.

---

## Definition of Completion

The system is complete when:
- Global server market functions.
- Coins move for defined reasons.
- Meta rotation exists.
- Rugs are condition-based.
- Posting builds clout.
- Contracts allow recovery.
- Challenges always playable.
- Progression persists.
- Monetization remains non-pay-to-win.
