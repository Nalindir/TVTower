SuperStrict
Import "Dig/base.gfx.bitmapfont.bmx"
Import "Dig/base.util.registry.spriteloader.bmx"
Import "Dig/base.util.math.bmx"
Import "game.gameobject.bmx"
Import "game.player.finance.bmx"
Import "game.player.base.bmx"
Import "basefunctions.bmx" 'dottedValue
Import "game.production.scripttemplate.bmx"
Import "game.broadcast.genredefinition.movie.bmx"
Import "game.gamescriptexpression.base.bmx"
'to access datasheet-functions
Import "common.misc.datasheet.bmx"



Type TScriptCollection Extends TGameObjectCollection
	'stores "languagecode::name"=>"used by id" connections
	Field protectedTitles:TStringMap = New TStringMap
	'=== CACHE ===
	'cache for faster access

	'holding used scripts
	Field _usedScripts:TList = CreateList() {nosave}
	Field _availableScripts:TList = CreateList() {nosave}
	Field _parentScripts:TList = CreateList() {nosave}

	Global _instance:TScriptCollection


	Function GetInstance:TScriptCollection()
		If Not _instance Then _instance = New TScriptCollection
		Return _instance
	End Function


	Method Initialize:TScriptCollection()
		Super.Initialize()
		Return Self
	End Method


	Method _InvalidateCaches()
		_usedScripts = Null
		_availableScripts = Null
		_parentScripts = Null
	End Method


	Method Add:Int(obj:TGameObject)
		Local script:TScript = TScript(obj)
		If Not script Then Return False

		_InvalidateCaches()
		'add child scripts too
		For Local subScript:TScript = EachIn script.subScripts
			Add(subScript)
		Next

		'protect title
		If Not script.HasParentScript()
			AddTitleProtection(script.customTitle, script.GetID())
			AddTitleProtection(script.title, script.GetID())
		EndIf

		Return Super.Add(script)
	End Method


	Method Remove:Int(obj:TGameObject)
		Local script:TScript = TScript(obj)
		If Not script Then Return False

		_InvalidateCaches()
		'remove child scripts too
		For Local subScript:TScript = EachIn script.subScripts
			Remove(subScript)
		Next

		'unprotect title
		If Not script.HasParentScript()
			RemoveTitleProtection(script.customTitle)
			RemoveTitleProtection(script.title)
		EndIf

		Return Super.Remove(script)
	End Method


	Method GetByID:TScript(ID:Int)
		Return TScript( Super.GetByID(ID) )
	End Method


	Method GetByGUID:TScript(GUID:String)
		Return TScript( Super.GetByGUID(GUID) )
	End Method


	Method GenerateFromTemplate:TScript(templateOrTemplateGUID:Object)
		Local template:TScriptTemplate
		If TScriptTemplate(templateOrTemplateGUID)
			template = TScriptTemplate(templateOrTemplateGUID)
		Else
			template = GetScriptTemplateCollection().GetByGUID( String(templateOrTemplateGUID) )
			If Not template Then Return Null
		EndIf

		Local script:TScript = TScript.CreateFromTemplate(template)
		script.SetOwner(TOwnedGameObject.OWNER_NOBODY)
		Add(script)
		Return script
	End Method


	Method GenerateFromTemplateID:TScript(ID:Int)
		Local template:TScriptTemplate = GetScriptTemplateCollection().GetByID( ID )
		If Not template Then Return Null

		Return GenerateFromTemplate(template)
	End Method


	Method GenerateRandom:TScript(avoidTemplateIDs:Int[])
		Local template:TScriptTemplate
		If Not avoidTemplateIDs Or avoidTemplateIDs.length = 0
			template = GetScriptTemplateCollection().GetRandomByFilter(True, True)
		Else
			Local foundValid:Int = False
			Local tries:Int = 0

			template = GetScriptTemplateCollection().GetRandomByFilter(True, True, "", avoidTemplateIDs)
			'get a random one, ignore avoid IDs
			If Not template And avoidTemplateIDs And avoidTemplateIDs.length > 0
				Print "TScriptCollection.GenerateRandom() - warning. No available template found (avoid-list too big?). Trying an avoided entry."
				template = GetScriptTemplateCollection().GetRandomByFilter(True, True)
			EndIf
			'get a random one, ignore availability
			If Not template
				Print "TScriptCollection.GenerateRandom() - failed. No available template found (avoid-list too big?). Using an unfiltered entry."
				template = GetScriptTemplateCollection().GetRandomByFilter(False, True)
			EndIf
		EndIf

		Local script:TScript = TScript.CreateFromTemplate(template)
		script.SetOwner(TOwnedGameObject.OWNER_NOBODY)
		Add(script)

		Return script
	End Method


	Method GetRandomAvailable:TScript(avoidTemplateIDs:Int[] = Null)
		'if no script is available, create (and return) some a new one
		If GetAvailableScriptList().Count() = 0 Then Return GenerateRandom(avoidTemplateIDs)

		'fetch a random script
		If Not avoidTemplateIDs Or avoidTemplateIDs.length = 0
			Return TScript(GetAvailableScriptList().ValueAtIndex(randRange(0, GetAvailableScriptList().Count() - 1)))
		Else
			Local possibleScripts:TScript[]
			For Local s:TScript = EachIn GetAvailableScriptList()
				If Not s.basedOnScriptTemplateID Or Not MathHelper.InIntArray(s.basedOnScriptTemplateID, avoidTemplateIDs)
					possibleScripts :+ [s]
				EndIf
			Next
			If possibleScripts.length = 0 Then Return GenerateRandom(avoidTemplateIDs)

			Return possibleScripts[ randRange(0, possibleScripts.length - 1) ]
		EndIf
	End Method


	Method GetTitleProtectedByID:Int(title:Object)
		If TLocalizedString(title)
			Local lsTitle:TLocalizedString = TLocalizedString(title)
			For Local langID:Int = EachIn lsTitle.GetLanguageIDs()
				Return Int(String(protectedTitles.ValueForKey(TLocalization.GetLanguageCode(langID) + "::" + lsTitle.Get(langID).ToLower())))
			Next
		ElseIf String(title) <> ""
			Return Int(String((protectedTitles.ValueForKey("custom::" + String(title).ToLower()))))
		EndIf
	End Method


	Method IsTitleProtected:Int(title:Object)
		If TLocalizedString(title)
			Local lsTitle:TLocalizedString = TLocalizedString(title)
			For Local langID:Int = EachIn lsTitle.GetLanguageIDs()
				If protectedTitles.Contains(TLocalization.GetLanguageCode(langID) + "::" + lsTitle.Get(langID).ToLower())
					Return True
				EndIf
			Next
		ElseIf String(title) <> ""
			If protectedTitles.Contains("custom::" + String(title).ToLower())
				Return True
			EndIf
		EndIf
		Return False
	End Method


	'pass string or TLocalizedString
	Method AddTitleProtection(title:Object, scriptID:Int)
		If TLocalizedString(title)
			Local lsTitle:TLocalizedString = TLocalizedString(title)
			For Local langID:Int = EachIn lsTitle.GetLanguageIDs()
				protectedTitles.Insert(TLocalization.GetLanguageCode(langID) + "::" + lsTitle.Get(langID).ToLower(), String(scriptID))
			Next
		ElseIf String(title) <> ""
			protectedTitles.insert("custom::" + String(title).ToLower(), String(scriptID))
		EndIf
	End Method


	'pass string or TLocalizedString
	Method RemoveTitleProtection(title:Object)
		If TLocalizedString(title)
			Local lsTitle:TLocalizedString = TLocalizedString(title)
			For Local langID:Int = EachIn lsTitle.GetLanguageIDs()
				protectedTitles.Remove(TLocalization.GetLanguageCode(langID) + "::" + lsTitle.Get(langID).ToLower())
			Next
		ElseIf String(title) <> ""
			protectedTitles.Remove("custom::" + String(title).ToLower())
		EndIf
	End Method


	'returns (and creates if needed) a list containing only available
	'and unused scripts.
	'Scripts of episodes and other children are ignored
	Method GetAvailableScriptList:TList()
		If Not _availableScripts
			_availableScripts = CreateList()
			For Local script:TScript = EachIn GetParentScriptList()
				'skip used scripts (or scripts already at the vendor)
				If script.IsOwned() Then Continue
				'skip scripts not available yet (or anymore)
				'(eg. they are obsolete now, or not yet possible)
				If Not script.IsAvailable() Then Continue
				If Not script.IsTradeable() Then Continue

				'print "GetAvailableScriptList: add " + script.GetTitle() ' +"   owned="+script.IsOwned() + "  available="+script.IsAvailable() + "  tradeable="+script.IsTradeable()
				_availableScripts.AddLast(script)
			Next
		EndIf
		Return _availableScripts
	End Method


	'returns (and creates if needed) a list containing only used scripts.
	Method GetUsedScriptList:TList()
		If Not _usedScripts
			_usedScripts = CreateList()
			For Local script:TScript = EachIn entries.Values()
				'skip unused scripts
				If Not script.IsOwned() Then Continue

				_usedScripts.AddLast(script)
			Next
		EndIf
		Return _usedScripts
	End Method


	'returns (and creates if needed) a list containing only parental scripts
	Method GetParentScriptList:TList()
		If Not _parentScripts
			_parentScripts = CreateList()
			For Local script:TScript = EachIn entries.Values()
				'skip scripts containing parent information or episodes
				If script.scriptLicenceType = TVTProgrammeLicenceType.EPISODE Then Continue
				If script.HasParentScript() Then Continue

				_parentScripts.AddLast(script)
			Next
		EndIf
		Return _parentScripts
	End Method


	Method SetScriptOwner:Int(script:TScript, owner:Int)
		If script.owner = owner Then Return False

		script.owner = owner
		'reset only specific caches, so script gets in the correct list
		_usedScripts = Null
		_availableScripts = Null

		Return True
	End Method
