local transposer = component.proxy(component.list("transposer")())
local tunnel = component.proxy(component.list("tunnel")())

local buffer = 1
local empower = 0
local infusion = 5
local crafting = 2
local main = 3
local name = "thermalexpansion:frame"
local frames = {148, 132, 147, 131, 146, 130, 129, 128, 0}
local framesCount = #frames
local fullCount = 0
local returnTriesCount = 8

local bufferSize = transposer.getInventorySize(buffer)
local mainSize transposer.getInventorySize(main)
local queue = {}
local ntc = {}
local funcs = {}

local function getSlot(id, exact)
  local allItems = transposer.getAllStacks(buffer).getAll()
  local slot
  if not id then
    return nil
  end
  if not exact then
    for i = 1, framesCount do
      if frames[i] == id then
        id = frames[i+1]
        break
      end
    end
  end
  for i = 1, bufferSize do
    if items[i].name == name and items[i].damage == id then
      slot = i
      break
    end
  end
  return slot
end

local function empw(id)
  local stack = transposer.getStackInSlot(empower, 1)
  if not stack then
    local slot = getSlot(id)
    if slot then
      transposer.transferItem(buffer, empower, 1, slot)
    end
    return
  end
  
  if stack.damage == 128 then
    return
  end
  
  queue[id] = queue[id] - transposer.transferItem(empower, buffer)
  return false
end

local function infuse(id)
  local slot = getSlot(id)
  if slot then
    queue[id] = queue[id] - transposer.transferItem(buffer, infusion, 1, slot)
  end
end

local function craft(id)
  local slot = getSlot(id)
  if slot then
    queue[id] = queue[id] - transposer.transferItem(buffer, crafting, 1, slot)
  end
end

local function returnItems()
  local tries = returnTriesCount
  while fullCount > 0 and tries > 0 do
    empw()
    for i = 1, bufferSize do
      fullCount = fullCount - transposer.transferItem(buffer, main, _, i)
    end
    tries = tries - 1
    computer.pullSignal(1)
  end
  ntc = {}
  queue = {}
end

funcs[128] = infuse
funcs[129] = empw
funcs[130] = craft
funcs[131] = craft
funcs[146] = infuse
funcs[147] = infuse

local function mainLoop()
  for k, v in pairs(queue) do
    if v > 0 and funcs[k] then
      funcs[k](k)
    end
  end
  local nmb
  for i = 1, #frames do
    if ntc[frames[i]] > 0 then
      nmb = frames[i]
      local slot = getSlot(nmb, true)
      if slot then
        ntc[nmb] = ntc[nmb] - transposer.transferItem(buffer, main, 1, slot)
      end
      break
    end
  end
  if not nmb then
    returnItems()
    return false
  end
  
  return true
end

local function main()
  local doCraft = false
  
  while true do
    local _, _, _, _, _, cmd, data = computer.pullSignal(1)
    if cmd == "start" then
      local allItems = transposer.getAllStacks(main).getAll()
      for i = 1, #allItems do
        if allItems[i].name == name then
          fullCount = fullCount + transposer.transferItem(main, buffer, _, i)
        end
      end
      for k, v in data:gmatch("(%d+)=(%d+)") do
        local id = tonumber(k)
        local count = tonumber(v)
        if count > 0 then
          ntc[id] = count
        end
      end
      local addCount = 0
      for i = 1, #frames - 1 do
        local id = frames[i]
        if ntc[id] then
          addCount = addCount + ntc[id]
        end
        queue[id] = addCount
      end
      doCraft = true
    elseif cmd == "stop" then
      returnItems()
      doCraft = false
    end
    
    if doCraft then
      doCraft = mainLoop()
    end
  end
end