require("atlas")

unit.hide()

function calcDistance(origCenter, destCenter, location)
    local pipe = (destCenter - origCenter):normalize()
    local r = (location-origCenter):dot(pipe) / pipe:dot(pipe)
    if r <= 0. then
       return (location-origCenter):len()
    elseif r >= (destCenter - origCenter):len() then
       return (location-destCenter):len()
    end
    local L = origCenter + (r * pipe)
    pipeDistance =  (L - location):len()

    return pipeDistance
end

function calcDistanceStellar(stellarObjectOrigin, stellarObjectDestination, currenLocation)
    local origCenter = vec3(stellarObjectOrigin.center)
    local destCenter = vec3(stellarObjectDestination.center)

    return calcDistance(origCenter, destCenter, currenLocation)
end

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

        if showClosestPipe == true or showClosestPipeDist == true or 
                showAliothClosestPipe == true or showAliothClosestPipeDist == true then
            closestPlanet = _stellarObjects[nearestPlanet]
            nearestPipeDistance = nil
            nearestAliothPipeDistance= nil
            for obj in pairs(_stellarObjects) do
                for obj2 in pairs(_stellarObjects) do
                    if (obj2 > obj) then
                        pipeDistance = calcDistanceStellar(_stellarObjects[obj], _stellarObjects[obj2], currentLocation)

                        if nearestPipeDistance == nil or pipeDistance < nearestPipeDistance then
                            nearestPipeDistance = pipeDistance;
                            sortestPipeKeyId = obj;
                            sortestPipeKey2Id = obj2;
                        end

                        if _stellarObjects[obj].name == "Alioth" and (nearestAliothPipeDistance == nil or pipeDistance < nearestAliothPipeDistance) then
                            nearestAliothPipeDistance = pipeDistance;
                            sortestAliothPipeKeyId = obj;
                            sortestAliothPipeKey2Id = obj2;
                        end
                    end
                end
            end

            if showClosestPipe == true then
                closestPipeData.value = _stellarObjects[sortestPipeKeyId].name .. " - " .. _stellarObjects[sortestPipeKey2Id].name
                system.updateData(closestPipeDataId, json.encode(closestPipeData))
            end

            if showClosestPipeDist == true then
                closestPipeDistData.value = string.format("%03.2f", nearestPipeDistance / 200000.0)
                system.updateData(closestPipeDistDataId, json.encode(closestPipeDistData))
            end

            if showAliothClosestPipe == true then
                closestAliothPipeData.value = _stellarObjects[sortestAliothPipeKeyId].name .. " - " .. _stellarObjects[sortestAliothPipeKey2Id].name
                system.updateData(closestAliothPipeDataId, json.encode(closestAliothPipeData))
            end

            if showAliothClosestPipeDist == true then
                closestAliothPipeDistData.value = string.format("%03.2f", nearestAliothPipeDistance / 200000.0)
                system.updateData(closestAliothPipeDistDataId, json.encode(closestAliothPipeDistData))
            end
        end
        currentLocation = coroutine.yield()
    end
end

local panelName = "Pipe info" --export: panel name
showClosestPlanet = true --export: show closest planet
showClosestPipe = true --export: show the closed Warp-Pipe 
showClosestPipeDist = true --export: show the closed Warp-Pipe 
showAliothClosestPipe = true
showAliothClosestPipeDist = true

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
coroutine.resume( refreshCoroutine, vec3(core.getConstructWorldPos()))
system:onEvent("update", 
    function () 
        coroutine.resume( refreshCoroutine, vec3(core.getConstructWorldPos()))
    end
)

system:onEvent("stop",
    function () 
        system.destroyWidgetPanel(panelid)
    end
)