End Type

'===== CONVENIENCE ACCESSOR =====
'return collection instance
Function GetScriptCollection:TScriptCollection()
	Return TScriptCollection.GetInstance()
End Function




Type TScript Extends TScriptBase {_exposeToLua="selected"}
	Field ownProduction:Int	= False

	Field newsTopicGUID:String = ""
	Field newsGenre:Int

	Field outcome:Float	= 0.0
	Field review:Float = 0.0
	Field speed:Float = 0.0
	Field potential:Float = 0.0

	'cast contains various jobs but with no "person" assigned in it, so
	'it is more a "job" definition (+role in the case of actors)
	Field cast:TProgrammePersonJob[]

	'See TVTProgrammePersonJob
	Field allowedGuestTypes:Int	= 0

	Field requiredStudioSize:Int = 1
	'more expensive
	Field requireAudience:Int = 0

	Field targetGroup:Int = -1

	Field price:Int	= 0
	Field blocks:Int = 0

	'if the script is a clone of something, basedOnScriptID contains
	'the ID of the original script.
	'This is used for "shows" to be able to use different values of
	'outcome/speed/price/... while still having a connecting link
	Field basedOnScriptID:Int = 0
	'template this script is based on (this allows to avoid that too
	'many scripts are based on the same script template on the same time)
	Field basedOnScriptTemplateID:Int = 0

	Global spriteNameOverlayXRatedLS:TLowerString = New TLowerString.Create("gfx_datasheet_overlay_xrated")


	Method GenerateGUID:String()
		Return "script-"+id
	End Method


	Function CreateFromTemplate:TScript(template:TScriptTemplate)
		Local script:TScript = New TScript
		script.title = template.GenerateFinalTitle()
		If GetScriptCollection().IsTitleProtected(script.title)
