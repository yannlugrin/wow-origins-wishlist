local function addOriginsWishlist(tooltip)
	local _, itemLink = tooltip:GetItem()

	if itemLink then
		local itemID = itemLink:match("item:(%d+):")

		if OriginsWishlistExport[itemID] ~= nil then
			tooltip:AddLine("\nOrïgins Wishlist")
			tooltip:AddLine(OriginsWishlistExport[itemID])
		end
	end
end

GameTooltip:HookScript("OnTooltipSetItem", addOriginsWishlist)
ItemRefTooltip:HookScript("OnTooltipSetItem", addOriginsWishlist)
