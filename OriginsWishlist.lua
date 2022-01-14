local addonname, addontable = ...
_G.OriginsWishlist = LibStub("AceAddon-3.0"):NewAddon(addontable, addonname, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0");

-- db shortcut
local db

-- lua
local ipairs, pairs, select, tContains, tinsert, tremove = ipairs, pairs, select, tContains, tinsert, tremove

-- Initilize method
--
-- Load exported data in local database if they have been updated.
function OriginsWishlist:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("OriginsWishlistDB", {factionrealm = {updatedAt = nil, items = {}, players = {}}})
	db = self.db.factionrealm

	if db.updatedAt ~= nil and OriginsWishlistExport.updatedAt <= db.updatedAt then return end

	db.items = {}
	for playerName, playerData in pairs(OriginsWishlistExport.players) do
		db.players[playerName] = playerData

		for _, itemID in ipairs(playerData.whishlist.items) do
			if itemID > 0 then
				if db.items[itemID] == nil then
					db.items[itemID] = {
						whishlist = {},
						needed = {},
						awarded = {}
					}
				end

				local itemStatus = "needed"
				if tContains(playerData.awarded.items, itemID) then
					itemStatus = "awarded"
				end

				tinsert(db.items[itemID][itemStatus], playerName)
				tinsert(db.items[itemID]["whishlist"], playerName)
			end
		end
	end

	db.updatedAt = OriginsWishlistExport.updatedAt
end

function OriginsWishlist:OnEnable()
	self:RegisterMessage("RCMLAwardSuccess", "OnRCLCEMessageReceived")
end

function OriginsWishlist:OnRCLCEMessageReceived(msg, session, winner, status)
	if msg ~= "RCMLAwardSuccess" then return end

	local lootTable = RCLootCouncil:GetLootTable()
	local itemID = tonumber(select(3, strfind(lootTable[session].link, "item:(%d+)")))
	local playerName = select(1, strsplit("-", winner, 2))
	
	if db.players[playerName] == nil then return end
	if not tContains(db.players[playerName].whishlist.items, itemID) then return end
	if tContains(db.players[playerName].awarded.items, itemID) then return end

	-- Add item to player awared list
	tinsert(db.players[playerName].awarded.items, itemID)
	db.players[playerName].awarded.count = db.players[playerName].awarded.count + 1
	db.players[playerName].awarded.lastAt = date("%d %b.")

	-- Add player to item awared list
	if db.items[itemID] == nil then
		db.items[itemID] = {
			whishlist = {},
			needed = {},
			awarded = {}
		}
	end

	tinsert(db.items[itemID].awarded, playerName)
	for index, value in ipairs(db.items[itemID].needed) do
		if value == playerName then tremove(db.items[itemID].needed, index) end
	end
end

-- Item Tooltip hook
local function addItemTooltip(tooltip)
	local _, itemLink = tooltip:GetItem()
	if not itemLink then return end

	local itemID = tonumber(itemLink:match("item:(%d+):"))
	if db.items[itemID] == nil then return end

	-- Prepare needed line
	local needed = ""
	for _, playerName in ipairs(db.items[itemID].needed) do
		if needed ~= "" then
			needed = needed .. ", "
		end

		needed = needed .. "|cff" ..  db.players[playerName].classColor .. playerName .. "|r (".. db.players[playerName].awarded.count .. "/" .. db.players[playerName].whishlist.count
		if db.players[playerName].awarded.lastAt ~= nil and db.players[playerName].awarded.lastAt ~= "" then
			needed = needed .. ", " .. db.players[playerName].awarded.lastAt
		end
		needed = needed .. ")"
	end

	-- Prepare awarded line
	local awarded = ""
	for _, playerName in ipairs(db.items[itemID].awarded) do
		if awarded ~= "" then
			awarded = awarded .. ", "
		end

		awarded = awarded .. "|cff" ..  db.players[playerName].classColor .. playerName .. "|r"
	end

	-- Display info on tooltip
	if (needed ~= "" or awarded ~= "") then
		tooltip:AddLine("\n")
		tooltip:AddLine("Orïgins Wishlist (" .. #db.items[itemID].awarded .. "/" .. #db.items[itemID].whishlist .. ")", nil, nil, nil, false)
	end
	if (needed ~= "") then
		tooltip:AddLine("Besoin : " .. needed, nil, nil, nil, true)
	end
	if (awarded ~= "") then
		tooltip:AddLine("Reçus : " .. awarded, nil, nil, nil, true)
	end
end

GameTooltip:HookScript("OnTooltipSetItem", addItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", addItemTooltip)

-- Player Tooltip hook
local function addPlayerTooltip(tooltip)
	local playerName, _ = tooltip:GetUnit()

	if db.players[playerName] ~= nil then
		tooltip:AddLine("\nOrïgins Wishlist (".. db.players[playerName].awarded.count .. "/" .. db.players[playerName].whishlist.count .. ")", nil, nil, nil, false)

		if db.players[playerName].awarded.lastAt ~= "" then
			tooltip:AddLine("Dernier loot le " .. db.players[playerName].awarded.lastAt, nil, nil, nil, false)
		end
	end
end

GameTooltip:HookScript("OnTooltipSetUnit", addPlayerTooltip)