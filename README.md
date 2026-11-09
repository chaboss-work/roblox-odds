# Odds: correct luck math for Roblox RNG games, eggs and loot

A small, dependency-free Luau module for the two kinds of randomness most Roblox games need. It also gives you the exact odds to show players.

- **`Odds.Chain`**: "1 in N" items such as auras, titles and rare drops. Luck works the way players expect.
- **`Odds.Weighted`**: weight tables such as eggs, chests and loot boxes. Weights become exact percentages, and luck boosts the rare tiers.

## The bug it avoids
A common way to add luck looks like this:
```lua
local roll = math.clamp(math.random() * luck, 0, 1)   -- then walk a cumulative table
```
With luck above 1, every roll that lands past 1 is clamped onto the last entry. "Impossible" items then drop far too often, and the real odds no longer match anything you show players. Questions about this come up on the DevForum again and again ("1 in 100000000000000000 value too often", "Luck multiplier doesn't increase rare drop rates").

`Odds.Chain` checks every item on its own, rarest first. An item wins with probability `luck / N`, capped at 100%:
- x2 luck doubles every rare chance;
- a "1 in 1,000,000" item stays exactly that rare at x1 luck, however many items you add;
- `Chain.odds` returns the exact final chance of each item, and the chances always add up to 100%.

## Use it
Put `Odds.lua` in `ReplicatedStorage` as a ModuleScript named `Odds`, or `rojo serve` this repo.

```lua
local Odds = require(game.ReplicatedStorage.Odds)

-- "1 in N" items (sort once, reuse)
local auras = Odds.Chain.sorted({
	{ Id = "dust", Chance = 2 },
	{ Id = "frost", Chance = 100 },
	{ Id = "nebula", Chance = 5000 },
	{ Id = "infinity", Chance = 50000000 },
})
local rng = Random.new()
local aura = Odds.Chain.roll(auras, 2, function() return rng:NextNumber() end)  -- x2 luck
local chances = Odds.Chain.odds(auras, 2)                -- { dust = ..., nebula = ... } exact
print(Odds.Chain.formatProbability(chances.nebula))      -- "1 in 2,500"
-- pity: only items of "1 in 1,000" or rarer can win this roll
local pityAura = Odds.Chain.roll(auras, 1, function() return rng:NextNumber() end, 1000)

-- Weighted tables (eggs, chests): Tier 1 = most common, luck boosts Tier > 1
local pets = { List = { { Id = "cat", Tier = 1 }, { Id = "fox", Tier = 3 }, { Id = "dragon", Tier = 4 } } }
local egg = { Odds = { cat = 90, fox = 9, dragon = 1 } }
local odds = Odds.Weighted.odds(egg, pets, 1)             -- { { Id = "cat", Chance = 0.9 }, ... }
local petId = Odds.Weighted.roll(odds, function() return rng:NextNumber() end)
print(Odds.Weighted.formatChance(odds[3].Chance))         -- "1%"
```

Roblox requires experiences to show the odds when Robux buys a chance at random items. Show the numbers from `odds`: they are the exact numbers the roll uses.

## Test
`OddsTest.server.lua` checks these in Studio:
- the odds add up to 100%;
- luck scales the chances correctly;
- 100,000 simulated rolls of each kind match the odds;
- pity rolls give only items that are rare enough;
- the formatting is right.

Put it in ServerScriptService and press Play.

## Full systems
This module is the roll math from two complete kits, which add UI, saving, anti-exploit checks and tests:
- [RNG Aura Roll Kit](https://chaboss-work.itch.io/rng-aura-roll-kit-luau): 30 auras, bonus rolls, pity, auto roll, index, odds list, saving. A [free 5-aura sampler](https://chaboss-work.itch.io/rng-aura-sampler-luau) is available too.
- [Pet System Kit](https://chaboss-work.itch.io/pet-system-kit-luau): eggs, smooth following pets drawn on each device, odds above eggs, golden pets, saving.
- [Roblox Kits Bundle](https://chaboss-work.itch.io/roblox-kits-bundle-luau): those two plus combat, anti-exploit, inventory saving and a simulator starter.

## License
MIT. Use it anywhere, including paid games.
