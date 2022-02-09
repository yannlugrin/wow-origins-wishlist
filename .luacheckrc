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
	"Libs",
	"OriginsWishlistExport.lua"
}

ignore = {
	"542", -- empty if branch
}

read_globals = {
	-- WoW API globals
	"CreateFrame",
	"GameTooltip",
	"GetAddOnMetadata",
	"ItemRefTooltip",
	"UnitName",
	
	-- WoW lua globals
	"tContains",
	"tinsert",
	"tremove",

	-- Libraries globals,
	"LibStub",

	-- Lua globals
	"date",
	"error",
	"floor",
	"geterrorhandler",
	"ipairs",
	"next",
	"pairs",
	"print",
	"select",
	"setmetatable",
	"strfind",
	"string",
	"strlower",
	"strsplit",
	"table",
	"time",
	"tonumber",
	"tostring",
	"type",
	"unpack"
}