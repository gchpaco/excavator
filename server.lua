function pulse(side)
   redstone.setOutput(side, true)
   sleep(0.2)
   redstone.setOutput(side, false)
end

function inch()
   pulse("front")
   sleep(0.6)
   pulse("front")
   sleep(0.6)
end

function translateMessage(message)
   start, stop = string.find(message, " ", 1, true)
   if start == nil then
      return nil
   else
      return string.sub(message, 1, start), string.sub(message, stop)
   end
end

local announceChannel = 1
local statusChannel = 2

local modem = peripheral.wrap("right")

function compileCensus()
   modem.transmit(statusChannel, statusChannel, "report")
   lastCensus = os.clock()
end

modem.open(announceChannel)
modem.open(statusChannel)
local timeoutThreshold = 60
local censusThreshold = 30

census = {}
lastmsg = {}

-- first, request that everybody report in, to get an initial census.
compileCensus()
while true do
   local event, modemSide, senderChannel,
   replyChannel, rawMessage, senderDistance = os.pullEvent("modem_message")

   message, sender = translateMessage(rawMessage)

   if senderChannel == announceChannel then
      if message == "hello" then
         census[sender] = "working"
         lastmsg[sender] = os.clock()
         modem.transmit(replyChannel, statusChannel, "dig")
      else
         print("Couldn't understand message "..rawMessage.." on announce")
      end
   elseif senderChannel == statusChannel then
      if rawMessage == "report" then
         -- that's just us.
      elseif message == "digging" then
         census[sender] = "working"
         lastmsg[sender] = os.clock()
      elseif message == "backlogged" then
         census[sender] = "backlogged"
         lastmsg[sender] = os.clock()
      elseif message == "ready" then
         census[sender] = "ready"
         lastmsg[sender] = os.clock()
      else
         print("Couldn't understand message "..rawMessage.." on status")
      end
   end

   local ready = true
   for id,status in pairs(census) do
      if status != "ready" then
         ready = false
      end
      if lastmsg[id] < lastCensus then
         -- evict guys who haven't responded since last census
         if os.clock() - lastmsg[id] > timeoutThreshold then
            print("Evicting "..sender)
            table.remove(census, sender)
            table.remove(lastmsg, sender)
         end
      end
   end

   if ready then
      print("all ready, advancing")
      inch()
      print("now digging")
      modem.transmit(statusChannel, statusChannel, "dig")
   elseif os.clock() - lastCensus > censusThreshold then
      print("triggering census")
      compileCensus()
   end
end
