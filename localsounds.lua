---------------------------------------------------------------------------------
-- Parameters

local exports = {}

---------------------------------------------------------------------------------
-- Export Functions

exports.load = function()
	if system.getInfo("platform") == "android" then
		shouldHandleSoundNatively = false
		loadedSounds = {
			alienKilled = audio.loadSound(soundPath("alien_killed")),
			playerLost  = audio.loadSound(soundPath("player_lost")),
			playerWon   = audio.loadSound(soundPath("player_won")),
			watch       = audio.loadSound(soundPath("watch")),
		}
		loadedStreams = {
			audio.loadStream(soundPath("soundtrack_0")),
			audio.loadStream(soundPath("soundtrack_1")),
			audio.loadStream(soundPath("soundtrack_2")),
		}
	else
		shouldHandleSoundNatively = true
		loadedSounds = {
			alienKilled = soundPath("alien_killed"),
			playerLost  = soundPath("player_lost"),
			playerWon   = soundPath("player_won"),
			watch       = soundPath("watch"),
		}
		loadedStreams = {
			soundPath("soundtrack_0"),
			soundPath("soundtrack_1"),
			soundPath("soundtrack_2"),
		}
	end
end

exports.load = function(handleNatively, soundPath)

	if not handleNatively then

		local loadedSounds = {
			alienKilled = audio.loadSound(soundPath("alien_killed")),
			playerLost  = audio.loadSound(soundPath("player_lost")),
			playerWon   = audio.loadSound(soundPath("player_won")),
			watch       = audio.loadSound(soundPath("watch")),
		}
	
		local loadedStreams = {
			audio.loadStream(soundPath("soundtrack_0")),
			audio.loadStream(soundPath("soundtrack_1")),
			audio.loadStream(soundPath("soundtrack_2")),
		}

		return loadedSounds, loadedStreams

	end

	local loadedSounds = {
		alienKilled = soundPath("alien_killed"),
		playerLost  = soundPath("player_lost"),
		playerWon   = soundPath("player_won"),
		watch       = soundPath("watch"),
	}
	
	local loadedStreams = {
		soundPath("soundtrack_0"),
		soundPath("soundtrack_1"),
		soundPath("soundtrack_2"),
	}

	return loadedSounds, loadedStreams
	
	
end

return exports