'			print "script title in use: " + script.title.Get()

			'use another random one
			Local tries:Int = 0
			Local validTitle:Int = False
			For Local i:Int = 0 Until 5
				script.title = template.GenerateFinalTitle()
				If Not GetScriptCollection().IsTitleProtected(script.title)
					validTitle = True
					Exit
				EndIf
			Next
			'no random one available or most already used
			If Not validTitle
				Local langIDs:Int[] = script.title.GetLanguageIDs()
				'remove numbers
				For Local langID:Int = EachIn langIDs
					Local numberfreeTitle:String = script.title.Get(langID)
					Local hashPos:Int = numberfreeTitle.FindLast("#")
					If hashPos > 2 '"sometext" + space + hash means > 2
						Local numberS:String = numberFreetitle[hashPos+1 .. ]
						If numberS = String(Int(numberS)) 'so "#123hashtag"
							numberfreeTitle = numberfreetitle[.. hashPos-1] 'remove space before too
						EndIf

						script.title.Set(numberfreeTitle, langID)
					EndIf
				Next
				'append number
				Local titleCopy:TLocalizedString = script.title.Copy()
				'start with "2" to avoid "title #1"
				Local number:Int = 2
				Repeat
					For Local langID:Int = EachIn langIDs
						script.title.Set(titleCopy.Get(langID) + " #"+number, langID)
					Next
					number :+ 1
					If number > 10000 Then Throw "TScript.CreateFromTemplate() - failed to generate title with increased number: " + script.title.Get()
				Until Not GetScriptCollection().IsTitleProtected(script.title)
			EndIf
		EndIf
		script.description = template.GenerateFinalDescription()

		script.outcome = template.GetOutcome()
		script.review = template.GetReview()
		script.speed = template.GetSpeed()
		script.potential = template.GetPotential()
		script.blocks = template.GetBlocks()
		script.price = template.GetPrice()

		script.flags = template.flags

		script.flagsOptional = template.flagsOptional
		script.productionBroadcastFlags = template.productionBroadcastFlags
		script.productionLicenceFlags = template.productionLicenceFlags

		script.liveTime = template.liveTime
		script.liveDateCode = template.liveDateCode

		script.broadcastTimeSlotStart = template.broadcastTimeSlotStart
		script.broadcastTimeSlotEnd = template.broadcastTimeSlotEnd

		script.SetProductionLimit( template.GetProductionLimit() )
		script.SetProductionBroadcastLimit( template.GetProductionBroadcastLimit() )

		script.productionTime = template.GetProductionTime()
		script.productionTimeMod = template.productionTimeMod

		script.scriptFlags = template.scriptFlags
		'mark tradeable
		script.SetScriptFlag(TVTScriptFlag.TRADEABLE, True)

		script.scriptLicenceType = template.scriptLicenceType
		script.scriptProductType = template.scriptProductType

		script.mainGenre = template.mainGenre
		'add genres
		For Local subGenre:Int = EachIn template.subGenres
			script.subGenres :+ [subGenre]
		Next

		'replace placeholders as we know the cast / roles now
		script.title = script._ReplacePlaceholders(script.title)
		script.description = script._ReplacePlaceholders(script.description)


		'add children
		For Local subTemplate:TScriptTemplate = EachIn template.subScripts
			Local subScript:TScript = TScript.CreateFromTemplate(subTemplate)
			If subScript Then script.AddSubScript(subScript)
		Next
		script.basedOnScriptTemplateID = template.GetID()

		'this would GENERATE a new block of jobs (including RANDOM ones)
		'- for single scripts we could use that jobs
		'- for parental scripts we use the jobs of the children
		If template.subScripts.length = 0
			script.cast = template.GetJobs()
		Else
			'for now use this approach
			'and dynamically count individual cast count by using
			'Max(script-cast-count, max-of-subscripts-cast-count)
			script.cast = template.GetJobs()
			Rem
			local myCastCountAll:int[] = new Int[TVTProgrammePersonJob.count]
			local myCastCountMale:int[] = new Int[TVTProgrammePersonJob.count]
			local myCastCountFemale:int[] = new Int[TVTProgrammePersonJob.count]
			local subCastCountAll:int[] = new Int[TVTProgrammePersonJob.count]
			local subCastCountMale:int[] = new Int[TVTProgrammePersonJob.count]
			local subCastCountFemale:int[] = new Int[TVTProgrammePersonJob.count]
			local allCastCountAll:int[] = new Int[TVTProgrammePersonJob.count]
			local allCastCountMale:int[] = new Int[TVTProgrammePersonJob.count]
			local allCastCountFemale:int[] = new Int[TVTProgrammePersonJob.count]

			For local j:TProgrammePersonJob = EachIn script.cast
				'increase count for each associated job
				For local jobIndex:int = 1 to TVTProgrammePersonJob.count
					local jobID:int = TVTProgrammePersonJob.GetAtIndex(jobIndex)
					if jobID & j.job = 0 then continue

					if j.gender = 0
						myCastCountAll[jobIndex-1] :+ 1
					elseif j.gender = TVTPersonGender.MALE
						myCastCountMale[jobIndex-1] :+ 1
					elseif j.gender = TVTPersonGender.FEMALE
						myCastCountFemale[jobIndex-1] :+ 1
					endif
				Next
			Next

			'do the same for all subs
			For local subScript:TScript = EachIn script.subScripts
				For local j:TProgrammePersonJob = EachIn script.cast
					'increase count for each associated job
					For local jobIndex:int = 1 to TVTProgrammePersonJob.count
						local jobID:int = TVTProgrammePersonJob.GetAtIndex(jobIndex)
						if jobID & j.job = 0 then continue

						if j.gender = 0
							subCastCountAll[jobIndex-1] :+ 1
						elseif j.gender = TVTPersonGender.MALE
							subCastCountMale[jobIndex-1] :+ 1
						elseif j.gender = TVTPersonGender.FEMALE
							subCastCountFemale[jobIndex-1] :+ 1
						endif
					Next
				Next

				'keep the biggest cast count of all subscripts
				For local jobIndex:int = 1 to TVTProgrammePersonJob.count
					allCastCountAll[jobIndex-1] = Max(allCastCountAll[jobIndex-1], subCastCountAll[jobIndex-1])
					allCastCountMale[jobIndex-1] = Max(allCastCountMale[jobIndex-1], subCastCountMale[jobIndex-1])
					allCastCountFemale[jobIndex-1] = Max(allCastCountFemale[jobIndex-1], subCastCountFemale[jobIndex-1])
				Next
			Next
			endrem
		EndIf


		'reset the state of the template
		'without that, the following scripts created with this template
		'as base will get the same title/description
		template.Reset()

		Return script
	End Function


	'override
	Method HasParentScript:Int()
		Return parentScriptID > 0
	End Method


	'override
	Method GetParentScript:TScript()
		If parentScriptID Then Return GetScriptCollection().GetByID(parentScriptID)
		Return Self
	End Method


	Method _ReplacePlaceholders:TLocalizedString(text:TLocalizedString)
		Local result:TLocalizedString = text.copy()

		'for each defined language we check for existent placeholders
		'which then get replaced by a random string stored in the
		'variable with the same name
		For Local langID:Int = EachIn text.GetLanguageIDs()
			Local value:String = text.Get(langID)
			Local placeHolders:String[] = StringHelper.ExtractPlaceholders(value, "%", True)
			If placeHolders.length = 0 Then Continue

			Local actorsFetched:Int = False
			Local actors:TProgrammePersonJob[]
			Local replacement:String = ""
			For Local placeHolder:String = EachIn placeHolders
				Local replaced:Int = False
				replacement = ""
				Select placeHolder.toUpper()
					Case "ROLENAME1", "ROLENAME2", "ROLENAME3", "ROLENAME4", "ROLENAME5", "ROLENAME6", "ROLENAME7"
						If Not actorsFetched
							actors = GetSpecificCast(TVTProgrammePersonJob.ACTOR | TVTProgrammePersonJob.SUPPORTINGACTOR)
							actorsFetched = True
						EndIf

						'local actorNum:int = int(placeHolder.toUpper().Replace("%ROLENAME", "").Replace("%",""))
						Local actorNum:Int = Int(Chr(placeHolder[8]))
						If actorNum > 0
							If actors.length > actorNum And actors[actorNum].roleGUID <> ""
								Local role:TProgrammeRole = GetProgrammeRoleCollection().GetByGUID(actors[actorNum].roleGUID)
								If role Then replacement = role.GetFirstName()
							EndIf
							'gender neutral default
							If replacement = ""
								Select actorNum
									Case 1	replacement = "Robin"
									Case 2	replacement = "Alex"
									Default	replacement = "Jamie"
								End Select
							EndIf
							replaced = True
						EndIf
					Case "ROLE1", "ROLE2", "ROLE3", "ROLE4", "ROLE5", "ROLE6", "ROLE7"
						If Not actorsFetched
							actors = GetSpecificCast(TVTProgrammePersonJob.ACTOR | TVTProgrammePersonJob.SUPPORTINGACTOR)
							actorsFetched = True
						EndIf

						'local actorNum:int = int(placeHolder.toUpper().Replace("%ROLE", "").Replace("%",""))
						Local actorNum:Int = Int(Chr(placeHolder[4]))
						If actorNum > 0
							If actors.length > actorNum And actors[actorNum].roleGUID <> ""
								Local role:TProgrammeRole = GetProgrammeRoleCollection().GetByGUID(actors[actorNum].roleGUID)
								If role Then replacement = role.GetFullName()
							EndIf
							'gender neutral default
							If replacement = ""
								Select actorNum
									Case 1	replacement = "Robin Mayer"
									Case 2	replacement = "Alex Hulley"
									Default	replacement = "Jamie Larsen"
								End Select
							EndIf
							replaced = True
						EndIf

					Case "GENRE"
						replacement = GetMainGenreString()
						replaced = True
					Case "EPISODES"
						replacement = GetMainGenreString()
						replaced = True

					Default
						If Not replaced Then replaced = ReplaceTextWithGameInformation(placeHolder, replacement)
						If Not replaced Then replaced = ReplaceTextWithScriptExpression(placeHolder, replacement)
				End Select

				'replace if some content was filled in
				If replaced Then value = value.Replace("%"+placeHolder+"%", replacement)
			Next

			result.Set(value, langID)
		Next

		Return result
	End Method


	'override
	Method FinishProduction(programmeLicenceID:Int)
		Super.FinishProduction(programmeLicenceID)

		If basedOnScriptTemplateID
			Local template:TScriptTemplate = GetScriptTemplateCollection().GetByID(basedOnScriptTemplateID)
			If template Then template.FinishProduction(programmeLicenceID)
		EndIf
	End Method


	Method GetScriptTemplate:TScriptTemplate()
		If Not basedOnScriptTemplateID Then Return Null

		Return GetScriptTemplateCollection().GetByID(basedOnScriptTemplateID)
	End Method


	'override default method to add subscripts
	Method SetOwner:Int(owner:Int=0)
		GetScriptCollection().SetScriptOwner(Self, owner)

		Super.SetOwner(owner)

		Return True
	End Method


	Method SetBasedOnScriptID(ID:Int)
		Self.basedOnScriptID = ID
	End Method


	Method GetSpecificCastCount:Int(job:Int, limitPersonGender:Int=-1, limitRoleGender:Int=-1, ignoreSubScripts:Int = False)
		Local result:Int = 0
		For Local j:TProgrammePersonJob = EachIn cast
			'skip roles with wrong gender
			If limitRoleGender >= 0 And j.roleGUID
				Local role:TProgrammeRole = GetProgrammeRoleCollection().GetByGUID(j.roleGUID)
				If role And role.gender <> limitRoleGender Then Continue
			EndIf
			'skip persons with wrong gender
			If limitPersonGender >= 0 And j.gender <> limitPersonGender Then Continue

			'current job is one of the given job(s)
			If job & j.job Then result :+ 1
		Next

		'override with maximum found in subscripts
		If Not ignoreSubscripts And subScripts
			For Local subScript:TScript = EachIn subScripts
				result = Max(result, subScript.GetSpecificCastCount(job, limitPersonGender, limitRoleGender))
			Next
		EndIf

		Return result
	End Method


	Method GetCast:TProgrammePersonJob[]()
		Return cast
	End Method


	Method GetSpecificCast:TProgrammePersonJob[](job:Int, limitPersonGender:Int=-1, limitRoleGender:Int=-1)
		Local result:TProgrammePersonJob[]
		For Local j:TProgrammePersonJob = EachIn cast
			'skip roles with wrong gender
			If limitRoleGender >= 0 And j.roleGUID
				Local role:TProgrammeRole = GetProgrammeRoleCollection().GetByGUID(j.roleGUID)
				If role And role.gender <> limitRoleGender Then Continue
			EndIf
			'skip persons with wrong gender
			If limitPersonGender >= 0 And j.gender <> limitPersonGender Then Continue

			'current job is one of the given job(s)
			If job & j.job Then result :+ [j]
		Next
		Return result
	End Method


	Method GetOutcome:Float() {_exposeToLua}
		'single-script
		If GetSubScriptCount() = 0 Then Return outcome

		'script for a package or scripts
		Local value:Float
		For Local s:TScript = EachIn subScripts
			value :+ s.GetOutcome()
		Next
		Return value / subScripts.length
	End Method


	Method GetReview:Float() {_exposeToLua}
		'single-script
		If GetSubScriptCount() = 0 Then Return review

		'script for a package or scripts
		Local value:Float
		For Local s:TScript = EachIn subScripts
			value :+ s.GetReview()
		Next
		Return value / subScripts.length
	End Method


	Method GetSpeed:Float() {_exposeToLua}
		'single-script
		If GetSubScriptCount() = 0 Then Return speed

		'script for a package or scripts
		Local value:Float
		For Local s:TScript = EachIn subScripts
			value :+ s.GetSpeed()
		Next
		Return value / subScripts.length
	End Method


	Method GetPotential:Float() {_exposeToLua}
		'single-script
		If GetSubScriptCount() = 0 Then Return potential

		'script for a package or scripts
		Local value:Float
		For Local s:TScript = EachIn subScripts
			value :+ s.GetPotential()
		Next
		Return value / subScripts.length
	End Method


	Method GetBlocks:Int() {_exposeToLua}
		Return blocks
	End Method


	Method GetEpisodeNumber:Int() {_exposeToLua}
		If Self <> GetParentScript() Then Return GetParentScript().GetSubScriptPosition(Self) + 1

		Return 0
	End Method


	Method GetEpisodes:Int() {_exposeToLua}
		If isSeries() Then Return GetSubScriptCount()

		Return 0
	End Method


	Method GetSellPrice:Int() {_exposeToLua}
		Return GetPrice()
	End Method


	Method GetPrice:Int() {_exposeToLua}
		Local value:Int
		'single-script
		If GetSubScriptCount() = 0
			value = price
		'script for a package or scripts
		Else
			For Local script:TScript = EachIn subScripts
				value :+ script.GetPrice()
			Next
			value :* 0.75
		EndIf

		'round to next "100" block
		value = Int(Floor(value / 100) * 100)

		Return value
	End Method

	'mixes main and subgenre criterias
	Method CalculateTotalGenreCriterias(totalReview:Float Var, totalSpeed:Float Var, totalOutcome:Float Var)
		Local genreDefinition:TMovieGenreDefinition = GetMovieGenreDefinition(mainGenre)
		If Not genreDefinition
			TLogger.Log("TScript.CalculateTotalGenreCriterias()", "script with wrong movie genre definition, criteria calculation failed.", LOG_ERROR)
			Return
		EndIf

		totalOutcome = genreDefinition.OutcomeMod
		totalReview = genreDefinition.ReviewMod
		totalSpeed = genreDefinition.SpeedMod

		'build subgenre-averages
		Local subGenreDefinition:TMovieGenreDefinition
		Local subGenreCount:Int
		Local subGenreOutcome:Float, subGenreReview:Float, subGenreSpeed:Float
		For Local i:Int = 0 Until subGenres.length
			subGenreDefinition = GetMovieGenreDefinition(i)
			If Not subGenreDefinition Then Continue

			subGenreOutcome :+ subGenreDefinition.OutcomeMod
			subGenreReview :+ subGenreDefinition.ReviewMod
			subGenreSpeed :+ subGenreDefinition.SpeedMod
			subGenreCount :+ 1
		Next
		If subGenreCount > 1
			subGenreOutcome :/ subGenreCount
			subGenreReview :/ subGenreCount
			subGenreSpeed :/ subGenreCount
		EndIf

		'mix maingenre and subgenres by 60:40
		If subGenreCount > 0
			'if main genre ignores outcome, ignore for subgenres too!
			If totalOutcome > 0
				totalOutcome = totalOutcome*0.6 + subGenreOutcome*0.4
			EndIf
			totalReview = totalReview*0.6 + subGenreReview*0.4
			totalSpeed = totalSpeed*0.6 + subGenreSpeed*0.4
		EndIf
	End Method


	'returns the criteria-congruence
	'(is review-speed-outcome weight of script the same as in the genres)
	'a value of 1.0 means a perfect match (eg. x*50% speed, x*20% outcome
	' and x*30% review)
	Method CalculateGenreCriteriaFit:Float()
		'Fetch corresponding genre definition, with this we are able to
		'see what values are "expected" for this genre.

		Local reviewGenre:Float, speedGenre:Float, outcomeGenre:Float
		CalculateTotalGenreCriterias(reviewGenre, speedGenre, outcomeGenre)

		'scale to total of 100%
		Local resultTotal:Float = reviewGenre + speedGenre + outcomeGenre
		reviewGenre :/ resultTotal
		speedGenre :/ resultTotal
		outcomeGenre :/ resultTotal

		Rem
		reviewGenre = 0.5
		speedGenre = 0.3
		outcomeGenre = 0.2

		'100% fit
		review = 0.4
		speed = 0.24
		outcome = 0.16
		endrem

		'scale to biggest property
		Local maxPropertyScript:Float, maxPropertyGenre:Float
		If outcomeGenre > 0
			maxPropertyScript = Max(review, Max(speed, outcome))
			maxPropertyGenre = Max(reviewGenre, Max(speedGenre, outcomeGenre))
		Else
			maxPropertyScript = Max(review, speed)
			maxPropertyGenre = Max(reviewGenre, speedGenre)
		EndIf
		If maxPropertyGenre = 0 Or MathHelper.AreApproximatelyEqual(maxPropertyScript, maxPropertyGenre)
			Return 1
		EndIf

		Local scaleFactor:Float = maxPropertyGenre / maxPropertyScript
		Local distanceReview:Float = Abs(reviewGenre - review*scaleFactor)
		Local distanceSpeed:Float = Abs(speedGenre - speed*scaleFactor)
		Local distanceOutcome:Float = Abs(outcomeGenre - outcome*scaleFactor)
		'ignore outcome ?
		If outcomeGenre = 0 Then distanceOutcome = 0

		Rem
		'print "maxPropertyGenre:   "+maxPropertyGenre
		'print "maxPropertyScript:  "+maxPropertyScript
		print "mainGenre:          "+mainGenre
		print "scaleFactor:        "+scaleFactor
		print "review:             "+review + "  genre:" + reviewGenre
		print "speed:              "+speed + "  genre:" + speedGenre
		print "Review Abweichung:  "+distanceReview
		print "Speed Abweichung:   "+distanceSpeed
		if outcomeGenre > 0
			print "Outcome Abweichung:   "+distanceOutcome
		endif
		print "ergebnis:           "+(1.0 - (distanceReview + distanceSpeed + distanceOutcome))
		endrem

		Return 1.0 - (distanceReview + distanceSpeed + distanceOutcome)
	End Method


	Method Sell:Int()
		Local finance:TPlayerFinance = GetPlayerFinance(owner,-1)
		If Not finance Then Return False

		finance.SellScript(GetSellPrice(), Self)

		'set unused again

		SetOwner( TOwnedGameObject.OWNER_NOBODY )

		Return True
	End Method


	'buy means pay and set owner, but in players collection only if left the room!!
	Method Buy:Int(playerID:Int=-1)
		Local finance:TPlayerFinance = GetPlayerFinance(playerID)
		If Not finance Then Return False

		If finance.PayScript(GetPrice(), Self)
			SetOwner(playerID)
			Return True
		EndIf
		Return False
	End Method


	Method GiveBackToScriptPool:Int()
		SetOwner( TOwnedGameObject.OWNER_NOBODY )

		'remove tradeability?
		'(eg. for "exclusively written for player X scripts")
		If HasScriptFlag(TVTScriptFlag.POOL_REMOVES_TRADEABILITY)
			SetScriptFlag(TVTScriptFlag.TRADEABLE, False)
		EndIf


		'remove tradeability for partially produced series
		If GetSubScriptCount() > 0 And GetProductionsCount() > 0
			SetScriptFlag(TVTScriptFlag.TRADEABLE, False)
		EndIf


		'refill production limits - or disable tradeability
		If GetProductionLimit() > 0 or IsExceedingProductionLimit()
			If HasScriptFlag(TVTScriptFlag.POOL_REFILLS_PRODUCTIONLIMITS)
				SetProductionLimit( GetProductionLimitMax() )
			Else
				SetScriptFlag(TVTProgrammeLicenceFlag.TRADEABLE, False)
			EndIf
		EndIf


		'randomize attributes?
		If HasScriptFlag(TVTScriptFlag.POOL_RANDOMIZES_ATTRIBUTES)
			Local template:TScriptTemplate
			If basedOnScriptTemplateID Then template = GetScriptTemplateCollection().GetByID(basedOnScriptTemplateID)
			If template
				outcome = template.GetOutcome()
				review = template.GetReview()
				speed = template.GetSpeed()
				potential = template.GetPotential()
				blocks = template.GetBlocks()
				price = template.GetPrice()
			EndIf
		EndIf


		'do the same for all children
		For Local subScript:TScript = EachIn subScripts
			subScript.GiveBackToScriptPool()
		Next

		'inform others about a now unused licence
		EventManager.triggerEvent( TEventSimple.Create("Script.onGiveBackToScriptPool", Null, Self))

		Return True
	End Method


	Method ShowSheet:Int(x:Int,y:Int, align:Int=0)
		'=== PREPARE VARIABLES ===
		Local sheetWidth:Int = 310
		Local sheetHeight:Int = 0 'calculated later
		'move sheet to left when right-aligned
		If align = 1 Then x = x - sheetWidth

		Local skin:TDatasheetSkin = GetDatasheetSkin("script")
		Local contentW:Int = skin.GetContentW(sheetWidth)
		Local contentX:Int = x + skin.GetContentY()
		Local contentY:Int = y + skin.GetContentY()

		Local showMsgEarnInfo:Int = False
		Local showMsgLiveInfo:Int = False
		Local showMsgBroadcastLimit:Int = False
		Local showMsgTimeSlotLimit:Int = False

		If IsPaid() Then showMsgEarnInfo = True
		If IsLive() Then showMsgLiveInfo = True
		If HasProductionBroadcastLimit() Then showMsgBroadcastLimit= True
		If HasBroadcastTimeSlot() Then showMsgTimeSlotLimit = True


		Local title:String
		If Not isEpisode()
			title = GetTitle()
		Else
			title = GetParentScript().GetTitle()
		EndIf

		'can player afford this licence?
		Local canAfford:Int = False
		'possessing player always can
		If GetPlayerBaseCollection().playerID = owner
			canAfford = True
		'if it is another player... just display "can afford"
		ElseIf owner > 0
			canAfford = True
		'not our licence but enough money to buy ?
		Else
			Local finance:TPlayerFinance = GetPlayerFinance(GetPlayerBaseCollection().playerID)
			If finance And finance.canAfford(GetPrice())
				canAfford = True
			EndIf
		EndIf


		'=== CALCULATE SPECIAL AREA HEIGHTS ===
		Local titleH:Int = 18, subtitleH:Int = 16, genreH:Int = 16, descriptionH:Int = 70, castH:Int=50
		Local splitterHorizontalH:Int = 6
		Local boxH:Int = 0, msgH:Int = 0, barH:Int = 0
		Local msgAreaH:Int = 0, boxAreaH:Int = 0, barAreaH:Int = 0
		Local boxAreaPaddingY:Int = 4, msgAreaPaddingY:Int = 4, barAreaPaddingY:Int = 4

		msgH = skin.GetMessageSize(contentW - 10, -1, "", "money", "good", Null, ALIGN_CENTER_CENTER).GetY()
		boxH = skin.GetBoxSize(89, -1, "", "spotsPlanned", "neutral").GetY()
		barH = skin.GetBarSize(100, -1).GetY()
		titleH = Max(titleH, 3 + GetBitmapFontManager().Get("default", 13, BOLDFONT).getBlockHeight(title, contentW - 10, 100))

		'message area
		If showMsgEarnInfo Then msgAreaH :+ msgH
		If showMsgLiveInfo Then msgAreaH :+ msgH
		If showMsgBroadcastLimit Then msgAreaH :+ msgH
		'suits into the live-block
