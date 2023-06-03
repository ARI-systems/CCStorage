local completion = require "cc.completion"
local strings = require "cc.strings"
local storageInventoryNames = {
    "back",
}
local storageInventories = {}
for index, name in ipairs(storageInventoryNames) do
    table.insert(storageInventories, peripheral.wrap(name))
end
local file = fs.open("interfaceName", "r")
local interfaceName = nil
if file then
    interfaceName = file.readLine()
    file.close()
end
if not interfaceName then
    file = fs.open("interfaceName", "a")
    interfaceName = read(nil, nil, completion.peripheral)
    file.write(interfaceName)
    file.close()
end
file = nil
local interfaceInventory = peripheral.wrap(interfaceName)


local storageItems = {}
local displayNames = {}
local options = {}
local filledSlots = 0
local totalSlots = 0
local isCounting = false

term.clear()

local function shortenNumber(number)
    local steps = {
        { 1,    "" },
        { 1e3,  "k" },
        { 1e6,  "m" },
        { 1e9,  "g" },
        { 1e12, "t" },
    }
    for _, b in ipairs(steps) do
        if b[1] <= number + 1 then
            steps.use = _
        end
    end
    local result = string.format("%.1f", number / steps[steps.use][1])
    if tonumber(result) >= 1e3 and steps.use < #steps then
        steps.use = steps.use + 1
        result = string.sub(string.format("%.1f", tonumber(result) / 1e3), 1, 3)
    end
    result = string.sub(result, 0, string.sub(result, -1) == "0" and -3 or -1)
    result = string.sub(result, 1, 4 - string.len(steps[steps.use][2]))
    if (string.sub(result, -1) == ".") then
        result = string.sub(result, 1, -2)
    end
    return result .. steps[steps.use][2]
end

local function itemString(item, i)
    local output = ""
    if (i) then
        output = strings.ensure_width(tostring(i), 2) .. " | "
    end
    output = output .. strings.ensure_width(shortenNumber(item.count), 4) .. " | " .. item.displayName
    return output
end

local w, h = term.getSize()

local filledBarWindow = window.create(term.current(), 1, 1, w, 1)
filledBarWindow.setCursorPos(1, 1)
filledBarWindow.setTextColor(colors.lightGray)
filledBarWindow.write("Counting items...")
filledBarWindow.setTextColor(colors.white)

local itemsDisplayWindow = window.create(term.current(), 1, 2, w, h - 2)

local itemNameInputWindow = window.create(term.current(), 1, h, w - 16, 1)

local moveItemsToStorageButton = window.create(term.current(), w - 15, h, 16, 1)
moveItemsToStorageButton.setBackgroundColor(colors.green)
moveItemsToStorageButton.setTextColor(colors.white)
moveItemsToStorageButton.setCursorPos(1, 1)
moveItemsToStorageButton.clearLine()
moveItemsToStorageButton.write("Move to storage")

for index, storageInventory in ipairs(storageInventories) do
    totalSlots = totalSlots + storageInventory.size()
end

local function getStorageItems()
    local filledSlotsTemp = 0
    local storageItemsTemp = {}
    local displayNamesTemp = {}

    isCounting = true
    for index, storageInventory in ipairs(storageInventories) do
        local items = storageInventory.list()
        for slot, item in pairs(items) do
            filledSlotsTemp = filledSlotsTemp + 1
            local id = item.nbt or item.name
            if (storageItemsTemp[id]) then
                storageItemsTemp[id].count = storageItemsTemp[id].count + item.count
                table.insert(storageItemsTemp[id].slots, {
                    slot = slot,
                    count = item.count,
                    inventoryIndex = index
                })
            else
                -- local detail = storageInventory.getItemDetail(slot)
                local displayName = item.name
                storageItemsTemp[id] =
                {
                    count = item.count,
                    name = item.name,
                    displayName = displayName,
                    slots = { {
                        slot = slot,
                        count = item.count,
                        inventoryIndex = index
                    } }
                }
                table.insert(displayNamesTemp, displayName)
            end
        end
    end
    filledSlots = filledSlotsTemp
    storageItems = storageItemsTemp
    displayNames = displayNamesTemp
    isCounting = false
    local percentage = math.floor((filledSlotsTemp / totalSlots) * 100)
    filledBarWindow.clear()
    if (percentage < 30) then
        filledBarWindow.setBackgroundColor(colors.green)
    elseif (percentage < 60) then
        filledBarWindow.setBackgroundColor(colors.yellow)
    else
        filledBarWindow.setBackgroundColor(colors.red)
    end
    filledBarWindow.setCursorPos(1, 1)
    filledBarWindow.write(string.rep("=", math.floor(w * (percentage / 100))) .. ">")
    filledBarWindow.setBackgroundColor(colors.black)
    filledBarWindow.setCursorPos(math.floor(w / 2), 1)
    filledBarWindow.write(percentage .. "%")
    table.sort(displayNamesTemp, function(a, b)
        return string.len(a) < string.len(b)
    end)
