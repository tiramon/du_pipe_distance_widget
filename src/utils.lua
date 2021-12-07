--[[
    formats the given distance in meter in km, su depending on size
]]--
function formatDistance(distanceInMeter)
    if (distanceInMeter > 0.5 * 200*1000) then
        return string.format("%.2f",distanceInMeter/(200*1000))
    elseif (distanceInMeter > 500) then
        return string.format("%.2f",distanceInMeter/1000)
    else 
        return string.format("%.2f", distanceInMeter)
    end
end

--[[
    returns the right unit for the result of formatDistance
]]--
function unitDistance(distanceInMeter)
    if (distanceInMeter > 0.5 * 200*1000) then
        return 'su'
    elseif (distanceInMeter > 500) then
        return 'km'
    else 
        return 'm'
    end
end

--[[
    calculates the signed angle between vecA and vecB on plane normal
]]--
function signedRotationAngle(normal, vecA, vecB)
    return math.atan(vecA:cross(vecB):dot(normal), vecA:dot(vecB))
end

--[[
    calculates the distance between the location and the closest point of the line connecting the vec3 origCenter and destCenter
]]--
function calcDistance(origCenter, destCenter, location)
    local pipe = (destCenter - origCenter):normalize()
    local r = (location - origCenter):dot(pipe) / pipe:dot(pipe)
    if r <= 0. then
       return (location - origCenter):len()
    elseif r >= (destCenter - origCenter):len() then
       return (location - destCenter):len()
    end
    local L = origCenter + (r * pipe)
    pipeDistance =  (L - location):len()

    return pipeDistance
end

--[[
    calculates the distance between the location and the closest point of the line connecting the center of the planets stellarObjectOrigin and stellarObjectDestination
]]--
function calcDistanceStellar(stellarObjectOrigin, stellarObjectDestination, currenLocation)
    local origCenter = vec3(stellarObjectOrigin.center)
    local destCenter = vec3(stellarObjectDestination.center)

    return calcDistance(origCenter, destCenter, currenLocation)
end