'If showMsgTimeSlotLimit and not showMsgLiveInfo Then msgAreaH :+ msgH
		If showMsgTimeSlotLimit  Then msgAreaH :+ msgH
		'if there are messages, add padding of messages
		If msgAreaH > 0 Then msgAreaH :+ 2* msgAreaPaddingY


		'bar area starts with padding, ends with padding and contains
		'also contains 3 bars
		barAreaH = 2 * barAreaPaddingY + 3 * (barH + 2)

		'box area
		'contains 1 line of boxes + padding at the top
		boxAreaH = 1 * boxH
		If msgAreaH = 0 Then boxAreaH :+ boxAreaPaddingY

		'total height
		sheetHeight = titleH + genreH + descriptionH + castH + barAreaH + msgAreaH + boxAreaH + skin.GetContentPadding().GetTop() + skin.GetContentPadding().GetBottom()
		If isEpisode() Then sheetHeight :+ subtitleH
		'there is a splitter between description and cast...
		sheetHeight :+ splitterHorizontalH


		'=== RENDER ===

		'=== TITLE AREA ===
		skin.RenderContent(contentX, contentY, contentW, titleH, "1_top")
			If titleH <= 18
				GetBitmapFontManager().Get("default", 13, BOLDFONT).drawBlock(title, contentX + 5, contentY -1, contentW - 10, titleH, ALIGN_LEFT_CENTER, skin.textColorNeutral, 0,1,1.0,True, True)
			Else
				GetBitmapFontManager().Get("default", 13, BOLDFONT).drawBlock(title, contentX + 5, contentY +1, contentW - 10, titleH, ALIGN_LEFT_CENTER, skin.textColorNeutral, 0,1,1.0,True, True)
			EndIf
		contentY :+ titleH


		'=== SUBTITLE AREA ===
		If isEpisode()
			skin.RenderContent(contentX, contentY, contentW, subtitleH, "1")
			'episode num/max + episode title
			skin.fontNormal.drawBlock((GetParentScript().GetSubScriptPosition(Self)+1) + "/" + GetParentScript().GetSubScriptCount() + ": " + GetTitle(), contentX + 5, contentY, contentW - 10, genreH -1, ALIGN_LEFT_CENTER, skin.textColorNeutral, 0,1,1.0,True, True)
			contentY :+ subtitleH
		EndIf


		'=== COUNTRY / YEAR / GENRE AREA ===
		skin.RenderContent(contentX, contentY, contentW, genreH, "1")
		Local genreString:String = GetMainGenreString()
		'avoid "Action-Undefined" and "Show-Show"
		If scriptProductType <> TVTProgrammeProductType.UNDEFINED And scriptProductType <> TVTProgrammeProductType.SERIES
			local sameType:int = (TVTProgrammeProductType.GetAsString(scriptProductType) = TVTProgrammeGenre.GetAsString(mainGenre))
			if sameType and scriptProductType = TVTProgrammeProductType.SHOW and TVTProgrammeGenre.GetGroupIndex(mainGenre) = TVTProgrammeGenre.SHOW then sameType = False
			if sameType and scriptProductType = TVTProgrammeProductType.FEATURE and TVTProgrammeGenre.GetGroupIndex(mainGenre) = TVTProgrammeGenre.FEATURE then sameType = False

