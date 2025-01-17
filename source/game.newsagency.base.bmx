SuperStrict
Import Brl.LinkedList
Import "game.programme.newsevent.bmx"
Import "game.figure.customfigures.bmx"
Import "game.world.bmx"
Import "game.game.base.bmx"
Import "game.newsagency.sports.bmx"


'likely a kind of agency providing news...
'at the moment only a base object
Type TNewsAgency
	'when to announce a new newsevent
'	Field NextEventTime:Double = -1
	'check for a new news every x-y minutes
'	Field NextEventTimeInterval:int[] = [90, 140]

	Field NextEventTimes:Double[]
	'check for a new news every x-y minutes
	Field NextEventTimeIntervals:Int[][]

	Field delayedLists:TList[]

	Field newsProviders:TNewsAgencyNewsProvider[]


	'=== TERRORIST HANDLING ===
	'both parties (VR and FR) have their own array entry
	'when to update aggression the next time
	Field terroristUpdateTime:Double[] = [Double(0),Double(0)]
	'update terrorists aggression every x-y minutes
	Field terroristUpdateTimeInterval:Int[] = [80, 100]
	'level of terrorists aggression (each level = new news)
	'party 2 starts later
	Field terroristAggressionLevel:Int[] = [0, -1]
	Field terroristAggressionLevelMax:Int = 4
	'progress in the given aggression level (0 - 1.0)
	Field terroristAggressionLevelProgress:Float[] = [0.0, 0.0]
	'rate the aggression level progresses each game hour
	Field terroristAggressionLevelProgressRate:Float[][] = [ [0.06,0.08], [0.06,0.08] ]

	Global _eventListeners:TEventListenerBase[]
	Global _instance:TNewsAgency


	Function GetInstance:TNewsAgency()
		If Not _instance Then _instance = New TNewsAgency
		Return _instance
	End Function


	Method New()
		NextEventTimes = New Double[ TVTNewsGenre.count ]
		NextEventTimeIntervals = NextEventTimeIntervals[.. TVTNewsGenre.count]
		For Local i:Int = 0 Until TVTNewsGenre.count
			NextEventTimeIntervals[i] = [180, 300]
		Next
	End Method


	Method Initialize:Int()
		'=== RESET TO INITIAL STATE ===
		For Local i:Int = 0 Until TVTNewsGenre.count
			'NextEventTimes[i] = GetWorldTime().GetTimeGone() - 60 * RandRange(60,180)
			NextEventTimes[i] = -1
		Next
		'setup the intervals of all genres
		InitializeNextEventTimeIntervals()


		terroristUpdateTime = [Double(0),Double(0)]
		terroristUpdateTimeInterval = [80, 100]
		terroristAggressionLevel = [0, -1]
		terroristAggressionLevelMax = 4
		terroristAggressionLevelProgress = [0.0, 0.0]
		terroristAggressionLevelProgressRate = [ [0.06,0.08], [0.06,0.08] ]


		'initialize all news providers too
		For Local nP:TNewsAgencyNewsProvider = EachIn newsProviders
			nP.Initialize()
		Next

		'register custom game modifier functions
		GetGameModifierManager().RegisterRunFunction("TFigureTerrorist.SendFigureToRoom", TFigureTerrorist.SendFigureToRoom)


		'=== REGISTER EVENTS ===
		EventManager.UnregisterListenersArray(_eventListeners)
		_eventListeners = New TEventListenerBase[0]

		'react to confiscations
		_eventListeners :+ [ EventManager.registerListenerFunction( "publicAuthorities.onConfiscateProgrammeLicence", onPublicAuthoritiesConfiscateProgrammeLicence) ]
		_eventListeners :+ [ EventManager.registerListenerFunction( "room.onBombExplosion", onRoomBombExplosion) ]
		_eventListeners :+ [ EventManager.registerListenerFunction( "programmecollection.addNews", onPlayerProgrammeCollectionAddNews) ]

		'resize news genres when loading an older savegame
		_eventListeners :+ [ EventManager.registerListenerFunction( "SaveGame.OnLoad", onSavegameLoad) ]


		delayedLists = New TList[4]
	End Method


	Method InitializeNextEventTimeIntervals()
		For Local i:Int = 0 Until TVTNewsGenre.count
			Select i
				Case TVTNewsGenre.POLITICS_ECONOMY
					NextEventTimeIntervals[i] = [210, 330]
				Case TVTNewsGenre.SHOWBIZ
					NextEventTimeIntervals[i] = [180, 290]
				Case TVTNewsGenre.SPORT
					NextEventTimeIntervals[i] = [200, 300]
				Case TVTNewsGenre.TECHNICS_MEDIA
					NextEventTimeIntervals[i] = [220, 350]
				Case TVTNewsGenre.CULTURE
					NextEventTimeIntervals[i] = [240, 380]
				'default
			'	case TVTNewsGenre.CURRENT_AFFAIRS
			'		NextEventTimeIntervals[i] = [180, 300]
				Default
					NextEventTimeIntervals[i] = [180, 300]
			End Select
		Next
	End Method


	Function onSavegameLoad:Int(triggerEvent:TEventBase)
		Local NA:TNewsAgency = GetInstance()
		If NA.NextEventTimes.length < TVTNewsGenre.count
			NA.NextEventTimes = NA.NextEventTimes[.. TVTNewsGenre.count]
			NA.NextEventTimeIntervals = NA.NextEventTimeIntervals[.. TVTNewsGenre.count]
		EndIf

		'=== SETUP ALL INTERVALS ===
		'this sets to the most current values (might differ from older
		'savegames)
		'and it also initializes times in savegames NOT having that time
		'defined yet
		NA.InitializeNextEventTimeIntervals()
	End Function


	Function onPlayerProgrammeCollectionAddNews:Int(triggerEvent:TEventBase)
		'remove news events from delayed list IF still there
		'(happens with 3 start news - added to delayed and then added
		' directly to collection)

		Local news:TNews = TNews(triggerEvent.GetData().get("news"))
		If Not news Then Return False
		_instance.RemoveFromDelayedListsByNewsEvent(news.owner, news.newsEvent)
	End Function


	Function onPublicAuthoritiesConfiscateProgrammeLicence:Int(triggerEvent:TEventBase)
		Local targetProgrammeGUID:String = triggerEvent.GetData().GetString("targetProgrammeGUID")
		Local confiscatedProgrammeGUID:String = triggerEvent.GetData().GetString("confiscatedProgrammeGUID")
		Local player:TPlayerBase = TPlayerBase(triggerEvent.GetSender())
		'nothing more for now
	End Function


	Function onRoomBombExplosion:Int(triggerEvent:TEventBase)
		Local roomGUID:String = triggerEvent.GetData().GetString("roomGUID")
		Local bombRedirectedByPlayers:Int = triggerEvent.GetData().GetInt("roomSignMovedByPlayers")
		Local bombLastRedirectedByPlayerID:Int = triggerEvent.GetData().GetInt("roomSignLastMoveByPlayerID")

		Local room:TRoomBase = TRoomBase( triggerEvent.GetSender() )
		If Not room
			TLogger.Log("NewsAgency", "Failed to create news for bomb explosion: invalid room passed for roomGUID ~q"+roomGUID+"~q", LOG_ERROR)
			Return False
		EndIf

		'collect all channels having done this
		Local caughtChannels:String = ""
		Local caughtChannelIDs:String = ""
		Local caughtChannelIDsArray:Int[]
		For Local i:Int = 1 To 4
			Local playerBitmask:Int = 2^(i-1)
			If bombRedirectedByPlayers & playerBitmask > 0
				If caughtChannels <> "" Then caughtChannels :+ ", "
				caughtChannels :+ GetPlayerBase(i).channelname

				If caughtChannelIDs <> "" Then caughtChannelIDs :+ ","
				caughtChannelIDs :+ String(i)

				caughtChannelIDsArray :+ [i]
			EndIf
		Next


		Local quality:Float = 0.01 * randRange(75,90)
		Local price:Float = 1.0 + 0.01 * randRange(-5,15)
		Local NewsEvent:TNewsEvent = New TNewsEvent.Init("", Null, Null, TVTNewsGenre.CURRENTAFFAIRS, quality, Null, TVTNewsType.InitialNewsByInGameEvent)
		Local newsChain1GUID:String = NewsEvent.GetGUID()+"-1"
		NewsEvent.title = GetRandomLocalizedString("BOMB_DETONATION_IN_TVTOWER")
		NewsEvent.description = GetRandomLocalizedString("BOMB_DETONATION_IN_TVTOWER_TEXT")
		NewsEvent.description.ReplaceLocalized("%ROOM%", room.GetDescriptionLocalized())

		NewsEvent.SetModifier(TNewsEvent.modKeyPriceLS, price)
		NewsEvent.SetModifier(TNewsEvent.modKeyTopicality_AgeLS, 1.25)
		NewsEvent.SetFlag(TVTNewsFlag.SEND_TO_ALL, True)

		'add news chain 2 ?
		Local data:TData = New TData
		data.AddString("trigger", "happen")
		data.AddString("type", "TriggerNews")
		data.AddNumber("probability", 100)
		'time = in 3-7 hrs
		data.AddString("time", "1,3,7")

		data.AddString("news", newsChain1GUID)

		NewsEvent.AddEffectByData(data)

		'not strictly "happened", but "journalists wrote about it"
		NewsEvent.happenedTime = GetWorldTime().GetTimeGone() + 60 * RandRange(5,20)

		Local NewsChainEvent1:TNewsEvent
		If bombRedirectedByPlayers = 0 Or RandRange(0,90) < 90
			'chain 1
			Local qualityChain1:Float = 0.01 * randRange(50,60)
			Local priceChain1:Float = 1.0 + 0.01 * randRange(-5,10)
			NewsChainEvent1 = New TNewsEvent.Init(newsChain1GUID, Null, Null, TVTNewsGenre.CURRENTAFFAIRS, qualityChain1, Null, TVTNewsType.FollowingNews)
			NewsChainEvent1.title = GetRandomLocalizedString("BOMB_DETONATION_IN_TVTOWER_NO_CLUES")
			NewsChainEvent1.description = GetRandomLocalizedString("BOMB_DETONATION_IN_TVTOWER_NO_CLUES_TEXT")
			NewsChainEvent1.SetModifier(TNewsEvent.modKeyPriceLS, priceChain1)
		Else
			'chain 2
			Local qualityChain1:Float = 0.01 * randRange(60,80)
			Local priceChain1:Float = 1.0 + 0.01 * randRange(0,15)
			NewsChainEvent1 = New TNewsEvent.Init(newsChain1GUID, Null, Null, TVTNewsGenre.CURRENTAFFAIRS, qualityChain1, Null, TVTNewsType.FollowingNews)
			NewsChainEvent1.title = GetRandomLocalizedString("BOMB_DETONATION_IN_TVTOWER_FOUND_CLUES")
			NewsChainEvent1.description = GetRandomLocalizedString("BOMB_DETONATION_IN_TVTOWER_FOUND_CLUES_TEXT")
			NewsChainEvent1.SetModifier(TNewsEvent.modKeyPriceLS, priceChain1)


			Local data:TData

			'do this for all caught ones
			For Local pID:Int = EachIn caughtChannelIDsArray
				data = New TData
				'decrease image for all caught channels
				data.AddString("trigger", "broadcastFirstTime")
				data.AddString("type", "ModifyChannelPublicImage")
				data.AddNumber("value", -3)
				data.AddNumber("valueIsRelative", True)
				data.AddNumber("playerID", pID)
				data.AddString("log", "decrease image for all caught channels")
				NewsChainEvent1.AddEffectByData(data)
			Next

			'increase image for a broadcasting channel not being caught
			data = New TData
			data.AddString("trigger", "broadcastFirstTime")
			data.AddString("type", "ModifyChannelPublicImage")
			data.AddNumber("value", 5)
			data.AddNumber("valueIsRelative", True)
			'use playerID of broadcasting player
			data.AddNumber("playerID", 0)
			data.Add("conditions", New TData.AddString("broadcaster_notInPlayerIDs", caughtChannelIDs))
			data.AddString("log", "increase image for a broadcasting channel not being caught")

			NewsChainEvent1.AddEffectByData(data)

			'increase image (a bit less) for a broadcasting channel being
			'caught but brave enough to send it...
			data = New TData
			data.AddString("trigger", "broadcastFirstTime")
			data.AddString("type", "ModifyChannelPublicImage")
			data.AddNumber("value", 2)
			data.AddNumber("valueIsRelative", True)
			'use playerID of broadcasting player
			data.AddNumber("playerID", 0)
			data.AddString("log", "increase for broadcasting channel")
			data.Add("conditions", New TData.AddString("broadcaster_inPlayerIDs", caughtChannelIDs))
			NewsChainEvent1.AddEffectByData(data)
		EndIf
		NewsChainEvent1.SetModifier(TNewsEvent.modKeyTopicality_AgeLS, 1.4)

		NewsChainEvent1.description.ReplaceLocalized("%ROOM%", room.GetDescriptionLocalized())
		NewsChainEvent1.description.Replace("%CHANNELS%", caughtChannels)


		GetNewsEventCollection().AddOneTimeEvent(NewsChainEvent1)
		GetNewsEventCollection().AddOneTimeEvent(NewsEvent)
	End Function


	Method AddNewsProvider:Int(newsProvider:TNewsAgencyNewsProvider)
		If Not HasNewsProvider(newsProvider)
			newsProviders :+ [newsProvider]
		EndIf
	End Method


	Method HasNewsProvider:Int(newsProvider:TNewsAgencyNewsProvider)
		For Local np:TNewsAgencyNewsProvider = EachIn newsProviders
			If np = newsProvider Then Return True
		Next
		Return False
	End Method


	Method Update:Int()
		'All players update their newsagency on their own.
		'As we use "randRange" this will produce the same random values
		'on all clients - so they should be sync'd all the time.

		'fetch new news from external providers
		ProcessNewsProviders()

		'check for new news triggered by previous ones
		ProcessUpcomingNewsEvents()

		'send out delayed news to players
		ProcessDelayedNews()


		For Local i:Int = 0 Until TVTNewsGenre.count
			If NextEventTimes[i] = -1
				TLogger.Log("NewsAgency", "Initialize NextEventTime for genre "+i, LOG_DEBUG)
				ResetNextEventTime(i, RandRange(-120, 0))
			EndIf

			If NextEventTimes[i] < GetWorldTime().GetTimeGone() Then AnnounceNewNewsEvent(i)
		Next

		UpdateTerrorists()
	End Method


	Method UpdateTerrorists:Int()
		'who is the mainaggressor? - this parties levelProgress grows faster
		Local mainAggressor:Int = (terroristAggressionLevel[1] + terroristAggressionLevelProgress[1] > terroristAggressionLevel[0] + terroristAggressionLevelProgress[0])

		For Local i:Int = 0 To 1
			If terroristUpdateTime[i] >= GetWorldTime().GetTimeGone() Then Continue
			UpdateTerrorist(i, mainAggressor)
		Next
	End Method


	Method UpdateTerrorist:Int(terroristNumber:Int, mainAggressor:Int)
		'set next update time (between min-max interval)
		terroristUpdateTime[terroristNumber] = GetWorldTime().GetTimeGone() + 60*randRange(terroristUpdateTimeInterval[0], terroristUpdateTimeInterval[1])


		'adjust level progress

		'randRange uses "ints", so convert 1.0 to 100
		Local increase:Float = 0.01 * randRange(Int(terroristAggressionLevelProgressRate[terroristNumber][0]*100), Int(terroristAggressionLevelProgressRate[terroristNumber][1]*100))
		'if not the mainaggressor, grow slower
		If terroristNumber <> mainAggressor Then increase :* 0.5

		'each level has its custom increasement
		'so responses come faster and faster
		Select terroristAggressionLevel[terroristNumber]
			Case 1
				terroristAggressionLevelProgress[terroristNumber] :+ 1.05 * increase
			Case 2
				terroristAggressionLevelProgress[terroristNumber] :+ 1.11 * increase
			Case 3
				terroristAggressionLevelProgress[terroristNumber] :+ 1.20 * increase
			Case 4
				terroristAggressionLevelProgress[terroristNumber] :+ 1.35 * increase
			Default
				terroristAggressionLevelProgress[terroristNumber] :+ increase
		End Select


		'handle "level ups"
		'nothing to do if no level up happens
		If terroristAggressionLevelProgress[terroristNumber] < 1.0 Then Return False

		'set to next level
		SetTerroristAggressionLevel(terroristNumber, terroristAggressionLevel[terroristNumber] + 1)
	End Method


	Method OnChangeTerroristAggressionLevel:Int(terroristGroup:Int, oldLevel:Int, newLevel:Int)
		If terroristGroup < 0 Or terroristGroup > 1 Then Return False

		'announce news for levels 1-4
		If terroristAggressionLevel[terroristGroup] <= terroristAggressionLevelMax
			Local newsEvent:TNewsEvent = GetTerroristNewsEvent(terroristGroup)
			If newsEvent Then announceNewsEvent(newsEvent, GetWorldTime().GetTimeGone() + 0)
		EndIf
		Return True
	End Method


	Method SetTerroristAggressionLevel:Int(terroristGroup:Int, level:Int)
		If terroristGroup < 0 Or terroristGroup > 1 Then Return False

		level = MathHelper.Clamp(level, 0, terroristAggressionLevelMax )
		'nothing to do
		If level = terroristAggressionLevel[terroristGroup] Then Return False

		Local oldLevel:Int = terroristAggressionLevel[terroristGroup]
		'assign new value
		terroristAggressionLevel[terroristGroup] = level
		'if progress was 1.05, keep the 0.05 for the new level
		terroristAggressionLevelProgress[terroristGroup] = Max(0, terroristAggressionLevelProgress[terroristGroup] - 1.0)


		'handle effects
		OnChangeTerroristAggressionLevel(terroristGroup, oldLevel, level)


		'reset level if limit reached, also delay next Update so things
		'do not happen one after another
		If terroristAggressionLevel[terroristGroup] >= terroristAggressionLevelMax
			'reset to level 0
			terroristAggressionLevel[terroristGroup] = 0
			'8 * normal random "interval"
			terroristUpdateTime[terroristGroup] :+ 8 * 60*randRange(terroristUpdateTimeInterval[0], terroristUpdateTimeInterval[1])
		EndIf
		Return True
	End Method


	Method GetTerroristAggressionLevel:Int(terroristGroup:Int = -1)
		If terroristGroup >= 0 And terroristGroup <= 1
			'the level might be 0 already after the terrorist got his
			'command to go to a room ... so we check the figure too
			Local level:Int = terroristAggressionLevel[terroristGroup]
			Local fig:TFigureTerrorist = TFigureTerrorist(GetGameBase().terrorists[terroristGroup])
			'figure is just delivering a bomb?
			If fig And fig.HasToDeliver() Then Return terroristAggressionLevelMax
			Return level
		Else
			Return Max( GetTerroristAggressionLevel(0), GetTerroristAggressionLevel(1) )
		EndIf
	End Method


	Method GetTerroristNewsEvent:TNewsEvent(terroristGroup:Int = 0)
		Local aggressionLevel:Int = terroristAggressionLevel[terroristGroup]
		Local quality:Float = 0.01 * (randRange(50,60) + aggressionLevel * 5)
		Local price:Float = 1.0 + 0.01 * (randRange(45,50) + aggressionLevel * 5)
		Local title:String
		Local description:String
		Local genre:Int = TVTNewsGenre.POLITICS_ECONOMY

		Local localizeTitle:TLocalizedString
		Local localizeDescription:TLocalizedString

		Select aggressionLevel
			Case 1,2,3,4
				localizeTitle = GetRandomLocalizedString("NEWS_TERROR_GROUP"+(terroristGroup+1)+"_LEVEL"+aggressionLevel+"_TITLE")
				localizeDescription = GetRandomLocalizedString("NEWS_TERROR_GROUP"+(terroristGroup+1)+"_LEVEL"+aggressionLevel+"_TEXT")

				If aggressionLevel = 4
					'currents instead of politics
					genre = TVTNewsGenre.CURRENTAFFAIRS
				EndIf
			Default
				Return Null
		End Select


		Local NewsEvent:TNewsEvent = New TNewsEvent.Init("", localizeTitle, localizeDescription, genre, quality, Null, TVTNewsType.InitialNewsByInGameEvent)
		NewsEvent.SetModifier(TNewsEvent.modKeyPriceLS, price)

		'send out terrorist
		If aggressionLevel = terroristAggressionLevelMax
			Local effect:TGameModifierBase = New TGameModifierBase

			effect.GetData().Add("figure", GetGameBase().terrorists[terroristGroup])
			effect.GetData().AddNumber("group", terroristGroup)
			'send figure to the intented target (it then looks for the position
			'using the "roomboard" - so switched signes are taken into
			'consideration there)
			If terroristGroup = 0
				effect.GetData().Add("room", GetRoomCollection().GetFirstByDetails("", "frduban"))
			Else
				effect.GetData().Add("room", GetRoomCollection().GetFirstByDetails("", "vrduban"))
			EndIf
			'mark as a special effect so AI can categorize it accordingly
			effect.setModifierType(TVTGameModifierBase.TERRORIST_ATTACK)
			'defined function to call when executing
			effect.GetData().AddString("customRunFuncKey", "TFigureTerrorist.SendFigureToRoom")

			'Variant 1: pass delay to the SendFigureToRoom-function (delay delivery schedule)
			'effect.GetData().AddNumber("delayTime", 60 * RandRange(45,120))
			'Variant 2: delay the execution of the effect
			effect.SetDelayedExecutionTime(Long(GetWorldTime().GetTimeGone()) +  60 * RandRange(45,120))
			NewsEvent.effects.AddEntry("happen", effect)
		EndIf

		'send without delay!
		NewsEvent.SetFlag(TVTNewsFlag.SEND_IMMEDIATELY, True)
		'do not delay other news
		NewsEvent.SetFlag(TVTNewsFlag.KEEP_TICKER_TIME, True)

		NewsEvent.AddKeyword("TERRORIST")

		GetNewsEventCollection().AddOneTimeEvent(NewsEvent)
		Return NewsEvent
	End Method


	Method GetMovieNewsEvent:TNewsEvent()
		Local licence:TProgrammeLicence = Self._GetAnnouncableProgrammeLicence()
		If Not licence Then Return Null
		If Not licence.getData() Then Return Null

		licence.GetData().releaseAnnounced = True

		Local localizeTitle:TLocalizedString
		Local localizeDescription:TLocalizedString

		'no director and no actors
		If licence.GetData().getActor(1) = Null And licence.GetData().getDirector(1) = Null
			localizeTitle = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_NO_CAST_TITLE")
			localizeDescription = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_NO_CAST_DESCRIPTION")
		'no director
		ElseIf licence.GetData().getDirector(1) = Null
			localizeTitle = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_NO_CAST_TITLE")
			localizeDescription = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_NO_CAST_DESCRIPTION")
		'no actor named (eg. cartoon)
		ElseIf licence.GetData().getActor(1) = Null
			localizeTitle = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_NO_ACTOR_TITLE")
			localizeDescription = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_NO_ACTOR_DESCRIPTION")
		'if same director and main actor...
		ElseIf licence.GetData().getActor(1) = licence.GetData().getDirector(1)
			localizeTitle = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_ACTOR_IS_DIRECTOR_TITLE")
			localizeDescription = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_ACTOR_IS_DIRECTOR_DESCRIPTION")
		'default
		Else
			localizeTitle = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_TITLE")
			localizeDescription = GetRandomLocalizedString("NEWS_ANNOUNCE_MOVIE_DESCRIPTION")
		EndIf

		'replace data
		Self._ReplaceProgrammeData(localizeTitle, licence.GetData())
		Self._ReplaceProgrammeData(localizeDescription, licence.GetData())

		'quality and price are based on the movies data
		'quality of movie news never can reach quality of "real" news
		'so cut them to a specific range (0.10 - 0.80)
		Local quality:Float = 0.1  + 0.70*licence.GetData().review
		'if outcome is less than 50%, it subtracts the price, else it increases
		Local priceModifier:Float = 1.0 + 0.2 * (licence.GetData().outcome - 0.5)
		Local NewsEvent:TNewsEvent = New TNewsEvent.Init("", localizeTitle, localizeDescription, TVTNewsGenre.SHOWBIZ, quality, Null, TVTNewsType.InitialNewsByInGameEvent)
		NewsEvent.SetModifier(TNewsEvent.modKeyPriceLS, priceModifier)

		'after 20 hours a news topicality is 0 - so accelerating it by
		'2 means it reaches topicality of 0 at 10 hours after creation.
		NewsEvent.SetModifier(TNewsEvent.modKeyTopicality_AgeLS, 2)

		NewsEvent.AddKeyword("MOVIE")


		'add triggers
		'attention: not all persons have a popularity yet - skip them
		For Local job:TProgrammePersonJob = EachIn licence.GetData().cast
			If job.personGUID
				Local person:TProgrammePerson = GetProgrammePerson(job.personGUID)
				If person And person.GetPopularity()
					Local jobMod:Float = TVTProgrammePersonJob.GetJobImportanceMod(job.job)
					If jobMod > 0.0
						NewsEvent.AddEffectByData(New TData.Add("trigger", "happen").Add("type", "ModifyPersonPopularity").Add("guid", job.personGUID).AddNumber("valueMin", 0.1 * jobMod).AddNumber("valueMax", 0.5 * jobMod))
						'TODO: take broadcast audience into consideration
						'      or maybe only use broadcastFirstTimeDone
						NewsEvent.AddEffectByData(New TData.Add("trigger", "broadcastDone").Add("type", "ModifyPersonPopularity").Add("guid", job.personGUID).AddNumber("valueMin", 0.01 * jobMod).AddNumber("valueMax", 0.025 * jobMod))
					EndIf
				EndIf
			EndIf
		Next
		'modify genre
		NewsEvent.AddEffectByData(New TData.Add("trigger", "broadcastFirstTime").Add("type", "ModifyMovieGenrePopularity").AddNumber("genre", licence.GetData().GetGenre()).AddNumber("valueMin", 0.025).AddNumber("valueMax", 0.04))
		NewsEvent.AddEffectByData(New TData.Add("trigger", "broadcast").Add("type", "ModifyMovieGenrePopularity").AddNumber("genre", licence.GetData().GetGenre()).AddNumber("valueMin", 0.005).AddNumber("valueMax", 0.01))


		GetNewsEventCollection().AddOneTimeEvent(NewsEvent)

		Return NewsEvent
	End Method


	Method _ReplaceProgrammeData:TLocalizedString(text:TLocalizedString, data:TProgrammeData)
		Local actor:TProgrammePersonBase
		Local director:TProgrammePersonBase
		For Local i:Int = 1 To 2
			actor = data.GetActor(i)
			director = data.GetDirector(i)
			If actor
				text.Replace("%ACTORNAME"+i+"%", actor.GetFullName())
			EndIf
			If director
				text.Replace("%DIRECTORNAME"+i+"%", director.GetFullName())
			EndIf
		Next
		text.Replace("%MOVIETITLE%", data.GetTitle())

		Return text
	End Method


	'helper to get a movie which can be used for a news
	Method _GetAnnouncableProgrammeLicence:TProgrammeLicence()
		'filter to entries we need
		Local candidates:TProgrammeLicence[] = New TProgrammeLicence[20]
		Local candidatesAdded:Int = 0
		'series,collections,movies but no episodes/collection entries
		For Local licence:TProgrammeLicence = EachIn GetProgrammeLicenceCollection()._GetParentLicences().Values()
			'must be in production!
			If Not licence.GetData().IsInProduction() Then Continue
			'ignore if filtered out
			If licence.IsOwned() Then Continue
			'ignore already announced movies
			If licence.getData().releaseAnnounced Then Continue
			'ignore unreleased if outside the given filter
			If Not licence.GetData().ignoreUnreleasedProgrammes And licence.getData().GetYear() < TProgrammeData._filterReleaseDateStart Or licence.getData().GetYear() > TProgrammeData._filterReleaseDateEnd Then Continue

			If candidates.length >= candidatesAdded Then candidates = candidates[.. candidates.length + 20]
			candidates[candidatesAdded] = licence
			candidatesAdded :+ 1
		Next
		If candidates.length > candidatesAdded Then candidates = candidates[.. candidatesAdded]

		If candidates.length > 0 Then Return GetProgrammeLicenceCollection().GetRandomFromArray(candidates)

		Return Null
	End Method


	'creates new news events out of templates containing happenedTime-configs
	'-> call this method on start of a game
	Method CreateTimedNewsEvents:Int()
		Local now:Long = GetWorldTime().GetTimeGone()

		For Local template:TNewsEventTemplate = EachIn GetNewsEventTemplateCollection().GetUnusedAvailableInitialTemplates()
			If template.happenTime = -1 Then Continue

			'create fixed future news
			Local newsEvent:TNewsEvent = New TNewsEvent.InitFromTemplate(template)

			'now and missed are not listed in the upcomingNewsList, so
			'no cache-clearance is needed
			'now
			If template.happenTime = 0
				template.happenTime = GetWorldTime().GetTimeGone()
				If template.IsAvailable()
					announceNewsEvent(newsEvent)
				EndIf
			'missed - only some minutes too late (eg gamestart news)
			'we could just announce them as their happen effects would
			'still be valid (attention: do not add a "new years eve -
			'drunken people"-effect as this would be active on game start
			'then)
			'this would mean a)
			ElseIf template.happenTime <= now
				'TODO: Wenn happened in der Vergangenheit liegt (und template noch nicht "used")
				'dann "onHappen" ausloesen damit Folgenachrichten kommen koennen
			EndIf

			GetNewsEventCollection().Add(newsEvent)
		Next
	End Method


	'announces planned news events (triggered by news some time before
	'or with an fixed data)
	Method ProcessUpcomingNewsEvents:Int()
		Local announced:Int = 0

		For Local newsEvent:TNewsEvent = EachIn GetNewsEventCollection().GetUpcomingNewsList()
			'skip news events not happening yet
			If Not newsEvent.HasHappened() Then Continue

			announceNewsEvent(newsEvent)

			'attention: RESET_TICKER_TIME is only "useful" for followup news
			If newsEvent.HasFlag(TVTNewsFlag.RESET_TICKER_TIME)
				ResetNextEventTime(newsEvent.GetGenre())
			EndIf

			announced:+1
		Next

		'invalidate upcoming list
		If announced > 0 Then GetNewsEventCollection()._InvalidateUpcomingNewsEvents()

		Return announced
	End Method


	'update external news sources and fetch their generated news
	Method ProcessNewsProviders:Int()
		Local delayed:Int = 0
		Local announced:Int = 0
		For Local nP:TNewsAgencyNewsProvider = EachIn newsProviders
			nP.Update()
			For Local newsEvent:TNewsEvent = EachIn nP.GetNewNewsEvents()
				'skip news events not happening yet
				'-> they will get processed once they happen (upcoming list)
				If Not newsEvent.HasHappened()
					delayed:+1
					Continue
				EndIf

				announceNewsEvent(newsEvent)

				'attention: KEEP_TICKER_TIME is only "useful" for initial/single news
				If Not newsEvent.HasFlag(TVTNewsFlag.KEEP_TICKER_TIME)
					ResetNextEventTime(newsEvent.GetGenre())
				EndIf

				announced :+ 1
			Next

			nP.ClearNewNewsEvents()
		Next

		'invalidate upcoming list
		If delayed > 0 Then GetNewsEventCollection()._InvalidateUpcomingNewsEvents()

		Return announced
	End Method


	'announces news to players with lower abonnement levels (delay)
	Method ProcessDelayedNews:Int()
		Local delayed:Int = 0

		For Local playerID:Int = 1 To delayedLists.Length
			Local player:TPlayerBase = GetPlayerBase(playerID)
			If Not delayedLists[playerID-1] Or Not player Then Continue

			Local toRemove:TNews[]
			For Local news:TNews = EachIn delayedLists[playerID-1]
				Local genre:Int = news.newsEvent.GetGenre()
				Local subscriptionDelay:Int = GetNewsAbonnementDelay(genre, player.GetNewsAbonnement(genre) )
				Local maxSubscriptionDelay:Int = GetNewsAbonnementDelay(genre, 1)

				'if playerID=1 then print "ProcessDelayedNews: " + news.GetTitle() + "  happened="+GetWorldTime().GetFormattedDate( news.GetHappenedTime())+"  announceToPlayer="+ GetWorldTime().GetFormattedDate( news.GetPublishTime() + subscriptionDelay )+ "  autoRemove=" + GetWorldTime().GetFormattedDate( news.GetPublishTime() + maxSubscriptionDelay + 1000 )

				'remove old news which are NOT subscribed on "latest
				'possible subscription-delay-time"
				'3600 - to also allow a bit "older" ones - like start news
				If news.GetPublishTime() + maxSubscriptionDelay + 3600 <  GetWorldTime().GetTimeGone()
					'mark the news for removal
					toRemove :+ [news]
					'print "ProcessDelayedNews #"+playerID+": Removed OLD/unsubscribed: " + news.GetTitle()
					Continue
				EndIf


				'skip news events not for publishing yet
				If Not news.IsReadyToPublish(subscriptionDelay)
					Continue
				EndIf

				'skip news events if not subscribed to its genre NOW
				'(including "not satisfying minimum subscription level")
				'alternatively also check: "or subscriptionDelay < 0"
				If Not news.newsEvent.HasFlag(TVTNewsFlag.SEND_TO_ALL)
					If player.GetNewsabonnement(genre)<=0 Or player.GetNewsabonnement(genre) < news.newsEvent.GetMinSubscriptionLevel()
						'if playerID=1 then print "ProcessDelayedNews #"+playerID+": NOT subscribed or not ready yet: " + news.GetTitle() + "   announceToPlayer="+ GetWorldTime().GetFormattedDate( news.GetPublishTime() + subscriptionDelay )
						Continue
					EndIf
				EndIf


				'do not charge for immediate news
				If news.newsEvent.HasFlag(TVTNewsFlag.SEND_IMMEDIATELY)
					news.priceModRelativeNewsAgency = 0.0
				Else
					news.priceModRelativeNewsAgency = GetNewsRelativeExtraCharge(genre, player.GetNewsAbonnement(genre))
				EndIf

				announceNews(news, playerID)

				'mark the news for removal
				toRemove :+ [news]
				delayed:+1
			Next

			For Local news:TNews = EachIn toRemove
				delayedLists[playerID-1].Remove(news)
			Next

