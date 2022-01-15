local addonname, addontable = ...
_G.OriginsWishlist = LibStub("AceAddon-3.0"):NewAddon(addontable, addonname, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceHook-3.0");

local RCLootCouncil = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil_Classic")
local LD = LibStub("LibDeflate")

-- db shortcut
local db

-- lua
local ipairs, pairs, select, tContains, time, tinsert, tremove = ipairs, pairs, select, tContains, time, tinsert, tremove

-- Initilize method
--
-- Load exported data in local database if they have been updated.
function OriginsWishlist:OnInitialize()
	self.name = addonname
	self.version = GetAddOnMetadata("OriginsWishlist", "Version")
	self.debug = false

	self.db = LibStub("AceDB-3.0"):New("OriginsWishlistDB", {factionrealm = {updatedAt = nil, items = {}, players = {}}})
	db = self.db.factionrealm

	
	-- if local database was updated more recently than the export, skip importation.
	if db.updatedAt ~= nil and OriginsWishlistExport.updatedAt <= db.updatedAt then return end

	-- if local awared items was updated more recently than last awarded item in export, keep local awarded items list.
	self:Debug("OnInitialize:LoadExport", db.updatedAt, OriginsWishlistExport.updatedAt, OriginsWishlistExport.lastAwardedAt)
	if db.lastAwardedAt ~= nil and OriginsWishlistExport.lastAwardedAt <= db.lastAwardedAt then
		for _, playerData in pairs(OriginsWishlistExport.players) do
			playerData.awarded = db.players[playerName].awarded
		end
	end

	-- Prepare whishlist per item.
	db.items = {}
	for playerName, playerData in pairs(OriginsWishlistExport.players) do
		db.players[playerName] = playerData

		for _, itemID in ipairs(playerData.whishlist.items) do
			if itemID > 0 then
				self:Debug("OnInitialize:AddItem", playerName, itemID)
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

	-- Set local database updated dates.
	db.updatedAt = OriginsWishlistExport.updatedAt
	db.lastAwardedAt = OriginsWishlistExport.lastAwardedAt
end

function OriginsWishlist:OnEnable()
	self:RegisterComm("RCLootCouncil")

	self:RegisterMessage("RCMLLootHistorySend", "OnMessageReceived")
	self:RegisterMessage("RCMLAwardSuccess", "OnMessageReceived")
	self:RegisterMessage("RCMLAwardFailed", "OnMessageReceived")

	self:RegisterChatCommand("whishlist", "ChatCommand")

	self:HookScript(GameTooltip, "OnTooltipSetItem", "addItemTooltip")
	self:HookScript(ItemRefTooltip, "OnTooltipSetItem", "addItemTooltip")
	self:HookScript(GameTooltip, "OnTooltipSetUnit", "addPlayerTooltip")
end

function OriginsWishlist:OnDisable()
	self:UnregisterChatCommand("whishlist")
	self:UnregisterAllComm()
	self:UnregisterAllEvents()
end

local function decompressor(data)
	local decoded = LD:DecodeForWoWAddonChannel(data)
	if not decoded then return data end -- Assume it's a pre 0.10 message.
	local serializedMsg = LD:DecompressDeflate(decoded)
	return serializedMsg or ""
end

function OriginsWishlist:OnCommReceived(prefix, compressedMessage, distri, sender)
	if prefix ~= "RCLootCouncil" then return end

	local test, command, data = RCLootCouncil:Deserialize(decompressor(compressedMessage))
	if RCLootCouncil:HandleXRealmComms(self, command, data, sender) then return end

	self:Debug("Comm received:", command, "from:", sender, "distri:", distri, "test:", test)
	for key, value in pairs(data) do
		self:Debug(key, value)
	end
end

function OriginsWishlist:OnMessageReceived(msg, session, winner, status)
	self:Debug("OnMessageReceived", msg, session, winner, status)
	if msg ~= "RCMLAwardSuccess" then return end

	local lootTable = RCLootCouncil:GetLootTable()

	if lootTable[session] == nil or lootTable[session].link == nil or winner == nil then return end
	local itemID = tonumber(select(3, strfind(lootTable[session].link, "item:(%d+)")))
	local playerName = select(1, strsplit("-", winner, 2))

	self:Debug("OnRCLCEMessageReceived:AddItem", playerName, itemID, lootTable[session].link)
	if db.players[playerName] == nil then return end
	if not tContains(db.players[playerName].whishlist.items, itemID) then return end
	if tContains(db.players[playerName].awarded.items, itemID) then return end

	-- Add item to player awared list.
	tinsert(db.players[playerName].awarded.items, itemID)
	db.players[playerName].awarded.count = db.players[playerName].awarded.count + 1
	db.players[playerName].awarded.lastAt = time()

	-- Add player to item awared list.
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
	
	-- Set database update times.
	db.updatedAt = db.players[playerName].awarded.lastAt
	db.lastAwardedAt = db.players[playerName].awarded.lastAt
end

-- Item Tooltip hook
function OriginsWishlist:addItemTooltip(tooltip)
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
		if db.players[playerName].awarded.lastAt ~= nil then
			needed = needed .. ", " .. date("%d %b.", db.players[playerName].awarded.lastAt)
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


-- Player Tooltip hook
function OriginsWishlist:addPlayerTooltip(tooltip)
	local playerName, _ = tooltip:GetUnit()

	if db.players[playerName] ~= nil then
		tooltip:AddLine("\nOrïgins Wishlist (".. db.players[playerName].awarded.count .. "/" .. db.players[playerName].whishlist.count .. ")", nil, nil, nil, false)

		if db.players[playerName].awarded.lastAt ~= "" then
			tooltip:AddLine("Dernier loot le " .. db.players[playerName].awarded.lastAt, nil, nil, nil, false)
		end
	end
end

-- Handle chat commands
function OriginsWishlist:ChatCommand(msg)
	local input = self:GetArgs(msg, 1)
	local args = {}
	local arg
	local startpos = input and #input + 1 or 0
	repeat
	    arg, startpos = self:GetArgs(msg, 1, startpos)
	    if arg then
	         table.insert(args, arg)
	    end
	until arg == nil
	input = strlower(input or "")

	self:Debug("/", input, unpack(args))

	if input == 'debug' or input == 'd' then
		self.debug = not self.debug
		self:Print("Debug:", tostring(self.debug))
		return
	end

	if input == 'version' or input == "v" then
		self:Print(self.name, self.version)
		self:Print("Database update:", db.updatedAt)
		return
	end
end

-- Display dubug message
function OriginsWishlist:Debug(msg, ...)
	if not self.debug then return end

	if select("#", ...) > 0 then
		self:Print("|cffcb6700debug:|r "..tostring(msg).."|cffff6767", ...)
	else
		self:Print("|cffcb6700debug:|r "..tostring(msg).."|r")
	end
end