'				If Not(TVTProgrammeProductType.GetAsString(scriptProductType) = "feature" And TVTProgrammeGenre.GetAsString(mainGenre).Find("feature")>=0)
			If not sameType
				genreString :+ " / " +GetProductionTypeString()
			EndIf
		EndIf
		If IsSeries()
			genreString :+ " / " + GetLocale("SERIES_WITH_X_EPISODES").Replace("%EPISODESCOUNT%", GetSubScriptCount())
		EndIf

		skin.fontNormal.drawBlock(genreString, contentX + 5, contentY, contentW - 10, genreH, ALIGN_LEFT_CENTER, skin.textColorNeutral, 0,1,1.0,True, True)
		contentY :+ genreH


		'=== DESCRIPTION AREA ===
		skin.RenderContent(contentX, contentY, contentW, descriptionH, "2")
		skin.fontNormal.drawBlock(GetDescription(), contentX + 5, contentY + 3, contentW - 10, descriptionH - 3, Null, skin.textColorNeutral)
		contentY :+ descriptionH


		'splitter
		skin.RenderContent(contentX, contentY, contentW, splitterHorizontalH, "1")
		contentY :+ splitterHorizontalH


		'=== CAST AREA ===
		skin.RenderContent(contentX, contentY, contentW, castH, "2")

		'cast
		Local cast:String = ""

		For Local i:Int = 1 To TVTProgrammePersonJob.count
			Local jobID:Int = TVTProgrammePersonJob.GetAtIndex(i)
			'call with "false" to return maximum required persons within
			'sub scripts too
			Local requiredPersons:Int = GetSpecificCastCount(jobID,-1,-1, False)
			If requiredPersons <= 0 Then Continue

			If cast <> "" Then cast :+ ", "

			Local requiredPersonsMale:Int = GetSpecificCastCount(jobID, TVTPersonGender.MALE)
			Local requiredPersonsFemale:Int = GetSpecificCastCount(jobID, TVTPersonGender.FEMALE)
			requiredPersons = Max(requiredPersons, requiredPersonsMale + requiredPersonsFemale)

			If requiredPersons = 1
				cast :+ "|b|"+requiredPersons+"x|/b| "+GetLocale("JOB_" + TVTProgrammePersonJob.GetAsString(jobID, True))
			Else
				cast :+ "|b|"+requiredPersons+"x|/b| "+GetLocale("JOB_" + TVTProgrammePersonJob.GetAsString(jobID, False))
			EndIf


			Local requiredDetails:String = ""
			If requiredPersonsMale > 0
				'write amount if multiple genders requested for this job type
				If requiredPersonsMale <> requiredPersons
					requiredDetails :+ requiredPersonsMale+"x "+GetLocale("MALE")
				Else
					requiredDetails :+ GetLocale("MALE")
				EndIf
			EndIf
			If requiredPersonsFemale > 0
				If requiredDetails <> "" Then requiredDetails :+ ", "
				'write amount if multiple genders requested for this job type
				If requiredPersonsFemale <> requiredPersons
					requiredDetails :+ requiredPersonsFemale+"x "+GetLocale("FEMALE")
				Else
					requiredDetails :+ GetLocale("FEMALE")
				EndIf
			EndIf
			If requiredPersons - (requiredPersonsMale + requiredPersonsFemale) > 0
				'write amount if genders for this job type were defined
				If requiredPersonsMale > 0 Or requiredPersonsFemale > 0
					If requiredDetails <> "" Then requiredDetails :+ ", "
					requiredDetails :+ (requiredPersons - (requiredPersonsMale + requiredPersonsFemale))+"x "+GetLocale("UNDEFINED")
				EndIf
			EndIf
			If requiredDetails <> ""
				cast :+ " (" + requiredDetails + ")"
			EndIf
		Next

