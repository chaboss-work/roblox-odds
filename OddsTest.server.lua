--[[
	Test for the Odds module. Put Odds in ReplicatedStorage, this Script in ServerScriptService, press Play.
	Prints "[Odds test] N passed, 0 failed".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage:WaitForChild("Odds"))
local Chain, Weighted = Odds.Chain, Odds.Weighted

local passed, failed = 0, 0
local function check(name: string, condition: boolean, detail: any?)
	if condition then
		passed += 1
	else
		failed += 1
		warn("[Odds test] FAIL " .. name .. (if detail ~= nil then ": " .. tostring(detail) else ""))
	end
end

-- Chain: "1 in N"
local items = Chain.sorted({
	{ Id = "common", Chance = 2 },
	{ Id = "rare", Chance = 100 },
	{ Id = "epic", Chance = 5000 },
	{ Id = "mythic", Chance = 1000000 },
})
check("sorted rarest first", items[1].Id == "mythic" and items[4].Id == "common")
for _, luck in ipairs({ 1, 2, 10, 1e9 }) do
	local sum = 0
	for _, p in pairs(Chain.odds(items, luck)) do
		sum += p
	end
	check("chain odds add up to 100% at luck " .. luck, math.abs(sum - 1) < 1e-9, sum)
end
local base = Chain.odds(items, 1)
check("1 in 1,000,000 stays exactly that rare at x1", math.abs(base.mythic - 1e-6) < 1e-15)
check("x10 luck makes it 10x likelier", math.abs(Chain.odds(items, 10).mythic / base.mythic - 10) < 1e-6)
local rng = Random.new(1)
local counts = {}
for _ = 1, 100000 do
	local item = Chain.roll(items, 1, function()
		return rng:NextNumber()
	end)
	counts[item.Id] = (counts[item.Id] or 0) + 1
end
for id, p in pairs(base) do
	local expected = p * 100000
	if expected >= 100 then
		check("simulated " .. id .. " matches", math.abs((counts[id] or 0) - expected) <= 5 * math.sqrt(expected),
			tostring(counts[id]) .. " vs " .. expected)
	end
end
check("pity roll only gives items at least as rare", Chain.roll(items, 1, function()
	return 0.999
end, 5000).Chance >= 5000)
check("format 1 in 2.5M", Chain.formatChance(2500000) == "1 in 2.5M", Chain.formatChance(2500000))
check("format 1 in 2.7", Chain.formatProbability(1 / 2.7) == "1 in 2.7", Chain.formatProbability(1 / 2.7))

-- Weighted: eggs and chests
local list = { List = { { Id = "cat", Tier = 1 }, { Id = "fox", Tier = 3 }, { Id = "dragon", Tier = 4 } } }
local egg = { Odds = { cat = 90, fox = 9, dragon = 1 } }
local odds = Weighted.odds(egg, list, 1)
check("weights become percentages", math.abs(odds[1].Chance - 0.9) < 1e-12 and math.abs(odds[3].Chance - 0.01) < 1e-12)
local lucky = Weighted.odds(egg, list, 2)
local sum = 0
for _, item in ipairs(lucky) do
	sum += item.Chance
end
check("luck keeps the total at 100%", math.abs(sum - 1) < 1e-12)
check("luck x2 raises the dragon to 2/110", math.abs(lucky[3].Chance - 2 / 110) < 1e-12)
local wcounts = {}
for _ = 1, 100000 do
	local id = Weighted.roll(odds, function()
		return rng:NextNumber()
	end)
	wcounts[id] = (wcounts[id] or 0) + 1
end
for _, item in ipairs(odds) do
	local expected = item.Chance * 100000
	check("simulated " .. item.Id .. " matches", math.abs((wcounts[item.Id] or 0) - expected) <= 5 * math.sqrt(expected),
		tostring(wcounts[item.Id]) .. " vs " .. expected)
end
check("format 0.9%", Weighted.formatChance(0.009) == "0.9%", Weighted.formatChance(0.009))

print(string.format("[Odds test] %d passed, %d failed", passed, failed))
