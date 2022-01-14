local addonname, addontable = ...
_G.OriginsWishlist = LibStub("AceAddon-3.0"):NewAddon(addontable, addonname, "AceConsole-3.0", "AceComm-3.0", "AceSerializer-3.0");

-- db shortcut
local db

-- lua
local ipairs, pairs, tContains, tinsert = ipairs, pairs, tContains, tinsert

-- Initilize method
--
-- Load exported data in local database if they have been updated.
function OriginsWishlist:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("OriginsWishlistDB", {factionrealm = {updatedAt = nil, items = {}, players = {}}})
	db = self.db.factionrealm

	if db.updatedAt ~= nil and OriginsWishlistExport.updatedAt <= db.updatedAt then return end

	db.items = {}
	for playerName, data in pairs(OriginsWishlistExport.players) do
		db.players[playerName] = data

		for _, itemID in ipairs(data.whishlist.items) do
			if db.items[itemID] == nil then
				db.items[itemID] = {
					whishlist = {},
					needed = {},
					awarded = {}
				}
			end

			local itemStatus = "needed"
			if tContains(data.awarded.items, itemID) then
				itemStatus = "awarded"
			end
			
			tinsert(db.items[itemID][itemStatus], playerName)
			tinsert(db.items[itemID]["whishlist"], playerName)
		end
	end

	db.updatedAt = OriginsWishlistExport.updatedAt
end

-- Item Tooltip hook
local function addItemTooltip(tooltip)
	local _, itemLink = tooltip:GetItem()

	if itemLink then
		local itemID = tonumber(itemLink:match("item:(%d+):"))

		if db.items[itemID] ~= nil then

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

			local awarded = ""
			for _, playerName in ipairs(db.items[itemID].awarded) do
				if awarded ~= "" then
					awarded = awarded .. ", "
				end

				awarded = awarded .. "|cff" ..  db.players[playerName].classColor .. playerName .. "|r"
			end
			
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