end

local function storeAllItems(inventory)
    local items = inventory.list()
    for slot, item in pairs(items) do
        for index, storageInventory in ipairs(storageInventories) do
            inventory.pushItems(storageInventoryNames[index] or "back", slot, item.count)
        end
    end
end

local nameFilter = ""
local function displayItems()
    itemsDisplayWindow.clear()
    local i = 1
    -- local filtered = textutils.complete(nameFilter, displayNames)
    for id, item in pairs(storageItems) do
        itemsDisplayWindow.setCursorPos(1, i)
        if (string.find(item.displayName, nameFilter, nil, true)) then
            itemsDisplayWindow.write(itemString(item, i))
            i = i + 1
        end
    end
end


function outputPrompt()
    itemNameInputWindow.clear()
    displayItems()
    -- for nbt, item in pairs(storageItems) do
    --     print(item.displayName .. " x" .. item.count)
    -- end
    term.setCursorPos(1, 1)
    local input = read("", nil, function(text)
        itemNameInputWindow.clear()
        itemNameInputWindow.setCursorPos(1, 1)
        itemNameInputWindow.write("> " .. text)
        if (text == "") then
            nameFilter = ""
            itemNameInputWindow.setTextColor(colors.lightGray)
            itemNameInputWindow.write("Input item name")
            itemNameInputWindow.setTextColor(colors.white)
        end
        nameFilter = text
        displayItems()
    end)
    local i = 1
    itemsDisplayWindow.clear()
    for id, item in pairs(storageItems) do
        if (string.find(item.displayName, input, nil, true)) then
            itemsDisplayWindow.setCursorPos(1, i)
            table.insert(options, item)
            itemsDisplayWindow.write(itemString(item, i))
            i = i + 1
        end
    end
    local n = tonumber(read("", nil, function(text)
        itemNameInputWindow.clear()
        itemNameInputWindow.setCursorPos(1, 1)
        itemNameInputWindow.write("> " .. text)
        if (text == "") then
            nameFilter = ""
            itemNameInputWindow.setTextColor(colors.lightGray)
            itemNameInputWindow.write("Input option")
            itemNameInputWindow.setTextColor(colors.white)
        end
        term.setCursorPos(1, 1)
    end))
    local item = options[n]
    options = {}
    if (item) then
        print("Moving items...")
        for _, slot in pairs(item.slots) do
            local amountMoved = 0
            success, amountMoved = pcall(storageInventories[slot.inventoryIndex].pushItems, "right", slot.slot,
                slot.count)
            if (not success) then
                amountMoved = storageInventories[slot.inventoryIndex].pushItems(interfaceName, slot.slot, slot.count)
            end
            if (amountMoved < slot.count) then
                break
            end
        end
    end
end

local function main()
    while true do
        parallel.waitForAny(outputPrompt, function()
            while true do
                getStorageItems()
                displayItems()
                os.sleep(10)
            end
        end)
    end
end

while true do
    parallel.waitForAny(main,
        function()
            while true do
                local event = { os.pullEvent() }
                if (event[1] == "mouse_click") then
                    local x, y = event[3], event[4]
                    if (x >= w - 15 and x <= w and y == h) then
                        local inventory = peripheral.wrap("right") or interfaceInventory
                        storeAllItems(inventory)
                    end
                end
            end
        end
    )
end
