local component = require("component")
local transposer = component.transposer
local gpu = component.gpu
local serialization = require("serialization")
local event = require("event")
local term = require("term")



local sides = {src = 1, del = 4, rep = 5}
local blItems = {}
local blMods = {}
local encList = {}
local aspects = {}
local custom = {}
local repairable = {"helm", "chest", "leg", "boots", "sword", "axe", "shovel", "feet", "head"}
local enchNumbers = {I = true, V = true, X = true}

local blActiveItems = true
local blActiveMods = true
local ignoreEnchsList = true
local enchSearch = false
local customSearch = false
local aspectsSearch = false
local _, height = gpu.getResolution()
local rowCount = height - 5

local funcs = {}
local pagesContent = {count = 0}

local function init()
  local file = io.open("sides", "r")
  if file then
    sides = serialization.unserialize(file:read())
    file:close()
  end
  
  local fileBL = io.open("blacklist", "r")
  if fileBL then
    for line in fileBL:lines() do
      blItems[line] = true
    end
    fileBL:close()
  end
  
  local fileMods = io.open("mods", "r")
  if fileMods then
    for line in fileMods:lines() do
      blMods[line] = true
    end
    fileMods:close()
  end
  
  local fileEnchantments = io.open("enchantments", "r")
  if fileEnchantments then
    for line in fileEnchantments:lines() do
      encList[line] = true
    end
    fileEnchantments:close()
  end
  
  local fileAspects = io.open("aspects", "r")
  if fileAspects then
    for line in fileAspects:lines() do
      aspects[line] = true
    end
    fileAspects:close()
  end
  
  repairable.n = #repairable
end

local function main()
  while true do
    io.write("> ")
    local data = io.read()
    local words = {}
    for word in data:gmatch("%S+") do
      table.insert(words, word)
    end
    local cmd = table.remove(words, 1)
    
    if funcs[cmd] then
      funcs[cmd](words)
    end
  end
end

funcs.exit = function()
  os.exit()
end

local function compareEnchantments(enchs)
  for i = 1, #enchs do
    local enchantment = enchs[i].label:gsub(" %w+$",
    function(c)
      if not c then
        return
      end
      c = c:upper()
      for i = 2, #c do
        if not enchNumbers[c:sub(i, i)] then
          return c
        end
      end
      return ""
    end)
    
    if encList[enchantment] then
      return true
    end
  end
  
  return false
end

local function searchSide(item)
  local label = item.label
  local name = item.name
  local fname = string.format("%s|%s", label, name)
  local modName = name:match("(.+):")
  local enchantments = item.enchantments
  
  if customSearch and custom[label] then
    return sides.cst
  end
  
  if enchantments and enchSearch then
    if ignoreEnchsList or compareEnchantments(enchantments) then
      return sides.enc
    end
  end
  
  if aspectSearch and item.aspects then
    for k, v in pairs(item.aspects) do
      if aspects[k] then
        return sides.asp
      end
    end
  end
  
  if (blActiveItems and blItems[fname]) or (blActiveMods and blMods[modName]) then
    return sides.del
  end
  
  for i = 1, repairable.n do
    if name:match(repairable[i]) then
      return sides.rep
    end
  end
end

funcs.start = function()
  local src = sides.src
  print("Сортировка начата. Для остановки нажмите F1")
  
  while true do
    local allItems = transposer.getAllStacks(src).getAll()
    for i = 1, #allItems do
      local side = searchSide(allItems[i])
      
      if side then
        transposer.transferItem(src, side, _, i)
      end 
    end
    
    local _, _, key, code = event.pull(10, "key_down")
    if key == 0 and code == 59 then
      break
    end
  end
end

local function writeToFile(name, tbl)
  local file = io.open(name, "w")
  for k, v in pairs(tbl) do
    file:write(k .. "\n")
  end
  file:close()
end

local function addToBlacklist(name, mod)
  local tbl = mod and blMods or blItems
  local str = mod and "Мод" or "Предмет"
  local fileName = mod and "mods" or "blacklist"
  
  if tbl[name] then
    return str .. " уже в черном списке: " .. name, false
  end
  
  tbl[name] = true
  writeToFile(fileName, tbl)
  
  return str .. " добавлен в черный список: " .. name, true
end

local function showPage(n)
  local s = (n - 1) * rowCount + 1
  local f = rowCount * n
  
  for i = s, f do
    if not pagesContent[i] then
      break
    end
    print(i .. " " .. pagesContent[i])
  end
  
  print(string.format("\nСтраница %s из %s\n", n, pagesContent.count))
end

funcs.page = function(args)
  local pg = tonumber(args[1])
  
  if not pg or pg < 1 or pg > pagesContent.count then
    print("Страница указана не верно")
    return
  end
  
  showPage(pg)
end

local function deleteFromBlacklist(name, mod)
  local tbl = mod and blMods or blItems
  local str = mod and "Мод" or "Предмет"
  local fileName = mod and "mods" or "blacklist"
  
  tbl[name] = nil
  writeToFile(fileName, tbl)
  
  return string.format("%s удален из черного списка: %s", str, name), true
end

funcs.bl = function(args)
  local cmd = args[1]
  local nmb = tonumber(args[2])
  local side = sides[args[3]]
  local mod = args[4]
  
  if not cmd then
    local tbl = mod and blMods or blItems
    
    for k, v in pairs(tbl) do
      table.insert(pagesContent, k)
    end
    pagesContent.count = math.ceil(#pagesContent / rowCount)
    
    showPage(1)
    
    return
  end
  
  if cmd == "add" then
    if not nmb then
      print("Не указан слот")
      return
    end
    
    if not side then
      print("Не указана сторона")
      return
    end
    
    local stack = transposer.getStackInSlot(side, nmb)
    local name
    
    if mod then
      name = stack.name:match("(.+):")
    else
      name = stack.label .. "|" .. stack.name
    end
    
    local result = addToBlacklist(name, mod)
    print(result)
    
    return
  end
  
  if cmd == "del" then
    if not nmb or nmb < 1 or nmb > #pagesContent then
      print("Номер предмета или мода указан не верно")
      return
    end
    
    local result = deleteFromBlacklist(pagesContent[nmb], mod)
    print(result)
    
    pagesContent = {count = 0}
    
    return
  end
end

init()
main()