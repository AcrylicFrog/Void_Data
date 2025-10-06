if not tes3.isModActive("Void_Data.esm") then return end

local config = require("VoidData.config")
local magic = require("VoidData.magic")
local sdf = require("VoidData.sdf")
local skyboxes = require("VoidData.skyboxes")

-- Setup MCM
dofile("VoidData.mcm")

event.register(tes3.event.loaded, function()

	-- Initialize player data
	--local data = tes3.player.data
    --data.voidData = data.voidData or {}
    --local myData = data.voidData
    --initTableValues(myData, player_data_defaults)

	if config.skyboxes then
		event.register(tes3.event.cellChanged, skyboxes.manageSkybox, { unregisterOnLoad = true })
	end

	if config.sdf then
		if not tes3.clothingSlot.automantric then tes3.addClothingSlot({ slot = 30, name = "Automantric", key = "automantric" }) end
		sdf.changeAutomantricsSlot()
	end
end)