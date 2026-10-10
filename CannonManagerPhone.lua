local modem = peripheral.find("modem")
local playerDetector = true
if (playerDetector) then
    playerDetector = peripheral.find("playerDetector")
end
--cannon number last digit
--0 is sending coords, 1 is receiving completion time
modem.open(6401)
modem.open(6411)

modem.open(6402)
modem.open(6412)

modem.open(6403)
modem.open(6413)

modem.open(6404)
modem.open(6414)

modem.open(6405)
modem.open(6415)

local targetPos = {}
    targetPos.x = 128
    targetPos.y = -60
    targetPos.z = -1200





print("Cannon 1")
modem.transmit(6401,6411,targetPos)
sleep(1)
print("Cannon 2")
modem.transmit(6402,6412,targetPos)
sleep(1)
print("Cannon 3")
modem.transmit(6403,6413,targetPos)
sleep(1)
print("Cannon 4")
modem.transmit(6404,6414,targetPos)
sleep(1)
print("Cannon 5")
modem.transmit(6405,6415,targetPos)

while(true) do
    event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if (message) then
        --player detector is either false or a table so this checks to see if it is a table
        if (playerDetector ~= false) then
            targetPos = playerDetector.getPlayerPos("Squid_Pig")
        end
        modem.transmit(replyChannel,senderChannel,targetPos)
    end
end