require("atlas")
require("pipe")
require("utils")

unit.hide()

--[[
    refresh function for closest pipe calculation and visualization
    it calculates the closest pipes and depending on current speed and current velocity vector switchs origin and destination
    then it refreshs the closests and closest alioth pipe information in the widget and redraws the visualization
]]--
refreshPipeData = function (currentLocation)
    while true do
        local smallestDistanceSq = nil;
        local nearestPlanet = nil;

        for obj in pairs(_stellarObjects) do
            local planetCenter = vec3(_stellarObjects[obj].center)
            local distanceSq = vec3(currentLocation - planetCenter):len2() 

            if (smallestDistanceSq == nil or distanceSq < smallestDistanceSq) then
                smallestDistanceSq = distanceSq;
                nearestPlanet = obj;
            end
        end

        if showClosestPlanet == true then
            planetInfoData.value = _stellarObjects[nearestPlanet].name
            system.updateData(planetInfoDataId, json.encode(planetInfoData))
        end

        local nearestPipe
        local aliothPipe

        if showClosestPipe == true or showClosestPipeDist == true or 
                showAliothClosestPipe == true or showAliothClosestPipeDist == true then
            closestPlanet = _stellarObjects[nearestPlanet]
            nearestPipeDistance = nil
            nearestAliothPipeDistance= nil
            local count = 0
            for ind, pipe in pairs(pipes) do
                local pipeDistance = pipe:calcDistance(currentLocation)
                --system.print(tostring(pipe) .. ' ' ..tostring(pipeDistance))
                --system.print(tostring(nearestPipeDistance).. ' '..tostring(pipeDistance))
                if nearestPipeDistance == nil or pipeDistance < nearestPipeDistance then
                    nearestPipeDistance = pipeDistance;
                    nearestPipe = pipe
                end

                if pipe.isAliothPipe and (nearestAliothPipeDistance == nil or pipeDistance < nearestAliothPipeDistance) then
                    nearestAliothPipeDistance = pipeDistance;
                    aliothPipe = pipe
                end

                count = count +1
                
                if (count % calcPipesPerFrame == 0) then
                    currentLocation = coroutine.yield()
                    count = 0

                    if currentLocation == nil then
                        system.print("shutting down pipe info")
                        return;
                    end
                end
               
            end

            aliothPlanet1, aliothPlanet2 = aliothPipe:checkSwitch(currentLocation)
            nearestPlanet1, nearestPlanet2 = nearestPipe:checkSwitch(currentLocation)

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
                draw(nearestPipe, currentLocation, nearestPipeDistance)
            end
            
            if currentLocation == nil then
                system.print("shutting down pipe info")
                break;
            end
        end
    end
end

--[[
    draws the visualization for the pipe given in the parameters
]]--
--[[
    draws the visualization for the pipe given in the parameters
]]--

