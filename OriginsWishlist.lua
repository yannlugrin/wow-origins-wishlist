local EventFrame = CreateFrame("frame", "EventFrame")
local OriginsWishlistItems = {}

-- Warmup
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_ENTERING_WORLD" then return end

	for playerName in pairs(OriginsWishlistExport) do
		local playerClassColor = OriginsWishlistExport[playerName].classColor

		for index in pairs(OriginsWishlistExport[playerName].whishlist.items) do
			local itemID = OriginsWishlistExport[playerName].whishlist.items[index]
			local itemStatus = "whishlist"

			OriginsWishlistItems[itemID] = OriginsWishlistItems[itemID] or {["whishlist"] = "", ["awarded"] = ""}
			if tContains(OriginsWishlistExport[playerName].awarded.items, itemID) then
				itemStatus = "awarded"
			end

			if OriginsWishlistItems[itemID][itemStatus] ~= "" then
				OriginsWishlistItems[itemID][itemStatus] = OriginsWishlistItems[itemID][itemStatus] .. ", "
			end
			OriginsWishlistItems[itemID][itemStatus] = OriginsWishlistItems[itemID][itemStatus] .. "|cff" .. playerClassColor .. playerName .. "|r"
			if itemStatus == "whishlist" then
				OriginsWishlistItems[itemID][itemStatus] = OriginsWishlistItems[itemID][itemStatus] .. " (".. OriginsWishlistExport[playerName].awarded.count .. "/" .. OriginsWishlistExport[playerName].whishlist.count .. ", " .. OriginsWishlistExport[playerName].awarded.lastAt .. ")"
			end
		end
	end
end)

-- Item Tooltip hook
local function addItemTooltip(tooltip)
	local _, itemLink = tooltip:GetItem()

	if itemLink then
		local itemID = tonumber(itemLink:match("item:(%d+):"))

		if OriginsWishlistItems[itemID] ~= nil then
			tooltip:AddLine("\nOrïgins Wishlist", nil, nil, nil, false)
			if OriginsWishlistItems[itemID].whishlist ~= "" then
				tooltip:AddLine("Besoin : " .. OriginsWishlistItems[itemID].whishlist, nil, nil, nil, true)
			end
			if OriginsWishlistItems[itemID].awarded ~= "" then
				tooltip:AddLine("Reçus : " .. OriginsWishlistItems[itemID].awarded, nil, nil, nil, true)
			end
		end
	end
end

GameTooltip:HookScript("OnTooltipSetItem", addItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", addItemTooltip)

-- Player Tooltip hook
local function addPlayerTooltip(tooltip)
	local playerName, _ = tooltip:GetUnit()

	if OriginsWishlistExport[playerName] ~= nil then
		tooltip:AddLine("\nOrïgins Wishlist (".. OriginsWishlistExport[playerName].awarded.count .. "/" .. OriginsWishlistExport[playerName].whishlist.count .. ")", nil, nil, nil, false)

		if OriginsWishlistExport[playerName].awarded.lastAt ~= "" then
			tooltip:AddLine("Dernier loot le " .. OriginsWishlistExport[playerName].awarded.lastAt, nil, nil, nil, false)
		end
	end
end

GameTooltip:HookScript("OnTooltipSetUnit", addPlayerTooltip)