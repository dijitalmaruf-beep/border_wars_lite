# Border Wars Lite Game Design

## Premise

Border Wars Lite is a compact territory conquest game inspired by classic map-control strategy. The MVP uses a committed, simplified world-map dataset so the first version feels like a global conquest game without parsing a huge GeoJSON file at runtime.

## Players

- 1 human player with chosen name and color.
- 3 bot players:
  - Atlas Bot: aggressive, attacks at 45% or better.
  - Nova Bot: opportunistic, attacks at 60% or better.
  - Terra Bot: defensive, attacks at 75% or better.

## Map

The MVP map has 48 larger real-world-style territories. Each territory has:

- Stable id.
- Display name.
- Normalized label anchor position.
- Owner id or neutral owner.
- Army count.
- Neighbor territory ids.
- Continent/group name.
- Simplified polygon boundary points.

## Turn Loop

Each turn starts in `reinforce`, moves to `attack`, then ends.

Reinforcements are:

```text
max(3, floor(ownedTerritories / 3))
```

The human applies all reinforcements by selecting an owned territory. Bots reinforce the border territory with the highest enemy pressure.

## Combat

Attack eligibility:

- Source belongs to the current player.
- Source has more than 1 army.
- Target is a neighbor.
- Target is not owned by the current player.

Win chance:

```text
attackerPower = source.armyCount - 1
defenderPower = target.armyCount * 1.15
winChance = attackerPower / (attackerPower + defenderPower)
```

On victory, the target changes owner and receives a clamped minimum of 1 moved army so conquered territories remain usable. On defeat, source and target army losses are bounded so counts never become negative and the source never drops below 1.

## Victory

A player wins by:

- Owning at least 70% of all territories.
- Being the only non-neutral player with territories left.

## Architecture

Game rules live under `lib/game/engine` and models under `lib/game/models`. Widgets call the engine and render returned immutable state. Firebase service classes are present under `lib/services/firebase`, but the app does not depend on Firebase at startup.
