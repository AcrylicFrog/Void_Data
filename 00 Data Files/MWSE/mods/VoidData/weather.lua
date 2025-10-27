local this = {}

local common = require("VoidData.common")
local tamrielDataCommon = require("TamrielData.common")
local tamrielDataWeather = require("TamrielData.weather")

local hasBeenToMasser = false -- Right now weather replacements interefere with other mods such as Weather Adjuster and TD itself. VD has to replace most of the weather including the ashstorms (which TD has replacements for), so for now it cannot change weathers at all unless the player has been to Masser in the current session

local masserClearColors = {
	ambientSunriseColor = tes3vector3.new(0.33344924449921, 0.23704965412617, 0.14496409893036),
	ambientDayColor = tes3vector3.new(0.60205310583115, 0.54016298055649, 0.52048689126968),
	ambientSunsetColor = tes3vector3.new(0.3905137181282, 0.26701810956001, 0.21518465876579),
	ambientNightColor = tes3vector3.new(0.16012275218964, 0.076117157936096, 0.0622812025249),

	skySunriseColor = tes3vector3.new(0.86806088685989, 0.40127098560333, 0.29599210619926),
	skyDayColor = tes3vector3.new(0.84770435094833, 0.42411622405052, 0.28223183751106),
	skySunsetColor = tes3vector3.new(0.41936293244362, 0.31905883550644, 0.29449909925461),
	skyNightColor = tes3vector3.new(0.038736172020435, 0.038727939128876, 0.038726814091206),

	sunSunriseColor = tes3vector3.new(0.94901967048645, 0.6235294342041, 0.46666669845581),
	sunDayColor = tes3vector3.new(0.99576979875565, 0.93321496248245, 0.88151997327805),
	sunSunsetColor = tes3vector3.new(0.48835605382919, 0.70857733488083, 0.86679488420486),
	sunNightColor = tes3vector3.new(0.078324243426323, 0.39300358295441, 0.72016263008118),

	fogSunriseColor = tes3vector3.new(1, 0.74117648601532, 0.61568629741669),
	fogDayColor = tes3vector3.new(0.98333942890167, 0.70113378763199, 0.5899515748024),
	fogSunsetColor = tes3vector3.new(0.8583248257637, 0.69131457805634, 0.63733404874802),
	fogNightColor = tes3vector3.new(0.043895747512579, 0.037395816296339, 0.035875331610441),

	sundiscSunsetColor = tes3vector3.new(0.48138418793678, 0.84445405006409, 0.99445337057114),
}
local masserClear = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = masserClearColors, sky = nil, clouds = nil, sound = nil }

local masserCloudyColors = {
	ambientSunriseColor = tes3vector3.new(0.38157007098198, 0.26800218224525, 0.22052690386772),
	ambientDayColor = tes3vector3.new(0.60306692123413, 0.56612521409988, 0.55812537670135),
	ambientSunsetColor = tes3vector3.new(0.39074423909187, 0.30294641852379, 0.26686233282089),
	ambientNightColor = tes3vector3.new(0.18608456850052, 0.08224131911993, 0.072520740330219),

	skySunriseColor = tes3vector3.new(0.84250062704086, 0.41527849435806, 0.36690276861191),
	skyDayColor = tes3vector3.new(0.93660247325897, 0.52352833747864, 0.4225372672081),
	skySunsetColor = tes3vector3.new(0.51484781503677, 0.35804954171181, 0.35163488984108),
	skyNightColor = tes3vector3.new(0.038736172020435, 0.038727939128876, 0.038726814091206),

	sunSunriseColor = tes3vector3.new(0.93868178129196, 0.6246252655983, 0.52235507965088),
	sunDayColor = tes3vector3.new(0.83564674854279, 0.71450281143188, 0.6697718501091),
	sunSunsetColor = tes3vector3.new(0.43660944700241, 0.54121768474579, 0.59852284193039),
	sunNightColor = tes3vector3.new(0.08218827098608, 0.18404769897461, 0.332728266716),

	fogSunriseColor = tes3vector3.new(0.89818143844604, 0.60814416408539, 0.49734088778496),
	fogDayColor = tes3vector3.new(0.82611429691315, 0.58741927146912, 0.49339452385902),
	fogSunsetColor = tes3vector3.new(0.84760695695877, 0.53756648302078, 0.45888656377792),
	fogNightColor = tes3vector3.new(0.046724565327168, 0.036672711372375, 0.034268621355295),

	sundiscSunsetColor = tes3vector3.new(0.48138418793678, 0.84445405006409, 0.99445337057114),
}
local masserCloudy = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = masserCloudyColors, sky = nil, clouds = nil, sound = nil }

