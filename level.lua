---------------------------------------------------------------------------------
-- Modules

local composer 			= require "composer"
local physics  			= require "physics"
local sounds     		= require "sounds"
local texts      		= require "texts"
local vibrator   		= require "vibrator"
local background 		= require "background"
local aliens     		= require "aliens"
local model      		= require "model"
local bonus      		= require "bonus"
local persistenceStore 	= require "revive.persistenceStore"
local engine			= require "engine.engine"
local messenger  		= require "engine.messenger"

---------------------------------------------------------------------------------
-- Parameters

local scene = composer.newScene()
local previousOccurrence = 0
local createAlienTimer
local paceFactorTimer
local aliensPaceFactor = 1
local disableAlienCreation = false
local reviveData
local reviveAlienGroup

---------------------------------------------------------------------------------
-- Sound

local function toggleVolume(event)
	log('level - toggleVolume')
	if not (sounds.isVolumeEnabled == event.isEnabled) then
		sounds.isVolumeEnabled = event.isEnabled
		if not event.isEnabled then
			sounds.stopSoundtrack()
		else
			sounds.playSoundtrack(0)
		end
	end
end

---------------------------------------------------------------------------------
-- Bonuses

local function useBomb()
	log('level - useBomb')
	aliens.killAliens()
	background.shake()
end

local function useWatch()
	log('level - useWatch')
	sounds.playWatch()
	aliensPaceFactor = 3
	aliens.changeAliensSpeed(3)
	paceFactorTimer = timer.performWithDelay(5000, function ()
		aliensPaceFactor = 1
		aliens.changeAliensSpeed(1)
	end)
end

---------------------------------------------------------------------------------
-- Revive

local function showReviveOverlay()
	log('level - showReviveOverlay')
	aliensPaceFactor = 1000000
	aliens.changeAliensSpeed(1000000)
	disableAlienCreation = true
	composer.setVariable( "titleFontName", 'Gulkave Regular' )
	composer.showOverlay( "revive.revive", { effect = "fade", time = 250, isModal = true } )
end

local function askRevive(alienGroup)
	log('level - askRevive')
	reviveAlienGroup = alienGroup
	local score = engine.score(engine.myUserId())

	if isSimulator then
		showReviveOverlay()
		return

	else

		if reviveData and reviveData.gameId and reviveData.minScoreTrigger and reviveData.minRatioTrigger and score and score > reviveData.minScoreTrigger then

			local bestScore = persistenceStore.bestScore(reviveData.gameId)
			local canRevive = persistenceStore.canRevive(reviveData.gameId)

			if bestScore then
			 	if canRevive and score > bestScore * reviveData.minRatioTrigger then
					showReviveOverlay()
					return
				end
			elseif canRevive then
				showReviveOverlay()
				return
			end

		end
	end 

	-- No revive
	aliensPaceFactor = 1000000
	aliens.changeAliensSpeed(1000000)
	aliens.endCollision(reviveAlienGroup)

end

function scene:doRevive()
	log('level - scene:doRevive')

	-- Save info
	if reviveData and reviveData.gameId and reviveData.disableDurationSec then
		persistenceStore.didRevive(reviveData.gameId, reviveData.disableDurationSec)
	end

	-- Kill all aliens
    useBomb()

    -- Go back to regular pace
	aliensPaceFactor = 1
	aliens.changeAliensSpeed(1)
	-- timer.resume(createAlienTimer)
	disableAlienCreation = false

end

function scene:cancelRevive()
	log('level - scene:cancelRevive')
	
	-- Make alien lost animation
	aliens.endCollision(reviveAlienGroup)

	-- Wait a lil before keeping the aliens poping while waiting for others...
	timer.performWithDelay(250, function() 
		aliensPaceFactor = 1
		aliens.changeAliensSpeed(1)
	end)
end

---------------------------------------------------------------------------------
-- Aliens

local function createAlien(occurrence)
	-- log('level - createAlien')

	local level = model.levelByScore(occurrence)
	local alien = aliens.create(occurrence, level)

	messenger.broadcastPopAlien(alien, occurrence)

	createAlienTimer = timer.performWithDelay(level.popInterval() * 1000, function () createAlien(occurrence + 1) end)
end

local function popAlien(alien, occurrence) 

	if occurence then
		previousOccurrence = occurrence
	else
		previousOccurrence = previousOccurrence + 1
	end

	if (previousOccurrence % aliensPaceFactor) == 0 and disableAlienCreation == false then
		aliens.pop(alien, aliensPaceFactor)
	end
end

