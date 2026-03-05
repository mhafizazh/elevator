import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics

-- Game constants
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240
local NUM_FLOORS = 5
local FLOOR_HEIGHT = SCREEN_HEIGHT  -- Each floor takes up full screen
local ELEVATOR_WIDTH = 80
local ELEVATOR_HEIGHT = 50
local ELEVATOR_X = 20  -- Moved to far left
local ELEVATOR_SCREEN_Y = SCREEN_HEIGHT / 2 - ELEVATOR_HEIGHT / 2  -- Fixed position on screen
local PASSENGER_SIZE = 8

-- Game state
local elevator = {
    worldY = FLOOR_HEIGHT * 0.5,  -- Position in world coordinates (start at floor 1)
    targetFloor = 1,
    currentFloor = 1,
    doorsOpen = false,
    capacity = 4,
    passengers = {}
}

local floors = {}
local score = 0
local gameTime = 0
local passengersDelivered = 0

-- Initialize floors
function initFloors()
    floors = {}
    for i = 1, NUM_FLOORS do
        floors[i] = {
            worldY = FLOOR_HEIGHT * (i - 0.5),  -- Position in world coordinates
            waitingPassengers = {}
        }
    end
end

-- Passenger class
function createPassenger(startFloor, targetFloor)
    return {
        startFloor = startFloor,
        targetFloor = targetFloor,
        inElevator = false,
        delivered = false
    }
end

-- Spawn random passenger
function spawnPassenger()
    local startFloor = math.random(1, NUM_FLOORS)
    local targetFloor
    repeat
        targetFloor = math.random(1, NUM_FLOORS)
    until targetFloor ~= startFloor
    
    local passenger = createPassenger(startFloor, targetFloor)
    table.insert(floors[startFloor].waitingPassengers, passenger)
end

-- Get elevator's current floor
function getElevatorFloor()
    local floor = math.floor(elevator.worldY / FLOOR_HEIGHT) + 1
    return math.max(1, math.min(NUM_FLOORS, floor))
end

-- Check if elevator is aligned with floor
function isAlignedWithFloor()
    local targetY = FLOOR_HEIGHT * (elevator.currentFloor - 0.5)
    return math.abs(elevator.worldY - targetY) < 15  -- Increased tolerance
end

-- Update elevator position based on crank
function updateElevator()
    local change, acceleratedChange = playdate.getCrankChange()
    
    -- Move elevator with crank (in world coordinates)
    if not elevator.doorsOpen then
        elevator.worldY = elevator.worldY + change * 0.5  -- Positive is up
        -- Clamp to valid range
        elevator.worldY = math.max(FLOOR_HEIGHT * 0.5, math.min(FLOOR_HEIGHT * (NUM_FLOORS - 0.5), elevator.worldY))
    end
    
    -- Update current floor
    elevator.currentFloor = getElevatorFloor()
end

-- Handle doors opening/closing
function toggleDoors()
    if isAlignedWithFloor() then
        elevator.doorsOpen = not elevator.doorsOpen
        
        if elevator.doorsOpen then
            -- Passengers exit if this is their floor
            local i = 1
            while i <= #elevator.passengers do
                local passenger = elevator.passengers[i]
                if passenger.targetFloor == elevator.currentFloor then
                    table.remove(elevator.passengers, i)
                    score = score + 10
                    passengersDelivered = passengersDelivered + 1
                else
                    i = i + 1
                end
            end
            
            -- Passengers enter if there's room
            local waiting = floors[elevator.currentFloor].waitingPassengers
            while #elevator.passengers < elevator.capacity and #waiting > 0 do
                local passenger = table.remove(waiting, 1)
                passenger.inElevator = true
                table.insert(elevator.passengers, passenger)
            end
        end
    end
end