local masserFoggyColors = {
	ambientSunriseColor = tes3vector3.new(0.2144970446825, 0.16593477129936, 0.16209203004837),
	ambientDayColor = tes3vector3.new(0.48764798045158, 0.41042533516884, 0.3903477191925),
	ambientSunsetColor = tes3vector3.new(0.29265037178993, 0.167635217309, 0.14823950827122),
	ambientNightColor = tes3vector3.new(0.12623943388462, 0.093936748802662, 0.084874756634235),

	skySunriseColor = tes3vector3.new(0.81032007932663, 0.49351236224174, 0.42406141757965),
	skyDayColor = tes3vector3.new(0.85333061218262, 0.41427105665207, 0.28625482320786),
	skySunsetColor = tes3vector3.new(0.75541079044342, 0.45076686143875, 0.38487136363983),
	skyNightColor = tes3vector3.new(0.13924111425877, 0.077647186815739, 0.052030239254236),

	sunSunriseColor = tes3vector3.new(0.9026905298233, 0.54966551065445, 0.46703842282295),
	sunDayColor = tes3vector3.new(0.62997782230377, 0.28264808654785, 0.18347425758839),
	sunSunsetColor = tes3vector3.new(0.75430738925934, 0.56058180332184, 0.45552554726601),
	sunNightColor = tes3vector3.new(0.35631701350212, 0.2461364865303, 0.19777220487595),

	fogSunriseColor = tes3vector3.new(0.80233514308929, 0.47534641623497, 0.40488234162331),
	fogDayColor = tes3vector3.new(0.92916697263718, 0.44503176212311, 0.30479067564011),
	fogSunsetColor = tes3vector3.new(0.75049996376038, 0.45760244131088, 0.39374601840973),
	fogNightColor = tes3vector3.new(0.1408734023571, 0.076967000961304, 0.04992862418294),

	sundiscSunsetColor = tes3vector3.new(0.87450987100601, 0.87450987100601, 0.87450987100601),
}
local masserFoggy = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = masserFoggyColors, sky = nil, clouds = nil, sound = nil }

local masserOvercastColors = {
	ambientSunriseColor = tes3vector3.new(0.36493134498596, 0.26504781842232, 0.20360624790192),
	ambientDayColor = tes3vector3.new(0.42611154913902, 0.37031421065331, 0.34982573986053),
	ambientSunsetColor = tes3vector3.new(0.34428340196609, 0.25039973855019, 0.21140196919441),
	ambientNightColor = tes3vector3.new(0.2139533162117, 0.13751409947872, 0.12713532149792),

	skySunriseColor = tes3vector3.new(0.53083258867264, 0.23336492478848, 0.11300400644541),
	skyDayColor = tes3vector3.new(0.73799443244934, 0.38386559486389, 0.2225645929575),
	skySunsetColor = tes3vector3.new(0.65496128797531, 0.35367235541344, 0.23152466118336),
	skyNightColor = tes3vector3.new(0.12542326748371, 0.072381071746349, 0.069673977792263),

	sunSunriseColor = tes3vector3.new(0.67086064815521, 0.41581824421883, 0.29188826680183),
	sunDayColor = tes3vector3.new(0.69255495071411, 0.60569089651108, 0.55772471427917),
	sunSunsetColor = tes3vector3.new(0.61398541927338, 0.5023695230484, 0.40852230787277),
	sunNightColor = tes3vector3.new(0.16364648938179, 0.22141046822071, 0.34077090024948),

	fogSunriseColor = tes3vector3.new(0.64752751588821, 0.38376072049141, 0.2769603729248),
	fogDayColor = tes3vector3.new(0.89190155267715, 0.48755145072937, 0.30398803949356),
	fogSunsetColor = tes3vector3.new(0.83715760707855, 0.46104454994202, 0.30856058001518),
	fogNightColor = tes3vector3.new(0.12546072900295, 0.075793050229549, 0.071115039288998),

	sundiscSunsetColor = tes3vector3.new(0.48138418793678, 0.84445405006409, 0.99445337057114),
}
local masserOvercast = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = masserOvercastColors, sky = nil, clouds = nil, sound = nil }

