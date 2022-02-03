local _, addon = ...
local LootFrame = addon:NewModule("LootFrame", "AceConsole-3.0", "AceHook-3.0")

local RCLootCouncil = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil_Classic")
local RCLootFrame = RCLootCouncil:GetModule("RCLootFrame")

-- db shortcut
local db

-- hooking protection
local hooking = {
    GetEntry = false
}

-- lua
local select, strfind, tContains, tonumber = select, strfind, tContains, tonumber

function LootFrame:OnInitialize()
    db = addon.db.factionrealm
end

function LootFrame:OnEnable()
	self:SecureHook(RCLootFrame.EntryManager, "GetEntry", "HookGetEntry")
end

function LootFrame:HookGetEntry(_, item)
	if not hooking.GetEntry then
		hooking.GetEntry = true
		local frame = RCLootFrame.EntryManager:GetEntry(item)
		if not self:IsHooked(frame, "Update") then
			self:SecureHook(frame, "Update", "HookEntryUpdate")
			frame:Update()
		end
	end
	hooking.GetEntry = false
end

function LootFrame.HookEntryUpdate(_, entry)
	local playerName = RCLootCouncil:UnitName(UnitName("player"))
    local bis = nil

	local session = entry.item.sessions and entry.item.sessions[1]
    if not session then return end

    local itemID = nil
    local lootTable = RCLootCouncil:GetLootTable()
    if lootTable[session] ~= nil and lootTable[session].link ~= nil then
        itemID = tonumber(select(3, strfind(lootTable[session].link, "item:(%d+)")))
    end
    if not itemID then return end

    if db.players[playerName] ~= nil and tContains(db.players[playerName].awarded.items, itemID) then
        bis = "awarded"
    end

    if db.players[playerName] ~= nil and tContains(db.players[playerName].needed.items, itemID) then
        bis = "BIS"
        if tContains(db.players[playerName].whishlist.nextPhase, itemID) then
            bis = "BIS " .. db.nextPhase
        end
    end

    if bis then
        entry.itemLvl:SetText("|c0000ff00"..bis.."|r  "..entry.itemLvl:GetText())
    end
end