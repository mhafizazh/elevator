CrankSystem = {}
CrankSystem.__index = CrankSystem

function CrankSystem.new(degreesPerStep, initialValue)
	local self = setmetatable({}, CrankSystem)
	self.degreesPerStep = degreesPerStep or 360
	self.value = initialValue or 0
	self.accumulator = 0
	return self
end

function CrankSystem:update(crankChange)
	self.accumulator = self.accumulator + crankChange

	while math.abs(self.accumulator) >= self.degreesPerStep do
		if self.accumulator > 0 then
			self.value = self.value + 1
			self.accumulator = self.accumulator - self.degreesPerStep
		else
			self.value = self.value - 1
			self.accumulator = self.accumulator + self.degreesPerStep
		end
	end
end

function CrankSystem:getValue()
	return self.value
end
