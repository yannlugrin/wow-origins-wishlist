local _, addon = ...
local VotingFrame = addon:NewModule("VotingFrame", "AceConsole-3.0", "AceHook-3.0")

local RCLootCouncil = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil_Classic")
local RCVotingFrame = RCLootCouncil:GetActiveModule("votingframe")

-- db shortcut
local db

-- current RCLootCouncil session
local session

-- lua
local select, strfind, tContains, tinsert, tonumber = select, strfind, tContains, tinsert, tonumber

function VotingFrame:OnInitialize()
	if not RCVotingFrame.scrollCols then -- RCVotingFrame hasn't been initialized.
		return self:ScheduleTimer("OnInitialize", 0.5)
	end

    db = addon.db.factionrealm

	self.votingFrame = RCLootCouncil:GetActiveModule("votingframe")
    self:Hook(self.votingFrame, "SwitchSession", function(_, s) session = s end)

	local whishlist = { name = "BIS", DoCellUpdate = VotingFrame.SetCellWhishlist, colName = "BIS", sortnext = #self.votingFrame.scrollCols + 2, width = 60, align = "CENTER", defaultsort = "dsc" }
	local countAwarded = { name = "Awarded", DoCellUpdate = VotingFrame.SetCellAwarded, colName = "countAwarded", sortnext = 5, width = 50, align = "CENTER", defaultsort = "asc" }
	local lastAwardedAt = { name = "Last awarded", DoCellUpdate = VotingFrame.SetCellLastAwarded, colName = "LastAwarded", sortnext = 5, width = 60, align = "LEFT", defaultsort = "dsc" }

	tinsert(self.votingFrame.scrollCols, whishlist)
	tinsert(self.votingFrame.scrollCols, countAwarded)
	tinsert(self.votingFrame.scrollCols, lastAwardedAt)
end

function VotingFrame.SetCellWhishlist(_, cellFrame, data, _, _, realrow, column)
	local playerName = RCLootCouncil:UnitName(data[realrow].name)
	local itemID = nil

	local lootTable = RCLootCouncil:GetLootTable()
	if lootTable[session] ~= nil and lootTable[session].link ~= nil then
		itemID = tonumber(select(3, strfind(lootTable[session].link, "item:(%d+)")))
	end

	if db.players[playerName] ~= nil and tContains(db.players[playerName].awarded.items, itemID) then
		cellFrame.text:SetText("awarded")
		data[realrow].cols[column].value = 0
		return
	end

	if db.players[playerName] ~= nil and tContains(db.players[playerName].needed.items, itemID) then
		cellFrame.text:SetText("BIS")
		data[realrow].cols[column].value = tonumber(db.currentPhase:match("P(%d+)"))

		if tContains(db.players[playerName].whishlist.nextPhase, itemID) then
			cellFrame.text:SetText("BIS " .. db.nextPhase)
			data[realrow].cols[column].value = tonumber(db.nextPhase:match("P(%d+)"))
		end

		cellFrame.text:SetTextColor(0, 1, 0, 1)
		return
	end

	cellFrame.text:SetText("")
	data[realrow].cols[column].value = 0
end

function VotingFrame.SetCellAwarded(_, cellFrame, data, _, _, realrow, column)
	local playerName = RCLootCouncil:UnitName(data[realrow].name)

	if db.players[playerName] ~= nil then
		cellFrame.text:SetText(db.players[playerName].awarded.count .. "/" .. db.players[playerName].whishlist.count)
		data[realrow].cols[column].value = db.players[playerName].awarded.count or 0

		return
	end

	cellFrame.text:SetText("")
	data[realrow].cols[column].value = 0
end

function VotingFrame.SetCellLastAwarded(_, cellFrame, data, _, _, realrow, column)
	local playerName = RCLootCouncil:UnitName(data[realrow].name)

	if db.players[playerName] ~= nil and db.players[playerName].awarded.lastAt ~= nil then
		cellFrame.text:SetText(date("%d %b.", db.players[playerName].awarded.lastAt))
		data[realrow].cols[column].value =db.players[playerName].awarded.lastAt

		return
	end

	cellFrame.text:SetText("")
	data[realrow].cols[column].value = 0
end
