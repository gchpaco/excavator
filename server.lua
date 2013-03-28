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

function sendMessage(send, reply, tbl)
   tbl.sender = os.getComputerID()
   modem.transmit(send, reply, textutils.serialize(tbl))
end

lastCensus = 0

function compileCensus()
   print("Compiling census")
   sendMessage(statusChannel, statusChannel, { type="report" })
end

announceChannel = 1
statusChannel = 2
modem = peripheral.wrap("left")

modem.open(announceChannel)
modem.open(statusChannel)
local timeoutThreshold = 60
local censusThreshold = 30

census = {}
lastmsg = {}

-- first, request that everybody report in, to get an initial census.
compileCensus()
timer = os.startTimer(censusThreshold)
while true do
   local event, modemSide, senderChannel,
   replyChannel, rawMessage, senderDistance = os.pullEvent()

   if event == "timer" then
      timer = os.startTimer(censusThreshold)
   elseif event == "modem_message" and senderDistance > 0 then
      message = textutils.unserialize(rawMessage)

      if senderChannel == announceChannel then
         if message.type == "hello" then
            print("Hello, worker "..message.sender)
            census[message.sender] = "working"
            lastmsg[message.sender] = os.clock()
            sendMessage(replyChannel, statusChannel, { type="dig" })
         else
            print("Couldn't understand message "..rawMessage.." on announce")
         end
      elseif senderChannel == statusChannel then
         if message.type == "status" then
            if message.status == "digging" then
               census[message.sender] = "working"
               lastmsg[message.sender] = os.clock()
            elseif message.status == "backlogged" then
               census[message.sender] = "backlogged"
               lastmsg[message.sender] = os.clock()
            elseif message.status == "ready" then
               census[message.sender] = "ready"
               lastmsg[message.sender] = os.clock()
            end
         else
            print("Couldn't understand message "..rawMessage.." on status")
         end
      end
   end

   if os.clock() - lastCensus > censusThreshold then
      compileCensus()
      lastCensus = os.clock()
   elseif table.maxn(census) > 0 then
      local ready = true
      local readyCount = 0
      local workingCount = 0
      local backloggedCount = 0
      local deadbeats = {}
      for id, status in pairs(census) do
         if lastmsg[id] < lastCensus then
            -- evict guys who haven't responded since last census
            if os.clock() - lastmsg[id] > timeoutThreshold then
               print("Evicting "..id)
               table.insert(deadbeats, id)
            end
         elseif status == "ready" then
            readyCount = readyCount + 1
         elseif status == "working" then
            workingCount = workingCount + 1
            ready = false
         elseif status == "backlogged" then
            backloggedCount = backloggedCount + 1
            ready = false
         else
            print("Saw a status for worker "..id.." that I don't understand: "..status)
            ready = false
         end
      end
      print("Ready:      "..readyCount)
      print("Working:    "..workingCount)
      print("Backlogged: "..backloggedCount)
      print("Deadbeats:  "..table.maxn(deadbeats))

      for index, id in pairs(deadbeats) do
         table.remove(census, id)
         table.remove(lastmsg, id)
      end

      if ready and table.maxn(census) > 0 then
         print("All ready, advancing")
         inch()
         print("Now dig!")
         sendMessage(statusChannel, statusChannel, { type="dig" })
         for id,status in pairs(census) do
            census[id] = "working"
         end
      end
   end
end
