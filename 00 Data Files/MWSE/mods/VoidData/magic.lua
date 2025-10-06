local this = {}

local common = require("VoidData.common")
local config = require("VoidData.config")
local tamrielDataMagic = require("TamrielData.magic")

if config.newEffects then
	tes3.claimSpellEffectId("V_summon_Farmer", 2900)
end

-- The effect costs for most TD summons were initially calculated by mort using a formula (dependent on a creature's health and soul) that is now lost and were then adjusted as seemed reasonable.
-- The new formula used by TD and therefore VD: Effect Cost = (.16 * Health) + (.035 * Soul)
-- effect id, effect name, creature id, effect mana cost, icon, effect description
local vd_summon_effects = {
	{ tes3.effect.V_summon_Farmer, common.i18n("magic.summonFarmer"), "V_Dae_Cre_Farmer", 35, "s\\tx_s_smmn_hunger.dds", common.i18n("magic.summonFarmerDesc")},
}

-- spell id, cast type, spell name, spell mana cost, 1st effect id, 1st range type, 1st area, 1st duration, 1st minimum magnitude, 1st maximum magnitude, ...
local vd_summon_spells = {
	{ "V_AS_Cnj_SummonFarmer", tes3.spellType.spell, common.i18n("magic.summonFarmer"), 105, { tes3.effect.V_summon_Farmer }, tes3.effectRange.self, 0, 60, 1, 1 },
}

-- Adds new magic effects based on the tables above
event.register(tes3.event.magicEffectsResolved, function()
	if config.newEffects then
		local summonHungerEffect = tes3.getMagicEffect(tes3.effect.summonHunger)

		for _,v in pairs(vd_summon_effects) do
			local effectID, effectName, creatureID, effectCost, iconPath, effectDescription = unpack(v)
			tes3.addMagicEffect{
				id = effectID,
				name = effectName,
				description = effectDescription,
				school = tes3.magicSchool.conjuration,
				baseCost = effectCost,
				speed = summonHungerEffect.speed,
				allowEnchanting = true,
				allowSpellmaking = true,
				appliesOnce = summonHungerEffect.appliesOnce,
				canCastSelf = true,
				canCastTarget = false,
				canCastTouch = false,
				casterLinked = summonHungerEffect.casterLinked,
				hasContinuousVFX = summonHungerEffect.hasContinuousVFX,
				hasNoDuration = summonHungerEffect.hasNoDuration,
				hasNoMagnitude = summonHungerEffect.hasNoMagnitude,
				illegalDaedra = summonHungerEffect.illegalDaedra,
				isHarmful = summonHungerEffect.isHarmful,
				nonRecastable = summonHungerEffect.nonRecastable,
				targetsAttributes = summonHungerEffect.targetsAttributes,
				targetsSkills = summonHungerEffect.targetsSkills,
				unreflectable = summonHungerEffect.unreflectable,
				usesNegativeLighting = summonHungerEffect.usesNegativeLighting,
				icon = iconPath,
				particleTexture = summonHungerEffect.particleTexture,
				castSound = summonHungerEffect.castSoundEffect.id,
				castVFX = summonHungerEffect.castVisualEffect.id,
				boltSound = summonHungerEffect.boltSoundEffect.id,
				boltVFX = summonHungerEffect.boltVisualEffect.id,
				hitSound = summonHungerEffect.hitSoundEffect.id,
				hitVFX = summonHungerEffect.hitVisualEffect.id,
				areaSound = summonHungerEffect.areaSoundEffect.id,
				areaVFX = summonHungerEffect.areaVisualEffect.id,
				lighting = {x = summonHungerEffect.lightingRed / 255, y = summonHungerEffect.lightingGreen / 255, z = summonHungerEffect.lightingBlue / 255},
				size = summonHungerEffect.size,
				sizeCap = summonHungerEffect.sizeCap,
				onTick = function(eventData)
					eventData:triggerSummon(creatureID)
				end,
				onCollision = nil
			}
		end
	end
end)

event.register(tes3.event.load, function()
	if config.newEffects then
		tamrielDataMagic.replaceSpells(vd_summon_spells)
	end
end)

return this