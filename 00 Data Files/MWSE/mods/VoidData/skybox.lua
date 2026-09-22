local this = {}

local common = require("VoidData.common")

-- Location tracking variables
local isOnMasser = false
local isOnSecunda = false
local hideMoons = false

-- Main skybox variables
local wc
local skyRoot
local sky
local exteriorColorsFog

-- New skybox variables
local attributionsShareSkybox
local voidSkybox

-- Plane(t) variables
local mundus
local nirn
local magnusDummyNode
local masser
local secunda

-- Skybox time variables
local currentDay = 0
local defaultSkyboxTimes = {}
local masserSkyboxTimes = {
	sunriseHourV = 5.6460738882307,			-- These are the true anomalies for their respective fields, which were determined by averaging the output of calculateSunTimes
	sunriseHourFraction = 0.273600568374,	-- The hour/orbit.P of the (first) sunrise hour; this is needed so that the sunriseHour and sunsetHour can have the right offset
	sunriseDurationV = 0.62159833915158,
	sunsetHourV = 2.1315504440128,
	sunsetDurationV = 0.39595529547405,
}
local secundaSkyboxTimes = {
	sunriseHourV = 5.6460736048537,		-- Placeholders copied from Masser's for when Secunda is made in 2900
	sunriseHourFraction = 0.273600568374,
	sunriseDurationV = 0.6215979509126,
	sunsetHourV = 2.1315502043283,
	sunsetDurationV = 0.3959551013546,
}

-- Minor variables calculated here for the sake of ease and insignificant performance improvements
local nirnRadius = 160			-- Unfortunately the radius is not available on the niTriShapeData type even though it is present on the block itself, so it is set manually here
local masserRadius = 128
local secundaRadius = 40
local nirnRadiusSquared = nirnRadius^2
local masserRadiusSquared = masserRadius^2
local secundaRadiusSquared = secundaRadius^2
local twoPi = 2 * math.pi

-- Lighting calculation variables
local magnusPosition = tes3vector3.new(0, -1, 0):normalized() * 64800	-- The placement of Magnus relative to Mundus; this makes no difference as far as Nirn is concerned while z is 0, but does determine how the sun moves in the lunar skyboxes
local lightCutoff = math.rad(90)	-- Vertices with normals that form this angle or a greater one with the sun will be transparent or black depending on the time of day
local lightDim = math.rad(80)		-- Vertices with normals that form this angle or a lesser one will be visible; angles that range from lightDim to lightCutoff will cause the vertices to be visible, but dimmer

-- Variables for determining when sunrise and sunset begin and end in-game
local sunAbove21 = false
local sunAboveHorizon = false
local sunriseBegin
local sunriseDuration
local sunsetBegin
local sunsetDuration
local sunriseBeginV
local sunriseDurationV
local sunsetBeginV
local sunsetDurationV
local previousTimestamp
local previousV

-- Vertex color change variables
local changeVertexColors = true			-- The calculations for the vertex colors are very expensive so they are performed only when enableVertexColorChange (running on a timer) has set this to true
local worldTransformsActive = false		-- The worldTransform property returns the wrong values when a game is loaded for the first time in a session; this variable tracks when that changes so that the vertex colors can corrected very quickly without sacrificing performance later on