local masserAshstormColors = {
	ambientSunriseColor = tes3vector3.new(0.23813058435917, 0.17061023414135, 0.16007867455482),
	ambientDayColor = tes3vector3.new(0.33647280931473, 0.16994585096836, 0.1436074078083),
	ambientSunsetColor = tes3vector3.new(0.38319018483162, 0.052525985985994, 0.063012562692165),
	ambientNightColor = tes3vector3.new(0.26281398534775, 0.12130510061979, 0.10842987149954),

	skySunriseColor = tes3vector3.new(0.50550448894501, 0.13131086528301, 0.11963578313589),
	skyDayColor = tes3vector3.new(0.60116565227509, 0.20102466642857, 0.16258192062378),
	skySunsetColor = tes3vector3.new(0.40955230593681, 0.21631334722042, 0.19730058312416),
	skyNightColor = tes3vector3.new(0.15970554947853, 0.04787340387702, 0.016314331442118),

	sunSunriseColor = tes3vector3.new(0.75037693977356, 0.26544919610023, 0.061523873358965),
	sunDayColor = tes3vector3.new(0.80425918102264, 0.54517948627472, 0.46536707878113),
	sunSunsetColor = tes3vector3.new(0.72549021244049, 0.33725491166115, 0.22352942824364),
	sunNightColor = tes3vector3.new(0.28657045960426, 0.24270516633987, 0.23380754888058),

	fogSunriseColor = tes3vector3.new(0.48376357555389, 0.15062862634659, 0.1317018866539),
	fogDayColor = tes3vector3.new(0.58546501398087, 0.21980695426464, 0.1257963180542),
	fogSunsetColor = tes3vector3.new(0.3927256166935, 0.22549296915531, 0.20749755203724),
	fogNightColor = tes3vector3.new(0.16751565039158, 0.041541509330273, 0.0094886962324381),

	sundiscSunsetColor = tes3vector3.new(0.87450987100601, 0.87450987100601, 0.87450987100601)
}
local masserAshstorm = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = masserAshstormColors, sky = nil, clouds = nil, sound = nil }

local masserScatteringTable = { inscatter = tes3vector3.new(0.096720301020052, 0.45920241806197, 0.509099200046), outscatter = tes3vector3.new(0.35370452573781, 0.30363342641662, 0.2474806474845) }
local masserSkylightScatteringTable = { mix = 0.398, skylight = tes3vector3.new(0.71800758740061, 0.61285649227168, 0.45412380778811) }

local defaultClearColors = {
	ambientSunriseColor = tes3vector3.new(0.1843137294054, 0.258823543787, 0.37647062540054),
	ambientDayColor = tes3vector3.new(0.53725492954254, 0.54901963472366, 0.62745100259781),
	ambientSunsetColor = tes3vector3.new(0.26666668057442, 0.29411765933037, 0.37647062540054),
	ambientNightColor = tes3vector3.new(0.12549020349979, 0.13725490868092, 0.16470588743687),

	skySunriseColor = tes3vector3.new(0.4588235616684, 0.55294120311737, 0.64313727617264),
	skyDayColor = tes3vector3.new(0.37254902720451, 0.52941179275513, 0.79607850313187),
	skySunsetColor = tes3vector3.new(0.21960785984993, 0.34901961684227, 0.50588238239288),
	skyNightColor = tes3vector3.new(0.035294119268656, 0.039215687662363, 0.04313725605607),

	fogSunriseColor = tes3vector3.new(1, 0.74117648601532, 0.61568629741669),
	fogDayColor = tes3vector3.new(0.80784320831299, 0.89019614458084,1),
	fogSunsetColor = tes3vector3.new(1, 0.74117648601532, 0.61568629741669),
	fogNightColor = tes3vector3.new(0.035294119268656, 0.039215687662363, 0.04313725605607),

	sunSunriseColor = tes3vector3.new(0.94901967048645, 0.6235294342041, 0.46666669845581),
	sunDayColor = tes3vector3.new(1, 0.98823535442352, 0.93333339691162),
	sunSunsetColor = tes3vector3.new(1, 0.44705885648727, 0.3098039329052),
	sunNightColor = tes3vector3.new(0.23137256503105, 0.38039219379425, 0.69019609689713),

	sundiscSunsetColor = tes3vector3.new(1, 0.74117648601532, 0.61568629741669)
}
local defaultClear = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = defaultClearColors, sky = nil, clouds = nil, sound = nil }

