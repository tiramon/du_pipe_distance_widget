require("atlas")
require("utils")
require("utils2")

unit.hide()

--[[
    refresh function for closest pipe calculation and visualization
    it calculates the closest pipes and depending on current speed and current velocity vector switchs origin and destination
    then it refreshs the closests and closest alioth pipe information in the widget and redraws the visualization
]]--
refreshPipeData = function (currentLocation)
    while true do
        local smallestDistance = nil;
        local nearestPlanet = nil;

        for obj in pairs(_stellarObjects) do
            local planetCenter = vec3(_stellarObjects[obj].center)
            local distance = vec3(currentLocation - planetCenter):len() 

            if (smallestDistance == nil or distance < smallestDistance) then
                smallestDistance = distance;
                nearestPlanet = obj;
            end
        end

        if showClosestPlanet == true then
            planetInfoData.value = _stellarObjects[nearestPlanet].name
            system.updateData(planetInfoDataId, json.encode(planetInfoData))
        end

        local nearestPlanet1
        local nearestPlanet2
        local aliothPlanet1
        local aliothPlanet2

        if showClosestPipe == true or showClosestPipeDist == true or 
                showAliothClosestPipe == true or showAliothClosestPipeDist == true then
            closestPlanet = _stellarObjects[nearestPlanet]
            nearestPipeDistance = nil
            nearestAliothPipeDistance= nil
            for obj, currentPlanet1 in pairs(_stellarObjects) do
                for obj2, currentPlanet2 in pairs(_stellarObjects) do
                    if (obj2 > obj) then
                        pipeDistance = calcDistanceStellar(currentPlanet1, currentPlanet2, currentLocation)

                        if nearestPipeDistance == nil or pipeDistance < nearestPipeDistance then
                            nearestPipeDistance = pipeDistance;
                            nearestPlanet1 = currentPlanet1
                            nearestPlanet2 = currentPlanet2
                        end

                        if currentPlanet1.name == "Alioth" and (nearestAliothPipeDistance == nil or pipeDistance < nearestAliothPipeDistance) then
                            nearestAliothPipeDistance = pipeDistance;
                            aliothPlanet1 = currentPlanet1
                            aliothPlanet2 = currentPlanet2
                        end
                    end
                end
                currentLocation = coroutine.yield()
            end
            nearestPlanet1, nearestPlanet2 = switch(nearestPlanet1, nearestPlanet2, currentLocation)
            aliothPlanet1, aliothPlanet2 = switch(aliothPlanet1, aliothPlanet2, currentLocation)

            if showClosestPipe == true then
                closestPipeData.value = nearestPlanet1.name .. " - " .. nearestPlanet2.name
                system.updateData(closestPipeDataId, json.encode(closestPipeData))
            end

            if showClosestPipeDist == true then
                closestPipeDistData.value = string.format("%03.2f", nearestPipeDistance / 200000.0)
                system.updateData(closestPipeDistDataId, json.encode(closestPipeDistData))
            end

            if showAliothClosestPipe == true then
                closestAliothPipeData.value = aliothPlanet1.name .. " - " .. aliothPlanet2.name
                system.updateData(closestAliothPipeDataId, json.encode(closestAliothPipeData))
            end

            if showAliothClosestPipeDist == true then
                closestAliothPipeDistData.value = string.format("%03.2f", nearestAliothPipeDistance / 200000.0)
                system.updateData(closestAliothPipeDistDataId, json.encode(closestAliothPipeDistData))
            end

            if showVisualization == true then
                draw(nearestPlanet1, nearestPlanet2, currentLocation, nearestPipeDistance)
            end
            
           
            if currentLocation == nil then
                system.print("shutting down pipe info")
                break;
            end
        end
    end
end

--[[
    calculates the current radius or similar base on both planetary values and progress of space traveked between
]]--
function calcProportion(origin, destination, percentDone, percentVisible, add)
    local percent = math.max(0,math.min(1, add and (percentDone + percentVisible) or (percentDone - percentVisible)))
    return destination * percent + origin * (1-percent)
end

