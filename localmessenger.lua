---------------------------------------------------------------------------------
-- Parameters

local ACTION_POP_ALIEN 	= "popAlien"
local ALIEN_KEY        	= "alien"
local OCCURRENCE_KEY 	= "occurrence"

---------------------------------------------------------------------------------

local exports = {}

exports.manageAction = function(action, message, listener)

	if action == ACTION_POP_ALIEN then
		listener(message[ALIEN_KEY], message[OCCURRENCE_KEY])
	end

end

exports.popAlienMessage = function(alien, occurrence)

	local message = {}
	message[ACTION_KEY]     = ACTION_POP_ALIEN
	message[ALIEN_KEY]      = alien
	message[OCCURRENCE_KEY] = occurrence

    return message
end

return exports