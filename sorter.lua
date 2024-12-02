local component = require("component")
local transposer = component.transposer
local gpu = component.gpu
local serialization = require("serialization")
local event = require("event")
local term = require("term")

local sides = {src = 1, del = 4, rep = 5, asp = 0, enc = 2, wls = 3}
local blacklist = {}
local whitelist = {}
local matBlacklist = {}
local encList = {}
local aspects = {}
local repairable = {helm = true, chest = true, leg = true, boots = true, sword = true, axe = true, shovel = true, feet = true, head = true}
local enchNumbers = {I = true, V = true, X = true}
local options = {bl = {"черном списке", "черный список", "blacklist"},
                 enc = {"списке зачарований", "список зачарований", "enchantments"},
                 asp = {"списке аспектов", "список аспектов", "aspects"},
                 wl = {"белом списке", "белый список", "whitelist"},
                 mat = {"списке материалов", "список материалов", "matblacklist"},
                 rep = {"списке ремонта", "список ремонта", "repairable"}}

local settings = {mbl = true, ibl = true, mwl = false, iwl = false, iel = true, enc = false, asp = false, mat = true, aspect = nil}
local description = {mbl = "Черный список модов",
                     ibl = "Черный список предметов",
                     mwl = "Белый список модов",
                     iwl = "Белый список предметов",
                     iel = "Игнорировать список зачарований",
                     enc = "Включить поиск зачарований",
                     asp = "Включить поиск аспектов",
                     mat = "Черный список материалов"}

local _, height = gpu.getResolution()
local rowCount = height - 5

local funcs = {}
local pagesContent = {count = 0}

local function init()
  local association = {blacklist = blacklist,
                       enchantments = encList,
                       aspects = aspects,
                       matblacklist = matBlacklist,
                       whitelist = whitelist,
                       repairable = repairable}
  for k, v in pairs(association) do
    local file = io.open(k, "r")
    if file then
      for line in file:lines() do
        v[line] = true
      end
      file:close()
    end
  end
  
  local serialized = {sides = sides,
                      settings = settings}
  for k, v in pairs(serialized) do
    local file = io.open(k, "r")
    if file then
      v = serialization.unserialize(file:read())
      file:close()
    end
  end
end

local function main()
  term.clear()
  while true do
    io.write("> ")
    local data = io.read()
    local words = {}
    for word in data:gmatch("%S+") do
      table.insert(words, word)
    end
    local cmd = table.remove(words, 1)
    
    if funcs[cmd] then
      local result = funcs[cmd](words)
      if result then
        print(result)
      end
    else
      print("Неверно введена команда")
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
    
    if encList[enchantment:lower()] then
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
  local itemAspects = item[settings.aspect]
  
  if name == "minecraft:air" then
    return false
  end
  
  if (settings.iwl and whiteList[fname]) or (settings.mwl and whiteList[modName]) then
    return sides.wls
  end
  
  if enchantments and settings.enc then
    if settings.iel or compareEnchantments(enchantments) then
      return sides.enc
    end
  end
  
  if settings.asp and itemAspects then
    for k, v in pairs(itemAspects) do
      if aspects[k] then
        return sides.asp
      end
    end
  end
  
  if (settings.ibl and blItems[fname]) or (settings.mbl and blMods[modName]) then
    return sides.del
  end
  
  if settings.mat then
    for k, v in pairs(matBlacklist) do
      if name:match(k) then
        return sides.del
      end
    end
  end
  
  for k, v in pairs(repairable) do
    if name:match(k) then
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

local function writeToFile(name, serialize, tbl)
  if not tbl then
    return
  end
  local file = io.open(name, "w")
  
  if serialize then
    file:write(serialization.serialize(tbl))
  else
    local str = ""
    for k, v in pairs(tbl) do
      str = str .. k .. "\n"
    end
    file:write(str)
  end
  file:close()
end

local function addToList(list, name, option)
  if list[name] then
    return string.format("Значение уже в %s: %s", option[1], name), false
  end
  
  list[name] = true
  writeToFile(option[3], false, list)
  
  return string.format("Значение добавлено в %s: %s", option[2], name), true
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
    return "Страница указана не верно"
  end
  
  showPage(pg)
end

local function removeFromList(list, name, option)
  list[name] = nil
  writeToFile(option[3], false, list)
  
  return string.format("Значение больше не в %s: %s", option[1], name), true
