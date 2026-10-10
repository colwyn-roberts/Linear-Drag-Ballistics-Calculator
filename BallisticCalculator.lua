--config
local cannonNumber = 1
local cannonPos = {}
    cannonPos.x = -178
    cannonPos.y = 249
    cannonPos.z = 17
    cannonPos.pitch = 0
    cannonPos.yaw = 0
    cannonPos.initalYaw = 0
local cannonLength = 28

local targetPos = {}
    targetPos.x = 361
    targetPos.y = 94
    targetPos.z = -978

--if cannon is between all of these values then it will NOT fire
local limitedAngles = {}
    limitedAngles.maxpitch = 9
    limitedAngles.minpitch = -3
    limitedAngles.maxyaw = 182
    limitedAngles.minyaw = 177

--cannon redstone connections
local reloadPosition = "front" 
local buildPosition = "back" 
local firePosition = "right" 

--physics constants
local gravity = 0.05    --1 block per tick
local drag = 0.01       --0.99 blocks per tick
local velocity = 16     --acquired through statisical regression
local mass = 1          --acquired through statisical regression

--peripherals
local pitchSpeedController = peripheral.wrap("back")
local yawSpeedController = peripheral.wrap("right")
local chatBox = peripheral.wrap("front")
local redstoneController = peripheral.wrap("bottom")
local modem = peripheral.wrap("top")
modem.closeAll()

--locational variables
local PITCH_kP = 1.5
local PITCH_kD = 0
local YAW_kP = 1.5
local YAW_kD = 0

--const
local PULSE_TIME = 0.2
local MIN_SPEED = 1

--libs
require "math"

sleep(1)

function round(num)
    if num - math.floor(num) > 0.5 then
        return math.ceil(num)
    else
        return math.floor(num)
    end
end

--organizational functions
function reload()
    redstoneController.setOutput(reloadPosition,true)
    sleep(PULSE_TIME)
    redstoneController.setOutput(reloadPosition,false)
end

function fireCannon()
    redstoneController.setOutput(firePosition,true)
    sleep(PULSE_TIME)
    redstoneController.setOutput(firePosition,false)
    sleep(PULSE_TIME)
    redstoneController.setOutput(buildPosition,false) --also resets cannon for next reload
end

--original function inputing theta and using physics constants to graph the xPos of the projectile to the yPos of the projectile
function f(x,distance)
    return (((((drag*(velocity*math.sin(x)))+(mass*gravity))/(drag*velocity*math.cos(x)))*distance)  +  (((mass*mass*gravity)/(drag*drag))*math.log(1-((drag*distance)/(mass*velocity*math.cos(x))))))
end

--dirivative of f(x)
function fprime(x,distance)
    --sec(x)^2
    local sec2X = (1 / math.cos(x))
    sec2X = sec2X * sec2X
    --cos(x)^2
    local cos2X = math.cos(x)
    cos2X = cos2X * cos2X
    --full calculation
    return (distance*sec2X)  +  ((mass*gravity*distance*math.sin(x))/(mass*velocity*cos2X))  +  (((mass*mass*gravity)/(drag*drag)) * (1/(1-((drag*distance)/(mass*velocity*math.cos(x)))))*-1 *((drag*distance*math.sin(x))/(mass*velocity*cos2X)))
end

--finds pitch using linear drag
function findPitch(distance,dY)
    local coordinateDY = dY
    local coordinateDX = distance
    local i = 0
    local theta
    --repeats 5 times so dY increase from cannon angle is accounted for
    while ( i < 5) do 
        theta = 20 * (math.pi/180)
        local ii = 0
        --uses newtons method to approximate zero of function
        while (ii < 10) do
            theta = theta - ((f(theta,distance)-dY)/fprime(theta,distance))
            ii = ii + 1
        end
        dY = coordinateDY + (math.sin(theta)*cannonLength)
        distance = coordinateDX - (math.cos(theta)*cannonLength)
        i = i + 1
    end
    return theta * (180/math.pi) --converts from rad to deg
end

