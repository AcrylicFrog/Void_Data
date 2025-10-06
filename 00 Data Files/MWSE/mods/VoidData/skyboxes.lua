local this = {}

local wc
local skyRoot
local sky
local exteriorColorsFog

local attributionsShareSkybox
local voidSkybox

local attributionsShareCells = {
}

local voidCells = {		-- Eventually there will need to be more skyboxes and thus more tables for cells that belong to The Void, but this will suffice for now
	["The Void, Aldereken"] = true,
}

---@param e cellChangedEventData
function this.manageSkybox(e)
	local function hideCustomSkyboxes()
		attributionsShareSkybox.appCulled = true
		voidSkybox.appCulled = true
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

	wc = tes3.worldController.weatherController
	skyRoot = wc.sceneSkyRoot
	sky = {
    	atmosphere = skyRoot.children[1],
    	stars = skyRoot.children[2],
    	magnus = skyRoot.children[3],
    	masser = skyRoot.children[4],
    	secunda = skyRoot.children[5],
    	clouds = skyRoot.children[6],
    	light = skyRoot.children[7]
	}

	attributionsShareSkybox = tes3.loadMesh("jo//jo_as_sky_01.nif")
	attributionsShareSkybox.name = "jo_as_sky_01"
	voidSkybox = tes3.loadMesh("jo//jo_vd_sky_01.nif")
	voidSkybox.name = "jo_vd_sky_01"

	if attributionsShareCells[e.cell.id] then
		hideCustomSkyboxes()
		replaceSkybox(attributionsShareSkybox)
		tes3.changeWeather({ id = tes3.weather.foggy, immediate = true })
		saveExteriorColorsFog()	-- Getting/changing the colors of wc.weathers[tes3.weather.foggy] is unreliable, so it is run after changing the weather to foggy in a suitable cell but before changing the colors
		setWeatherInteriorColors()
	elseif voidCells[e.cell.id] then
		hideCustomSkyboxes()
		replaceSkybox(voidSkybox)
		tes3.changeWeather({ id = tes3.weather.foggy, immediate = true })
		saveExteriorColorsFog()
		setWeatherInteriorColors()
	elseif e.previousCell and (attributionsShareCells[e.previousCell.id] or voidCells[e.previousCell.id]) then
		skyRoot.appCulled = not tes3.player.cell.isOrBehavesAsExterior

		-- Show vanilla sky
		for _,node in pairs(sky) do node.appCulled = false end

    	hideCustomSkyboxes()

    	-- Update everything
    	skyRoot:update()
    	skyRoot:updateProperties()
    	skyRoot:updateEffects()

		tes3.changeWeather({ id = tes3.weather.foggy, immediate = true })
		restoreWeatherExteriorColors()
	end
end

return this