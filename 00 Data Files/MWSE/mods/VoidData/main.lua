if not tes3.isModActive("Void_Data.esm") then return end

local config = require("VoidData.config")
local magic = require("VoidData.magic")
local sdf = require("VoidData.sdf")
local skybox = require("VoidData.skybox")
local weather = require("VoidData.weather")

-- Setup MCM
dofile("VoidData.mcm")

event.register(tes3.event.loaded, function()

	-- Initialize player data
	--local data = tes3.player.data
    --data.voidData = data.voidData or {}
    --local myData = data.voidData
    --initTableValues(myData, player_data_defaults)

	if config.skyboxes then
		skybox.setupSkyboxes()
		event.register(tes3.event.cellChanged, skybox.switchSkybox, { unregisterOnLoad = true })
		event.register(tes3.event.render, skybox.manageOrbits, { unregisterOnLoad = true })
		timer.start{ duration = 1/120, iterations = -1, type = timer.game, callback = skybox.enableVertexColorChange }
	end

	if config.weathers then
		event.register(tes3.event.cellChanged, weather.manageWeathers, { unregisterOnLoad = true })
		event.register(tes3.event.weatherChangedImmediate, weather.manageWeathers, { unregisterOnLoad = true })
		event.register(tes3.event.weatherTransitionStarted, weather.manageWeathers, { unregisterOnLoad = true })
	end

	if config.sdf then
		if not tes3.clothingSlot.automantric then tes3.addClothingSlot({ slot = 30, name = "Automantric", key = "automantric" }) end
		sdf.changeAutomantricsSlot()
	end
end)