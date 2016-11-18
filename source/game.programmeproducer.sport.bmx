SuperStrict
Import "game.programmeproducer.base.bmx"
Import "game.newsagency.sports.bmx"
'for TSportsProgrammeData
Import "game.programme.programmedata.specials.bmx"
Import "game.programme.programmelicence.bmx"

'nach test wieder entfernen
Import "game.player.programmecollection.bmx"
'to know the short country name of the used map
Import "game.stationmap.bmx"

'register self to producer collection
GetProgrammeProducerCollection().Add( TProgrammeProducerSport.GetInstance() )




Type TProgrammeProducerSport extends TProgrammeProducerBase
	Global _eventsRegistered:int= FALSE
	Global _eventListeners:TLink[]
	Global _instance:TProgrammeProducerSport


	'override
	Method GenerateGUID:string()
		return "programmeproducersport-"+id
	End Method


	Function GetInstance:TProgrammeProducerSport()
		if not _instance then _instance = new TProgrammeProducerSport
		return _instance
	End Function


	Method New()
		if not _eventsRegistered
			'=== remove all registered event listeners
			EventManager.unregisterListenersByLinks(_eventListeners)
			_eventListeners = new TLink[0]

			_eventListeners :+ [ EventManager.registerListenerFunction("SportLeague.StartSeason", onSportLeagueStartSeason) ]
			'_eventListeners :+ [ EventManager.registerListenerFunction("Sport.StartPlayoffs", onSportLeagueStartSeason) ]

			_eventsRegistered = TRUE
		Endif
	End Method


	Function onSportLeagueStartSeason:int( triggerEvent:TEventBase )
		local league:TNewsEventSportLeague = TNewsEventSportLeague(triggerEvent.GetSender())
		if not league then return False
		
		print "TODO: neue Lizenzen anlegen"
		'ignore seasons if the first match already happened ?
		if league.GetDoneMatchesCount() = 0 and league.GetNextMatchTime() > GetWorldTime().GetTimeGone()
			print "neue Ligaseason gestartet"
		else
			print "neue Ligaseason gestartet aber schon angespielt"
		endif

		local licence:TProgrammeLicence = GetInstance().CreateLeagueMatchesCollectionProgrammeLicence(league)
		if licence
			'add children
			For local sub:TProgrammeLicence = EachIn licence.subLicences
				GetProgrammeDataCollection().Add(sub.GetData())
				GetProgrammeLicenceCollection().AddAutomatic(sub)
			Next

			GetProgrammeDataCollection().Add(licence.GetData())
			GetProgrammeLicenceCollection().AddAutomatic(licence)


			print "added licence: " + licence.GetTitle()

			GetPlayerProgrammeCollection(1).AddProgrammeLicence(licence)
		endif
	End Function


	Method CreateLeagueMatchesCollectionProgrammeLicence:TProgrammeLicence(league:TNewsEventSportLeague)
		if not league then return null

		local programmeData:TProgrammeData = new TSportsProgrammeData
		local programmeLicence:TProgrammeLicence = new TProgrammeLicence
		programmeLicence.SetData(programmeData)
		programmeLicence.licenceType = TVTProgrammeLicenceType.COLLECTION

		programmeData.GUID = "programmedata-sportleaguecollection-"+league.GetGUID() +"-season-"+league.GetCurrentSeason().GetGUID()
		programmeData.title = new TLocalizedString.Set( league.name + " " + GetWorldTime().GetYear(league.GetNextMatchTime()), null )
		programmeData.description = new TLocalizedString.Set( "Alle Spiele der x. Liga", null )
		programmeData.titleProcessed = Null
		programmeData.descriptionProcessed = Null
		programmeData.productType = TVTProgrammeProductType.EVENT 'or MISC?

		programmeData.country = GetStationMapCollection().config.GetString("nameShort", "UNK")
		programmeData.distributionChannel = TVTProgrammeDistributionChannel.TV
		programmeData.blocks = 1 'overridden in the individual matches

		programmeData.SetFlag(TVTProgrammeDataFlag.LIVE, True)

		programmeData.review = 0.2
		programmeData.speed = 0.5

		programmeData.genre = TVTProgrammeGenre.Event_Sport

		programmeData.releaseTime = league.GetNextMatchTime()

		'so the licence datasheet does expose that information
		programmeData.SetBroadcastLimit(3)
		'once sold, this programmelicence wont be buyable anylonger
		programmeLicence.setLicenceFlag(TVTProgrammeLicenceFlag.LICENCEPOOL_REMOVES_TRADEABILITY, True)

		'fuer jetzt: alle noch kommenden Spiele "verlizenzen"
		local matchNumber:int = 0
		For local match:TNewsEventSportMatch = EachIn league.GetUpcomingMatches(GetWorldTime().GetTimeGone(), -1)
			local matchLicence:TProgrammeLicence = GetInstance().CreateMatchProgrammelicence(match, programmeLicence)
			'add to collections

			if matchLicence
				programmeLicence.AddSubLicence(matchLicence, matchNumber)
				matchNumber :+ 1
			endif
		Next

		return programmeLicence
	End Method
	

	Method CreateMatchProgrammeLicence:TProgrammeLicence(match:TNewsEventSportMatch, parentLicence:TProgrammeLicence)
		'TODO: programmeData.speed 		abhaengig von Liga und Platzierung (-> in Update() )
		'TODO: programmeData.country	Map-Country
		'TODO: keywords: soccer mit Sportartname ersetzen
		'TODO: cast: Moderator hinzufuegen (wenn moeglich - 50% - mit "Event_sport"-Erfahrung, was erst nach der ersten Produktion moeglich ist)
		if not match then return null

		local programmeData:TProgrammeData
		if parentLicence then programmeData = TProgrammeData(THelper.CloneObject(parentLicence.data, "id"))
		if not programmeData then programmeData = new TSportsProgrammeData

		local programmeLicence:TProgrammeLicence = new TProgrammeLicence
		programmeLicence.SetData(programmeData)
		programmeLicence.licenceType = TVTProgrammeLicenceType.SINGLE

		programmeData.GUID = "programmedata-sportmatch-"+match.GetGUID()
		programmeData.title = new TLocalizedString.Set( match.GetReportShort(), null )
		programmeData.description = new TLocalizedString.Set( "Match der x. Liga", null )
		programmeData.titleProcessed = Null
		programmeData.descriptionProcessed = Null
		programmeData.productType = TVTProgrammeProductType.EVENT 'or MISC?

		programmeData.country = GetStationMapCollection().config.GetString("nameShort", "UNK")
		programmeData.distributionChannel = TVTProgrammeDistributionChannel.TV
		programmeData.blocks = ceil(match.duration/3600.0)

		programmeData.SetFlag(TVTProgrammeDataFlag.LIVE, True)

		programmeData.review = 0.2
		programmeData.speed = 0.5
		programmeData.genre = TVTProgrammeGenre.Event_Sport
		programmeData.outcome = 0.8

		programmeData.releaseTime = match.matchTime - 2*24*3600 - 24*3600

		'remove after broadcasting 3 times
		programmeLicence.setLicenceFlag(TVTProgrammeLicenceFlag.REMOVE_ON_REACHING_BROADCASTLIMIT, True)
		'once sold, this programmelicence wont be buyable anylonger
		programmeLicence.setLicenceFlag(TVTProgrammeLicenceFlag.LICENCEPOOL_REMOVES_TRADEABILITY, True)
		programmeLicence.SetBroadcastLimit(3) 'needed?
		programmeData.SetBroadcastLimit(3)

		'programmeData.AddKeyword("SOCCER")


		return programmeLicence
	End Method

	'TODO: CreateProgrammeData -> "Eine Geschichte des Sports/Fussballs/Handballs..."
End Type