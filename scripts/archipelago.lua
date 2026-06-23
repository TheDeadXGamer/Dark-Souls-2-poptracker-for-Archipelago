--- Item mappings for Archipelago integration.
--- @type table<integer, string>
local ITEM_MAPPING = require("item_mapping")

--- Location mappings for Archipelago integration.
--- @type table<integer, string>
local LOCATION_MAPPING

--- Index of the last processed item/location, used to ignore duplicate callbacks from Archipelago.
--- @type integer?
local CUR_INDEX = nil

--- The slot data received from AP on clear, used for setting options and other details.
--- @type table?
local SLOT_DATA = nil

if not IS_ITEMS_ONLY then
    LOCATION_MAPPING = require("location_mapping")
end

--- Called when connection to a server is made. Resets locations and items, and loads options based on recieved slot data.
--- @param slot_data table The slot data received from Archipelago. Contains item options and other logic details.
local function onClear(slot_data)
    if slot_data == nil then
        if LOG_LEVEL <= LOG_LEVELS.WARNING then
            print("> WARNING: [onClear] Successfully connected to server, received slot_data: nil")
        end
    elseif LOG_LEVEL <= LOG_LEVELS.INFO then
        print(string.format("> INFO: [onClear] Successfully connected to server, received slot_data:\n%s",
            DumpTable(slot_data)))
    end

    if not IS_ITEMS_ONLY then
        -- Reset locations
        if LOG_LEVEL <= LOG_LEVELS.INFO then
            print(string.format("> INFO: [onClear] Resetting locations..."))
        end

        for _, location_section in pairs(LOCATION_MAPPING) do
            if location_section then
                local location_obj = GetObjTypeSafe(location_section, OBJECT_TYPES.LocationSection)
                if location_obj then
                    if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                        print(string.format("> DEBUG: [onClear] Resetting location section: '%s'", location_section))
                    end
                    location_obj.AvailableChestCount = location_obj.ChestCount
                end
            else
                if LOG_LEVEL <= LOG_LEVELS.WARNING then
                    print(string.format("> WARNING: [onClear] LOCATION_MAPPING has an empty value"))
                end
            end
        end
    end

    -- Reset items
    if LOG_LEVEL <= LOG_LEVELS.INFO then
        print(string.format("> INFO: [onClear] Resetting items..."))
    end

    for _, item_code in pairs(ITEM_MAPPING) do
        if item_code then
            local item_obj = GetObjTypeSafe(item_code, OBJECT_TYPES.JsonItem)
            if item_obj then
                if item_obj.Type == "toggle" then
                    if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                        print(string.format("> DEBUG: [onClear] Resetting toggle item: '%s'", item_code))
                    end
                    item_obj.Active = false
                else
                    if LOG_LEVEL <= LOG_LEVELS.ERROR then
                        print(string.format("> ERROR: [onClear] Unrecognized item type '%s' for item: '%s'",
                            item_obj.Type, item_code))
                    end
                end
            end
        else
            if LOG_LEVEL <= LOG_LEVELS.WARNING then
                print(string.format("> WARNING: [onClear] ITEM_MAPPING has an empty value"))
            end
        end
    end

    if SLOT_DATA == nil or IS_ITEMS_ONLY then
        return
    end

    -- Set all hidden items to false
    SetAllHiddenItems(false)

    -- Game Version is 0 if playing SotFS and Vanilla otherwise
    local game_version = SLOT_DATA['game_version'] and "Vanilla" or "SotFS"
    if LOG_LEVEL <= LOG_LEVELS.INFO then
        print(string.format("> INFO: [onClear] Setting options for Game Version: '%s'", game_version))
    end

    local version_obj = GetObjTypeSafe(game_version, OBJECT_TYPES.JsonItem)
    if version_obj then
        version_obj.Active = game_version and true or false
    end


    if LOG_LEVEL <= LOG_LEVELS.INFO then
        print(string.format("> INFO: [onClear] Setting DLC options based on slot data..."))
    end

    -- Set each DLC item
    for _, dlc_item in pairs({ "old_iron_king_dlc", "ivory_king_dlc", "sunken_king_dlc" }) do
        local enable_dlc_item = SLOT_DATA[dlc_item]
        if enable_dlc_item then
            local dlc_item_obj = GetObjTypeSafe(dlc_item, OBJECT_TYPES.JsonItem)
            if dlc_item_obj then
                if type(enable_dlc_item) == "number" then
                    if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                        print(string.format("> DEBUG: [onClear] Setting '%s' active state to '%s' from number",
                            dlc_item, tostring(enable_dlc_item ~= 0)))
                    end
                    dlc_item_obj.Active = enable_dlc_item ~= 0
                elseif type(enable_dlc_item) == "boolean" then
                    if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                        print(string.format("> DEBUG: [onClear] Setting '%s' active state to '%s' from boolean",
                            dlc_item, tostring(enable_dlc_item)))
                    end
                    dlc_item_obj.Active = enable_dlc_item
                else
                    if LOG_LEVEL <= LOG_LEVELS.ERROR then
                        print(string.format("> ERROR: [onClear] Unexpected type for slot_data.options.enable_dlc: '%s'",
                            type(enable_dlc_item)))
                    end
                end
            end
        else
            if LOG_LEVEL <= LOG_LEVELS.WARNING then
                print(string.format("> WARNING: [onClear] slot_data.options.enable_dlc is nil"))
            end
        end
    end
