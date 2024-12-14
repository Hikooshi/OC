local component = require("component")
local transposer = component.transposer
local modem = component.modem
local event = require("event")

local fuelSide = 1
local partsSide
local reporcSide
local oxSide = 0
local robotSide
local partsInvSize

local craftSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
local resultSlot = 13

local fuels = setmetatable({elements = {}},
  {__call = function(self, str)
              local words = {}
              for word in str:gmatch("%S+") do
                table.insert(words, word)
              end
              local e2 = #words == 7 and words[7] or words[2]
              self[words[1]] = {words2 = {dmg = tonumber(words[3]),
                                            cnt = tonumber(words[4])}, 
                                e2 = {dmg = tonumber(words[5]),
                                      cnt = tonumber(words[6])}}
            end})

fuels("TBU thorium 4 9 4 9")
fuels("LEU233 uranium 0 1 8 8")
fuels("OxLEU233 uranium 1 1 8 8")
fuels("HEU233 uranium 0 4 8 5")
fuels("OxHEU233 uranium 1 4 8 5")
fuels("LEU235 uranium 4 1 8 8")
fuels("OxLEU235 uranium 5 1 8 8")
fuels("HEU235 uranium 4 4 8 5")
fuels("OxHEU235 uranium 5 4 8 5")
fuels("LEN236 neptunium 0 1 4 8")
fuels("OxLEN236 neptunium 1 1 4 8")
fuels("HEN236 neptunium 0 4 4 5")
fuels("OxHEN236 neptunium 1 4 4 5")
fuels("LEP239 plutonium 4 1 12 8")
fuels("OxLEP239 plutonium 5 1 12 8")
fuels("HEP239 plutonium 4 4 12 5")
fuels("OxHEP239 plutonium 5 4 12 5")
fuels("LEP241 plutonium 8 1 12 8")
fuels("OxLEP241 plutonium 9 1 12 8")
fuels("HEP241 plutonium 8 4 12 5")
fuels("OxHEP241 plutonium 9 4 12 5")
fuels("MOX239 plutonium 5 1 8 8 uranium")
fuels("MOX241 plutonium 9 1 8 8 uranium")
fuels("LEA242 americium 4 1 8 8")
fuels("OxLEA242 americium 5 1 8 8")
fuels("HEA242 americium 4 4 8 5")
fuels("OxHEA242 americium 5 4 8 5")
fuels("LECm243 curium 0 1 8 8")
fuels("OxLECm243 curium 1 1 8 8")
fuels("HECm243 curium 0 4 8 5")
fuels("OxHECm243 curium 1 4 8 5")
fuels("LECm245 curium 4 1 8 8")
fuels("OxLECm245 curium 5 1 8 8")
fuels("HECm245 curium 4 4 8 5")
fuels("OxHECm245 curium 5 4 8 5")
fuels("LECm247 curium 12 1 8 8")
fuels("OxLECm247 curium 13 1 8 8")
fuels("HECm247 curium 12 4 8 5")
fuels("OxHECm247 curium 13 4 8 5")
fuels("LEB248 berkelium 4 1 0 8")
fuels("OxLEB248 berkelium 5 1 0 8")
fuels("HEB248 berkelium 4 4 0 5")
fuels("OxHEB248 berkelium 5 4 0 5")
fuels("LECf249 californium 0 1 12 8")
fuels("OxLECf249 californium 1 1 12 8")
fuels("HECf249 californium 0 4 12 5")
fuels("OxHECf249 californium 1 4 12 5")
fuels("LECf251 californium 8 1 12 8")
fuels("OxLECf251 californium 9 1 12 8")
fuels("HECf251 californium 8 4 12 5")
fuels("OxHECf251 californium 9 4 12 5")

local function init()
  modem.open(4)
  
  for i = 2, 5 do
    local name = transposer.getInventoryName(i)
    local size = transposer.getInventorySize(i) or 0
    if size == 27 then
      reprocSide = i
    elseif size > 27 then
      partsSide = i
      partsInvSize = size
    else
      if name == "opencomputers:robot" then
        robotSide = i
      end
    end
  end
  
  local messages = {}
  if transposer.getInventorySize(fuelSide) == 0 then
    table.insert(messages, "Не установлен инвентарь для топлива")
  end
  if not partsSide then
    table.insert(messages, "Не установлен инвентарь для изотопов")
  end
  if not reprocSide then
    table.insert(messages, "Не установлен инвентарь переработки")
  end
  if not robotSide then
    table.insert(messages, "Сторона крафта или робота не указана")
  end
  
  if #messages > 0 then
    for i = 1, #messages do
      print(messages[i])
    end
    return
  end
end

local function findElements(tiny)
  local nmb = tiny and 1 or 0
  local allItems = transposer.getAllStacks(partsSide).getAll()
  local elements = {}
  for i = 1, partsInvSize do
    if allItems[i].name ~= "minecraft:air" then
      local damage = allItems[i].damage
      local name = allItems[i].name:match(":(%w+)")
      local fname = name .. damage
      if math.floor(damage / 2) % 2 == nmb then
        if elements[fname] then
          elements[fname].size = elements[fname].size + allItems[i].size
          table.insert(elements[fname].slots, i)
        else
          elements[fname] = {size = allItems[i].size, slots = {i}}
          if tiny then
            elements[fname].relation = name .. (damage - 2)
          end
        end
      end
    end
  end
  
  return elements
end

local function reprocess(tbl, side, size)
  local ntt = size
  for i = 1, #tbl.slots do
    ntt = ntt - transposer.transferItem(side, reprocSide, ntt, tbl.slots[i])
    if ntt == 0 then
      break
    end
  end
end

local function recraftElements()
  local elements = findElements(true)
  for k, v in pairs(elements) do
    if not fuels.elements[v.relation] then
      reprocess(v, partsSide, v.size)
    else
      local count = math.floor(v.size / 9)
      count = count > 64 and 64 or count
      local slot = table.remove(v.slots, #v.slots)
      for i = 1, 9 do
        local toTransfer = count
        while toTransfer > 0 do
          toTransfer = toTransfer - transposer.transferItem(partsSide, robotSide, toTransfer, slot, craftSlots[i])
          if transposer.getSlotStackSize(partsSide, slot) == 0 then
            slot = table.remove(v.slots, #v.slots)
          end
        end
      end
      
      modem.broadcast(4, "craft")
      local _, _, _, _, _, message = event.pull(4, "modem_message")
      if message then
        while count > 0 do
          count = count - transposer.transferItem(robotSide, partsSide, count, resultSlot)
          os.sleep()
        end
      end
    end
  end
end

init()

while true do
  recraftElements()
  os.sleep(1)
end