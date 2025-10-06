local common = require("VoidData.common")
local config = require("VoidData.config")

----------------------
-- MCM Template --
----------------------

local function registerModConfig()

    local template = mwse.mcm.createTemplate{name=common.i18n("mcm.name")}
    template:saveOnClose("VoidData", config)

    -- Preferences Page
    local preferences = template:createSideBarPage{label=common.i18n("mcm.preferences")}
    preferences.sidebar:createInfo{text=common.i18n("mcm.preferencesInfo")}

    -- Sidebar Credits
    local credits = preferences.sidebar:createCategory{label=common.i18n("mcm.credits")}
    credits:createHyperlink{
        text = common.i18n("mcm.Kynesifnar"),
        url = "https://www.nexusmods.com/users/56893332?tab=user+files",
    }

    -- Feature Toggles
    local toggles = preferences:createCategory{label = common.i18n("mcm.settings")}
    toggles:createOnOffButton{
        label = common.i18n("mcm.skyboxesLabel"),
        description = common.i18n("mcm.skyboxesDescription"),
        variable = mwse.mcm.createTableVariable{
            id = "skyboxes",
            table = config,
        },
    }
    toggles:createOnOffButton{
        label = common.i18n("mcm.newEffectsLabel"),
        description = common.i18n("mcm.newEffectsDescription"),
        variable = mwse.mcm.createTableVariable{
            id = "newEffects",
            table = config,
        },
    }

    template:register()
end

event.register(tes3.event.modConfigReady, registerModConfig)