--[[
    switches planet1 and planet2 depending on current speed and movement direction
]]--
function switch(planet1, planet2, location)
    local origCenter = vec3(planet1.center);
    local destCenter = vec3(planet2.center);
    local pipe = (destCenter - origCenter)
    local pipeDirection = pipe:normalize()
    local movementVector = vec3(core.getWorldVelocity());
    local speed = movementVector:len() *3.6
    

    if speed > 0.1 then
        system.print('speed ' ..speed)
    end
    local switch = false
    if (speed < 2000 and (location-origCenter) < (location-destCenter)) then
        switch = true
    else
        local pipe2movement = signedRotationAngle(vec3(1,1,1), movementVector, pipeDirection)
        system.print('moving '..tostring(pipeDirection) .. ' '..tostring(movementVector).. ' '..pipe2movement)

        if math.abs(pipe2movement) > (math.pi/2) then
            system.print('switch target destination')
            switch = true
        end
    end

    if switch then
        return planet2, planet1
    else 
        return planet1, planet2
    end
end

--[[
    draws the visualization for the pipe given in the parameters
]]--
function draw(planet1, planet2, location, distance)
    local shipWidth = 12
    local shipHeight = 10

    local distLeftSide = 25
    local distScreenBorders = 600

    local upperPlanetY = 25
    local lowerPlanetY = upperPlanetY + distScreenBorders
    local midY = (upperPlanetY+lowerPlanetY)/2

    local visibleMeter =  math.max(10*200*1000, distance)
    local scale = 1 * (2*visibleMeter) / distScreenBorders

    local origCenter = vec3(planet1.center);
    local destCenter = vec3(planet2.center);
    local pipe = (destCenter - origCenter)

    local pipePercentDone = (location-origCenter):dot(pipe) / pipe:dot(pipe)

    local pipePercentVisible = 100*visibleMeter/pipe:len() / 100
    local pipePercentVisibleUp = pipePercentVisible
    local pipePercentVisibleDown = pipePercentVisible
    
    local pipeLengthScaled = pipe:len() / scale

    local origRadiusScaled = planet1.radius / scale
    local origAtmoScaled = (planet1.radius + planet1.noAtmosphericDensityAltitude) / scale
    local origSafeZoneScaled = planet1.safeAreaEdgeAltitude / scale

    local destRadiusScaled = planet2.radius / scale
    local destAtmoScaled = (planet2.radius + planet2.noAtmosphericDensityAltitude) / scale
    local destSafeZoneScaled = planet2.safeAreaEdgeAltitude / scale

    local scannerRange = 2 * 200*1000 /scale

    local distanceScaled = distance /scale
    
    
    local planetStuff = ''
    local rotateAngle  = 0
    local shipY = midY
    if (pipePercentDone > 1.0-pipePercentVisible and pipePercentDone < 1.0+pipePercentVisible) then
        --system.print('near target')
        pipePercentVisibleDown = pipePercentDone-1.0
        lowerPlanetY = (midY - (pipePercentVisibleDown * pipeLengthScaled))
        local pipeFlownFromCenter = pipePercentVisibleDown * pipe:len()
        if (pipePercentDone > 100.0 and math.abs(pipeFlownFromCenter) > planet2.radius) then
            rotateAngle = 90
            shipY = lowerPlanetY
        elseif pipePercentDone > 100.0 then
            local distCenter = (location-destCenter):len()
            local L = origCenter + (pipePercentDone * pipe)
            local pipeDistance =  (L - location):len()
            rotateAngle = math.deg(math.asin(pipeDistance / distCenter))
            rotateDistance = distCenter
            shipY = lowerPlanetY
        end

        planetStuff = [[
                <path id="scanner" fill="none" stroke-dasharray="5" stroke="black" d="
                    M ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    L ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ) + scannerRange))..[[,]]..lowerPlanetY..[[ 
                    A ]]..destSafeZoneScaled..[[ ]]..destSafeZoneScaled..[[ 0 0 1 ]]..(distLeftSide-(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ) + scannerRange))..[[ ]]..lowerPlanetY.. [[
                    M ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    Z"/>
                <circle id="planet-safezone" cx="]]..distLeftSide..[[" cy="]]..lowerPlanetY..[[" r="]]..destSafeZoneScaled..[[" fill="green" fill-opacity=".25"/>
                <circle id="planet-atmo"     cx="]]..distLeftSide..[[" cy="]]..lowerPlanetY..[[" r="]]..destAtmoScaled..[[" fill="green" fill-opacity=".5"/>
                <circle id="planet-surface"  cx="]]..distLeftSide..[[" cy="]]..lowerPlanetY..[[" r="]]..destRadiusScaled..[[" fill="green"/>
        ]]
    elseif (pipePercentDone > 0.-pipePercentVisible and pipePercentDone < 0.+pipePercentVisible) then
        --system.print('near origin')
        pipePercentVisibleUp = pipePercentDone
        upperPlanetY = (midY-pipePercentVisibleUp*pipeLengthScaled)
        local pipeFlownFromCenter = pipePercentVisibleUp*pipe:len()
        if pipeFlownFromCenter < 0 and math.abs(pipeFlownFromCenter) > planet1.radius then
            rotateAngle = -90
            shipY = upperPlanetY
        elseif pipeFlownFromCenter < 0 then
            local distCenter = (location- origCenter):len()
            local L = origCenter + (pipePercentDone * pipe)
            local pipeDistance =  (L - location):len()
            rotateAngle = -math.deg(math.asin(pipeDistance / distCenter))
            rotateDistance = distCenter
            shipY = upperPlanetY
        end

        planetStuff = [[
                <path id="scanner" fill="none" stroke-dasharray="5" stroke="black" d="
                    M ]]..(distLeftSide-(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    A ]]..origSafeZoneScaled..[[ ]]..origSafeZoneScaled..[[ 0 0 1 ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true) + scannerRange))..[[ ]]..upperPlanetY.. [[
                    L ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true) + scannerRange))..[[,]]..lowerPlanetY..[[ 
                    M ]]..(distLeftSide-(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    Z"/>

                <circle id="planet-safezone" cx="]]..distLeftSide..[[" cy="]]..upperPlanetY..[[" r="]]..origSafeZoneScaled..[[" fill="green" fill-opacity=".25"/>
                <circle id="planet-atmo"     cx="]]..distLeftSide..[[" cy="]]..upperPlanetY..[[" r="]]..origAtmoScaled..[[" fill="green" fill-opacity=".5"/>
                <circle id="planet-surface"  cx="]]..distLeftSide..[[" cy="]]..upperPlanetY..[[" r="]]..origRadiusScaled..[[" fill="green"/>
        ]]
    elseif (pipePercentDone <= 1.-pipePercentVisible and pipePercentDone >= pipePercentVisible) then
        --system.print('in lane')
        planetStuff = [[
                <path id="scanner" fill="none" stroke-dasharray="5" stroke="black" d="
                    M ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[
                    L ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true) + scannerRange))..[[,]]..lowerPlanetY..[[
                    M ]]..(distLeftSide+(calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[
                    Z"/>
        ]]
    end
    
    local  svg = [[
        <svg xmlns="http://www.w3.org/2000/svg" width="]]..(distLeftSide + 200)..[[" height="]]..(distScreenBorders + 50)..[[">
            <path id="pipe-safezone" fill="grey" fill-opacity=".25" d="
                M ]]..(distLeftSide-calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                L ]]..(distLeftSide-calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY ..[[ 
                L ]]..(distLeftSide+calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                Z"/>
            <path id="pipe-atmo" fill="grey" fill-opacity=".5"  d="
                M ]]..(distLeftSide-calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                L ]]..(distLeftSide-calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                Z"/>
            <path id="pipe-surface" fill="grey" fill-opacity=".75" d="
                M ]]..(distLeftSide-calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                L ]]..(distLeftSide-calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                Z"/>

            <path id="pipe-center" stroke="black" stroke-width="1" d="
                M ]]..distLeftSide..[[,]]..upperPlanetY..[[ 
                L ]]..distLeftSide..[[,]]..lowerPlanetY..[[ 
                Z"/>
        ]] .. planetStuff .. [[
                <text id="planet1-name" x="]]..distLeftSide..[[" y="]]..(upperPlanetY+20)..[[">]]..planet1.name..[[</text>
                <text id="planet2-name" x="]]..distLeftSide..[[" y="]]..(lowerPlanetY-5)..[[">]]..planet2.name..[[</text>
                <text text-anchor="end" y="]]..(midY+10)..[[">
                    <tspan x="]]..(95 + distLeftSide)..[[" >]]..string.format("%.2f",pipePercentDone*100)..[[</tspan>  
                    <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(distance)..[[</tspan>  
                    <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-calcProportion(planet1.radius, planet2.radius, pipePercentDone, 0, false)))..[[</tspan>
                    <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-calcProportion(planet1.radius+planet1.noAtmosphericDensityAltitude, planet2.radius+planet2.noAtmosphericDensityAltitude, pipePercentDone, 0, false)))..[[</tspan>
                    <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone, 0, false)))..[[</tspan>                    
                    <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone, 0, false)-scannerRange))..[[</tspan>
                    <tspan x="]]..(95 + distLeftSide)..[[" dy="20" fill="none">0</tspan>
                </text>

                <text y="]]..(midY+10)..[[">
                    <tspan x="]]..(100 + distLeftSide)..[[">%</tspan>
                    <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(distance)..[[</tspan>
                    <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-calcProportion(planet1.radius, planet2.radius, pipePercentDone, 0, false)))..[[</tspan>
                    <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-calcProportion(planet1.radius+planet1.noAtmosphericDensityAltitude, planet2.radius+planet2.noAtmosphericDensityAltitude, pipePercentDone, 0, false)))..[[</tspan>
                    <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone, 0, false)))..[[</tspan>
                    <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone, 0, false)-scannerRange))..[[</tspan>
                </text>
                <text y="]]..(midY+10)..[[">
                    <tspan x="]]..(125 + distLeftSide)..[["></tspan>
                    <tspan x="]]..(125 + distLeftSide)..[[" dy="20">center</tspan>
                    <tspan x="]]..(125 + distLeftSide)..[[" dy="20">surface</tspan>
                    <tspan x="]]..(125 + distLeftSide)..[[" dy="20">atmo</tspan>
                    <tspan x="]]..(125 + distLeftSide)..[[" dy="20">safe</tspan>
                    <tspan x="]]..(125 + distLeftSide)..[[" dy="20">scanner</tspan>
                </text>
        ]]    
        if rotateAngle == 0 then