-- These are not true orbits given the lack of real measurements for fictional bodies/holes that can be of infinite size. They have been chosen for the sake of aesthetic appeal and bearing some resemblance to how the vanilla moons look from Nirn.
-- The final four values of these tables (s, saa, sax, and sz) do not actually relate to the orbit and are calculated in the updateOrbitTables function. They are included for the sake of convenience and essentially describe where on the moon the worldspace is located.
local masserOrbit = {
	a = 672,											-- Semi-major axis
	i = math.rad(35),									-- Inclination
	N = math.rad(266),									-- Longitude of the ascending node
	v0 = math.rad(0),									-- True anomaly at the epoch time, which is defined as the time at the start of a new game in manageOrbits
	v = math.rad(0),									-- True anomaly at the current time; a true anomaly of 0 degrees is intended to be the point where a body is directly overhead in-game (ignoring the latitude of Vvardenfell and the orbit's inclination)
	P = 24.0,											-- Orbital period in hours
	s = tes3vector3.new(0.7, -0.5, .7),					-- Location of the center of Nirn/Mundus in Masser's skybox
	saa = nil,											-- Base rotation of the Mundus system about the axis sax
	sax = nil,											-- Axis of rotation of the mundus system based on the xy components of the position s
	sz = nil											-- Base rotation of the Mundus system about its z-axis
}

local secundaOrbit = {
	a = 464,											-- Semi-major axis
	i = math.rad(50),									-- Inclination
	N = math.rad(270),									-- Longitude of the ascending node
	v0 = math.rad(175.5),								-- True anomaly at the epoch time, which is defined as the time at the start of a new game in manageOrbits
	v = math.rad(175.5),								-- True anomaly at the current time; a true anomaly of 0 degrees is intended to be the point where a body is directly overhead in-game (ignoring the latitude of Vvardenfell and the orbit's inclination)
	P = 19.2,											-- Orbital period in hours
	s = tes3vector3.new(1, 1, 1),						-- Location of the center of Nirn/Mundus in Secunda's skybox
	saa = nil,											-- Base rotation of the Mundus system about the axis sax
	sax = nil,											-- Axis of rotation of the mundus system based on the xy components of the position s
	sz = nil											-- Base rotation of the Mundus system about its z-axis
}

-- Cells that are considered part of AS
local attributionsShareCells = {
}

-- Cells that are considered part of the Void
local voidCells = {		-- Eventually there will need to be more skyboxes and thus more tables for cells that belong to The Void, but this will suffice for now
	["The Void, Aldereken"] = true,
}

function this.setupSkyboxes()
	local function setOrbitValues(orbit, radius)
		orbit.s = orbit.s:normalized() * (orbit.a - radius)		-- The skybox is effectively centered on part of the moon's surface, not the center of the moon itself
		local xyLength = math.sqrt(orbit.s.x^2 + orbit.s.y^2)
		orbit.sax = tes3vector2.new()

		if xyLength > 0 then
			local saaSign = 1
			if not ((orbit.s.x >= 0 and orbit.s.y >= 0) or (orbit.s.x < 0 and orbit.s.y < 0)) then
				saaSign = -1
			end

			orbit.saa = math.atan(saaSign * orbit.s.z / xyLength)
			orbit.sax.x = orbit.s.y / xyLength
			orbit.sax.y = orbit.s.x / xyLength

			local cos45 = math.cos(math.pi / 4)
			local sin45 = math.sin(math.pi / 4)
			local rotationMatrix = tes3matrix33.new(cos45, -sin45, 0, sin45, cos45, 0, 0, 0, 1)
			local szComponents = tes3vector3.new(orbit.s.x, orbit.s.y, 0):normalized()
			szComponents = rotationMatrix * szComponents

			if szComponents.x == szComponents.y then				-- Accounts for Nirn being directly west or east of the worlspace; after all of the work required to make the calculations work for all other positions, I didn't care to adjust the calculations below any further
				if szComponents.x > 0 then	-- West
					orbit.sz = math.pi / 2
				else						-- East
					orbit.sz = -math.pi / 2
				end
			else
				local szSign = 1
				if szComponents.y > 0 then
					szSign = -1
				end

				local szYSign = 1
				if (szComponents.x * szComponents.y) < 0 then
					szYSign = -1
				end

				orbit.sz = szSign * (math.acos(szComponents.x) + (szYSign * math.asin(szComponents.y)))
				local szFinalSign = orbit.sz / math.abs(orbit.sz)
				if math.abs(orbit.sz) > math.pi / 2 then
					orbit.sz = orbit.sz - (szFinalSign * math.pi)
				end
			end
		else
			orbit.saa = math.pi / 2
			orbit.sax.x = 1
			orbit.sz = 0
		end

	end

	local function setLunarSkyboxTimesTable(orbit, skyboxTimes)
		-- Sunrise begins and sunset ends when the sun is at the same height as the root.
		-- Sunrise ends and sunset begins when the sun is at a ~21 degree angle with the root

		local function getNormalizedAngle(v)
			while v > twoPi do	-- Naturally, math.normalizeangle doesn't work as one would expect
				v = v - twoPi
			end

			while v < 0 do
				v = v + twoPi
			end

			return v / twoPi
		end

		skyboxTimes.sunriseHour = skyboxTimes.sunriseHourFraction * orbit.P
		local offset = skyboxTimes.sunriseHour - getNormalizedAngle(skyboxTimes.sunriseHourV + orbit.v0) * orbit.P
		skyboxTimes.sunriseDuration = getNormalizedAngle(skyboxTimes.sunriseDurationV) * orbit.P

		skyboxTimes.sunsetHour = getNormalizedAngle(skyboxTimes.sunsetHourV + orbit.v0) * orbit.P + offset
		if skyboxTimes.sunsetHour < 0 then
			skyboxTimes.sunsetHour = orbit.P + skyboxTimes.sunsetHour
		end
		skyboxTimes.sunsetDuration = getNormalizedAngle(skyboxTimes.sunsetDurationV) * orbit.P

		skyboxTimes.starsFadingDuration = skyboxTimes.sunsetDuration
		skyboxTimes.starsPostSunsetStart = skyboxTimes.sunsetHour + skyboxTimes.starsFadingDuration
		skyboxTimes.starsPreSunriseFinish = skyboxTimes.sunriseHour - skyboxTimes.starsFadingDuration

		skyboxTimes.ambientPostSunriseTime = skyboxTimes.sunriseDuration
		skyboxTimes.ambientPostSunsetTime = skyboxTimes.sunsetDuration * .625
		skyboxTimes.ambientPreSunriseTime = skyboxTimes.sunriseDuration * .25
		skyboxTimes.ambientPreSunsetTime = skyboxTimes.sunsetDuration * .5

		skyboxTimes.fogPostSunriseTime = skyboxTimes.sunriseDuration * .5
		skyboxTimes.fogPostSunsetTime = skyboxTimes.sunsetDuration * .5
		skyboxTimes.fogPreSunriseTime = skyboxTimes.sunriseDuration * .25
		skyboxTimes.fogPreSunsetTime = skyboxTimes.sunsetDuration

		skyboxTimes.skyPostSunriseTime = skyboxTimes.sunriseDuration* .5
		skyboxTimes.skyPostSunsetTime = skyboxTimes.sunsetDuration * .25
		skyboxTimes.skyPreSunriseTime = skyboxTimes.sunriseDuration * .25
		skyboxTimes.skyPreSunsetTime = skyboxTimes.sunsetDuration * .75

		skyboxTimes.sunPostSunriseTime = 0
		skyboxTimes.sunPostSunsetTime = skyboxTimes.sunsetDuration * .625
		skyboxTimes.sunPreSunriseTime = 0
		skyboxTimes.sunPreSunsetTime = skyboxTimes.sunsetDuration * .5
	end

	local function addNodeToSkybox(node, attachAmbient)
		local preexistingNodes = {}
		for _,child in pairs(sky.objects.children) do
		    table.insert(preexistingNodes, child)
		    sky.objects:detachChild(child)
		end

		sky.objects:attachChild(node, true)
		for _,child in pairs(preexistingNodes) do
		    sky.objects:attachChild(child, true)
		end
		if attachAmbient then node:attachEffect(sky.light) end
		skyRoot:updateEffects()	-- Is this needed?
	end

	-- Initialize useful variables for working with the skybox
	wc = tes3.worldController.weatherController
	skyRoot = wc.sceneSkyRoot
	sky = {
		atmosphere = skyRoot.children[1],
		stars = skyRoot.children[2],
		magnus = skyRoot.children[3],
		masserVanilla = skyRoot.children[4],
		secundaVanilla = skyRoot.children[5],
		objects = skyRoot.children[6],
		light = skyRoot.children[7]
	}

	-- Save the skybox times for Nirn and set up those for the moons
	if not defaultSkyboxTimes then
		defaultSkyboxTimes.sunriseHour = wc.sunriseHour
		defaultSkyboxTimes.sunriseDuration = wc.sunriseDuration

		defaultSkyboxTimes.sunsetHour = wc.sunsetHour
		defaultSkyboxTimes.sunsetDuration = wc.sunsetDuration

		defaultSkyboxTimes.starsFadingDuration = wc.starsFadingDuration
		defaultSkyboxTimes.starsPostSunsetStart = wc.starsPostSunsetStart
		defaultSkyboxTimes.starsPreSunriseFinish = wc.starsPreSunriseFinish

		defaultSkyboxTimes.ambientPostSunriseTime = wc.ambientPostSunriseTime
		defaultSkyboxTimes.ambientPostSunsetTime = wc.ambientPostSunsetTime
		defaultSkyboxTimes.ambientPreSunriseTime = wc.ambientPreSunriseTime
		defaultSkyboxTimes.ambientPreSunsetTime = wc.ambientPreSunsetTime

		defaultSkyboxTimes.fogPostSunriseTime = wc.fogPostSunriseTime
		defaultSkyboxTimes.fogPostSunsetTime = wc.fogPostSunsetTime
		defaultSkyboxTimes.fogPreSunriseTime = wc.fogPreSunriseTime
		defaultSkyboxTimes.fogPreSunsetTime = wc.fogPreSunsetTime

		defaultSkyboxTimes.skyPostSunriseTime = wc.skyPostSunriseTime
		defaultSkyboxTimes.skyPostSunsetTime = wc.skyPostSunsetTime
		defaultSkyboxTimes.skyPreSunriseTime = wc.skyPreSunriseTime
		defaultSkyboxTimes.skyPreSunsetTime = wc.skyPreSunsetTime

		defaultSkyboxTimes.sunPostSunriseTime = wc.sunPostSunriseTime
		defaultSkyboxTimes.sunPostSunsetTime = wc.sunPostSunsetTime
		defaultSkyboxTimes.sunPreSunriseTime = wc.sunPreSunriseTime
		defaultSkyboxTimes.sunPreSunsetTime = wc.sunPreSunsetTime
	end

	-- Calculate values needed for the moons' orbits and skybox times
	setOrbitValues(masserOrbit, masserRadius)
	setOrbitValues(secundaOrbit, secundaRadius)
	setLunarSkyboxTimesTable(masserOrbit, masserSkyboxTimes)
	setLunarSkyboxTimesTable(secundaOrbit, secundaSkyboxTimes)

	-- Load relevant meshes and add them to the skybox
	attributionsShareSkybox = tes3.loadMesh("jo//jo_as_sky_01.nif")	-- These definitions need to be made after startup, or the game will crash
	voidSkybox = tes3.loadMesh("jo//jo_vd_sky_01.nif")

	mundus = tes3.loadMesh("mm//mm_sky_nirn.nif")
	nirn = mundus.children[1]
	magnusDummyNode = mundus.children[2]
	magnusDummyNode.translation = magnusPosition

	masser = tes3.loadMesh("mm//mm_sky_masser.nif")
	mundus:attachChild(masser)

	secunda = tes3.loadMesh("mm//mm_sky_secunda.nif")
	mundus:attachChild(secunda)

	addNodeToSkybox(mundus, false)
end

---@param e cellChangedEventData
function this.switchSkybox(e)
	local function hideCustomSkyboxesAndObjects()
		attributionsShareSkybox.appCulled = true
		voidSkybox.appCulled = true

		mundus.appCulled = true
		nirn.appCulled = true
		masser.appCulled = true
		secunda.appCulled = true
	end

	local function replaceSkybox(skybox)
		skyRoot:attachChild(skybox)

		-- Hide vanilla sky
		for _,node in pairs(sky) do node.appCulled = true end

		-- Show realm skybox
		skybox.appCulled = false
		sky.light.ambient = sky.light.ambient * 1	-- Adjust ambient light
		skybox:attachEffect(sky.light)

		-- Update everything
		skyRoot:update()
		skyRoot:updateProperties()
		skyRoot:updateEffects()
	end

	local function setSkyboxTimes(skyboxTimes)
		wc.sunriseHour = skyboxTimes.sunriseHour
		wc.sunriseDuration = skyboxTimes.sunriseDuration

		wc.sunsetHour = skyboxTimes.sunsetHour
		wc.sunsetDuration = skyboxTimes.sunsetDuration

		wc.starsFadingDuration = skyboxTimes.starsFadingDuration
		wc.starsPostSunsetStart = skyboxTimes.starsPostSunsetStart
		wc.starsPreSunriseFinish = skyboxTimes.starsPreSunriseFinish

		wc.ambientPostSunriseTime = skyboxTimes.ambientPostSunriseTime
		wc.ambientPostSunsetTime = skyboxTimes.ambientPostSunsetTime
		wc.ambientPreSunriseTime = skyboxTimes.ambientPreSunriseTime
		wc.ambientPreSunsetTime = skyboxTimes.ambientPreSunsetTime

		wc.fogPostSunriseTime = skyboxTimes.fogPostSunriseTime
		wc.fogPostSunsetTime = skyboxTimes.fogPostSunsetTime
		wc.fogPreSunriseTime = skyboxTimes.fogPreSunriseTime
		wc.fogPreSunsetTime = skyboxTimes.fogPreSunsetTime

		wc.skyPostSunriseTime = skyboxTimes.skyPostSunriseTime
		wc.skyPostSunsetTime = skyboxTimes.skyPostSunsetTime
		wc.skyPreSunriseTime = skyboxTimes.skyPreSunriseTime
		wc.skyPreSunsetTime = skyboxTimes.skyPreSunsetTime

		wc.sunPostSunriseTime = skyboxTimes.sunPostSunriseTime
		wc.sunPostSunsetTime = skyboxTimes.sunPostSunsetTime
		wc.sunPreSunriseTime = skyboxTimes.sunPreSunriseTime
		wc.sunPreSunsetTime = skyboxTimes.sunPreSunsetTime
	end

	local function saveExteriorColorsFog()
		if not exteriorColorsFog and tes3.getCurrentWeather().index == tes3.weather.foggy then
			exteriorColorsFog = {}

			exteriorColorsFog.ambientSunriseColor = wc.currentWeather.ambientSunriseColor:copy()
			exteriorColorsFog.ambientDayColor = wc.currentWeather.ambientDayColor:copy()
			exteriorColorsFog.ambientSunsetColor = wc.currentWeather.ambientSunsetColor:copy()
			exteriorColorsFog.ambientNightColor = wc.currentWeather.ambientNightColor:copy()

			exteriorColorsFog.fogSunriseColor = wc.currentWeather.fogSunriseColor:copy()
			exteriorColorsFog.fogDayColor = wc.currentWeather.fogDayColor:copy()
			exteriorColorsFog.fogSunsetColor = wc.currentWeather.fogSunsetColor:copy()
			exteriorColorsFog.fogNightColor = wc.currentWeather.fogNightColor:copy()

			exteriorColorsFog.sunSunriseColor = wc.currentWeather.sunSunriseColor:copy()
			exteriorColorsFog.sunDayColor = wc.currentWeather.sunDayColor:copy()
			exteriorColorsFog.sunSunsetColor = wc.currentWeather.sunSunsetColor:copy()
			exteriorColorsFog.sunNightColor = wc.currentWeather.sunNightColor:copy()

			exteriorColorsFog.landFogDayDepth = wc.currentWeather.landFogDayDepth
			exteriorColorsFog.landFogNightDepth = wc.currentWeather.landFogNightDepth
			if mge.enabled() then
				exteriorColorsFog.mgeFog = mgeWeatherConfig.getDistantFog(tes3.weather.foggy)
			end
		end
	end

	local function setWeatherInteriorColors()
		local ambientColor = tes3vector3.new(e.cell.ambientColor.b / 255, e.cell.ambientColor.g / 255, e.cell.ambientColor.r / 255)		-- Currently the r and b properties of niPackedColor are pointed to each other rather than the correct values
		local fogColor = tes3vector3.new(e.cell.fogColor.b / 255, e.cell.fogColor.g / 255, e.cell.fogColor.r / 255)
		local sunColor = tes3vector3.new(e.cell.sunColor.b / 255, e.cell.sunColor.g / 255, e.cell.sunColor.r / 255)

		wc.currentWeather.ambientSunriseColor = ambientColor
		wc.currentWeather.ambientDayColor = ambientColor
		wc.currentWeather.ambientSunsetColor = ambientColor
		wc.currentWeather.ambientNightColor = ambientColor

		wc.currentWeather.fogSunriseColor = fogColor
		wc.currentWeather.fogDayColor = fogColor
		wc.currentWeather.fogSunsetColor = fogColor
		wc.currentWeather.fogNightColor = fogColor

		wc.currentWeather.sunSunriseColor = sunColor
		wc.currentWeather.sunDayColor = sunColor
		wc.currentWeather.sunSunsetColor = sunColor
		wc.currentWeather.sunNightColor = sunColor

		-- Fog density should be accounted for here at some point, though setDistantFog doesn't seem to do anything in interiors. At least the default MGE values for foggy weather seem close to a fog density of 1
	end

	local function restoreWeatherExteriorColors()
		if exteriorColorsFog then
			wc.currentWeather.ambientSunriseColor = exteriorColorsFog.ambientSunriseColor
			wc.currentWeather.ambientDayColor = exteriorColorsFog.ambientDayColor
			wc.currentWeather.ambientSunsetColor = exteriorColorsFog.ambientSunsetColor
			wc.currentWeather.ambientNightColor = exteriorColorsFog.ambientNightColor

			wc.currentWeather.fogSunriseColor = exteriorColorsFog.fogSunriseColor
			wc.currentWeather.fogDayColor = exteriorColorsFog.fogDayColor
			wc.currentWeather.fogSunsetColor = exteriorColorsFog.fogSunsetColor
			wc.currentWeather.fogNightColor = exteriorColorsFog.fogNightColor

			wc.currentWeather.sunSunriseColor = exteriorColorsFog.sunSunriseColor
			wc.currentWeather.sunDayColor = exteriorColorsFog.sunDayColor
			wc.currentWeather.sunSunsetColor = exteriorColorsFog.sunSunsetColor
			wc.currentWeather.sunNightColor = exteriorColorsFog.sunNightColor

			wc.currentWeather.landFogDayDepth = exteriorColorsFog.landFogDayDepth
			wc.currentWeather.landFogNightDepth = exteriorColorsFog.landFogNightDepth
			--if mge.enabled() then
			--	mgeWeatherConfig.setDistantFog({ weather = tes3.weather.foggy, distance = exteriorColorsFog.mgeFog.distance, offset = exteriorColorsFog.mgeFog.offset })
			--end
		end
	end

	if attributionsShareCells[e.cell.id] then
		hideCustomSkyboxesAndObjects()
		hideMoons = true
		replaceSkybox(attributionsShareSkybox)
		setSkyboxTimes(defaultSkyboxTimes)
		tes3.changeWeather({ id = tes3.weather.foggy, immediate = true })
		saveExteriorColorsFog()	-- Getting/changing the colors of wc.weathers[tes3.weather.foggy] is unreliable, so it is run after changing the weather to foggy in a suitable cell but before changing the colors
		setWeatherInteriorColors()

		isOnMasser = false
		isOnSecunda = false
	elseif voidCells[e.cell.id] then
		hideCustomSkyboxesAndObjects()
		hideMoons = true
		replaceSkybox(voidSkybox)
		setSkyboxTimes(defaultSkyboxTimes)
		tes3.changeWeather({ id = tes3.weather.foggy, immediate = true })
		saveExteriorColorsFog()
		setWeatherInteriorColors()

		isOnMasser = false
		isOnSecunda = false
	elseif tes3.player.cell.region and common.masserRegions[tes3.player.cell.region.id] then
		hideCustomSkyboxesAndObjects()
		hideMoons = true
		mundus.appCulled = false
		nirn.appCulled = false
		secunda.appCulled = false

		setSkyboxTimes(masserSkyboxTimes)

		skyRoot:update()
		skyRoot:updateProperties()
		skyRoot:updateEffects()
		isOnMasser = true
		isOnSecunda = false
	elseif not e.previousCell or ((attributionsShareCells[e.previousCell.id] or voidCells[e.previousCell.id] or (e.previousCell.region and common.masserRegions[e.previousCell.region.id]))) then
		skyRoot.appCulled = not tes3.player.cell.isOrBehavesAsExterior

		-- Show vanilla sky
		for _,node in pairs(sky) do node.appCulled = false end
		hideMoons = false
    	hideCustomSkyboxesAndObjects()

    	-- Update everything
    	skyRoot:update()
    	skyRoot:updateProperties()
    	skyRoot:updateEffects()

		if e.previousCell then
			setSkyboxTimes(defaultSkyboxTimes)
			tes3.changeWeather({ id = tes3.weather.foggy, immediate = true })	-- Remove?
		end
		restoreWeatherExteriorColors()

		isOnMasser = false
		isOnSecunda = false
	end
end

local function getSkyboxTimes(orbit, currentTimestamp)
	local difference = magnusDummyNode.worldTransform.translation.z - skyRoot.worldTransform.translation.z
	local distance = magnusDummyNode.worldTransform.translation:distance(skyRoot.worldTransform.translation)
	local angle = math.deg(math.asin(difference/distance))
	--mwse.log(angle)
	if math.abs(angle) < .01 or (angle < 21.01 and angle > 20.99) then
		tes3.findGlobal("Timescale").value = 1		-- Accuracy of the calculations below is increased by having a a small timescale, but might also be improved by having a high FPS and a long orbital period
	elseif (angle < 21.1 and angle > 20.9) then
		tes3.findGlobal("Timescale").value = 4
	elseif math.abs(angle) < .1 then
		tes3.findGlobal("Timescale").value = 8
	else
		tes3.findGlobal("Timescale").value = 41.667 * orbit.P
	end

	if previousV then
		if sunAboveHorizon and angle <= 0 and sunsetBegin then
			sunsetDuration = (currentTimestamp + previousTimestamp) / 2 - sunsetBegin	-- The true value will always be somewhere between the current timestep and the previous timestep, so the average of the two is used
			mwse.log("sunsetDuration: " .. sunsetDuration)

			sunsetDurationV = (orbit.v + previousV) / 2 - sunsetBeginV
			mwse.log("sunsetDurationV: " .. sunsetDurationV)
		elseif not sunAboveHorizon and angle > 0 then
			sunriseBegin = (currentTimestamp + previousTimestamp) / 2
			mwse.log("sunriseBegin: " .. sunriseBegin)

			sunriseBeginV = (orbit.v + previousV) / 2
			mwse.log("sunriseBeginV: " .. sunriseBeginV)
		elseif sunAbove21 and angle <= 21 then
			sunsetBegin = (currentTimestamp + previousTimestamp) / 2
			mwse.log("sunsetBegin: " .. sunsetBegin)

			sunsetBeginV = (orbit.v + previousV) / 2
			mwse.log("sunsetBeginV: " .. sunsetBeginV)
		elseif not sunAbove21 and angle > 21 and sunriseBegin then
			sunriseDuration = (currentTimestamp + previousTimestamp) / 2 - sunriseBegin
			mwse.log("sunriseDuration: " .. sunriseDuration)

			sunriseDurationV = (orbit.v + previousV) / 2 - sunriseBeginV
			mwse.log("sunriseDurationV: " .. sunriseDurationV)
		end
	end

	previousTimestamp = currentTimestamp
	previousV = orbit.v

	if angle > 0 then
		sunAboveHorizon = true
	else
		sunAboveHorizon = false
	end

	if angle > 21 then
		sunAbove21 = true
	else
		sunAbove21 = false
	end
end

function this.manageOrbits()
	local function calculateTrueAnomaly(orbit, time)
		orbit.v = (((time / orbit.P) * twoPi) + orbit.v0) % twoPi
	end

	---@param mesh niNode
	local function calculateMoonTransforms(mesh, orbit)
		local sinN = math.sin(orbit.N)
		local cosN = math.cos(orbit.N)
		local sini = math.sin(orbit.i)
		local cosi = math.cos(orbit.i)
		local sinv = math.sin(orbit.v)
		local cosv = math.cos(orbit.v)

		-- Calculate and set the position of the given moon relative to Nirn, which works because it is relative to the other moon that the player is currently on
		local x = orbit.a * ((cosN * cosv) - (sinN * sinv * cosi))
		local y = orbit.a * ((sinN * cosv) + (cosN * sinv * cosi))
		local z = orbit.a * sinv * sini
		mesh.translation = tes3vector3.new(x, y, z)

		-- Rotate the moon such that it is tidally locked to Nirn
		local lockedRotation = tes3matrix33.new(-(sinN * sinv * cosi) + (cosN * cosv), -(sinN * cosv * cosi) - (cosN * sinv), sinN * sini,
													(cosN * sinv * cosi) + (sinN * cosv), (cosN * cosv * cosi) - (sinN * sinv), -sini * cosN,
													sini * sinv, 						  sini * cosv, 									cosi)
		mesh.rotation = lockedRotation
	end

	local function rotateNirnAndSystem(orbit, time)
		local longitudeRotation = tes3matrix33.new()
		longitudeRotation:fromEulerXYZ(0, 0, orbit.N + orbit.sz)													-- The rotation of Nirn as it is seen due to the orientation of the current moon's orbit and the angle correction depending on the placement of Mundus in the skybox

		local librationRotation = tes3matrix33.new()
		librationRotation:toRotation((math.sin(-orbit.v) * orbit.i) + orbit.saa, orbit.sax.x, orbit.sax.y, 0)		-- The rotation of Nirn as it is seen due to the inclination of the current moon's orbit
		librationRotation:reorthogonalize()

		local anomalyRotation = tes3matrix33.new()
		anomalyRotation:fromEulerXYZ(0, 0, orbit.v)																	-- The rotation of Nirn as it is seen due to the position of the current moon

		local totalRotation = longitudeRotation * librationRotation * anomalyRotation
		totalRotation:reorthogonalize()
		mundus.rotation = totalRotation

		local axialRotation = tes3matrix33.new()
		axialRotation:fromEulerXYZ(0, 0, ((time % 24) / 24) * twoPi)												-- The rotation of Nirn itself that is repsonsible for its day-night cycle
		nirn.rotation = axialRotation

		return totalRotation
	end

	-- setVertexColors was written to apply RGB colors from the sky to the vertex colors of the visible NiTriShape of the mesh; however, this appears to be unnecessary and has no effect with MGE fully enabled, so the relevant lines have been commented out for now.
	-- The remaining calculations are still expensive, so care has been taken to focus on performance even at the expense of readability
	---@param mesh niNode
	local function setVertexColors(mesh, radiusSquared, hour)
		---@param pole niNode
		local function vertexColorRayTest(pole)
			local result = tes3.rayTest({ root = sky.atmosphere, position = skyRoot.translation, direction = (pole.worldTransform * pole.translation) - skyRoot.translation, returnColor = true, maxDistance = 3600, observeAppCullFlag = false })
			if result and result.object == sky.atmosphere.children[1] and result.color then
				return result.color
			else
				return sky.atmosphere.children[1].data.colors[2]	-- If the rayTest does not hit the atmosphere mesh, then it is probably aimed below the mesh's lowest vertices, in which case the color of one of those vertices should be used
			end
		end

		---@param vertex tes3vector3
		local function calculatePoleVertexColors(vertex, poleColors)
			local xClose, yClose, zClose

			if vertex.x >= 0 then xClose = poleColors.xPos		-- If vertex.x equals 0 then the value assigned to xClose is irrelevant because it will not influence the final vertex color at all; the same is true for the other axes
			else xClose = poleColors.xNeg end
			local xInfluence = math.abs(vertex.x^2 / radiusSquared)

			if vertex.y >= 0 then yClose = poleColors.yPos
			else yClose = poleColors.yNeg end
			local yInfluence = math.abs(vertex.y^2 / radiusSquared)

			if vertex.z >= 0 then zClose = poleColors.zPos
			else zClose = poleColors.zNeg end
			local zInfluence = math.abs(vertex.z^2 / radiusSquared)

			local r = (xClose.r * xInfluence) + (yClose.r * yInfluence) + (zClose.r * zInfluence)
			local g = (xClose.g * xInfluence) + (yClose.g * yInfluence) + (zClose.g * zInfluence)
			local b = (xClose.b * xInfluence) + (yClose.b * yInfluence) + (zClose.b * zInfluence)
			return niPackedColor.new(r, g, b, 255)
		end

		if not changeVertexColors then return end

		if not worldTransformsActive then
			if magnusDummyNode.worldTransform.translation.z == mundus.worldTransform.translation.z then
				return
			else
				worldTransformsActive = true
			end
		end

		local magnusProjection = magnusDummyNode.worldTransform.translation - mundus.worldTransform.translation	-- This vector is always directed towards Mundus rather than each invidiual mesh because the sun should (presumably) be so far away that its rays are parallel to each other across the system
		--local vertices = mesh.children[2].data.vertices
		local vertexColors = mesh.children[2].data.colors
		local vertexColorsShadow = mesh.children[1].data.colors
		local normals = mesh.children[2].data.normals
		local rotation = mesh.worldTransform.rotation
		--local poleColors = {
		--	xPos = vertexColorRayTest(mesh.children[3]),
		--	xNeg = vertexColorRayTest(mesh.children[4]),
		--	yPos = vertexColorRayTest(mesh.children[5]),
		--	yNeg = vertexColorRayTest(mesh.children[6]),
		--	zPos = vertexColorRayTest(mesh.children[7]),
		--	zNeg = vertexColorRayTest(mesh.children[8])
		--}

		local isNight = false		-- Used to avoid checking the daytime repatedly, which can get quite expensive for thousands of normals
		local isSunrise = false
		local isSunset = false
		local transitionFactor = 1
		local transitionShadow = 0
		if hour >= wc.sunsetHour + wc.sunsetDuration or hour < wc.sunriseHour then
			isNight = true
		elseif hour >= wc.sunriseHour and hour < wc.sunriseHour + wc.sunriseDuration then
			isSunrise = true
			transitionFactor = (hour - wc.sunriseHour) / wc.sunriseDuration
			transitionShadow = math.ease.expoIn(1 - transitionFactor) * 255		-- ease.expoIn has to be used instead of eerp because the latter only works with values greater than 0
		elseif hour >= wc.sunsetHour and hour < wc.sunsetHour + wc.sunsetDuration then
			isSunset = true
			transitionFactor = (hour - wc.sunsetHour) / wc.sunsetDuration
			transitionShadow = math.ease.expoIn(transitionFactor) * 255
		end

		local weatherFactor = 1
		if wc.currentWeather.index > 2 then
			weatherFactor = 0
		elseif wc.currentWeather.index == 2 then
			if hour > wc.starsPostSunsetStart then		-- The clouds around the horizon clear out for foggy weather as the stars become visible and vice versa
				weatherFactor = math.remapclamped(hour, wc.starsPostSunsetStart, wc.starsPostSunsetStart + wc.starsFadingDuration, 0, 1)
			elseif hour < wc.starsPreSunriseFinish + wc.starsFadingDuration then
				weatherFactor = math.remapclamped(hour, wc.starsPreSunriseFinish, wc.starsPreSunriseFinish + wc.starsFadingDuration, 1, 0)
			else
				weatherFactor = 0
			end
		end

		if wc.nextWeather then
			if wc.nextWeather.index < 2	then				-- Changing to clear/cloudy
				weatherFactor = math.remapclamped(wc.transitionScalar, 0, .42, weatherFactor, 1)
			elseif wc.nextWeather.index == 2 then			-- Changing to foggy
				if hour > wc.starsPostSunsetStart then		-- The clouds around the horizon clear out for foggy weather as the stars become visible and vice versa
					weatherFactor = math.remapclamped(wc.transitionScalar, 0, .42, weatherFactor, math.remapclamped(hour, wc.starsPostSunsetStart, wc.starsPostSunsetStart + wc.starsFadingDuration, 0, 1))
				elseif hour < wc.starsPreSunriseFinish + wc.starsFadingDuration then
					weatherFactor = math.remapclamped(wc.transitionScalar, 0, .42, weatherFactor, math.remapclamped(hour, wc.starsPreSunriseFinish, wc.starsPreSunriseFinish + wc.starsFadingDuration, 1, 0))
				else
					weatherFactor = math.remapclamped(wc.transitionScalar, .58, 1, weatherFactor, 0)
				end
			else											-- Changing to a fully obscured weather
				weatherFactor = math.remapclamped(wc.transitionScalar, .58, 1, weatherFactor, 0)
			end
		end

		local transitionShadowColor = niPackedColor.new(transitionShadow, transitionShadow, transitionShadow, 255)
		local whiteColor = niPackedColor.new(255, 255, 255, 255)
		local blackColor = niPackedColor.new(0, 0, 0, 255)
		local invisibleNightColor = niPackedColor.new(0, 0, 0, 255)
		local visibleNightColor = niPackedColor.new(255 * weatherFactor, 255 * weatherFactor, 255 * weatherFactor, 255)
		local invisibleDayColor = niPackedColor.new(0, 0, 0, 0)
		local visibleDayColor = niPackedColor.new(255, 255, 255, 0.467 * 255 * weatherFactor)

		for index,normal in pairs(normals) do
			local value
			local worldSpaceNormal = rotation * normal
			local angle = worldSpaceNormal:angle(magnusProjection)
			if angle <= lightDim then
				value = 255
			elseif angle < lightCutoff then
				value = math.remapclamped(angle, lightDim, lightCutoff, 255, 0)
			else
				value = 0
			end

			---@cast wc tes3weatherController
			if isNight then
				vertexColorsShadow[index] = whiteColor		-- Setting the color in one operation is much faster than setting the RGBA values separately

				if value == 0 then
					vertexColors[index] = invisibleNightColor
				elseif value == 255 then
					vertexColors[index] = visibleNightColor
				else
					value = value * weatherFactor
					vertexColors[index] = niPackedColor.new(value, value, value, 255)
				end
			elseif isSunset then
				vertexColorsShadow[index] = transitionShadowColor

				local transitionColor = 255 * weatherFactor
				if value < 255 then
					transitionColor = (math.ease.expoIn(1 - transitionFactor) * (255 - value) + value) * weatherFactor
				end

				local min = math.min(value, 0.467 * 255) * weatherFactor
				vertexColors[index] = niPackedColor.new(transitionColor, transitionColor, transitionColor, math.ease.expoIn(transitionFactor) * (255 - min) + min)
			elseif isSunrise then
				vertexColorsShadow[index] = transitionShadowColor

				local transitionColor = 255 * weatherFactor
				if value < 255 then
					transitionColor = (math.ease.expoIn(transitionFactor) * (255 - value) + value) * weatherFactor
				end

				local min = math.min(value, 0.467 * 255) * weatherFactor
				vertexColors[index] = niPackedColor.new(transitionColor, transitionColor, transitionColor, math.ease.expoIn(1 - transitionFactor) * (255 - min) + min)
			else
				--local interpolatedColor = calculatePoleVertexColors(vertices[index], poleColors)
				--vertexColorsShadow[index] = interpolatedColor
				vertexColorsShadow[index] = blackColor

				if value == 0 then
					vertexColors[index] = invisibleDayColor
				elseif value > 120 then
					vertexColors[index] = visibleDayColor
				else
					vertexColors[index] = niPackedColor.new(255, 255, 255, math.min(value, 0.467 * 255) * weatherFactor)
				end
			end
		end

		mesh.children[1].data:markAsChanged()
		mesh.children[2].data:markAsChanged()
	end

	---@param parentNode niNode
	---@param childNodes niNode[]
	local function setNodeOrder(parentNode, childNodes)
		local childNodeDistances = {}
		for _,childNode in pairs(childNodes) do
			childNodeDistances[childNode] = childNode.children[1].worldTransform.translation:distance(skyRoot.translation)
			parentNode:detachChild(childNode)
		end

		for childNode,_ in table.sortedpairs(childNodeDistances, function (a, b) return childNodeDistances[a] > childNodeDistances[b] end) do
			parentNode:attachChild(childNode, true)
		end
	end

	local function shiftSkyboxTimes(orbit, skyboxTimes)
		if tes3.worldController.daysPassed.value ~= currentDay then
			mwse.log("\n")
			mwse.log(wc.sunriseHour)
			mwse.log(wc.sunsetHour)
			currentDay = tes3.worldController.daysPassed.value

			wc.sunriseHour = wc.sunriseHour - 24
			wc.sunsetHour = wc.sunsetHour - 24

			wc.starsPostSunsetStart = wc.starsPostSunsetStart - 24
			wc.starsPreSunriseFinish = wc.starsPreSunriseFinish - 24

			if wc.starsPostSunsetStart + wc.starsFadingDuration < 0 then
				wc.sunriseHour = wc.sunriseHour + orbit.P
				wc.sunsetHour = wc.sunsetHour + orbit.P

				wc.starsPostSunsetStart = wc.starsPostSunsetStart + orbit.P
				wc.starsPreSunriseFinish = wc.starsPreSunriseFinish + orbit.P
				--local effectiveDay = currentDay - 1
				--local hourOffset = effectiveDay * 24
				--local effectiveSunriseHour = skyboxTimes.sunriseHour - hourOffset
				--local effectiveSunsetHour = skyboxTimes.sunsetHour - hourOffset

				--while skyboxTimes.sunsetHour < 0 do
				--	effectiveSunriseHour = effectiveSunriseHour + orbit.P
				--	effectiveSunsetHour = effectiveSunsetHour + orbit.P
				--end

				--if effectiveSunriseHour > 0 then	-- If the sun has yet to rise, then the time of the sunset must be put before that of sunrise instead of after
				--	effectiveSunsetHour = effectiveSunriseHour - (orbit.P - (skyboxTimes.sunsetHour - skyboxTimes.sunriseHour))
				--end

				--wc.sunriseHour = effectiveSunriseHour
				--wc.sunsetHour = effectiveSunsetHour
				mwse.log(wc.sunriseHour)
				mwse.log(wc.sunsetHour)
			end
		--elseif wc.sunriseHour > 0 and tes3.worldController.hour.value >= wc.sunriseHour and wc.sunsetHour < wc.sunriseHour then
		--	wc.sunsetHour = wc.sunsetHour + orbit.P
		--	mwse.log(wc.sunsetHour)
		--elseif wc.sunsetHour > 0 and tes3.worldController.hour.value >= wc.sunsetHour and wc.sunriseHour < wc.sunsetHour then
		--	wc.sunriseHour = wc.sunriseHour + orbit.P
		--	mwse.log(wc.sunriseHour)
		end
	end

	-- Future work:
	--		Sky colors are shifting when the sun is below the horizon near sunrise and sunset; this likely requires changes to MGE's sunshaft shader and atmospheric scattering. Doing this is required for orbital periods that are not 24 hours to work at all
	--		Shadows are based on the vanilla sun's position at the current time rather than the actual position of the sun node. Perhaps sky.magnus could then be moved to Nirn during the night so that it is the source of the sunlight.
	--		Remove dependency on sunshaft shader and atmospheric scattering?
	--		Fix vertex colors being wrong when changing the time with Weather Adjuster

	if not sky or tes3.menuMode() then return end

	if hideMoons then
		sky.masserVanilla.appCulled = true
		sky.secundaVanilla.appCulled = true
	end

	if isOnMasser or isOnSecunda then
		-- Rescale and move parts of the skybox so that the added objects have space to move around in
		sky.atmosphere.children[1].scale = 2
		sky.atmosphere.children[1].translation.z = -100
		sky.objects.children[2].scale = .25
		sky.objects.children[2].translation.z = 60
		sky.objects.children[3].scale = .25
		sky.objects.children[3].translation.z = 60

		local time = tes3.getSimulationTimestamp() - 3746001			-- Time since the start of the game
		local hour = tes3.worldController.hour.value

		calculateTrueAnomaly(masserOrbit, time)
		calculateTrueAnomaly(secundaOrbit, time)

		if isOnMasser then
			mundus.translation = masserOrbit.s
			local totalRotation = rotateNirnAndSystem(masserOrbit, time)
			if hour > wc.sunriseHour - wc.sunPreSunriseTime and hour < wc.sunsetHour + wc.sunsetDuration then
				sky.magnus.translation = mundus.translation + totalRotation * magnusDummyNode.translation	-- Keeping the sun locked in place when it is below the horizon causes problems with MGE's sunshaft shader and atmospheric scattering for some reason; this bypass works as long as the orbital period is 24 hours and be comparable to the vanilla sunrise/sunset times
			end

			calculateMoonTransforms(secunda, secundaOrbit)

			setVertexColors(secunda, secundaRadiusSquared, hour)
			setNodeOrder(mundus, { nirn, secunda })
			--shiftSkyboxTimes(masserOrbit, masserSkyboxTimes)
			--getSkyboxTimes(masserOrbit, hour)
		else
			mundus.translation = secundaOrbit.s
			local totalRotation = rotateNirnAndSystem(secundaOrbit, time)
			sky.magnus.translation = mundus.translation + totalRotation * magnusDummyNode.translation
			calculateMoonTransforms(masser, masserOrbit)

			setVertexColors(masser, masserRadiusSquared, hour)
			setNodeOrder(mundus, { nirn, masser })
			--shiftSkyboxTimes(secundaOrbit, secundaSkyboxTimes)
			--getSkyboxTimes(secundaOrbit, time)
		end
		setVertexColors(nirn, nirnRadiusSquared, hour)

		skyRoot:update()
		skyRoot:updateProperties()
		skyRoot:updateEffects()

		if worldTransformsActive then changeVertexColors = false end
	end
end

function this.enableVertexColorChange()
	changeVertexColors = true
end

return this