modem.callRemote("modem_0","open",6400+cannonNumber)
local reloadStartTime = os.clock()+7
while (true) do 
    event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
    targetPos = message
    print("> Program Start")
    redstoneController.setOutput(buildPosition,false)
    yawSpeedController.setTargetSpeed(0)
    pitchSpeedController.setTargetSpeed(0)
    while (reloadStartTime+7 > os.clock()) do sleep(0.1) end
    chatBox.sendMessageToPlayer("Reloading...","Squid_Pig","Cannon "..cannonNumber)
    print("> Reloading...")
    reloadStartTime = os.clock()
    reload()
    sleep(5-PULSE_TIME)

    print("> Finished")
    redstoneController.setOutput(buildPosition,true)
    sleep(PULSE_TIME)

    --finds pitch
    local dX = (targetPos.x - cannonPos.x)
    local dZ = (targetPos.z - cannonPos.z)
    targetPos.distance = math.sqrt((dX*dX) + (dZ*dZ)) --horizontal diff, != actual distance, doesnt account for vertical position
    local targetPitch = findPitch(targetPos.distance,targetPos.y - cannonPos.y)
    local targetYaw = (-(math.atan2(targetPos.x - cannonPos.x,targetPos.z - cannonPos.z) * (180/math.pi) ) )% 360
    chatBox.sendMessageToPlayer("Shooting ".. targetPos.distance .. "m","Squid_Pig","Cannon "..cannonNumber)

    --cannon PID
    local pitchPrevError = (targetPitch - cannonPos.pitch) 
    local pitchError = (targetPitch - cannonPos.pitch) 
    local pitchSpeed = 0
    local yawPrevError = (targetYaw - cannonPos.yaw) 
    local yawError = (targetYaw - cannonPos.yaw) 
    local yawSpeed = 0
    local prevTime = os.clock()
    chatBox.sendMessageToPlayer("Cannon PID starting","Squid_Pig","Cannon "..cannonNumber)
    print("> Cannon PID starting")
    while (math.abs(yawError) > 0.06 and (math.abs(pitchError) > 0.06))do
        --required to not break the speed controller from create's anti-ticking feature
        sleep(0.21)

        --updates cannon position
        cannonPos.pitch = modem.callRemote("block_reader_0","getBlockData").CannonPitch
        cannonPos.yaw = modem.callRemote("block_reader_0","getBlockData").CannonYaw
        --chatBox.sendMessageToPlayer("pitch error".. pitchError .. "m","Squid_Pig","Cannon "..cannonNumber)
        chatBox.sendMessageToPlayer("yawt ".. targetYaw .. "   yawc " .. cannonPos.yaw,"Squid_Pig","Cannon "..cannonNumber)
        --updates cannon position w/o block reader
        --cannonPos.pitch = ((cannonPos.pitch + ((os.clock() - prevTime)*(pitchSpeed*0.75))))
        --cannonPos.yaw = ((cannonPos.yaw + ((os.clock() - prevTime)*(yawSpeed*0.75))))
        prevTime = os.clock()

        --pd equation
        pitchError = (targetPitch - cannonPos.pitch) 
        pitchSpeed = (pitchError * PITCH_kP) + (pitchPrevError * PITCH_kD)
        yawError = (targetYaw - cannonPos.yaw) 
        local yawError2 = -1*(cannonPos.yaw + (360-targetYaw))
        if (math.abs(yawError) > math.abs(yawError2)) then
            yawError = yawError2
        end
        yawSpeed = (yawError * YAW_kP) + (yawPrevError * YAW_kD)

        --clamp pitchSpeed to [-256,256]
        if (pitchSpeed > 256) then
            pitchSpeed = 256
        elseif (pitchSpeed < -256) then
            pitchSpeed = -256
        end
        --clamp yawSpeed to [-256,256]
        if (yawSpeed > 256) then
            yawSpeed = 256
        elseif (yawSpeed < -256) then
            yawSpeed = -256
        elseif (math.abs(yawSpeed)<MIN_SPEED) then
            if (yawSpeed > 0) then
                yawSpeed = MIN_SPEED
            else
                yawSpeed = -MIN_SPEED
            end
        end
        print("Yaw: "..cannonPos.yaw .. " Error: " ..yawError .." Speed: " .. yawSpeed)
        pitchSpeedController.setTargetSpeed(-1*pitchSpeed)
        yawSpeedController.setTargetSpeed(yawSpeed)
        pitchPrevError = pitchError
        yawPrevError = yawError
    end
    chatBox.sendMessageToPlayer("Cannon Pitch: ".. cannonPos.pitch.."| Cannon Yaw: "..cannonPos.yaw,"Squid_Pig","Cannon "..cannonNumber)
    pitchSpeedController.setTargetSpeed(0)
    yawSpeedController.setTargetSpeed(0)
    sleep(5)
    if (cannonPos.pitch < limitedAngles.maxpitch and cannonPos.pitch > limitedAngles.minpitch and cannonPos.yaw > limitedAngles.minyaw and cannonPos.yaw < limitedAngles.maxyaw) then
        chatBox.sendMessageToPlayer("Aborting Fire","Squid_Pig","Cannon "..cannonNumber)
        modem.callRemote("modem_0","transmit",replyChannel,senderChannel,false)
    else
        chatBox.sendMessageToPlayer("Fired","Squid_Pig","Cannon "..cannonNumber)
        fireCannon()
        cannonPos.yaw = 180
        cannonPos.pitch = 0
        modem.callRemote("modem_0","transmit",replyChannel,senderChannel,true)
    end
end
