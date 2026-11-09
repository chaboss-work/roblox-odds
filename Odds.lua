--[[
	Odds: correct luck math and exact odds for Roblox RNG games, eggs and loot tables.
	MIT License, Chaboss Dev Kits. https://github.com/chaboss-work/roblox-odds

	Odds.Chain     "1 in N" items (auras, titles, rare drops). Every item is checked on its own, rarest
	               first: it wins with probability luck / N. x2 luck doubles every rare chance, and a
	               "1 in 1,000,000" item stays exactly that rare at x1, however many items you add.
	               Avoids the classic bug where `random * luck` is clamped and "impossible" items drop too often.

	Odds.Weighted  weight tables (eggs, chests): weights become exact percentages; luck multiplies the
	               weight of everything rarer than the most common tier.

	Both have an `odds` function that returns the exact final chance of every item. Show those numbers to
	players: they are the numbers the roll uses (Roblox requires showing odds when Robux buys a chance).
]]

local Chain = {}
local Weighted = {}


export type Item = { Id: string, Name: string, Chance: number, [string]: any }

-- Copy of the list, rarest first (ties keep list order).
function Chain.sorted(list: { Item }): { Item }
	local copy = table.clone(list)
	local order = {}
	for i, item in ipairs(list) do
		order[item] = i
	end
	table.sort(copy, function(a, b)
		if a.Chance ~= b.Chance then
			return a.Chance > b.Chance
		end
		return order[a] < order[b]
	end)
	return copy
end

function Chain.chanceOf(item: Item, luck: number): number
	return math.clamp(luck / item.Chance, 0, 1)
end

-- sorted: from Chain.sorted. random: function returning a number in [0, 1).
-- minChance (optional): only items at least this rare can be the result (used for pity rolls).
function Chain.roll(sorted: { Item }, luck: number, random: () -> number, minChance: number?): Item
	local floor = minChance or 1
	local fallback = nil
	for _, item in ipairs(sorted) do
		if item.Chance >= floor then
			if random() < Chain.chanceOf(item, luck) then
				return item
			end
			fallback = item
		end
	end
	return fallback or sorted[#sorted]
end

-- Exact probability of each item: { [id] = probability }, adds up to 1.
function Chain.odds(sorted: { Item }, luck: number, minChance: number?): { [string]: number }
	local floor = minChance or 1
	local result = {}
	local remaining = 1
	local last = nil
	for _, item in ipairs(sorted) do
		if item.Chance >= floor then
			local p = Chain.chanceOf(item, luck)
			result[item.Id] = (result[item.Id] or 0) + remaining * p
			remaining *= 1 - p
			last = item
		end
	end
	last = last or sorted[#sorted]
	if last then
		result[last.Id] = (result[last.Id] or 0) + remaining
	end
	return result
end

-- Luck from several sources. "multiply": x2 and x3 make x6. "add": +100% and +200% make x4.
function Chain.combineLuck(multipliers: { number }, mode: string?): number
	local total = 1
	for _, m in ipairs(multipliers) do
		if mode == "add" then
			total += m - 1
		else
			total *= m
		end
	end
	return math.max(total, 0)
end

-- rollNumber counts from 1. every = 10 makes rolls 10, 20, 30... bonus rolls.
function Chain.isBonusRoll(rollNumber: number, every: number?): boolean
	return every ~= nil and every > 0 and rollNumber % every == 0
end

-- count = rolls since the last item at least as rare as the pity target.
function Chain.pityDue(count: number, pityRolls: number?): boolean
	return pityRolls ~= nil and pityRolls > 0 and count + 1 >= pityRolls
end

function Chain.tierOf(tiers: { any }, chance: number)
	for _, tier in ipairs(tiers) do
		if chance >= tier.MinChance then
			return tier
		end
	end
	return tiers[#tiers]
end

local function commas(n: number): string
	local digits = tostring(math.floor(n + 0.5))
	local grouped = (digits:reverse():gsub("(%d%d%d)", "%1,")):reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	return grouped
end

local UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

-- 1500 -> "1,500", 350000 -> "350K", 2500000 -> "2.5M"
function Chain.short(n: number): string
	if n < 100000 then
		return commas(n)
	end
	for _, unit in ipairs(UNITS) do
		if n >= unit[1] then
			local value = n / unit[1]
			local text
			if value >= 100 then
				text = tostring(math.floor(value + 0.5))
			else
				text = (string.format("%.1f", value):gsub("%.0$", ""))
			end
			return text .. unit[2]
		end
	end
	return commas(n)
end

function Chain.formatChance(chance: number): string
	return "1 in " .. Chain.short(chance)
end

-- 0.5 -> "1 in 2", 0.37 -> "1 in 2.7", 1 -> "Guaranteed"
function Chain.formatProbability(p: number): string
	if p >= 1 then
		return "Guaranteed"
	end
	if p <= 0 then
		return "Never"
	end
	local x = 1 / p
	if x < 10 then
		return "1 in " .. (string.format("%.1f", x):gsub("%.0$", ""))
	end
	return "1 in " .. Chain.short(x)
end


-- Exact chance of every entry of a weighted table: { { Id, Weight, Chance } } in list order.
-- egg = { Odds = { [id] = weight } }; pets = { List = { { Id = "cat", Tier = 1 }, ... } } (Tier 1 = most common).
-- Luck multiplies the weight of every entry with Tier > 1; the chances still add up to 1.
function Weighted.odds(egg, pets, luck: number?)
	local multiplier = math.max(luck or 1, 0)
	local list, total = {}, 0
	for _, pet in ipairs(pets.List) do
		local weight = egg.Odds[pet.Id]
		if type(weight) == "number" and weight > 0 and weight == weight and weight ~= math.huge then
			if pet.Tier > 1 then
				weight *= multiplier
			end
			table.insert(list, { Id = pet.Id, Weight = weight, Chance = 0 })
			total += weight
		end
	end
	for _, item in ipairs(list) do
		item.Chance = if total > 0 then item.Weight / total else 0
	end
	return list
end

-- random: function returning a number in [0, 1).
function Weighted.roll(oddsList, random: () -> number): string?
	local r = random()
	local acc = 0
	for _, item in ipairs(oddsList) do
		acc += item.Chance
		if r < acc then
			return item.Id
		end
	end
	local last = oddsList[#oddsList]
	return last and last.Id
end

-- "45%", "0.9%", "0.01%"
function Weighted.formatChance(chance: number): string
	local percent = chance * 100
	local text
	if percent >= 10 then
		text = string.format("%.0f", percent)
	elseif percent >= 1 then
		text = string.format("%.1f", percent)
	elseif percent >= 0.01 then
		text = string.format("%.2f", percent)
	else
		text = string.format("%.4f", percent)
	end
	text = text:gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")
	return text .. "%"
end


return {
	Chain = Chain,
	Weighted = Weighted,
}
