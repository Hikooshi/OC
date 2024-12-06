local transposer = component.proxy(component.list("transposer")())
local tunnel = component.proxy(component.list("tunnel")())

local sourceSide = 1
local size = transposer.getInventorySize(sourceSide)

local function empw(count, side, slots)
  for i = 1, count do
    transposer.transferItem(sourceSide, side, 1, slots[1])
    while transposer.getStackInSlot(side, 1).damage == 128 then
      os.sleep(1)
    end
    trnasposer.transferItem(side, sourceSide, 1)
    if transposer.getSlotStackSize(sourceSide, slots[1]) == 0 then
      table.remove(slots, 1)
    end
  end
end