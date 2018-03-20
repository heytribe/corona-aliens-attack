---------------------------------------------------------------------------------
-- Modules

local messenger 	= require "engine.messenger"
local texts      	= require "texts"

---------------------------------------------------------------------------------
-- Parameters

local engine = {}
local myUserId, masterUserId
local playersIds    = {}
local playersById   = {}
local playingIds    = {}
local playersScores = {}

---------------------------------------------------------------------------------
-- Timestamp

engine.getStartGameTimestamp = function()
	return os.time() + 5
end

engine.getDelayUntilTimestamp = function(timestamp)
	return math.max(0, timestamp - os.time()) * 1000
end

---------------------------------------------------------------------------------
-- Game Master

engine.isMaster = function() 
	return myUserId == masterUserId
end

---------------------------------------------------------------------------------
-- Scores

engine.score = function(playerId)
	return playersScores[myUserId]
end

engine.myUserId = function()
	return myUserId
end

engine.addPointsToScore = function(points)
	log('engine - addPointsToScore')
	local score = playersScores[myUserId]
	if score then
		score = score + points
	else
		score = points
	end
	playersScores[myUserId] = score
	engine.broadcastUpdatedScores()
	return score
end

engine.broadcastUpdatedScores = function() 
	log('engine - broadcastUpdatedScores')
	for i,id in ipairs(playersIds) do
		if not playersScores[id] then
			playersScores[id] = 0
		end
	end
	if engine.isMaster() then
		messenger.broadcastScores(playersScores)
	else
		-- Reduced payload
		local message = {}
		message[myUserId] = playersScores[myUserId] 
		messenger.broadcastScores(message)
	end
end

engine.scoresUpdated = function(updatedPlayersScores)
	log('engine - scoresUpdated')
	for userId,score in pairs(updatedPlayersScores) do
		playersScores[userId] = score
	end
	Runtime:dispatchEvent({ name='coronaView', event='scoresUpdated', scores=playersScores })
end

engine.resetScores = function()
	log('engine - resetScores')
	playersScores = {}
	engine.broadcastUpdatedScores()
end

---------------------------------------------------------------------------------

engine.startGame = function(event) 
	log('engine - startGame')
	
	myUserId     = event.myUserId
	masterUserId = event.masterUserId
	playersById = {}
	
	for i,u in ipairs(event.playersUsers) do
		playersById[u.id] = u
		table.insert(playersIds, u.id)
	end

	timer.performWithDelay(500, function() 
		log('engine - will broadcastUserReady')
		messenger.broadcastUserReady()
		if engine.isMaster() then
			engine.resetScores()
			messenger.broadcastNewGame(myUserId, engine.getStartGameTimestamp(), playersIds)
		end
	end)

end

engine.userJoined = function(event) 
	log('engine - userJoined')
	local user = event.user
	playersById[user.id] = user
	table.insert(playersIds, user.id)
	if isMaster() then
		broadcastUpdatedScores()
	end
end

engine.userLeft = function(event) 
	log('engine - userLeft')
	local userId = event.userId
	playingIds[userId]    = nil
	playersById[userId]   = nil
	playersScores[userId] = nil
	if masterUserId == userId then
		reelectNewMaster()
	end
end

---------------------------------------------------------------------------------

engine.becomeGameMaster = function()
	log('engine - becomeGameMaster')
	engine.resetScores()
	messenger.broadcastNewGame(myUserId, engine.getStartGameTimestamp(), playersIds)
end

---------------------------------------------------------------------------------

engine.localUserGameOver = function()
	log('engine - localUserGameOver')
	messenger.broadcastUserGameOver(myUserId)
end

engine.userGameOver = function(userId)
	log('engine - userGameOver')
	if playingIds[userId] then
		playingIds[userId] = nil
		if engine.isMaster() then
			-- No-one is playing anymore
			if next(playingIds) == nil then
				log('engine - userGameOver - broadcastGameOver')
				messenger.broadcastGameOver(userId)
			else
				log('engine - userGameOver - broadcastShowUserLost')
				messenger.broadcastShowUserLost(userId)
			end
		end
	end
end

engine.showUserLost = function(userId)
	log('engine - showUserLost')
	if userId == myUserId then
		texts.showYouLost()
	else
		local user = playersById[userId]
		texts.showSomeoneLost(user.displayName)
	end
end

engine.gameOver = function(winnerId)
	log('engine - gameOver')
	if winnerId then
		if winnerId == myUserId then
			if #playersIds > 1 then
				texts.showYouWon({ onComplete=engine.becomeGameMaster })
			else
				texts.showYouLost({ onComplete=engine.becomeGameMaster })
			end

		else
			local winner = playersById[winnerId]
			texts.showSomeoneWon(winner.displayName)
		end
	else
		if fromUserId == myUserId or not fromUserId then
			texts.showGameOver({ onComplete=engine.becomeGameMaster })
		else
			texts.showGameOver()
		end
	end
end

engine.newGame = function(fromUserId, timestamp, playersIds)
	log('engine - newGame')
	masterUserId = fromUserId
	playingIds = {}
	for i,v in ipairs(playersIds) do
		playingIds[v] = true
	end
end

engine.takeOverGame = function()
	log('engine - takeOverGame')
	engine.broadcastUpdatedScores()
	if next(playingIds) == nil then
		messenger.broadcastGameOver(nil)
	else
		createAlien(previousOccurrence)
	end
end

engine.reelectNewMaster = function()
	log('engine - reelectNewMaster')
	table.sort(playersIds)
	masterUser = playersById[playersIds[0]]
	if engine.isMaster() then
		engine.takeOverGame()
	end
end

---------------------------------------------------------------------------------
-- Events listener

Runtime:addEventListener('startGame',    engine.startGame)
Runtime:addEventListener('userJoined',   engine.userJoined)
Runtime:addEventListener('userLeft',     engine.userLeft)

messenger.addMessageListener('newGame',			engine.newGame)
messenger.addMessageListener('scoresUpdated', 	engine.scoresUpdated)
messenger.addMessageListener('showUserLost',  	engine.showUserLost)
messenger.addMessageListener('userGameOver',  	engine.userGameOver)
messenger.addMessageListener('gameOver',	  	engine.gameOver)

return engine