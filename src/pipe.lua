minSpeed = 40/3.6
safezoneHeight = 500000

Pipe = {
    planet1 = nil,
    planet2 = nil,
    planet1Center = nil,
    planet2Center = nil,
    pipe = nil,
    pipeNormalized = nil,
    pipeLength = nil,
    isAliothPipe = false,

    pipeDistance = nil,
    pipePercentDone = nil,
    reversed = false
}
function Pipe:new(planet1, planet2)
    if (planet1 == nil) then
        error('Pipe creation with nil value for planet1')
    elseif (planet1 == nil) then
        error('Pipe creation with nil value for planet2')
    end
    o = {}   -- create object if user does not provide one
    setmetatable(o, self)
    o.planet1 = planet1
    o.planet2 = planet2
    o.planet1Center = vec3(planet1.center)
    o.planet2Center = vec3(planet2.center)
    o.pipe =  (o.planet2Center - o.planet1Center)
    o.pipeNormalized =  o.pipe:normalize()
    o.pipeLength = o.pipe:len()
    o.isAliothPipe = planet1.name[1] == 'Alioth' or planet2.name[1] == 'Alioth'
    
    self.__index = self
    return o
end

function Pipe:calcDistance(location)
    self.pipePercentDone = (location-self.planet1Center):dot(self.pipe) / self.pipe:dot(self.pipe)

    local r = (location - self.planet1Center):dot(self.pipeNormalized) / self.pipeNormalized:dot(self.pipeNormalized)
    if r <= 0. then
       return (location - self.planet1Center):len()
    elseif r >= self.pipeLength then
       return (location - self.planet2Center):len()
    end
    local L = self.planet1Center + (r * self.pipeNormalized)

    self.pipeDistance =  (L - location):len()
    
    return self.pipeDistance
end

function Pipe:calcProportion(planet1Value, planet2Value, percentVisible, add)
    percentVisible = percentVisible or 0
    add = add or true
    local percent = math.max(0,math.min(1, add and (self:getPipePercentDone() + percentVisible) or (self:getPipePercentDone() - percentVisible)))
    return planet2Value * percent + planet1Value * (1 - percent)
end

function Pipe:calcProportionRadius(percentVisible, add)
    return self:calcProportion(self:getPlanet1().radius, self:getPlanet2().radius, percentVisible, add)
end

function Pipe:calcProportionAtmo(percentVisible, add)
    return self:calcProportion(self:getPlanet1().atmosphereRadius, self:getPlanet2().atmosphereRadius, percentVisible, add)
end

function Pipe:calcProportionSafezone(percentVisible, add)
    return self:calcProportion(self:getPlanet1().radius + safezoneHeight, self:getPlanet2().radius + safezoneHeight, percentVisible, add)
end

function Pipe:isAliothPipe()
    return self.isAliothPipe
end

function Pipe:__tostring()
    return self.planet1.name[localization] .. ' -> ' .. self.planet2.name[localization]
end

function Pipe:calcAngleToVelocity(velocityVector)
    return math.deg(signedRotationAngle(vec3(1,1,1), velocityVector, self:getPipe()))
end

function Pipe:checkSwitch(currentLocation)
    local currentSpeed = vec3(core.getWorldVelocity())
    
    self.reversed = false
    if (currentSpeed:len2() < (minSpeed*minSpeed) and (currentLocation - self.planet1Center) < (currentLocation - self.planet2Center)) then
        self.reversed = true
    else
        local pipe2movement = signedRotationAngle(vec3(1,1,1), currentSpeed, self.pipeNormalized)
        system.print('moving '..tostring(self.pipeNormalized) .. ' '..tostring(currentSpeed).. ' '..pipe2movement)

        if math.abs(pipe2movement) > (math.pi / 2) then
            system.print('switch target destination')
            self.reversed = true
        end
    end

    return self:getPlanets()
end

function Pipe:getPlanets() 
    if self.reversed then
        return self.planet2, self.planet1
    else 
        return self.planet1, self.planet2
    end
end
function Pipe:getPlanetCenters() 
    if self.reversed then
        return self.planet2Center, self.planet1Center
    else 
        return self.planet1Center, self.planet2Center
    end
end
function Pipe:getPlanet1()
    if self.reversed == true then
        return self.planet2
    else
        return self.planet1
    end
end

function Pipe:getPlanet2()
    if self.reversed == true then
        return self.planet1
    else
        return self.planet2
    end
end

function Pipe:getPipeNormalized()
    if self.reversed == true then
        return self.pipeNormalized * vec3(-1,-1,-1)
    else
        return self.pipeNormalized
    end
end

function Pipe:getPipe()
    if self.reversed == true then
        return self.pipe * vec3(-1,-1,-1)
    else
        return self.pipe
    end
end

function Pipe:getPipePercentDone()
    if self.reversed == true then
        return 1.0 - self.pipePercentDone
    else
        return self.pipePercentDone
    end
end
