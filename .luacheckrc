-- Disable unused self warnings.
self = false

-- Add exceptions for external libraries.
std = "lua51"

globals = {
	-- Origins Wishlist
	"OriginsWishlistExport"
}

exclude_files = {
	".luacheckrc",
}

ignore = {
	"542", -- empty if branch
}

read_globals = {
	-- WoW API globals
	"GameTooltip",
	"ItemRefTooltip",

	-- Lua globals
	"floor",
	"geterrorhandler",
	"error",
	"ipairs",
	"pairs",
	"print",
	"select",
	"setmetatable",
	"string",
	"table",
	"tonumber",
	"tostring",
	"type"
}