local defaultCloudyColors = {
	ambientSunriseColor = tes3vector3.new(0.258823543787, 0.29019609093666, 0.34117648005486),
	ambientDayColor = tes3vector3.new(0.53725492954254, 0.5686274766922, 0.62745100259781),
	ambientSunsetColor = tes3vector3.new(0.27843138575554, 0.3137255012989, 0.36078432202339),
	ambientNightColor = tes3vector3.new(0.12549020349979, 0.15294118225574, 0.21176472306252),

	skySunriseColor = tes3vector3.new(0.49411767721176, 0.61960786581039, 0.678431391716),
	skyDayColor = tes3vector3.new(0.4588235616684, 0.62745100259781, 0.84313732385635),
	skySunsetColor = tes3vector3.new(0.43529415130615, 0.44705885648727, 0.6235294342041),
	skyNightColor = tes3vector3.new(0.035294119268656, 0.039215687662363, 0.04313725605607),

	fogSunriseColor = tes3vector3.new(1, 0.8117647767067, 0.58431375026703),
	fogDayColor = tes3vector3.new(0.96078437566757, 0.9215686917305, 0.87843143939972),
	fogSunsetColor = tes3vector3.new(1, 0.60784316062927, 0.41568630933762),
	fogNightColor = tes3vector3.new(0.035294119268656, 0.039215687662363, 0.04313725605607),

	sunSunriseColor = tes3vector3.new(0.94509810209274, 0.69411766529083, 0.38823533058167),
	sunDayColor = tes3vector3.new(1, 0.92549026012421, 0.8666667342186),
	sunSunsetColor = tes3vector3.new(1, 0.34901961684227, 0),
	sunNightColor = tes3vector3.new(0.30196079611778, 0.35686275362968, 0.48627454042435),

	sundiscSunsetColor = tes3vector3.new(1, 0.79215693473816, 0.70196080207825)
}
local defaultCloudy = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = defaultCloudyColors, sky = nil, clouds = nil, sound = nil }

local defaultFoggyColors = {
	ambientSunriseColor = tes3vector3.new(0.18823531270027, 0.16862745583057, 0.14509804546833),
	ambientDayColor = tes3vector3.new(0.36078432202339, 0.42745101451874, 0.47058826684952),
	ambientSunsetColor = tes3vector3.new(0.11372549831867, 0.20784315466881, 0.29803922772408),
	ambientNightColor = tes3vector3.new(0.10980392992496, 0.1294117718935, 0.15294118225574),

	skySunriseColor = tes3vector3.new(0.77254909276962, 0.74509805440903, 0.70588237047195),
	skyDayColor = tes3vector3.new(0.72156864404678, 0.82745105028152, 0.89411771297455),
	skySunsetColor = tes3vector3.new(0.55686277151108, 0.6235294342041, 0.69019609689713),
	skyNightColor = tes3vector3.new(0.070588238537312, 0.090196080505848, 0.10980392992496),

	fogSunriseColor = tes3vector3.new(0.678431391716, 0.64313727617264, 0.58039218187332),
	fogDayColor = tes3vector3.new(0.58823531866074, 0.73333334922791, 0.81960791349411),
	fogSunsetColor = tes3vector3.new(0.44313728809357, 0.52941179275513, 0.61568629741669),
	fogNightColor = tes3vector3.new(0.074509806931019, 0.094117656350136, 0.11372549831867),

	sunSunriseColor = tes3vector3.new(0.69411766529083, 0.63529413938522, 0.53725492954254),
	sunDayColor = tes3vector3.new(0.43529415130615, 0.5137255191803, 0.59215688705444),
	sunSunsetColor = tes3vector3.new(0.49019610881805, 0.61568629741669, 0.74117648601532),
	sunNightColor = tes3vector3.new(0.31764706969261, 0.39215689897537, 0.46666669845581),

	sundiscSunsetColor = tes3vector3.new(0.87450987100601, 0.87450987100601, 0.87450987100601)
}
local defaultFoggy = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = defaultFoggyColors, sky = nil, clouds = nil, sound = nil }