--            system.print('no rotate')
            svg = svg .. [[
                    <g>
                        <circle cx="]]..distLeftSide..[[" cy="]]..midY..[[" r="1" fill="black"/>
                        <line x1="]]..distLeftSide..[[" y1="]]..midY..[[" x2="]]..(distLeftSide+distanceScaled)..[[" y2="]]..midY..[[" stroke="black" stroke-width="1"/>

                        <path id="ship" fill="black" d="M ]]..(shipWidth/2)..[[,0 L 0,]]..shipHeight..[[ L ]]..shipWidth..[[,]]..shipHeight..[[ Z"/ transform="translate(]]..(distLeftSide+ distanceScaled-(shipWidth/2))..[[,]]..(midY-(shipHeight/2))..[[)">
                    </g>
                </svg>
            ]] 
        else 
--            system.print('rotate')
            svg = svg .. [[
                    <g transform="rotate(]]..(rotateAngle+90)..[[ ]]..distLeftSide..[[ ]]..shipY..[[)">
                        <circle cx="]]..distLeftSide..[[" cy="]]..shipY..[[" r="1" fill="black"/>
                        <line x1="]]..distLeftSide..[[" y1="]]..shipY..[[" x2="]]..(distLeftSide+distanceScaled)..[[" y2="]]..shipY..[[" stroke="black" stroke-width="1"/>

                        <path id="ship" fill="black" d="M ]]..(shipWidth/2)..[[,]]..shipHeight..[[ L 0,0 L ]]..shipWidth..[[,0 Z"/ transform="translate(]]..(distLeftSide+ (rotateDistance/scale)-(shipWidth/2))..[[,]]..(shipY-(shipHeight/2))..[[) ">
                    </g>
                </svg>
            ]]
        end
    system.showScreen(1)
    system.setScreen([[
        <div style="position: absolute; left: ]]..visualizationX..[[px; top:]]..visualizationY..[[px;">
            <svg width="]]..((distLeftSide + 200)*visualizationScale)..[[" height="]]..((distScreenBorders + 50)*visualizationScale)..[[" viewBox="0 0 ]]..(distLeftSide + 200)..[[ ]]..(distScreenBorders + 50)..[[">
                <rect width="100%" height="100%" rx="10" ry="10" fill="white" fill-opacity="]]..visualizationOpacity..[["/>
                ]]..svg..[[
            </svg>
        </div>]])
    