local function alienKilled(points) 
	log('level - alienKilled')

	sounds.playAlienKilled()
	vibrator.sendImpact()

	local score = engine.addPointsToScore(points)
	if score > 0 then
		if score % 100 == 0 then
			bonus.showBomb()
		elseif score % 50 == 0 then
			bonus.showWatch()
		end
	end

	background.switchGradient(score)
	sounds.playSoundtrack(score)
end

local function alienWillReachTheGround(alienGroup) 
	log('level - alienWillReachTheGround')
	askRevive(alienGroup)
end

local function alienDidReachTheGround() 
	log('level - alienDidReachTheGround')

	local score = engine.score(engine.myUserId())

	if score then
		if reviveData and reviveData.gameId then
			persistenceStore.saveScore(score, reviveData.gameId)
		end
		Runtime:dispatchEvent({ name='coronaView', event='saveScore', score=score })
	end

	bonus.removeBonuses()
	aliens.gameEnded()
	engine.localUserGameOver()
end

---------------------------------------------------------------------------------
-- Game Flow

local function startGame(event)
	sounds.isVolumeEnabled = event.isVolumeEnabled
	sounds.playSoundtrack(0)
end

local function newGame(fromUserId, timestamp, playersIds)
	log('level - newGame - fromUserId = ' .. fromUserId .. ' - timestamp = ' .. timestamp)

	aliens.gameStarted()
	background.resetGradient()
	sounds.playSoundtrack(0)

	texts.showTitle({ onComplete=function ()
		texts.showLetsGo()
	end })

	previousOccurrence = 0
	if engine.isMaster() then
		timer.performWithDelay(engine.getDelayUntilTimestamp(timestamp), function ()
			createAlien(0)
		end)
	end
end

local function showUserLost(userId)
	log('level - showUserLost')
	sounds.playPlayerLost()
end

local function gameOver(winnerId)
	log('level - gameOver')

	aliensPaceFactor = 1
	disableAlienCreation = false

	if paceFactorTimer  then timer.cancel(paceFactorTimer)  end
	if createAlienTimer then timer.cancel(createAlienTimer) end
	
	sounds.playPlayerWon()
end

---------------------------------------------------------------------------------
-- Scene

function scene:create(event)
	log('level - scene:create')

	physics.start()
	physics.pause()
	sounds.load()

	local sceneGroup = self.view
	sceneGroup:insert(background.load())
	sceneGroup:insert(aliens.load())
	sceneGroup:insert(bonus.load())

	messenger.addMessageListener('newGame',       newGame)
	messenger.addMessageListener('popAlien',      popAlien)
	messenger.addMessageListener('showUserLost',  showUserLost)
	messenger.addMessageListener('gameOver',	  gameOver)

	aliens.addAlienListener('alienKilled', 			 	alienKilled)
	aliens.addAlienListener('alienWillReachTheGround', 	alienWillReachTheGround)
	aliens.addAlienListener('alienDidReachTheGround', 	alienDidReachTheGround)

	bonus.addBonusListener('useBomb',  useBomb)
	bonus.addBonusListener('useWatch', useWatch)

	Runtime:addEventListener('startGame',    startGame)
	Runtime:addEventListener('toggleVolume', toggleVolume)

	-- Load best score from native if needed
	reviveData = Runtime:dispatchEvent({ name='coronaView', event='reviveData' })
	if reviveData and reviveData.gameId then
		persistenceStore.bestScore(reviveData.gameId)
	end

end

function scene:show(event)
	log('level - scene:show ' .. event.phase)
	if event.phase == "did" then
		physics.start()
		Runtime:dispatchEvent({ name='coronaView', event='gameLoaded' })
		if isSimulator then
			local user = { id='toto', displayName='TOTO', username='toto' }
			-- local user2 = { id='toto2', displayName='TOTO2', username='toto2' }
			local event = { myUserId=user.id, masterUserId=user.id, playersUsers={user}, isVolumeEnabled=true }
			startGame(event)
			engine.startGame(event)
		end
	end
end

function scene:hide(event)
	log('level - scene:hide ' .. event.phase)
	if event.phase == "will" then
		physics.stop()
	end
end

function scene:destroy(event)
	log('level - scene:destroy')
	sounds.dispose()
	background.dispose()
	aliens.dispose()
	package.loaded[physics] = nil
	physics = nil
end

---------------------------------------------------------------------------------

scene:addEventListener('create',  scene)
scene:addEventListener('show',    scene)
scene:addEventListener('hide',    scene)
scene:addEventListener('destroy', scene)

---------------------------------------------------------------------------------

return scene