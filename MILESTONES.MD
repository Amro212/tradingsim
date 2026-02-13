# FILE: MILESTONES.md
# TradingSim Milestones (Chronological Build Order)

This is the single source of truth for build order. Each milestone references sections in:
- `SYSTEMS_SPEC.md`
- `WORLD_SPEC.md`

---

## Milestone 1: Global Market + Terminal UI
Implement:
- Systems: Market snapshot (`SYSTEMS_SPEC.md` §4, §3.1)
- World: Trading Terminal Row station shell (`WORLD_SPEC.md` Station A)

Done when:
- Two clients see identical top movers + prices.
- Clicking a terminal opens Trading UI.

---

## Milestone 2: Real Candles + Timeframes
Implement:
- Systems: Candles (`SYSTEMS_SPEC.md` §4.2)
- UI: ChartRenderer realism (candles, grid, tooltip)
- World: Terminal monitor SurfaceGui displays top movers (optional)

Done when:
- 1s/5s/15s/1m/5m/15m timeframes work.
- Chart looks realistic and performs well.

---

## Milestone 3: Launchpad + Coin Lifecycle
Implement:
- Systems: Launchpad (`SYSTEMS_SPEC.md` §5)
- World: Launchpad Stage (`WORLD_SPEC.md` Station B)

Done when:
- Countdown + new coin launches work.
- Coin appears on stage and can deep-link to chart.

---

## Milestone 4: Events + News Feed
Implement:
- Systems: EventService (`SYSTEMS_SPEC.md` §6)
- World: News displayed on terminal ticker and launchpad screen

Done when:
- Whale/dev/trust events visibly move price and write news entries.

---

## Milestone 5: Meta Heat + Narrative Rotation
Implement:
- Systems: MetaService (`SYSTEMS_SPEC.md` §7)
- World: Meta Billboard + Creator Studio trending board (`WORLD_SPEC.md` Stations C/F)

Done when:
- Hot metas rotate and coins within meta become correlated.

---

## Milestone 6: Liquidity, Slippage, and Net Flow
Implement:
- Systems: TradeService improvements (`SYSTEMS_SPEC.md` §4.3, §6, §3.2)

Done when:
- Big orders slip more in low liquidity.
- Trading activity affects coin behavior.

---

## Milestone 7: Rug Mechanics (Condition-Based)
Implement:
- Systems: Rugs (`SYSTEMS_SPEC.md` §8)
- World: optional warning lights on terminals/ticker

Done when:
- Rugs only happen under defined conditions.
- Risk meters exist in trading UI.

---

## Milestone 8: Posting + Clout (Creator Studio)
Implement:
- Systems: Posts (`SYSTEMS_SPEC.md` §9, §12)
- World: Creator Studio station (`WORLD_SPEC.md` Station C)

Done when:
- Template posts grant clout and modest hype/meta influence with cooldowns.

---

## Milestone 9: Contracts (Recovery Loop)
Implement:
- Systems: Contracts (`SYSTEMS_SPEC.md` §10)
- World: Contract Board station (`WORLD_SPEC.md` Station D)

Done when:
- Busted player can recover cash via contracts.

---

## Milestone 10: Prop Firm Challenges
Implement:
- Systems: Challenges (`SYSTEMS_SPEC.md` §11)
- World: Prop Firm Office station (`WORLD_SPEC.md` Station E)

Done when:
- Always-playable bankroll mode works and rewards progression.

---

## Milestone 11: Progression + Stipend + Persistence
Implement:
- Systems: Progression + Save (`SYSTEMS_SPEC.md` §12–§13)

Done when:
- Rejoin restores tier/clout/cash/holdings.
- Unlocks appear correctly.

---

## Milestone 12: Monetization (Cosmetics Only)
Implement:
- Systems: Monetization hooks (`SYSTEMS_SPEC.md` §14)

Done when:
- Cosmetics store exists; no trade advantage or cash sales.