-- Draw game
function drawGame()
    gfx.clear()
    
    -- Calculate camera offset (world position - screen position)
    local cameraOffset = elevator.worldY - (ELEVATOR_SCREEN_Y + ELEVATOR_HEIGHT / 2)
    
    -- Draw background floor line
    gfx.setColor(gfx.kColorBlack)
    for i = 1, NUM_FLOORS do
        local worldY = FLOOR_HEIGHT * i
        local screenY = worldY - cameraOffset
        
        -- Only draw if on screen
        if screenY > -20 and screenY < SCREEN_HEIGHT + 20 then
            gfx.drawLine(0, screenY, SCREEN_WIDTH, screenY)
        end
    end
    
    -- Draw precision zone for current floor
    local targetY = FLOOR_HEIGHT * (elevator.currentFloor - 0.5)
    local precisionZoneY = targetY - cameraOffset - ELEVATOR_HEIGHT / 2
    local zoneHeight = 10  -- Size of precision zone (±5 pixels)
    
    -- Draw precision zone indicator brackets on right side only
    if isAlignedWithFloor() then
        -- In the zone - draw filled indicator
        gfx.setColor(gfx.kColorBlack)
        gfx.setPattern({0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55})  -- Pattern fill
        gfx.fillRect(ELEVATOR_X + ELEVATOR_WIDTH + 1, precisionZoneY - zoneHeight / 2, 3, zoneHeight)
        gfx.setColor(gfx.kColorBlack)
    else
        -- Out of zone - draw outline brackets
        gfx.setColor(gfx.kColorBlack)
        -- Right bracket
        gfx.drawLine(ELEVATOR_X + ELEVATOR_WIDTH + 1, precisionZoneY - zoneHeight / 2, ELEVATOR_X + ELEVATOR_WIDTH + 4, precisionZoneY - zoneHeight / 2)
        gfx.drawLine(ELEVATOR_X + ELEVATOR_WIDTH + 4, precisionZoneY - zoneHeight / 2, ELEVATOR_X + ELEVATOR_WIDTH + 4, precisionZoneY + zoneHeight / 2)
        gfx.drawLine(ELEVATOR_X + ELEVATOR_WIDTH + 1, precisionZoneY + zoneHeight / 2, ELEVATOR_X + ELEVATOR_WIDTH + 4, precisionZoneY + zoneHeight / 2)
    end
    
    -- Draw BIG floor number in center
    gfx.setFont(gfx.getSystemFont(gfx.font.kVariantBold))
    local floorText = "FLOOR " .. elevator.currentFloor
    local textWidth = gfx.getTextSize(floorText)
    gfx.drawText(floorText, (SCREEN_WIDTH - textWidth) / 2, 10)
    gfx.setFont(gfx.getSystemFont(gfx.font.kVariantNormal))
    
    -- Draw elevator (fixed position on screen)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(ELEVATOR_X, ELEVATOR_SCREEN_Y, ELEVATOR_WIDTH, ELEVATOR_HEIGHT)
    gfx.drawRect(ELEVATOR_X - 1, ELEVATOR_SCREEN_Y - 1, ELEVATOR_WIDTH + 2, ELEVATOR_HEIGHT + 2)
    
    -- Draw elevator doors
    if elevator.doorsOpen then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(ELEVATOR_X + 20, ELEVATOR_SCREEN_Y, ELEVATOR_WIDTH - 40, ELEVATOR_HEIGHT)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(ELEVATOR_X, ELEVATOR_SCREEN_Y, ELEVATOR_WIDTH, ELEVATOR_HEIGHT)
    end
    
    -- Draw waiting passengers indicator
    local waitingCount = #floors[elevator.currentFloor].waitingPassengers
    if waitingCount > 0 then
        gfx.setColor(gfx.kColorBlack)
        local indicatorX = ELEVATOR_X + ELEVATOR_WIDTH + 30
        local indicatorY = ELEVATOR_SCREEN_Y + 15
        gfx.fillCircleAtPoint(indicatorX, indicatorY, 10)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawTextAligned(tostring(waitingCount), indicatorX, indicatorY - 4, kTextAlignment.center)
        
        -- Draw arrow pointing to waiting area
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("Waiting ->", indicatorX + 15, indicatorY - 5)
    end
    
    -- Draw info panel on right side
    local panelX = 225
    local panelY = 45
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(panelX - 10, panelY - 5, 180, 185)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(panelX - 8, panelY - 3, 176, 181)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(panelX - 10, panelY - 5, 180, 185)
    
    -- Panel title
    gfx.setFont(gfx.getSystemFont(gfx.font.kVariantBold))
    gfx.drawText("ELEVATOR", panelX + 35, panelY)
    gfx.setFont(gfx.getSystemFont(gfx.font.kVariantNormal))
    gfx.drawLine(panelX - 8, panelY + 15, panelX + 168, panelY + 15)
    
    local currentY = panelY + 22
    
    -- Show passengers in elevator section
    gfx.drawText("INSIDE:", panelX, currentY)
    currentY = currentY + 13
    gfx.drawText(#elevator.passengers .. " of " .. elevator.capacity .. " full", panelX + 8, currentY)
    currentY = currentY + 17
    
    if #elevator.passengers > 0 then
        gfx.drawText("Want to go:", panelX, currentY)
        currentY = currentY + 13
        
        -- Collect unique floors
        local floors_list = {}
        for i, passenger in ipairs(elevator.passengers) do
            table.insert(floors_list, passenger.targetFloor)
        end
        
        -- Show first 4 floors
        for i = 1, math.min(4, #floors_list) do
            gfx.drawText("  Floor " .. floors_list[i], panelX + 8, currentY)
            currentY = currentY + 13
        end
        
        if #floors_list > 4 then
            gfx.drawText("  (+" .. (#floors_list - 4) .. " more)", panelX + 8, currentY)
            currentY = currentY + 13
        end
    else
        gfx.drawText("  (Empty)", panelX + 8, currentY)
        currentY = currentY + 13
    end
    
    -- Separator
    currentY = currentY + 5
    gfx.drawLine(panelX - 8, currentY, panelX + 168, currentY)
    currentY = currentY + 10
    
    -- Show waiting passengers at current floor
    gfx.drawText("WAITING:", panelX, currentY)
    currentY = currentY + 13
    
    if waitingCount > 0 then
        gfx.drawText(waitingCount .. " people here", panelX + 8, currentY)
        currentY = currentY + 17
        
        gfx.drawText("Want to go:", panelX, currentY)
        currentY = currentY + 13
        
        for i, passenger in ipairs(floors[elevator.currentFloor].waitingPassengers) do
            if i <= 3 then
                gfx.drawText("  Floor " .. passenger.targetFloor, panelX + 8, currentY)
                currentY = currentY + 13
            end
        end
        
        if waitingCount > 3 then
            gfx.drawText("  (+" .. (waitingCount - 3) .. " more)", panelX + 8, currentY)
        end
    else
        gfx.drawText("  (Nobody)", panelX + 8, currentY)
    end


    
    -- Draw status bar at bottom
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, SCREEN_HEIGHT - 30, SCREEN_WIDTH, 30)
    gfx.setColor(gfx.kColorWhite)
    
    -- Doors status
    local doorStatus = elevator.doorsOpen and "[OPEN]" or "[CLOSED]"
    gfx.drawText("Doors: " .. doorStatus, 10, SCREEN_HEIGHT - 25)
    
    -- Controls hint
    if isAlignedWithFloor() then
        gfx.drawText(">>> A: Open/Close <<<", 10, SCREEN_HEIGHT - 13)
    else
        local targetY = FLOOR_HEIGHT * (elevator.currentFloor - 0.5)
        local distance = math.abs(elevator.worldY - targetY)
        gfx.drawText("Align: " .. math.floor(distance) .. " away", 10, SCREEN_HEIGHT - 13)
    end
    
    -- Score
    gfx.drawText("Score: " .. score, 250, SCREEN_HEIGHT - 25)
    gfx.drawText("Delivered: " .. passengersDelivered, 250, SCREEN_HEIGHT - 13)
end

-- Initialize game
function playdate.update()
    gameTime = gameTime + 1
    
    -- Spawn passengers periodically
    if gameTime % 180 == 0 then  -- Every 3 seconds (at 60 fps)
        spawnPassenger()
    end
    
    -- Check for button presses directly in update
    if playdate.buttonJustPressed(playdate.kButtonA) then
        toggleDoors()
    end
    
    if playdate.buttonJustPressed(playdate.kButtonB) then
        if elevator.doorsOpen then
            toggleDoors()
        end
    end
    
    updateElevator()
    drawGame()
    playdate.timer.updateTimers()
end

-- Initialize game
function init()
    playdate.display.setRefreshRate(60)
    initFloors()
    
    -- Spawn initial passengers
    for i = 1, 3 do
        spawnPassenger()
    end
end

init()