end

local debug = false

local panelName = "Pipe info" --export: panel name
showClosestPlanet = true --export: show closest planet
showClosestPipe = true --export: show the closed Warp-Pipe 
showClosestPipeDist = true --export: show the closed Warp-Pipe 
showAliothClosestPipe = true
showAliothClosestPipeDist = true
showVisualization = true --export: show the svg visualization
visualizationX = 0 --export: x position of visualization
visualizationY = 0 --export: y position of visualization
visualizationScale = 1.0 --export: svg scale
visualizationOpacity = 1.0 --export

-- panel setup
panelid = system.createWidgetPanel(panelName)

if showClosestPlanet == true then
    -- closest planet
    widgetClosestPlanetId = system.createWidget(panelid, "value")
    planetInfoData = {
        value = "XYZ", 
        unit = "", 
        label = "Closest planet"
    }

    planetInfoDataId = system.createData(json.encode(planetInfoData))
    system.addDataToWidget(planetInfoDataId, widgetClosestPlanetId)
end

if showClosestPipe == true then
    -- showClosestPipe
    closestPipeId = system.createWidget(panelid, "value")
    closestPipeData = {
        value = "XYZ", 
        unit = "",
        label = "Closest Pipe"
    }

    closestPipeDataId = system.createData(json.encode(closestPipeData))
    system.addDataToWidget(closestPipeDataId, closestPipeId)