'			if playerID=1 then end
		Next

		Return delayed
	End Method


	Method RemoveFromDelayedListsByNewsEvent(playerID:Int=0, newsEvent:TNewsEvent)
		If playerID<=0
			For Local i:Int = 1 To delayedLists.Length
				RemoveFromDelayedListsByNewsEvent(playerID, newsEvent)
			Next
		Else
			If delayedLists.length >= playerID And delayedLists[playerID-1]
				Local remove:TNews[]
				For Local n:TNews = EachIn delayedLists[playerID-1]
					If n.newsEvent = newsEvent Then remove :+ [n]
				Next
				For Local n:TNews = EachIn remove
					delayedLists[playerID-1].Remove(n)
				Next
				For Local n:TNews = EachIn delayedLists[playerID-1]
					If n.newsEvent = newsEvent Then remove :+ [n]
				Next
			EndIf
		EndIf
	End Method


	Method ResetDelayedList(playerID:Int=0)
		If playerID<=0
			For Local i:Int = 1 To delayedLists.Length
				If delayedLists[i-1] Then delayedLists[i-1].Clear()
			Next
		Else
			If delayedLists.length >= playerID And delayedLists[playerID-1]
				delayedLists[playerID-1].Clear()
			EndIf
		EndIf
	End Method


	Function GetNewsAbonnementDelay:Int(genre:Int, level:Int) {_exposeToLua}
		If level = 3 Then Return 0
		If level = 2 Then Return 60*60
		If level = 1 Then Return 150*60 'not needed but better overview
		Return -1
	End Function


	'Returns the extra charge for a news
	Function GetNewsRelativeExtraCharge:Float(genre:Int, level:Int) {_exposeToLua}
		'up to now: ignore genre, all share the same values
		If level = 3 Then Return 0.20
		If level = 2 Then Return 0.10
		If level = 1 Then Return 0.00 'not needed but better overview
		Return 0.00
	End Function


	'Returns the price for this level of a news abonnement
	Function GetNewsAbonnementPrice:Int(playerID:Int, newsGenreID:Int, level:Int=0)
		If level = 1 Then Return 10000
		If level = 2 Then Return 25000
		If level = 3 Then Return 50000
		Return 0
	End Function


	Method AddNewsEventToPlayer:Int(newsEvent:TNewsEvent, forPlayer:Int=-1, sendNow:Int=False, fromNetwork:Int=False)
		Local player:TPlayerBase = GetPlayerBase(forPlayer)
		If Not player Then Return False

		If newsEvent.HasFlag(TVTNewsFlag.INVISIBLE_EVENT) Then Return False

		Local news:TNews = TNews.Create("", 0, newsEvent)

		sendNow = sendNow Or newsEvent.HasFlag(TVTNewsFlag.SEND_IMMEDIATELY)
		If sendNow
			announceNews(news, player.playerID)
		Else
			'add to publishLater-List
			'so dynamical checks of "subscription levels" can take
			'place - and also "older" new will get added to the
			'players when they subscribe _after_ happening of the event
			If Not delayedLists[player.playerID-1] Then delayedLists[player.playerID-1] = CreateList()
			delayedLists[player.playerID-1].AddLast(news)
		EndIf
	End Method


	Method announceNewsEvent:Int(newsEvent:TNewsEvent, happenedTime:Double=0, sendNow:Int=False)
		If happenedTime = 0 Then happenedTime = newsEvent.happenedTime
		newsEvent.doHappen(happenedTime)

		'only announce as news if not invisible
		If Not newsEvent.HasFlag(TVTNewsFlag.INVISIBLE_EVENT)
			For Local i:Int = 1 To 4
				AddNewsEventToPlayer(newsEvent, i, sendNow)
			Next
		EndIf
	End Method


	'make news available for the player
	Method announceNews:Int(news:TNews, player:Int)
		If Not GetPlayerProgrammeCollection(player) Then Return False
		Return GetPlayerProgrammeCollection(player).AddNews(news)
	End Method


	'generates a new news event from various sources (such as new
	'movie announcements, actor news ...)
	Method GenerateNewNewsEvent:TNewsEvent(genre:Int = -1)
		Local newsEvent:TNewsEvent = Null

		'=== TYPE MOVIE NEWS ===
		'25% chance: try to load some movie news ("new movie announced...")
		If genre = -1 Or genre = TVTNewsGenre.SHOWBIZ
			If Not newsEvent And RandRange(1,100) < 25
				newsEvent = GetMovieNewsEvent()
			EndIf
		EndIf


		'=== TYPE RANDOM NEWS ===
		'if no "special case" triggered, just use a random news
		If Not newsEvent
			newsEvent = GetNewsEventCollection().CreateRandomAvailable(genre)
		EndIf

		Return newsEvent
	End Method

	'forceAdd: add regardless of abonnement levels?
	'sendNow: ignore delay of abonnement levels?
	'skipIfUnsubscribed: happen regardless of nobody subscribed to the news genre?
	Method AnnounceNewNewsEvent:TNewsEvent(genre:Int=-1, adjustHappenedTime:Int=0, forceAdd:Int=False, sendNow:Int=False, skipIfUnsubscribed:Int=True)
		'=== CREATE A NEW NEWS ===
		Local newsEvent:TNewsEvent = GenerateNewNewsEvent(genre)


		'=== ANNOUNCE THE NEWS ===
		Local announced:Int = False
		'only announce if forced or somebody is listening
		If newsEvent
			Local skipNews:Int = newsEvent.IsSkippable()
			'override newsevent skippability
			If Not skipIfUnsubscribed Then skipNews = False

			If skipNews
				For Local player:TPlayerBase = EachIn GetPlayerBaseCollection().players
					'a player listens to this genre, disallow skipping
					If player.GetNewsabonnement(newsEvent.GetGenre()) > 0 Then skipNews = False
				Next
				If Not forceAdd And Not skipIfUnsubscribed
					?debug
					If skipNews Then Print "[NEWSAGENCY] Nobody listens to genre "+newsEvent.GetGenre()+". Skip news: ~q"+newsEvent.GetTitle()+"~q."
					?
					If skipNews Then TLogger.Log("NewsAgency", "Nobody listens to genre "+newsEvent.GetGenre()+". Skip news: ~q"+newsEvent.GetTitle()+"~q.", LOG_DEBUG)
				Else
					?debug
					If skipNews Then Print "[NEWSAGENCY] Nobody listens to genre "+newsEvent.GetGenre()+". Would skip news, but am forced to add: ~q"+newsEvent.GetTitle()+"~q."
					?
					If skipNews Then TLogger.Log("NewsAgency", "Nobody listens to genre "+newsEvent.GetGenre()+". Would skip news, but am forced to add: ~q"+newsEvent.GetTitle()+"~q.", LOG_DEBUG)
				EndIf
			EndIf

			If Not skipNews Or forceAdd
				announceNewsEvent(newsEvent, GetWorldTime().GetTimeGone() + adjustHappenedTime, sendNow)
				announced = True
				TLogger.Log("NewsAgency", "Added news: ~q"+newsEvent.GetTitle()+"~q for day "+GetWorldTime().getDay(newsEvent.happenedtime)+" at "+GetWorldTime().GetFormattedTime(newsEvent.happenedtime)+".", LOG_DEBUG)
			EndIf
		EndIf


		'=== ADJUST TIME FOR NEXT NEWS ANNOUNCEMENT ===
		'reset even if no news was found - or if news allows so
		'attention: KEEP_TICKER_TIME is for initial news
		'           RESET_TICKER_TIME for follow up news
		If Not newsEvent Or Not newsEvent.HasFlag(TVTNewsFlag.KEEP_TICKER_TIME)
			ResetNextEventTime(genre)
		EndIf

		If announced Then Return newsEvent
		Return Null
	End Method


	Method SetNextEventTime:Int(genre:Int, time:Long)
		If genre >= TVTNewsGenre.count Or genre < 0 Then Return False

		NextEventTimes[genre] = time
	End Method


	Method ResetNextEventTime:Int(genre:Int, addMinutes:Int = 0)
		If genre >= TVTNewsGenre.count Or genre < 0 Then Return False

		'during night, news come not that often
		If GetWorldTime().GetDayHour() < 4
			addMinutes :+ RandRange(15,45)
		'during night, news come not that often
		ElseIf GetWorldTime().GetDayHour() >= 22
			addMinutes :+ RandRange(15,30)
		'work time - even earlier now
		ElseIf GetWorldTime().GetDayHour() > 8 And GetWorldTime().GetDayHour() < 14
			addMinutes :- RandRange(15,30)
		EndIf


		'adjust time until next news
		NextEventTimes[genre] = GetWorldTime().GetTimeGone() + 60 * (randRange(NextEventTimeIntervals[genre][0], NextEventTimeIntervals[genre][1]) + addMinutes)

		'25% chance to have an even longer time (up to 2x)
		If RandRange(0,100) < 25
			NextEventTimes[genre] :+ randRange(NextEventTimeIntervals[genre][0], NextEventTimeIntervals[genre][1])
			TLogger.Log("NewsAgency", "Reset NextEventTime for genre "+genre+" to "+ GetWorldTime().GetFormattedDate(NextEventTimes[genre])+" ("+Long(NextEventTimes[genre])+"). DOUBLE TIME.", LOG_DEBUG)
		Else
			TLogger.Log("NewsAgency", "Reset NextEventTime for genre "+genre+" to "+ GetWorldTime().GetFormattedDate(NextEventTimes[genre])+" ("+Long(NextEventTimes[genre])+")", LOG_DEBUG)
		EndIf
	End Method
End Type

'===== CONVENIENCE ACCESSOR =====
'return singleton instance
Function GetNewsAgency:TNewsAgency()
	Return TNewsAgency.GetInstance()
End Function




Type TNewsAgencyNewsProvider
	Field newNewsEvents:TNewsEvent[]


	Method Initialize:Int()
		ClearNewNewsEvents()
	End Method


	Method Update:Int() Abstract


	Method AddNewNewsEvent:Int(newsEvent:TNewsEvent)
		newNewsEvents :+ [newsEvent]
	End Method


	Method GetNewNewsEvents:TNewsEvent[]()
		Return newNewsEvents
	End Method


	Method ClearNewNewsEvents:Int()
		newNewsEvents = newNewsEvents[..0]
		Return True
	End Method
End Type



