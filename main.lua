---------------------------------------------------------------------------------
-- Modules

local composer = require "composer"

---------------------------------------------------------------------------------
-- Parameters

-- Global - Hackish way to detect the simulator...
isSimulator = true -- system.getInfo("build") == '2017.3184'

function log(string)
	print('🍺 - Corona - ' .. string)
end

---------------------------------------------------------------------------------

composer.gotoScene("level")
