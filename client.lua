announceChannel = 1
statusChannel = nil
digTimeout = 5
modem = peripheral.wrap("right")
replyChannel = math.random(2, 65536)
modem.open(replyChannel)

function sendMessage(send, reply, tbl)
   tbl.sender = os.getComputerID()
   modem.transmit(send, reply, textutils.serialize(tbl))
end

-- announce presence to server and figure out what we should do
sendMessage(announceChannel, replyChannel, { type="hello" })

timer = os.startTimer(5)
while true do
   local event, modemSide, senderChannel,
   hisReplyChannel, rawMessage, senderDistance = os.pullEvent()

   if event == "timer" then
      timer = os.startTimer(5)
      sendMessage(announceChannel, replyChannel, { type="hello" })
   elseif event == "modem_message" and senderDistance > 0 then
      message = textutils.unserialize(rawMessage)
      if message.type == "dig" then
         statusChannel = hisReplyChannel
         modem.open(statusChannel)
         break
      end
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
         if not turtle.dropDown() then
            status = false
         end
      end
   end
   turtle.select(1)
   return status
end

function startDigging()
   turtle.select(1)
   turtle.place()
end

startDigging()
status = "digging"

while true do
   print("Current status: "..status)
   local event, modemSide, senderChannel,
   replyChannel, rawMessage, senderDistance = os.pullEvent()
   if event == "timer" then
      timer = os.startTimer(5)
      if status ~= "ready" then
         print("Cleaning inventory")
         -- happens for many reasons.  First, is the inventory clear?
         if inventorySize() == 0 then
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
      end
   elseif event == "modem_message" then
      if senderDistance > 0 then
         print("got message "..rawMessage)
         message = textutils.unserialize(rawMessage)
         if message.type == "dig" and status == "ready" then
            startDigging()
            status = "digging"
         elseif message.type == "report" then
            sendMessage(replyChannel, statusChannel,
               { type="status", status=status })
         else
            print("Got a message I couldn't understand: "..param4)
         end
      else
         -- that's just us
      end
   else
      print("Got an event I couldn't understand: "..event)
   end
end