end

local function updatePagesData(tbl)
  pagesContent = {count = 0}
  local n = 0
  
  if not tbl then
    return
  end
  
  for k, v in pairs(tbl) do
    table.insert(pagesContent, k)
    n = n + 1
  end
  pagesContent.count = math.ceil(n / rowCount)
end

local function commonFunction(args, list, option)
  local cmd = args[1]
  local data = tonumber(args[2]) or args[2]
  
  if not cmd then
    updatePagesData(list)
    showPage(1)
    
    return
  end
  
  if not data then
    return "Не указан второй параметр"
  end
  
  if cmd == "add" then
    if type(data) == "string" then
      data = data:lower()
    end
    
    return addToList(list, data, option)
  end
  
  if cmd == "del" then
    local value = pagesContent[data]
    if not value then
      return "Неверно указан номер"
    end
    
    return removeFromList(list, value, option)
  end
  
  return "Команда введена не верно"
end

local function changeSetting(setting, value)
  settings[setting] = value
  writeToFile("settings", true, settings)
  
  return "Опция изменена", true
end

funcs.settings = function(args)
  local setting = args[1]
  local value = args[2]
  
  if not setting then
    for k, v in pairs(settings) do
      if description[k] then
        print(k, v, description[k])
      end
    end
    
    return
  end
  
  if settings[setting] == nil then
    return "Опции не существует"
  end
  
  if not value then
    return "Не указано значение опции (true или false)"
  end
  
  if value == "true" then
    value = true
  elseif value == "false" then
    value = false
  else
    return "Значение опции должно быть true или false"
  end
  
  return changeSetting(setting, value)
end

funcs.bl = function(args)
  local cmd = args[1]
  local nmb = tonumber(args[2])
  local side = sides[args[3]]
  local mod = args[#args] == "mod" and true or false
  
  if cmd == "add" then
    if not nmb then
      return "Не указан слот"
    end
    
    if not side then
      return "Не указана сторона"
    end
    
    local stack = transposer.getStackInSlot(side, nmb)
    if not stack then
      return "Слот пуст"
    end
    
    local name
    if mod then
      name = stack.name:match("(.+):")
    else
      name = stack.label .. "|" .. stack.name
    end
    
    return addToList(blacklist, name, options.bl)
  end
  
  return commonFunction(args, blacklist, options.bl)
end

local function changeSide(side, nmb)
  sides[side] = nmb
  writeToFile("sides", true, sides)
  
  return "Значение стороны изменено", true
end

funcs.sides = function(args)
  local side = args[1]
  local nmb = tonumber(args[2])
  
  if not side then
    for k, v in pairs(sides) do
      print(k, v)
    end
    return
  end
  
  if not sides[side] then
    return "Неверно указана сторона"
  end
  
  return changeSide(side, nmb)
end

funcs.get = function(args)
  local side = sides[args[1]]
  local slot = tonumber(args[2])
  local tbl = args[3]
  
  if not side then
    return "Сторона указана не верно"
  end
  
  local size = transposer.getInventorySize(side)
  if not slot or slot < 1 or slot > size then
    return "Слот указан не верно"
  end
  
  local data = transposer.getStackInSlot(side, slot)
  if not data then
    return "Слот пуст"
  end
  
  if tbl then
    if type(data[tbl]) ~= "table" then
      return "Значение " .. tbl .. " не является таблицей"
    end
    
    data = data[tbl]
  end
  
  for k, v in pairs(data) do
    local str = type(v) == "table" and "Таблица" or v
    print(k, str)
  end
end

funcs.enc = function(args)
  return commonFunction(args, encList, options.enc)
end

funcs.wl = function(args)
  return commonFunction(args, whitelist, options.wl)
end

funcs.asp = function(args)
  local cmd = args[1]
  local data = tonumber(args[2]) or args[2]
  
  if cmd == "getasp" then
    return aspect or "Аспект не установлен"
  end
  
  if cmd == "setasp" then
    if not data then
      return "Не указано название аспекта"
    end
    aspect = data
    writeToFile("settings", true, settings)
    
    return "Значение аспекта установлено, как " .. data
  end
  
  return commonFunction(args, aspects, options.asp)
end

funcs.mat = function(args)
  return commonFunction(args, matBlacklist, options.mat)
end

funcs.rep = function(args)
  return commonFunction(args, repairable, options.rep)
end

init()
main()