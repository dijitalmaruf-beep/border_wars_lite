# Chroma Conquest Game Design

## Premise

Chroma Conquest is a compact territory conquest game inspired by classic map-control strategy. The MVP uses a committed, simplified world-map dataset so the first version feels like a global conquest game without parsing a huge GeoJSON file at runtime.

Official English slogan:

```text
One Color. One World.
Until the last color stands.
```

Official Turkish slogan:

```text
Tek Renk. Tüm Dünya.
Son renk kalana kadar.
```

## Players

- 1 human player with chosen name and color.
- Selectable bot count in local play.
- Bot personalities:
  - Atlas Bot: aggressive, attacks at 45% or better.
  - Nova Bot: opportunistic, attacks at 60% or better.
  - Terra Bot: defensive, attacks at 75% or better.

## Map

The MVP map has 47 larger real-world-style territories. Each territory has:

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
base = max(3, floor(ownedTerritories / 3))
total = base + controlledContinentBonuses
```

Strategic region bonuses use each territory's `continent` field:

- North America: +5
- South America: +3
- Europe: +5
- Africa: +4
- Asia: +7
- Oceania: +2

All playable territories are assigned to one of those six groups in `world_territories.dart`. A player receives a group's bonus only while they own every playable territory in that group.

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

On victory, the target changes owner and the player chooses how many available armies advance. On defeat, source and target army losses are bounded so counts never become negative and the source never drops below 1.

## Victory

Match modes:

- Quick Match: win by controlling 40% of territories.
- Standard Match: win by controlling 70% of territories.
- Total Conquest: win by eliminating all opponents or controlling all territories.

## Architecture

Game rules live under `lib/game/engine` and models under `lib/game/models`. Widgets call the engine and render returned immutable state. Firebase service classes are present under `lib/services/firebase`, but the app does not depend on Firebase at startup.
