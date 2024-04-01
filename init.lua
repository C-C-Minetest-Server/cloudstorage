-- cloudstorage/init.lua
-- Command-based Parcel Locker
-- Copyright (C) 2024  1F616EMO
-- SPDX-License-Identifier: LGPL-2.0-or-later

cloudstorage = {}

local S = minetest.get_translator("cloudstorage")
local DIR = minetest.get_worldpath() .. "/cloudstorage_items/"
local logger = logging.logger("cloudstorage")

minetest.mkdir(DIR)

function cloudstorage.get_item(id)
    local f = io.open(DIR .. id, "r")
    if not f then return false end

    local itemstring = f:read("*a")
    f:close()

    local itemstack = ItemStack(itemstring)
    return itemstack
end

function cloudstorage.remove_item(id)
    os.remove(DIR .. id, "r")
end

function cloudstorage.store_item(id, itemstack)
    local itemstring = itemstack:to_string()

    local f = io.open(DIR .. id, "w")
    if not f then return false end

    f:write(itemstring)
    f:close()

    return true
end

minetest.register_privilege("cloudstorage", {
    description = S("Can store items into the cloud storage"),
    give_to_singleplayer = true,
})

local cmd = chatcmdbuilder.register("cloudstorage", {
    description = S("Interact with the cloud storage"),
    privs = { interact = true },
})

cmd:sub("store :id", {
    privs = { cloudstorage = true },
    func = function(name, id)
        id = string.trim(id)
        if id == "" then
            return false, S("The ID must not be empty.")
        end

        local player = minetest.get_player_by_name(name)
        if not player then
            return false, S("You must be online to run this command.")
        end

        local itemstack = player:get_wielded_item()
        if itemstack:is_empty() then
            return false, S("You must hold the item you want to store in your hand.")
        end

        if not minetest.is_creative_enabled(name) then
            player:set_wielded_item(ItemStack())
        end

        cloudstorage.store_item(id, itemstack)
        logger:action(("%s stored the following item into slot %s: %s"):format(
            name, id, itemstack:to_string()
        ))
        return true, S("Successfully stored the item into slot @1.", id)
    end,
})

cmd:sub("get :id", {
    func = function(name, id)
        id = string.trim(id)
        if id == "" then
            return false, S("The ID must not be empty.")
        end

        local player = minetest.get_player_by_name(name)
        if not player then
            return false, S("You must be online to run this command.")
        end

        local itemstack = cloudstorage.get_item(id)
        if not itemstack then
            return false, S("Item not found in slot @1.", id)
        end

        local inv = player:get_inventory()
        if not inv:room_for_item("main", itemstack) then
            return false, S("No room for the item!")
        end

        cloudstorage.remove_item(id)
        inv:add_item("main", itemstack)
        logger:action(("%s took the following item from slot %s: %s"):format(
            name, id, itemstack:to_string()
        ))
        return true, S("Successfully obtained the item from slot @1.", id)
    end,
})

cmd:sub("list", {
    privs = { cloudstorage = true },
    func = function(name)
        local slot_list = minetest.get_dir_list(DIR, false)
        return true, S("List of cloud storage slots: @1", table.concat(slot_list, ", "))
    end,
})

local help_string = table.concat({
    "/cloudstorage store :id - " .. S("Store the item in your hand into the slot with the given ID"),
    "/cloudstorage get :id - " .. S("Obtain the item in the given slot, putting it into your inventory"),
    "/cloudstorage list - " .. S("List all occupied slots"),
}, "\n")

cmd:sub("help", {
    func = function(name)
        return true, help_string
    end
})