end

--- Called when an item gets collected. Updates the corresponding item based on the received item_id.
--- @param index integer The event index.
--- @param item_id integer The id of the collected item.
--- @param item_name string The name of the collected item.
--- @param player_number integer The id of the player who collected the item.
local function onItem(index, item_id, item_name, player_number)
    if LOG_LEVEL <= LOG_LEVELS.INFO then
        print(string.format(
            "> INFO: [onItem] Received item event with index: '%s', item_id: '%s', item_name: '%s', player_number: '%s'",
            index, item_id, item_name, player_number))
    end

    if CUR_INDEX and index <= CUR_INDEX then
        if LOG_LEVEL <= LOG_LEVELS.INFO then
            print(string.format(
                "> DEBUG: [onItem] Event already processed (index: '%s', current index: '%s'), ignoring event", index,
                CUR_INDEX))
        end
        return
    end

    CUR_INDEX = index;

    local item_code = ITEM_MAPPING[item_id]
    if not item_code then
        if LOG_LEVEL <= LOG_LEVELS.INFO then
            print(string.format("> DEBUG: [onItem] No mapping found for item_id: '%s' ('%s')", item_id, item_name))
        end
        return
    end

    local item_obj = GetObjTypeSafe(item_code, OBJECT_TYPES.JsonItem)
    if item_obj then
        if item_obj.Type == "toggle" then
            if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                print(string.format("> DEBUG: [onItem] Activating toggle item: '%s' ('%s')", item_id, item_name))
            end
            item_obj.Active = true
        elseif item_obj.Type == "progressive" then
            if item_obj.Active then
                if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                    print(string.format("> DEBUG: [onItem] Incrementing progressive item: '%s' ('%s')", item_id,
                        item_name))
                end
                item_obj.CurrentStage = item_obj.CurrentStage + 1
            else
                if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                    print(string.format("> DEBUG: [onItem] Activating progressive item: '%s' ('%s')", item_id, item_name))
                end
                item_obj.Active = true
            end
        else
            if LOG_LEVEL <= LOG_LEVELS.ERROR then
                print(string.format("> ERROR: [onItem] Unrecognized item type '%s' for item: '%s' ('%s')", item_obj.Type,
                    item_id, item_name))
            end
        end
    end
end

Archipelago:AddClearHandler("clear handler", onClear)
Archipelago:AddItemHandler("item handler", onItem)

if not IS_ITEMS_ONLY then
    --- Called when a location gets cleared. Updates the corresponding location section based on the received location_id.
    --- @param location_id integer The id of the cleared location.
    --- @param location_name string The name of the cleared location.
    local function onLocation(location_id, location_name)
        if LOG_LEVEL <= LOG_LEVELS.INFO then
            print(string.format("> INFO: [onLocation] Received location event with id: '%s', name: '%s'", location_id,
                location_name))
        end

        local location_section = LOCATION_MAPPING[location_id]
        if not location_section then
            if LOG_LEVEL <= LOG_LEVELS.ERROR then
                print(string.format("> ERROR: [onLocation] No mapping found for location_id: '%s' ('%s')", location_id,
                    location_name))
            end
            return
        end

        local location_obj = GetObjTypeSafe(location_section, OBJECT_TYPES.LocationSection)
        if location_obj then
            location_obj.AvailableChestCount = location_obj.AvailableChestCount - 1
            if LOG_LEVEL <= LOG_LEVELS.DEBUG then
                if location_obj.AvailableChestCount <= 0 then
                    print(string.format("> DEBUG: [onLocation] Deactivating location section: '%s', ('%s')",
                        location_section, location_id))
                else
                    print(string.format(
                        "> DEBUG: [onLocation] Decrementing location section: '%s', ('%s'), available chest count: '%s'",
                        location_section, location_id, location_obj.AvailableChestCount))
                end
            end
        end
    end
    Archipelago:AddLocationHandler("location handler", onLocation)
end