local defaultOvercastColors = {
	ambientSunriseColor = tes3vector3.new(0.32941177487373, 0.34509804844856, 0.36078432202339),
	ambientDayColor = tes3vector3.new(0.3647058904171, 0.37647062540054, 0.41176474094391),
	ambientSunsetColor = tes3vector3.new(0.32549020648003, 0.30196079611778, 0.29411765933037),
	ambientNightColor = tes3vector3.new(0.22352942824364, 0.23529413342476, 0.258823543787),

	skySunriseColor = tes3vector3.new(0.35686275362968, 0.38823533058167, 0.41568630933762),
	skyDayColor = tes3vector3.new(0.56078433990479, 0.57254904508591, 0.58431375026703),
	skySunsetColor = tes3vector3.new(0.42352944612503, 0.45098042488098, 0.47450983524323),
	skyNightColor = tes3vector3.new(0.074509806931019, 0.086274512112141, 0.098039224743843),

	fogSunriseColor = tes3vector3.new(0.35686275362968, 0.38823533058167, 0.41568630933762),
	fogDayColor = tes3vector3.new(0.56078433990479, 0.57254904508591, 0.58431375026703),
	fogSunsetColor = tes3vector3.new(0.42352944612503, 0.45098042488098, 0.47450983524323),
	fogNightColor = tes3vector3.new(0.074509806931019, 0.086274512112141, 0.098039224743843),

	sunSunriseColor = tes3vector3.new(0.34117648005486, 0.49019610881805, 0.63921570777893),
	sunDayColor = tes3vector3.new(0.89411771297455,0.54509806632996,0.44705885648727),
	sunSunsetColor = tes3vector3.new(0.33333334326744, 0.40392160415649, 0.61568629741669),
	sunNightColor = tes3vector3.new(0.12549020349979, 0.21176472306252, 0.39215689897537),

	sundiscSunsetColor = tes3vector3.new(0.50196081399918, 0.50196081399918, 0.50196081399918)
}
local defaultOvercast = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = defaultOvercastColors, sky = nil, clouds = nil, sound = nil }

local defaultAshColors = {
	ambientSunriseColor = tes3vector3.new(0.21176472306252,0.16470588743687,0.14509804546833),
	ambientDayColor = tes3vector3.new(0.29411765933037,0.19215688109398,0.16078431904316),
	ambientSunsetColor = tes3vector3.new(0.18823531270027,0.15294118225574,0.13725490868092),
	ambientNightColor = tes3vector3.new(0.14117647707462,0.16470588743687,0.19215688109398),

	skySunriseColor = tes3vector3.new(0.35686275362968,0.21960785984993,0.20000001788139),
	skyDayColor = tes3vector3.new(0.48627454042435,0.28627452254295,0.22745099663734),
	skySunsetColor = tes3vector3.new(0.41568630933762,0.21568629145622,0.15686275064945),
	skyNightColor = tes3vector3.new(0.078431375324726,0.082352943718433,0.086274512112141),

	fogSunriseColor = tes3vector3.new(0.35686275362968,0.21960785984993,0.20000001788139),
	fogDayColor = tes3vector3.new(0.48627454042435,0.28627452254295,0.22745099663734),
	fogSunsetColor = tes3vector3.new(0.41568630933762,0.21568629145622,0.15686275064945),
	fogNightColor = tes3vector3.new(0.078431375324726,0.082352943718433,0.086274512112141),

	sunSunriseColor = tes3vector3.new(0.72156864404678,0.35686275362968,0.27843138575554),
	sunDayColor = tes3vector3.new(0.89411771297455,0.54509806632996,0.44705885648727),
	sunSunsetColor = tes3vector3.new(0.72549021244049,0.33725491166115,0.22352942824364),
	sunNightColor = tes3vector3.new(0.21176472306252,0.258823543787,0.29019609093666),

	sundiscSunsetColor = tes3vector3.new(0.50196081399918,0.50196081399918,0.50196081399918)
}
local defaultAshstorm = { fog = nil, fogMGE = nil, wind = nil, windMGE = nil,
						colors = defaultAshColors, sky = nil, clouds = nil, sound = nil }

local defaultScatteringTable
local defaultSkylightScatteringTable

