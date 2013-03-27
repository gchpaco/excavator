local announceChannel = 1
local statusChannel = nil
local digTimeout = 5
local modem = peripheral.wrap("right")
replyChannel = math.random(2, 65536)
modem.open(replyChannel)

-- announce presence to server and figure out what we should do
modem.transmit(announceChannel, replyChannel, "hello "..os.getComputerID())
lastHello = os.clock()

while true do
   local event, modemSide, senderChannel,
   replyChannel, rawMessage, senderDistance = os.pullEvent("modem_message")

   if rawMessage == "dig" then
      statusChannel = replyChannel
      modem.open(statusChannel)
      break
   elseif lastHello == nil or lastHello - os.clock() > 5 then
      modem.transmit(announceChannel, replyChannel,
                     "hello "..os.getComputerID())
      lastHello = os.clock()
   end
end

function inventorySize()
   size = 0
   for i = 1,16 do
      size = size + turtle.getItemCount(i)
   end
   return size
end

function clearInventory()
   status = true
   for i = 1,16 do
      if turtle.getItemCount(i) > 0 then
         turtle.select(i)
         if not turtle.drop() then
            status = false
         end
      end
   end
   return status
end

function startDigging()
   turtle.select(1)
   turtle.place()
   turtle.turnLeft()
   turtle.turnLeft()
end

startDigging()
local status = "digging"

while true do
   timeout = os.startTimer(5)
   local event, param1, param2, param3, param4, param5 = os.pullEvent()
   if event == "timer" and param1 == timeout then
      -- happens for many reasons.  First, is the inventory clear?
      if status != "ready" and inventorySize() == 0 then
         turtle.turnLeft()
         turtle.turnLeft()
         turtle.dig()
         status = "ready"
      else
         -- okay, clear the inventory
         if clearInventory() then
            status = "digging"
         else
            status = "backlogged"
         end
      end
   elseif event == "timer" and param1 ~= timeout then
      -- probably a stale timer.  Ignore it.
   elseif event == "modem_message" then
      message = param4
      if message == "dig" and status == "ready" then
         startDigging()
         status = "digging"
      elseif message == "report" then
         replyChannel = param3
         modem.transmit(replyChannel, statusChannel,
                        status.." "..os.getComputerID())
      else
         print("Got a message I couldn't understand: "..message)
      end
   else
      print("Got an event I couldn't understand: "..event)
   end
end
