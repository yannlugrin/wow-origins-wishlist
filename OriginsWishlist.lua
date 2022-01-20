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

	-- if expport database was updated recently load it.
	if db.updatedAt == nil or OriginsWishlistExport.updatedAt >= db.updatedAt then
		OriginsWishlist:loadExport()
	end

	db.version = self.version
end

function OriginsWishlist:loadExport(resetAwarded)
	resetAwarded = resetAwarded or false

	self:Debug("OnInitialize:LoadExport", db.updatedAt, OriginsWishlistExport.updatedAt, OriginsWishlistExport.lastAwardedAt)

	-- Prepare whishlist per item.
	db.currentPhase = OriginsWishlistExport.currentPhase
	db.nextPhase = OriginsWishlistExport.nextPhase
	db.items = {}
	for playerName, playerData in pairs(OriginsWishlistExport.players) do
		if db.players[playerName] == nil then
			db.players[playerName] =  {
				name = playerData.name,
				classColor = playerData.classColor,
			}
		end

		-- Ensure to set awarded items for data comming from version previous to 0.3.3
		if db.players[playerName]["awarded"] ~= nil and db.players[playerName]["awarded"].items == nil then
			db.players[playerName]["awarded"] = nil
		end

		-- if local awared items was updated more recently than last awarded item in export, keep local awarded items list.
		if resetAwarded or db.players[playerName]["awarded"] == nil or db.lastAwardedAt == nil or OriginsWishlistExport.lastAwardedAt >= db.lastAwardedAt then
			db.players[playerName]["awarded"] = { items = {}, count = 0, lastAt = playerData.awarded.lastAt }
		end
		db.players[playerName]["whishlist"] = { items = {}, nextPhase = {}, count = playerData.whishlist[db.currentPhase].count }
		db.players[playerName]["needed"] = { items = {}, count = 0 }
		db.players[playerName]["awarded"]["count"] = 0

		-- Populate items lists.
		for _, itemID in ipairs(playerData.whishlist[db.currentPhase].items) do
			self:Debug("OnInitialize:AddItem", playerName, itemID)

			if db.items[itemID] == nil then
				db.items[itemID] = {
					whishlist = { players = {}, count = 0 },
					needed = { players = {}, count = 0 },
					awarded = { players = {}, count = 0 }
				}
			end

			local itemStatus = "needed"
			if tContains(db.players[playerName].awarded.items, itemID) or tContains(playerData.awarded.items, itemID) then
				itemStatus = "awarded"
			end

			tinsert(db.items[itemID]["whishlist"].players, playerName)
			db.items[itemID]["whishlist"].count = db.items[itemID]["whishlist"].count + 1

			tinsert(db.items[itemID][itemStatus].players, playerName)
			db.items[itemID][itemStatus].count = db.items[itemID][itemStatus].count + 1

			tinsert(db.players[playerName]["whishlist"].items, itemID)

			if tContains(playerData.whishlist[db.nextPhase].items, itemID) then
				tinsert(db.players[playerName]["whishlist"].nextPhase, itemID)
			end

			if not tContains(db.players[playerName][itemStatus].items, itemID) then
				tinsert(db.players[playerName][itemStatus].items, itemID)
			end
			db.players[playerName][itemStatus].count = db.players[playerName][itemStatus].count + 1
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

	if command == "awarded" then
		self:AwardItem(data[1], distri)
		return
	end
end

function OriginsWishlist:OnMessageReceived(msg, session, winner, status)
	self:Debug("OnMessageReceived", msg, session, winner, status)

	if msg == "RCMLAwardSuccess" then
		self:AwardItem(session, winner)
		return
	end
end

function OriginsWishlist:AwardItem(session, winner)
	local lootTable = RCLootCouncil:GetLootTable()

	if lootTable[session] == nil or lootTable[session].link == nil or winner == nil then return end
	local itemID = tonumber(select(3, strfind(lootTable[session].link, "item:(%d+)")))
	local playerName = select(1, strsplit("-", winner, 2))

	self:Debug("OriginsWishlist:AwardItem", playerName, itemID, lootTable[session].link)
	if db.players[playerName] == nil then return end
	if not tContains(db.players[playerName].whishlist.items, itemID) then return end
	if tContains(db.players[playerName].awarded.items, itemID) then return end

	-- Add item to player awared list.
	tinsert(db.players[playerName].awarded.items, itemID)
	db.players[playerName].awarded.count = db.players[playerName].awarded.count + 1
	db.players[playerName].awarded.lastAt = time()

	for index, value in ipairs(db.players[playerName].needed.items) do
		if value == itemID then tremove(db.players[playerName].needed.items, index) end
	end
	db.players[playerName].needed.count = db.players[playerName].needed.count - 1

	-- Add player to item awared list.
	if db.items[itemID] == nil then
		db.items[itemID] = {
			whishlist = { players = {}, count = 0 },
			needed = { players = {}, count = 0 },
			awarded = { players = {}, count = 0 }
		}
	end

	tinsert(db.items[itemID].awarded.players, playerName)
	db.items[itemID].awarded.count = db.items[itemID].awarded.count + 1

	for index, value in ipairs(db.items[itemID].needed.players) do
		if value == playerName then tremove(db.items[itemID].needed.players, index) end
	end
	db.items[itemID].needed.count = db.items[itemID].needed.count - 1

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
	for _, playerName in ipairs(db.items[itemID].needed.players) do
		if needed ~= "" then
			needed = needed .. ", "
		end

		needed = needed .. "|cff" ..  db.players[playerName].classColor .. playerName .. "|r ("

		if tContains(db.players[playerName]["whishlist"].nextPhase, itemID) then
			needed = needed .. db.nextPhase .. ", "
		end

		needed = needed .. db.players[playerName].awarded.count .. "/" .. db.players[playerName].whishlist.count

		if db.players[playerName].awarded.lastAt ~= nil then
			needed = needed .. ", " .. date("%d %b.", db.players[playerName].awarded.lastAt)
		end

		needed = needed .. ")"
	end

	-- Prepare awarded line
	local awarded = ""
	for _, playerName in ipairs(db.items[itemID].awarded.players) do
		if awarded ~= "" then
			awarded = awarded .. ", "
		end

		awarded = awarded .. "|cff" ..  db.players[playerName].classColor .. playerName .. "|r"
	end

	-- Display info on tooltip
	if (needed ~= "" or awarded ~= "") then
		tooltip:AddLine("\n")
		tooltip:AddLine("Orïgins Wishlist (" .. db.items[itemID].awarded.count .. "/" .. db.items[itemID].whishlist.count .. ")", nil, nil, nil, false)
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

		if db.players[playerName].awarded.lastAt ~= nil then
			tooltip:AddLine("Dernier loot le " .. date("%d %b.", db.players[playerName].awarded.lastAt), nil, nil, nil, false)
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

	if input == 'reset' then
		OriginsWishlist:loadExport(true)
		return
	end

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