end

if showClosestPipeDist == true then
    -- showClosestPipeDist
    closestPipeDistId = system.createWidget(panelid, "value")
    closestPipeDistData = {
        value = "0.0", 
        unit = "SU",
        label = "Pipe dist."
    }

    closestPipeDistDataId = system.createData(json.encode(closestPipeDistData))
    system.addDataToWidget(closestPipeDistDataId, closestPipeDistId)
end

-- showClosestPipe
closestAliothPipeId = system.createWidget(panelid, "value")
closestAliothPipeData = {
    value = "XYZ", 
    unit = "",
    label = "Alioth Pipe"
}

closestAliothPipeDataId = system.createData(json.encode(closestAliothPipeData))
system.addDataToWidget(closestAliothPipeDataId, closestAliothPipeId)


if showAliothClosestPipeDist == true then
    -- showClosestPipeDist
    closestAliothPipeDistId = system.createWidget(panelid, "value")
    closestAliothPipeDistData = {
        value = "0.0", 
        unit = "SU",
        label = "Alioth pipe dist."
    }

    closestAliothPipeDistDataId = system.createData(json.encode(closestAliothPipeDistData))
    system.addDataToWidget(closestAliothPipeDistDataId, closestAliothPipeDistId)
end

--refreshPipeData(vec3(core.getConstructWorldPos())) end
refreshCoroutine = coroutine.create(refreshPipeData)
state, error = coroutine.resume( refreshCoroutine, vec3(core.getConstructWorldPos()))
if (state == false) then
    system.print(error);
    unit.exit();
end
system:onEvent("update", 
    function () 
        state, error = coroutine.resume( refreshCoroutine, vec3(core.getConstructWorldPos()))
        if (state == false) then
            system.print(error);
            unit.exit();
        end
    end
)

unit:onEvent("stop",
    function ()
        coroutine.resume( refreshCoroutine, nil)
        system.destroyWidgetPanel(panelid)
    end
)
