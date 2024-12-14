local crafting = component.proxy(component.list("crafting")())
local modem = component.proxy(component.list("modem")())

component.proxy(component.list("robot")()).select(13)
modem.open(4)

while true do
  local _, _, _, _, _, message = computer.pullSignal()
  if message == "craft" then
    computer.pullSignal(0.5)
    local result = crafting.craft()
    modem.broadcast(4, result)
  end
end