local addonname, addontable = ...
_G.OriginsWishlist = LibStub("AceAddon-3.0"):NewAddon(addontable, addonname, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceHook-3.0");

local LD = LibStub("LibDeflate")

local RCLootCouncil = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil_Classic")

-- db shortcut
local db

-- lua
local ipairs, pairs, select, tContains, time, tinsert, tremove, unpack = ipairs, pairs, select, tContains, time, tinsert, tremove, unpack

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

function OriginsWishlist:OnEnable()
	self:RegisterComm("RCLootCouncil")

	self:RegisterMessage("RCMLLootHistorySend", "OnMessageReceived")
	self:RegisterMessage("RCMLAwardSuccess", "OnMessageReceived")
	self:RegisterMessage("RCMLAwardFailed", "OnMessageReceived")

	self:RegisterChatCommand("wishlist", "ChatCommand")

	self:HookScript(GameTooltip, "OnTooltipSetItem", "addItemTooltip")
	self:HookScript(ItemRefTooltip, "OnTooltipSetItem", "addItemTooltip")
	self:HookScript(GameTooltip, "OnTooltipSetUnit", "addPlayerTooltip")
end

function OriginsWishlist:OnDisable()
	self:UnregisterChatCommand("wishlist")
	self:UnregisterAllComm()
	self:UnregisterAllEvents()
	self:UnhookAll()
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
	if command == "history" then
		for key, value in pairs(data[2]) do
			self:Debug(key, value)
		end
	end

	if command == "awarded" then
		self:AwardItem(data[1], data[2])
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

function OriginsWishlist:loadExport(resetAwarded)
	resetAwarded = resetAwarded or false

	self:Debug("OnInitialize:LoadExport", db.updatedAt, OriginsWishlistExport.updatedAt, OriginsWishlistExport.lastAwardedAt)

	-- Prepare whishlist per item.
	db.currentPhase = OriginsWishlistExport.currentPhase
	db.nextPhase = OriginsWishlistExport.nextPhase
	db.items = {}
	for _, playerData in pairs(OriginsWishlistExport.players) do
		local playerName = RCLootCouncil:UnitName(playerData.name)

		if db.players[playerName] == nil then
			db.players[playerName] =  {
				name = playerData.name,
				classColor = playerData.classColor,
			}
		end

		-- if local awared items was updated more recently than last awarded item in export, keep local awarded items list.
		local awarded = nil
		if db.players[playerName].awarded ~= nil and db.players[playerName].awarded.items ~= nil then
			awarded = {unpack(db.players[playerName].awarded.items)}
		end
		if resetAwarded or awarded == nil or db.lastAwardedAt == nil or OriginsWishlistExport.lastAwardedAt >= db.lastAwardedAt then
			awarded = {unpack(playerData.awarded.items)}
		end
		db.players[playerName]["whishlist"] = { items = {}, nextPhase = {}, count = playerData.whishlist[db.currentPhase].count }
		db.players[playerName]["needed"] = { items = {}, count = 0 }
		db.players[playerName]["awarded"] = { items = {}, count = 0, lastAt = playerData.awarded.lastAt }

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
			if awarded ~= nil and tContains(awarded, itemID) then
				itemStatus = "awarded"

				for index, value in ipairs(awarded) do
					if value == itemID then tremove(awarded, index); break end
				end
			end

			tinsert(db.items[itemID]["whishlist"].players, playerData.name)
			db.items[itemID]["whishlist"].count = db.items[itemID]["whishlist"].count + 1

			tinsert(db.items[itemID][itemStatus].players, playerData.name)
			db.items[itemID][itemStatus].count = db.items[itemID][itemStatus].count + 1

			tinsert(db.players[playerName]["whishlist"].items, itemID)
			tinsert(db.players[playerName][itemStatus].items, itemID)

			if tContains(playerData.whishlist[db.nextPhase].items, itemID) then
				tinsert(db.players[playerName]["whishlist"].nextPhase, itemID)
			end
		end

		db.players[playerName].whishlist.count = playerData.whishlist[db.currentPhase].count
		db.players[playerName].needed.count = playerData.whishlist[db.currentPhase].count - playerData.awarded.count
		db.players[playerName].awarded.count = playerData.awarded.count
	end

	-- Set local database updated dates.
	db.updatedAt = OriginsWishlistExport.updatedAt
	db.lastAwardedAt = OriginsWishlistExport.lastAwardedAt
end

function OriginsWishlist:AwardItem(session, winner)
	local lootTable = RCLootCouncil:GetLootTable()

	if lootTable[session] == nil or lootTable[session].link == nil or winner == nil then return end
	local itemID = tonumber(select(3, strfind(lootTable[session].link, "item:(%d+)")))
	local playerName = RCLootCouncil:UnitName(winner)

	self:Debug("OriginsWishlist:AwardItem", playerName, itemID, lootTable[session].link)
	if db.players[playerName] == nil then return end
	if not tContains(db.players[playerName].whishlist.items, itemID) then return end
	if tContains(db.players[playerName].awarded.items, itemID) then return end

	-- Add item to player awared list.
	tinsert(db.players[playerName].awarded.items, itemID)
	db.players[playerName].awarded.count = db.players[playerName].awarded.count + 1
	db.players[playerName].awarded.lastAt = time()

	for index, value in ipairs(db.players[playerName].needed.items) do
		if value == itemID then tremove(db.players[playerName].needed.items, index); break end
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

	tinsert(db.items[itemID].awarded.players, db.players[playerName].name)
	db.items[itemID].awarded.count = db.items[itemID].awarded.count + 1

	for index, value in ipairs(db.items[itemID].needed.players) do
		if RCLootCouncil:UnitName(value) == playerName then tremove(db.items[itemID].needed.players, index); break end
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
	for _, name in ipairs(db.items[itemID].needed.players) do
		local playerName = RCLootCouncil:UnitName(name)

		if needed ~= "" then
			needed = needed .. ", "
		end

		needed = needed .. "|cff" ..  db.players[playerName].classColor .. name .. "|r ("

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
	for _, name in ipairs(db.items[itemID].awarded.players) do
		local playerName = RCLootCouncil:UnitName(name)

		if awarded ~= "" then
			awarded = awarded .. ", "
		end

		awarded = awarded .. "|cff" ..  db.players[playerName].classColor .. name .. "|r"
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
	playerName = RCLootCouncil:UnitName(playerName)

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

	if input == 'reload' then
		OriginsWishlist:loadExport(false)
		return
	end

	if input == 'reset' or input == 'full-reset' then
		db.items = {}
		db.players = {}
		db.updatedAt = nil
		db.lastAwardedAt = nil
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
		self:Print("Last awarded:", db.lastAwardedAt)
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