---@param e weatherChangedImmediateEventData
function this.manageWeathers(e)
	if not defaultScatteringTable then
		defaultScatteringTable = mge.weather.getScattering()
		defaultScatteringTable = mge.weather.getSkylightScattering()
	end

	if e.cell and not e.cell.isOrBehavesAsExterior then
		return	-- Don't bother with anything below if the player is entering a normal interior cell
	end

	local weather
	local nextWeather

	if not e.to then
		weather = tes3.getCurrentWeather()
		if weather.controller.nextWeather then
			nextWeather = weather.controller.nextWeather
		end
	else
		weather = e.to
	end

	local extCell = tamrielDataCommon.getExteriorCell(tes3.player.cell)	-- Should be more reliable than getRegion

	if extCell.region and common.masserRegions[extCell.region.id] then
		hasBeenToMasser = true
		if mge.enabled() then
			mge.weather.setScattering({ inscatter = masserScatteringTable.inscatter, outscatter = masserScatteringTable.outscatter })
			mge.weather.setSkylightScattering({ inscatter = masserSkylightScatteringTable.mix, skylight = masserSkylightScatteringTable.skylight })
		end

		if weather.name == "Clear" or (nextWeather and nextWeather.name == "Clear") then
			if weather.name == "Clear" then
				tamrielDataWeather.changeWeather(weather, masserClear)
			else
				tamrielDataWeather.changeWeather(nextWeather, masserClear)
			end
		elseif weather.name == "Cloudy" or (nextWeather and nextWeather.name == "Cloudy") then
			if weather.name == "Cloudy" then
				tamrielDataWeather.changeWeather(weather, masserCloudy)
			else
				tamrielDataWeather.changeWeather(nextWeather, masserCloudy)
			end
		elseif weather.name == "Foggy" or (nextWeather and nextWeather.name == "Foggy") then
			if weather.name == "Foggy" then
				tamrielDataWeather.changeWeather(weather, masserFoggy)
			else
				tamrielDataWeather.changeWeather(nextWeather, masserFoggy)
			end
		elseif weather.name == "Overcast" or (nextWeather and nextWeather.name == "Overcast") then
			if weather.name == "Overcast" then
				tamrielDataWeather.changeWeather(weather, masserOvercast)
			else
				tamrielDataWeather.changeWeather(nextWeather, masserOvercast)
			end
		elseif weather.name == "Ashstorm" or (nextWeather and nextWeather.name == "Ashstorm") then
			if weather.name == "Ashstorm" then
				tamrielDataWeather.changeWeather(weather, masserAshstorm)
			else
				tamrielDataWeather.changeWeather(nextWeather, masserAshstorm)
			end
		end
	elseif hasBeenToMasser then
		if mge.enabled() and mge.weather.getScattering().inscatter == masserScatteringTable.inscatter then
			mge.weather.setScattering({ inscatter = defaultScatteringTable.inscatter, outscatter = defaultScatteringTable.outscatter })
			mge.weather.setSkylightScattering({ inscatter = defaultSkylightScatteringTable.mix, skylight = defaultSkylightScatteringTable.skylight })
		end

		if weather.name == "Clear" or (nextWeather and nextWeather.name == "Clear") then
			if weather.name == "Clear" then
				tamrielDataWeather.changeWeather(weather, defaultClear)
			else
				tamrielDataWeather.changeWeather(nextWeather, defaultClear)
			end
		elseif weather.name == "Cloudy" or (nextWeather and nextWeather.name == "Cloudy") then
			if weather.name == "Cloudy" then
				tamrielDataWeather.changeWeather(weather, defaultCloudy)
			else
				tamrielDataWeather.changeWeather(nextWeather, defaultCloudy)
			end
		elseif weather.name == "Foggy" or (nextWeather and nextWeather.name == "Foggy") then
			if weather.name == "Foggy" then
				tamrielDataWeather.changeWeather(weather, defaultFoggy)
			else
				tamrielDataWeather.changeWeather(nextWeather, defaultFoggy)
			end
		elseif weather.name == "Overcast" or (nextWeather and nextWeather.name == "Overcast") then
			if weather.name == "Overcast" then
				tamrielDataWeather.changeWeather(weather, defaultOvercast)
			else
				tamrielDataWeather.changeWeather(nextWeather, defaultOvercast)
			end
		elseif weather.name == "Ashstorm" or (nextWeather and nextWeather.name == "Ashstorm") then
			if weather.name == "Ashstorm" then
				tamrielDataWeather.changeWeather(weather, defaultAshstorm)
			else
				tamrielDataWeather.changeWeather(nextWeather, defaultAshstorm)
			end
		end
	end
end

return this