Rem
		local requiredDirectors:int = GetSpecificCastCount(TVTProgrammePersonJob.DIRECTOR)
		local requiredStarRoleActorFemale:int = GetSpecificCastCount(TVTProgrammePersonJob.ACTOR, TVTPersonGender.FEMALE)
		local requiredStarRoleActorMale:int = GetSpecificCastCount(TVTProgrammePersonJob.ACTOR, TVTPersonGender.MALE)
		local requiredStarRoleActors:int = GetSpecificCastCount(TVTProgrammePersonJob.ACTOR)

		if requiredDirectors > 0 then cast :+ "|b|"+requiredDirectors+"x|/b| "+GetLocale("MOVIE_DIRECTOR")
		if cast <> "" then cast :+ ", "

		if requiredStarRoleActors > 0
			local requiredStars:int = requiredStarRoleActorMale + requiredStarRoleActorFemale
			cast :+ "|b|"+requiredStars+"x|/b| "+GetLocale("MOVIE_LEADINGACTOR")

			local actorDetails:string = ""
			if requiredStarRoleActorMale > 0
				actorDetails :+ requiredStarRoleActorMale+"x "+GetLocale("MALE")
			endif
			if requiredStarRoleActorFemale > 0
				if actorDetails <> "" then actorDetails :+ ", "
				actorDetails :+ requiredStarRoleActorFemale+"x "+GetLocale("FEMALE")
			endif
			if requiredStarRoleActors - (requiredStarRoleActorMale + requiredStarRoleActorFemale)  > 0
				if actorDetails <> "" then actorDetails :+ ", "
				actorDetails :+ requiredStarRoleActors+"x "+GetLocale("UNDEFINED")
			endif

			cast :+ " (" + actorDetails + ")"
		endif
