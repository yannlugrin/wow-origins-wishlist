-- Disable unused self warnings.
self = false

-- Disable line length limits.
max_line_length = false
max_code_line_length = false
max_string_line_length = false
max_comment_line_length = false

-- Add exceptions for external libraries.
std = "lua51"

globals = {
	-- Origins Wishlist
	"OriginsWishlist",
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
	"CreateFrame",
	"tContains",
	"tinsert",
	"tremove",

	-- Libraries globals,
	"LibStub",

	-- Lua globals
	"floor",
	"geterrorhandler",
	"error",
	"ipairs",
	"next",
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
