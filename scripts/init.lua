--- Different log levels of the pack
--- @enum log_level
LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
}

--- Enables Poptracker's own error logging
DEBUG = { "errors" }

--- The log level of the pack
--- @type log_level
LOG_LEVEL = LOG_LEVELS.INFO

--- Whether the loaded variant is items only
--- @type boolean
IS_ITEMS_ONLY = Tracker.ActiveVariantUID:find("itemsonly") ~= nil

print("---- Dark Souls II AP Tracker ----")

require("utils")
require("scripts.archipelago")

Tracker:AddItems("items/items.jsonc")
Tracker:AddLayouts("layouts/items.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/broadcast.json")

if not IS_ITEMS_ONLY then
    Tracker:AddItems("items/options.jsonc")
    Tracker:AddLayouts("layouts/options.json")
    Tracker:AddMaps("maps/maps.json")
    ScriptHost:LoadScript("scripts/locations_mapping.lua")
end