endrem

		If cast <> ""
			'render director + cast (offset by 3 px)
			contentY :+ 3

			skin.fontNormal.drawBlock("|b|"+GetLocale("MOVIE_CAST") + ":|/b| " + cast, contentX + 5, contentY , contentW  - 10, castH, Null, skin.textColorNeutral)

			contentY:+ castH - 3
		Else
			contentY:+ castH
		EndIf


		'=== BARS / MESSAGES / BOXES AREA ===
		'background for bars + boxes
		skin.RenderContent(contentX, contentY, contentW, barAreaH + msgAreaH + boxAreaH, "1_bottom")


		'===== DRAW RATINGS / BARS =====

		'bars have a top-padding
		contentY :+ barAreaPaddingY
		'speed
		skin.RenderBar(contentX + 5, contentY, 200, 12, GetSpeed())
		skin.fontSemiBold.drawBlock(GetLocale("MOVIE_SPEED"), contentX + 5 + 200 + 5, contentY, 75, 15, Null, skin.textColorLabel)
		contentY :+ barH + 2
		'critic/review
		skin.RenderBar(contentX + 5, contentY, 200, 12, GetReview())
		skin.fontSemiBold.drawBlock(GetLocale("MOVIE_CRITIC"), contentX + 5 + 200 + 5, contentY, 75, 15, Null, skin.textColorLabel)
		contentY :+ barH + 2
		'potential
		skin.RenderBar(contentX + 5, contentY, 200, 12, GetPotential())
		skin.fontSemiBold.drawBlock(GetLocale("SCRIPT_POTENTIAL"), contentX + 5 + 200 + 5, contentY, 75, 15, Null, skin.textColorLabel)
		contentY :+ barH + 2


		'=== MESSAGES ===
		'if there is a message then add padding to the begin
		If msgAreaH > 0 Then contentY :+ msgAreaPaddingY

		If showMsgLiveInfo
			skin.RenderMessage(contentX+5, contentY, contentW - 9, -1, GetPlannedLiveTimeText(), "runningTime", "bad", skin.fontSemiBold, ALIGN_CENTER_CENTER)
			contentY :+ msgH

			If showMsgTimeSlotLimit
				skin.RenderMessage(contentX+5, contentY, contentW - 9, -1, GetLocale("BROADCAST_ONLY_ALLOWED_FROM_X_TO_Y").Replace("%X%", GetBroadcastTimeSlotStart()).Replace("%Y%", GetBroadcastTimeSlotEnd()), "spotsPlanned", "warning", skin.fontSemiBold, ALIGN_CENTER_CENTER)
				contentY :+ msgH
			EndIf
		EndIf

		If showMsgBroadcastLimit
			if GetProductionBroadcastLimit() = 1
				skin.RenderMessage(contentX+5, contentY, contentW - 9, -1, GetLocale("ONLY_1_BROADCAST_POSSIBLE"), "spotsPlanned", "warning", skin.fontSemiBold, ALIGN_CENTER_CENTER)
			Else
				skin.RenderMessage(contentX+5, contentY, contentW - 9, -1, getLocale("ONLY_X_BROADCASTS_POSSIBLE").Replace("%X%", GetProductionBroadcastLimit()), "spotsPlanned", "warning", skin.fontSemiBold, ALIGN_CENTER_CENTER)
			EndIf
			contentY :+ msgH
		EndIf

		If showMsgEarnInfo
			skin.RenderMessage(contentX+5, contentY, contentW - 9, -1, getLocale("MOVIE_CALLINSHOW").Replace("%PROFIT%", "***"), "money", "good", skin.fontSemiBold, ALIGN_CENTER_CENTER)
			contentY :+ msgH
		EndIf

		'if there is a message then add padding to the bottom
		If msgAreaH > 0 Then contentY :+ msgAreaPaddingY


		'=== BOXES ===
		'boxes have a top-padding (except with messages)
		'if msgAreaH = 0 then contentY :+ boxAreaPaddingY
		contentY :+ boxAreaPaddingY
		'blocks
		skin.RenderBox(contentX + 5, contentY, 50, -1, GetBlocks(), "duration", "neutral", skin.fontBold)
		if IsLive()
			'(pre-)production time
			skin.RenderBox(contentX + 5 + 60, contentY, 65, -1, "~~ " + (productionTime/60) + GetLocale("HOUR_SHORT"), "runningTime", "neutral", skin.fontBold)
		EndIf
		'price
		If canAfford
			skin.RenderBox(contentX + 5 + 194, contentY, contentW - 10 - 194 +1, -1, MathHelper.DottedValue(GetPrice()), "money", "neutral", skin.fontBold, ALIGN_RIGHT_CENTER)
		Else
			skin.RenderBox(contentX + 5 + 194, contentY, contentW - 10 - 194 +1, -1, MathHelper.DottedValue(GetPrice()), "money", "neutral", skin.fontBold, ALIGN_RIGHT_CENTER, "bad")
		EndIf
		contentY :+ boxH


		'=== DEBUG ===
		If TVTDebugInfos
			'begin at the top ...again
			contentY = y + skin.GetContentY()
			Local oldAlpha:Float = GetAlpha()

			SetAlpha oldAlpha * 0.75
			SetColor 0,0,0
			DrawRect(contentX, contentY, contentW, sheetHeight - skin.GetContentPadding().GetTop() - skin.GetContentPadding().GetBottom())
			SetColor 255,255,255
			SetAlpha oldAlpha

			skin.fontBold.drawBlock("Drehbuch: "+GetTitle(), contentX + 5, contentY, contentW - 10, 28)
			contentY :+ 28
			skin.fontNormal.draw("Tempo: "+MathHelper.NumberToString(GetSpeed(), 4), contentX + 5, contentY)
			contentY :+ 12
			skin.fontNormal.draw("Kritik: "+MathHelper.NumberToString(GetReview(), 4), contentX + 5, contentY)
			contentY :+ 12
			skin.fontNormal.draw("Potential: "+MathHelper.NumberToString(GetPotential(), 4), contentX + 5, contentY)
			contentY :+ 12
			skin.fontNormal.draw("Preis: "+GetPrice(), contentX + 5, contentY)
			contentY :+ 12
			skin.fontNormal.draw("IsProduced: "+IsProduced(), contentX + 5, contentY)
		EndIf

		'=== OVERLAY / BORDER ===
		skin.RenderBorder(x, y, sheetWidth, sheetHeight)

		'=== X-Rated Overlay ===
		If IsXRated()
			GetSpriteFromRegistry(spriteNameOverlayXRatedLS).Draw(contentX + sheetWidth, y, -1, ALIGN_RIGHT_TOP)
		EndIf
	End Method
End Type