function draw(pipe, location, distance)
    local shipWidth = 12
    local shipHeight = 10

    local distLeftSide = 25
    local distScreenBorders = 600

    local upperPlanetY = 25
    local lowerPlanetY = upperPlanetY + distScreenBorders
    local midY = (upperPlanetY+lowerPlanetY)/2

    local visibleMeter =  math.max(10*200*1000, distance)
    local scale = 1 * (2*visibleMeter) / distScreenBorders

    local planet1, planet2 = pipe:getPlanets()
    local origCenter, destCenter = pipe:getPlanetCenters()
    --local pipe = pipe:getPipe()

    local pipePercentDone = pipe:getPipePercentDone()

    local pipePercentVisible = 100*visibleMeter / pipe.pipeLength / 100
    local pipePercentVisibleUp = pipePercentVisible
    local pipePercentVisibleDown = pipePercentVisible
    
    local pipeLengthScaled = pipe.pipeLength / scale

    local origRadiusScaled = planet1.radius / scale
    local origAtmoScaled = (planet1.radius + planet1.noAtmosphericDensityAltitude) / scale
    local origSafeZoneScaled = planet1.safeAreaEdgeAltitude / scale

    local destRadiusScaled = planet2.radius / scale
    local destAtmoScaled = (planet2.radius + planet2.noAtmosphericDensityAltitude) / scale
    local destSafeZoneScaled = planet2.safeAreaEdgeAltitude / scale

    local scannerRange = 2 * 200*1000 /scale

    local speedVector = vec3(core.getWorldVelocity())
    local speedSq = speedVector:len2()
    local velocityAngle
    if speedSq > 0.1  then
        velocityAngle = pipe:calcAngleToVelocity(speedVector)
    end

    system.print('dist '..distance .. ' scale ' .. scale .. ' angle '.. tostring(velocityAngle) .. ' ' .. speedSq)
    local distanceScaled = distance /scale
    
    local planetStuff = ''
    local rotateAngle  = 0
    local shipY = midY
    if (pipePercentDone > 1.0-pipePercentVisible and pipePercentDone < 1.0+pipePercentVisible) then
        --system.print('near target')
        pipePercentVisibleDown = pipePercentDone-1.0
        lowerPlanetY = (midY - (pipePercentVisibleDown * pipeLengthScaled))
        local pipeFlownFromCenter = pipePercentVisibleDown * pipe.pipeLength
        if (pipePercentDone > 100.0 and math.abs(pipeFlownFromCenter) > planet2.radius) then
            rotateAngle = 90
            shipY = lowerPlanetY
        elseif pipePercentDone > 100.0 then
            local distCenter = (location-destCenter):len()
            local L = origCenter + (pipePercentDone * pipe:getPipe())
            local pipeDistance =  (L - location):len()
            rotateAngle = math.deg(math.asin(pipeDistance / distCenter))
            rotateDistance = distCenter
            shipY = lowerPlanetY
        end

        planetStuff = [[
                <path id="scanner" fill="none" stroke-dasharray="5" stroke="black" d="
                    M ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    L ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ) + scannerRange))..[[,]]..lowerPlanetY..[[ 
                    A ]]..destSafeZoneScaled..[[ ]]..destSafeZoneScaled..[[ 0 0 1 ]]..(distLeftSide-(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ) + scannerRange))..[[ ]]..lowerPlanetY.. [[
                    M ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    Z"/>
                <circle id="planet-safezone" cx="]]..distLeftSide..[[" cy="]]..lowerPlanetY..[[" r="]]..destSafeZoneScaled..[[" fill="green" fill-opacity=".25"/>
                <circle id="planet-atmo"     cx="]]..distLeftSide..[[" cy="]]..lowerPlanetY..[[" r="]]..destAtmoScaled..[[" fill="green" fill-opacity=".5"/>
                <circle id="planet-surface"  cx="]]..distLeftSide..[[" cy="]]..lowerPlanetY..[[" r="]]..destRadiusScaled..[[" fill="green"/>
        ]]
    elseif (pipePercentDone > 0.-pipePercentVisible and pipePercentDone < 0.+pipePercentVisible) then
        --system.print('near origin')
        pipePercentVisibleUp = pipePercentDone
        upperPlanetY = (midY-pipePercentVisibleUp*pipeLengthScaled)
        local pipeFlownFromCenter = pipePercentVisibleUp*pipe.pipeLength
        if pipeFlownFromCenter < 0 and math.abs(pipeFlownFromCenter) > planet1.radius then
            rotateAngle = -90
            shipY = upperPlanetY
        elseif pipePercentDone < 0 then
            local distCenter = (location-origCenter):len()
            local L = origCenter + (pipePercentDone * pipe:getPipe())
            local pipeDistance =  (L - location):len()
            rotateAngle = -math.deg(math.asin(pipeDistance / distCenter))
            rotateDistance = distCenter
            shipY = upperPlanetY
        end
        
        planetStuff = [[
                <path id="scanner" fill="none" stroke-dasharray="5" stroke="black" d="
                    M ]]..(distLeftSide-(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    A ]]..origSafeZoneScaled..[[ ]]..origSafeZoneScaled..[[ 0 0 1 ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true) + scannerRange))..[[ ]]..upperPlanetY.. [[
                    L ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true) + scannerRange))..[[,]]..lowerPlanetY..[[ 
                    M ]]..(distLeftSide-(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[ 
                    Z"/>

                <circle id="planet-safezone" cx="]]..distLeftSide..[[" cy="]]..upperPlanetY..[[" r="]]..origSafeZoneScaled..[[" fill="green" fill-opacity=".25"/>
                <circle id="planet-atmo"     cx="]]..distLeftSide..[[" cy="]]..upperPlanetY..[[" r="]]..origAtmoScaled..[[" fill="green" fill-opacity=".5"/>
                <circle id="planet-surface"  cx="]]..distLeftSide..[[" cy="]]..upperPlanetY..[[" r="]]..origRadiusScaled..[[" fill="green"/>
        ]]
    elseif (pipePercentDone <= 1.-pipePercentVisible and pipePercentDone >= pipePercentVisible) then
        --system.print('in lane')
        planetStuff = [[
                <path id="scanner" fill="none" stroke-dasharray="5" stroke="black" d="
                    M ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[
                    L ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true) + scannerRange))..[[,]]..lowerPlanetY..[[
                    M ]]..(distLeftSide+(pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false) + scannerRange))..[[,]]..upperPlanetY..[[
                    Z"/>
        ]]
    end
    
    local  svg = [[
        <svg xmlns="http://www.w3.org/2000/svg" width="]]..(distLeftSide + 200)..[[" height="]]..(distScreenBorders + 50)..[[">
            <path id="pipe-safezone" fill="grey" fill-opacity=".25" d="
                M ]]..(distLeftSide-pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                L ]]..(distLeftSide-pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY ..[[ 
                L ]]..(distLeftSide+pipe:calcProportion(origSafeZoneScaled, destSafeZoneScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                Z"/>
            <path id="pipe-atmo" fill="grey" fill-opacity=".5"  d="
                M ]]..(distLeftSide-pipe:calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                L ]]..(distLeftSide-pipe:calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+pipe:calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+pipe:calcProportion(origAtmoScaled, destAtmoScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                Z"/>
            <path id="pipe-surface" fill="grey" fill-opacity=".75" d="
                M ]]..(distLeftSide-pipe:calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
                L ]]..(distLeftSide-pipe:calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+pipe:calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleDown, true ))..[[,]]..lowerPlanetY..[[ 
                L ]]..(distLeftSide+pipe:calcProportion(origRadiusScaled, destRadiusScaled, pipePercentDone, pipePercentVisibleUp, false))..[[,]]..upperPlanetY..[[ 
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
                <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-pipe:calcProportion(planet1.radius, planet2.radius, pipePercentDone)))..[[</tspan>
                <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-pipe:calcProportion(planet1.radius+planet1.noAtmosphericDensityAltitude, planet2.radius+planet2.noAtmosphericDensityAltitude, pipePercentDone)))..[[</tspan>
                <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-pipe:calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone)))..[[</tspan>                    
                <tspan x="]]..(95 + distLeftSide)..[[" dy="20">]]..formatDistance(math.max(0,distance-pipe:calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone)-scannerRange))..[[</tspan>
                <tspan x="]]..(95 + distLeftSide)..[[" dy="20" fill="none">0</tspan>
            </text>

            <text y="]]..(midY+10)..[[">
                <tspan x="]]..(100 + distLeftSide)..[[">%</tspan>
                <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(distance)..[[</tspan>
                <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-pipe:calcProportion(planet1.radius, planet2.radius, pipePercentDone)))..[[</tspan>
                <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-pipe:calcProportion(planet1.radius+planet1.noAtmosphericDensityAltitude, planet2.radius+planet2.noAtmosphericDensityAltitude, pipePercentDone)))..[[</tspan>
                <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-pipe:calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone)))..[[</tspan>
                <tspan x="]]..(100 + distLeftSide)..[[" dy="20">]]..unitDistance(math.max(0,distance-pipe:calcProportion(planet1.radius+planet1.safeAreaEdgeAltitude, planet2.radius+planet2.safeAreaEdgeAltitude, pipePercentDone)-scannerRange))..[[</tspan>
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
        if rotateAngle ~= nil and rotateAngle == 0 then
            --system.print('no rotate')
            svg = svg .. [[
                    <g>
                        <circle cx="]]..distLeftSide..[[" cy="]]..midY..[[" r="1" fill="black"/>
                        <line x1="]]..distLeftSide..[[" y1="]]..midY..[[" x2="]]..(distLeftSide+distanceScaled)..[[" y2="]]..midY..[[" stroke="black" stroke-width="1"/>

                        <path id="ship" fill="black" d="M ]]..(shipWidth/2)..[[,]]..shipHeight..[[ L 0,0 L ]]..shipWidth..[[,0 Z"/ transform="translate(]]..(distLeftSide + distanceScaled - (shipWidth/2))..[[,]]..(midY - (shipHeight/2))..[[)"/>
                    ]]
                   
            if speedSq > 0.1 then
                svg = svg..[[    <line id="currentcourse" x1="]]..(distLeftSide + distanceScaled)..[[" y1="]]..(midY+40)..[[" x2="]]..(distLeftSide + distanceScaled)..[[" y2="]]..(midY)..[[" stroke-width="1" stroke="red" transform="rotate(]]..velocityAngle..[[ ]]..(distLeftSide + distanceScaled)..[[ ]]..(midY)..[[)"/>]]
            end
            svg = svg .. '</g>'
        else 
            --system.print('rotate')
            svg = svg .. [[
                    <g transform="rotate(]]..(rotateAngle+90)..[[ ]]..distLeftSide..[[ ]]..shipY..[[)">
                        <circle cx="]]..distLeftSide..[[" cy="]]..shipY..[[" r="1" fill="black"/>
                        <line x1="]]..distLeftSide..[[" y1="]]..shipY..[[" x2="]]..(distLeftSide+distanceScaled)..[[" y2="]]..shipY..[[" stroke="black" stroke-width="1"/>

                        <path id="ship" fill="black" d="M ]]..(shipWidth/2)..[[,]]..shipHeight..[[ L 0,0 L ]]..shipWidth..[[,0 Z"/ transform="translate(]]..(distLeftSide + (rotateDistance/scale) - (shipWidth/2))..[[,]]..(shipY-(shipHeight/2))..[[) "/>
                    ]]
            if speedSq > 0.1 then
                svg = svg..[[<line id="currentcourse" x1="]]..(distLeftSide + (rotateDistance/scale))..[[" y1="]]..(shipY+40)..[[" x2="]]..(distLeftSide + (rotateDistance/scale))..[[" y2="]]..(shipY)..[[ stroke-width="1" stroke="red" transform="rotate(]]..(velocityAngle - (rotateAngle+90))..[[  ]]..(distLeftSide + (rotateDistance/scale))..[[ ]]..(shipY)..[[)"/>]]
            end
            svg = svg .. '</g>'
        end
        svg = svg ..  [[
                </svg>
        ]] 
    system.showScreen(1)
    system.setScreen([[
        <div style="position: absolute; left: ]]..visualizationX..[[px; top:]]..visualizationY..[[px;">
            <svg width="]]..((distLeftSide + 200)*visualizationScale)..[[" height="]]..((distScreenBorders + 50)*visualizationScale)..[[" viewBox="0 0 ]]..(distLeftSide + 200)..[[ ]]..(distScreenBorders + 50)..[[">
                <rect width="100%" height="100%" rx="10" ry="10" fill="white" fill-opacity="]]..visualizationOpacity..[["/>
                ]]..svg..[[
            </svg>
        </div>]])
    
end
--init pipes
system.print('initializing pipes')
pipes = {}
local countPipes = 0
for obj, currentPlanet1 in pairs(_stellarObjects) do
    for obj2, currentPlanet2 in pairs(_stellarObjects) do
        if (obj < obj2) then
            table.insert(pipes, Pipe:new(currentPlanet1, currentPlanet2))
            countPipes = countPipes +1
        end
    end
end
system.print('initialized '..countPipes..' pipes')
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
visualizationOpacity = 1.0 --export: opacity of visualization
calcPipesPerFrame = 10 --export: currently total of 78 pipes, reduce this if load is to much

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

refreshCoroutine = coroutine.create(refreshPipeData)
state, errorResponse = coroutine.resume( refreshCoroutine, vec3(core.getConstructWorldPos()))
if (state == false) then
    system.print(errorResponse)
    unit.exit()
end

system:onEvent("update", 
    function () 
        state, errorResponse = coroutine.resume( refreshCoroutine, vec3(core.getConstructWorldPos()))
        if (state == false) then
            system.print(errorResponse)
            unit.exit()
        end
    end
)

unit:onEvent("stop",
    function ()
        state, errorResponse = coroutine.resume( refreshCoroutine, nil)
        if (state == false) then
            system.print(errorResponse)
            unit.exit()
        end
        system.destroyWidgetPanel(panelid)
    end
)

