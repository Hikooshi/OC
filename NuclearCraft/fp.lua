local component = require("component")
local transposer = component.transposer
local modem = component.modem
local gpu = component.gpu
local event = require("event")

local fuelSide = 1
local partsSide
local reporcSide
local oxSide = 0
local robotSide
local partsInvSize

local craftSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
local resultSlot = 13

local fuels = setmetatable({n=0},
  {__call = function(self, str, ctg)
              local words = {}
              for word in str:gmatch("%S+") do
                table.insert(words, word)
              end
              local e1 = words[2]
              local d1 = tonumber(words[3])
              local c1 = tonumber(words[4])
              local e2 = #words == 7 and words[7] or words[2]
              local d2 = tonumber(words[5])
              local c2 = tonumber(words[6])
              local oxides = {}
              if d1 % 2 == 1 then
                d1 = d1 - 1
                oxides[e1 .. d1] = c1
              end
              if d2 % 2 == 1 then
                d2 = d2 - 1
                oxides[e2 .. d2] = c2
              end
              local tbl = {elements={}}
              tbl.elements[e1 .. d1] = c1
              tbl.elements[e2 .. d2] = c2
              tbl.oxides = oxides
              tbl.category = ctg and ctg or words[2]
              tbl.n = self.n
              self.n = self.n + 1
              self[words[1]] = tbl
            end})

local selectedFuels = {}
local selectedElements = {}

fuels("TBU thorium 4 9 4 9")
fuels("OxTBU thorium 4 9 4 9")
fuels("MOX-239 plutonium 5 1 8 8 uranium", "MOX")
fuels("MOX-241 plutonium 9 1 8 8 uranium", "MOX")
fuels("LEU-233 uranium 0 1 8 8")
fuels("OxLEU-233 uranium 1 1 8 8")
fuels("HEU-233 uranium 0 4 8 5")
fuels("OxHEU-233 uranium 1 4 8 5")
fuels("LEU-235 uranium 4 1 8 8")
fuels("OxLEU-235 uranium 5 1 8 8")
fuels("HEU-235 uranium 4 4 8 5")
fuels("OxHEU-235 uranium 5 4 8 5")
fuels("LEN-236 neptunium 0 1 4 8")
fuels("OxLEN-236 neptunium 1 1 4 8")
fuels("HEN-236 neptunium 0 4 4 5")
fuels("OxHEN-236 neptunium 1 4 4 5")
fuels("LEP-239 plutonium 4 1 12 8")
fuels("OxLEP-239 plutonium 5 1 12 8")
fuels("HEP-239 plutonium 4 4 12 5")
fuels("OxHEP-239 plutonium 5 4 12 5")
fuels("LEP-241 plutonium 8 1 12 8")
fuels("OxLEP-241 plutonium 9 1 12 8")
fuels("HEP-241 plutonium 8 4 12 5")
fuels("OxHEP-241 plutonium 9 4 12 5")
fuels("LEA-242 americium 4 1 8 8")
fuels("OxLEA-242 americium 5 1 8 8")
fuels("HEA-242 americium 4 4 8 5")
fuels("OxHEA-242 americium 5 4 8 5")
fuels("LECm-243 curium 0 1 8 8")
fuels("OxLECm-243 curium 1 1 8 8")
fuels("HECm-243 curium 0 4 8 5")
fuels("OxHECm-243 curium 1 4 8 5")
fuels("LECm-245 curium 4 1 8 8")
fuels("OxLECm-245 curium 5 1 8 8")
fuels("HECm-245 curium 4 4 8 5")
fuels("OxHECm-245 curium 5 4 8 5")
fuels("LECm-247 curium 12 1 8 8")
fuels("OxLECm-247 curium 13 1 8 8")
fuels("HECm-247 curium 12 4 8 5")
fuels("OxHECm-247 curium 13 4 8 5")
fuels("LEB-248 berkelium 4 1 0 8")
fuels("OxLEB-248 berkelium 5 1 0 8")
fuels("HEB-248 berkelium 4 4 0 5")
fuels("OxHEB-248 berkelium 5 4 0 5")
fuels("LECf-249 californium 0 1 12 8")
fuels("OxLECf-249 californium 1 1 12 8")
fuels("HECf-249 californium 0 4 12 5")
fuels("OxHECf-249 californium 1 4 12 5")
fuels("LECf-251 californium 8 1 12 8")
fuels("OxLECf-251 californium 9 1 12 8")
fuels("HECf-251 californium 8 4 12 5")
fuels("OxHECf-251 californium 9 4 12 5")

local buttons = setmetatable({},
  {__call = function(self, str, n, func)
              local _, q = math.modf(n / 4)
              q = q / 25 * 100
              local tbl = {}
              tbl.text = str
              tbl.x = 10 + (14 * q)
              tbl.y = 4 + math.floor(n / 4)
              tbl.width = 12
              tbl.height = 1
              tbl.foreground = 0xFFFFFF
              tbl.background = 0x000000
              tbl.func = func
              table.insert(self, tbl)
            end})
buttons.exit = {x = 78, y = 1, width = 3, height = 1, text = "X", foreground = 0xFF0000, background = 0x444444}
buttons.start = {x = 35, y = 19, width = 7, height = 3, text = "Start", foreground = 0x444444, background = 0xFFFF00}

local function drawButton(btn)
  gpu.setForeground(btn.foreground)
  gpu.setBackground(btn.background)
  gpu.fill(btn.x, btn.y, btn.width, btn.height, " ")
  gpu.set(btn.x + 1, btn.y + math.floor(btn.height / 2), btn.text)
end

local function selectFuel(tbl)
  local function getColor(fuel, color)
    if fuel.oxide and not oxSide then
      return 0xFF0000
    end
    return color == 0x000000 and 0x00FF00 or 0x000000
  end
  
  local name = tbl.text
  local fuel = fuels[name]
  local ctg = fuel.category
  local color = getColor(fuel, tbl.background)
  if color == 0x00FF00 then
    for k, v in pairs(fuel.elements) do
      local se = selectedElements[k] or 1
      se = se + 1
      selectedElements[k] = se
    end
    local sf = selectedFuels[ctg] or {}
    table.insert(sf, name)
    selectedFuels[ctg] = sf
  elseif color == 0x000000 then
    for k, v in pairs(fuel.elements) do
      local se = selectedElements[k] or 1
      se = se - 1
      selectedElements[k] = se > 0 and se or nil
    end
    local sf = selectedFuels[ctg]
    if sf then
      for i = 1, #sf do
        if sf[i] == name then
          table.remove(sf, i)
        end
      end
    end
  end
  tbl.background = color
  drawButton(tbl)
--[[local n1 = next(fuel.elements)
local n2 = next(fuel.elements, n1)
gpu.set(1, 1, n1)
gpu.set(1, 2, n2 or "")]]
end

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
  
  for k, v in pairs(fuels) do
    if k ~= "n" then
      buttons(k, v.n, selectFuel)
    end
  end
  
  for _, v in pairs(buttons) do
    drawButton(v)
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

local function main()
  init()
  while true do
    local _, _, x, y = event.pull(10, "touch")
    if x and y then
      for k, v in pairs(buttons) do
        if x >= v.x and x < v.x + v.width and y >= v.y and y < v.y + v.height then
          v.func(v)
        end
      end
    end
  end
end

main()