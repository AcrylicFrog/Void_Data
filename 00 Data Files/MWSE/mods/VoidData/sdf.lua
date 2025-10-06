local this = {}

-- clothing id
local automantrics = {
	"V_Rem_Cm_Automantric_01",
}

function this.changeAutomantricsSlot()
	for _,clothingID in pairs(automantrics) do
		tes3.getObject(clothingID).slot = tes3.clothingSlot.automantric
	end
end

return this