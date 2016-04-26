SuperStrict
Import "common.misc.plannerlist.base.bmx"
Import "game.programme.programmelicence.bmx"
Import "game.programme.programmelicence.gui.bmx"
Import "game.player.programmecollection.bmx"
Import "game.game.base.bmx"
Import "game.screen.programmeplanner.gui.bmx"
Import "Dig/base.gfx.gui.button.bmx"


'the programmelist shown in the programmeplaner
Type TgfxProgrammelist Extends TPlannerList
	Field displaceEpisodeTapes:TVec2D = New TVec2D.Init(6,5)
	'area of all genres/filters including top/bottom-area
	Field genresRect:TRectangle
	Field genresCount:Int = -1
	Field genreSize:TVec2D = New TVec2D
	Field currentEntry:Int = -1
	Field currentSubEntry:Int = -1
	Field subEntriesRect:TRectangle
	Field entriesPage:int = 1
	Field entriesPages:int = 1
	Field subEntriesPage:int = 1
	Field subEntriesPages:int = 1

	Field entriesButtonPrev:TGUIButton
	Field entriesButtonNext:TGUIButton
	Field subEntriesButtonPrev:TGUIButton
	Field subEntriesButtonNext:TGUIButton

	'licence with children
	Field hoveredParentalLicence:TProgrammeLicence = Null
	'licence 
	Field hoveredLicence:TProgrammeLicence = Null

	Const MAX_LICENCES_PER_PAGE:int= 8
	Const MODE_PROGRAMMEPLANNER:Int=0	'creates a GuiProgrammePlanElement
	Const MODE_ARCHIVE:Int=1			'creates a GuiProgrammeLicence

	

	Method Create:TgfxProgrammelist(x:Int, y:Int)
		genreSize = GetSpriteFromRegistry("gfx_programmegenres_entry.default").area.dimension.copy()
		entrySize = GetSpriteFromRegistry("gfx_programmeentries_entry.default").area.dimension.copy()

		'right align the list
		Pos.SetXY(x - genreSize.GetX(), y)

		'recalculate dimension of the area of all genres
		genresRect = New TRectangle.Init(Pos.GetX(), Pos.GetY(), genreSize.GetX(), 0)
		genresRect.dimension.y :+ GetSpriteFromRegistry("gfx_programmegenres_top.default").area.GetH()
		genresRect.dimension.y :+ TProgrammeLicenceFilter.GetVisibleCount() * genreSize.GetY()
		genresRect.dimension.y :+ GetSpriteFromRegistry("gfx_programmegenres_bottom.default").area.GetH()


		Return Self
	End Method


	'override
	Method GetEntriesRect:TRectangle()
		if not entriesRect
			'recalculate dimension of the area of all entries (also if not all slots occupied)
			entriesRect = New TRectangle.Init(genresRect.GetX() - 175, genresRect.GetY(), entrySize.GetX(), 0)
			entriesRect.dimension.y :+ GetSpriteFromRegistry("gfx_programmeentries_top.default").area.GetH()
			'max 10 licences per page
			entriesRect.dimension.y :+ MAX_LICENCES_PER_PAGE * entrySize.GetY()

			if entriesPages > 1
				entriesRect.dimension.y :+ GetSpriteFromRegistry("gfx_programmeentries_bottomButton.default").area.GetH()
			else
				entriesRect.dimension.y :+ GetSpriteFromRegistry("gfx_programmeentries_bottom.default").area.GetH()
			endif

			'height added when button visible
			'entriesRectButtonH = GetSpriteFromRegistry("gfx_programmeentries_bottomButton.default").area.GetH() - GetSpriteFromRegistry("gfx_programmeentries_bottom.default").area.GetH()
		endif
		
		return entriesRect
	End Method


	Method GetSubEntriesRect:TRectangle()
		if not subEntriesRect
			'recalculate dimension of the area of all entries (also if not all slots occupied)
			subEntriesRect = New TRectangle.Init(GetEntriesRect().GetX() + 175, GetEntriesRect().GetY(), entrySize.GetX(), 0)
			subEntriesRect.dimension.y :+ GetSpriteFromRegistry("gfx_programmeentries_top.default").area.GetH()
			'max 10 licences per page
			subEntriesRect.dimension.y :+ MAX_LICENCES_PER_PAGE * entrySize.GetY()
			subEntriesRect.dimension.y :+ GetSpriteFromRegistry("gfx_programmeentries_bottom.default").area.GetH()
			'height added when button visible
			'subEntriesRectButtonH = GetSpriteFromRegistry("gfx_programmeentries_bottomButton.default").area.GetH() - GetSpriteFromRegistry("gfx_programmeentries_bottom.default").area.GetH()
		endif
		return subEntriesRect
	End Method
	

	Method SetEntriesPages(pages:int)
		if entriesPages <> pages
			entriesPages = pages
			'reset rect
			entriesRect = null
		endif
	End Method


	Method SetSubEntriesPages(pages:int)
		if subEntriesPages <> pages
			subEntriesPages = pages
			'reset rect
			subEntriesRect = null
		endif
	End Method


	Method Draw()
		If Not enabled Then Return
		if Not owner Then Return

		'draw genre selector
		If Self.openState >=1
			Local programmeCollection:TPlayerProgrammeCollection = GetPlayerProgrammeCollection(owner)

			'mark new genres
			'TODO: do this part in programmecollection (only on add/remove)
			Local visibleFilters:TProgrammeLicenceFilter[] = TProgrammeLicenceFilter.GetVisible()
			Local containsNew:Int[visibleFilters.length]

			For Local licence:TProgrammeLicence = EachIn programmeCollection.justAddedProgrammeLicences
				'check all filters if they take care of this licence
				For Local i:Int = 0 Until visibleFilters.length
					'no check needed if already done
					If containsNew[i] Then Continue

					If visibleFilters[i].DoesFilter(licence)
						containsNew[i] = 1
						'do not check other filters
						Exit
					EndIf
				Next
			Next

			'=== DRAW ===
			Local currSprite:TSprite
			'maybe it has changed since initialization
			genreSize = GetSpriteFromRegistry("gfx_programmegenres_entry.default").area.dimension.copy()
			Local currY:Int = genresRect.GetY()
			Local currX:Int = genresRect.GetX()
			Local textRect:TRectangle = New TRectangle.Init(currX + 13, currY, genreSize.x - 12 - 5, genreSize.y)
			 
			Local oldAlpha:Float = GetAlpha()

			'draw each visible filter
			Local filter:TProgrammeLicenceFilter
			For Local i:Int = 0 Until visibleFilters.length
				Local entryPositionType:String = "entry"
				If i = 0 Then entryPositionType = "first"
				If i = visibleFilters.length-1 Then entryPositionType = "last"

				Local entryDrawType:String = "default"
				'highlighted - if genre contains new entries
				If containsNew[i] = 1 Then entryDrawType = "highlighted"
				'active - if genre is the currently used (selected to see tapes)
				If i = currentGenre Then entryDrawType = "active"
				'hovered - draw hover effect if hovering
				'can only haver if no episode list is open
				If Self.openState <3 And THelper.MouseIn(currX, currY, int(genreSize.GetX()), int(genreSize.GetY())-1) Then entryDrawType="hovered"

				'add "top" portion when drawing first item
				'do this in the for loop, so the entrydrawType is known
				'(top-portion could contain color code of the drawType)
				If i = 0
					currSprite = GetSpriteFromRegistry("gfx_programmegenres_top."+entryDrawType)
					currSprite.draw(currX, currY)
					currY :+ currSprite.area.GetH()
				EndIf

				'draw background
				GetSpriteFromRegistry("gfx_programmegenres_"+entryPositionType+"."+entryDrawType).draw(currX,currY)

				'genre background contains a 2px splitter (bottom + top)
				'so add 1 pixel to textY
				textRect.position.SetY(currY + 1)


				Local licenceCount:Int = programmeCollection.GetFilteredLicenceCount(visibleFilters[i])
				Local filterName:String = visibleFilters[i].GetCaption()

				
				If licenceCount > 0
					GetBitmapFontManager().baseFont.drawBlock(filterName + " (" +licenceCount+ ")", textRect.GetX(), textRect.GetY(), textRect.GetW(), textRect.GetH(), ALIGN_LEFT_CENTER, TColor.clBlack)
Rem
					SetAlpha 0.6; SetColor 0, 255, 0
					'takes 20% of fps...
					For Local i:Int = 0 To genrecount -1
						DrawLine(currX + 121 + i * 2, currY + 4 + lineHeight*genres - 1, currX + 121 + i * 2, currY + 17 + lineHeight*genres - 1)
					Next
endrem
				Else
					SetAlpha 0.25 * GetAlpha()
					GetBitmapFontManager().baseFont.drawBlock(filterName, textRect.GetX(), textRect.GetY(), textRect.GetW(), textRect.GetH(), ALIGN_LEFT_CENTER, TColor.clBlack)
					SetAlpha 4 * GetAlpha()
				EndIf
				'advance to next line
				currY:+ genreSize.y

				'add "bottom" portion when drawing last item
				'do this in the for loop, so the entrydrawType is known
				'(top-portion could contain color code of the drawType)
				If i = visibleFilters.length-1
					currSprite = GetSpriteFromRegistry("gfx_programmegenres_bottom."+entryDrawType)
					currSprite.draw(currX, currY)
					currY :+ currSprite.area.GetH()
				EndIf
			Next
		EndIf

		'draw tapes of current genre + episodes of a selected series
		If Self.openState >=2 And currentGenre >= 0
			DrawTapes(currentgenre)
		EndIf

		'draw episodes background
		If Self.openState >=3
			If currentGenre >= 0 Then DrawSubTapes(hoveredParentalLicence)
		EndIf

	End Method


	Method DrawTapes:Int(filterIndex:Int=-1)
		'skip drawing tapes if no genreGroup is selected
		If filterIndex < 0 Then Return False

		If not owner then Return False 
			 
		Local programmeCollection:TPlayerProgrammeCollection = GetPlayerProgrammeCollection(owner)
		Local filter:TProgrammeLicenceFilter = TProgrammeLicenceFilter.GetAtIndex(filterIndex)
		Local licences:TProgrammeLicence[] = programmeCollection.GetLicencesByFilter(filter)

		SetEntriesPages( ceil(licences.length / Float(MAX_LICENCES_PER_PAGE)) )

		Local currSprite:TSprite
		'maybe it has changed since initialization
		entrySize = GetSpriteFromRegistry("gfx_programmeentries_entry.default").area.dimension.copy()
		Local currY:Int = GetEntriesRect().GetY()
		Local currX:Int = GetEntriesRect().GetX()
		Local font:TBitmapFont = GetBitmapFont("Default", 10)


		'draw slots, even if empty
		local startIndex:int = (entriesPage-1)*MAX_LICENCES_PER_PAGE
		local endIndex:int = entriesPage*MAX_LICENCES_PER_PAGE -1
		For Local i:Int = startIndex To endIndex
			Local entryPositionType:String = "entry"
			If i = startIndex Then entryPositionType = "first"
			If i = endIndex Then entryPositionType = "last"

			Local entryDrawType:String = "default"
			Local tapeDrawType:String = "default"
			If licences and i < licences.length 
				'== BACKGROUND ==
				'planned is more important than new - both only happen
				'on startprogrammes
				If licences[i].IsPlanned()
					entryDrawType = "planned"
					tapeDrawType = "planned"
				Else
					'switch background to "new" if the licence is a just-added-one
					For Local licence:TProgrammeLicence = EachIn programmeCollection.justAddedProgrammeLicences
						If licences[i] = licence
							entryDrawType = "new"
							tapeDrawType = "new"
							Exit
						EndIf
					Next
				EndIf
			EndIf

			
			'=== BACKGROUND ===
			'add "top" portion when drawing first item
			'do this in the for loop, so the entrydrawType is known
			'(top-portion could contain color code of the drawType)
			If i = startIndex
				currSprite = GetSpriteFromRegistry("gfx_programmeentries_top."+entryDrawType)
				currSprite.draw(currX, currY)
				currY :+ currSprite.area.GetH()
			EndIf
			GetSpriteFromRegistry("gfx_programmeentries_"+entryPositionType+"."+entryDrawType).draw(currX,currY)


			'=== DRAW TAPE===
			If licences and i < licences.length
				'== ADJUST TAPE TYPE ==
				'do that afterwards because now "new" and "planned" are
				'already handled

				'active - if tape is the currently used
				If i = currentEntry Then tapeDrawType = "hovered"
				'hovered - draw hover effect if hovering
				'we add 1 pixel to height - to hover between tapes too
				If THelper.MouseIn(currX, currY + 1, int(entrySize.GetX()), int(entrySize.GetY())) Then tapeDrawType="hovered"


				If licences[i].isSingle()
					GetSpriteFromRegistry("gfx_programmetape_movie."+tapeDrawType).draw(currX + 8, currY+1)
				Else
					GetSpriteFromRegistry("gfx_programmetape_series."+tapeDrawType).draw(currX + 8, currY+1)
				EndIf
				font.drawBlock(licences[i].GetTitle(), currX + 22, currY + 3, 150,15, ALIGN_LEFT_CENTER, TColor.clBlack ,0, True, 1.0, False)

			EndIf


			'advance to next line
			currY:+ entrySize.y

			'add "bottom" portion when drawing last item
			'do this in the for loop, so the entrydrawType is known
			'(top-portion could contain color code of the drawType)
			If i = endIndex
				if entriesPages > 1
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_bottomButton."+entryDrawType)
				else
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_bottom."+entryDrawType)
				endif
				currSprite.draw(currX, currY)
				currY :+ currSprite.area.GetH()
			EndIf
		Next

		'handle page buttons
		if entriesPages > 1
			local w:int = 0.5 * GetSubEntriesRect().GetW() - 14 - 20
			if not entriesButtonPrev
				entriesButtonPrev = new TGUIButton.Create(new TVec2D.Init(currX + 5 , currY - 23), new TVec2D.Init(w, 18), "<", "PLANNERLIST_PROGRAMMELIST")
				entriesButtonPrev.spriteName = "gfx_gui_button.datasheet"
				'manage on our own
				GuiManager.Remove(entriesButtonPrev)
			endif
			if not entriesButtonNext
				entriesButtonNext = new TGUIButton.Create(new TVec2D.Init(currX + GetEntriesRect().GetW() - 7 - w, currY - 23), new TVec2D.Init(w, 18), ">", "PLANNERLIST_PROGRAMMELIST")
				entriesButtonNext.spriteName = "gfx_gui_button.datasheet"
				GuiManager.Remove(entriesButtonNext)
			endif


			local oldAlpha:float = GetAlpha()
			if entriesButtonPrev
				if not entriesButtonPrev.IsEnabled() then SetAlpha 0.5*oldAlpha
				entriesButtonPrev.Draw()
				if not entriesButtonPrev.IsEnabled() then SetAlpha oldAlpha
			endif
			if entriesButtonNext
				if not entriesButtonNext.IsEnabled() then SetAlpha 0.5*oldAlpha
				entriesButtonNext.Draw()
				if not entriesButtonNext.IsEnabled() then SetAlpha oldAlpha
			endif			

			GetBitmapFont("Default", 10).DrawBlock(entriesPage+"/" + entriesPages, currX, currY - 22, GetEntriesRect().GetW(), 20, ALIGN_CENTER_CENTER, TColor.clBlack)
		endif
				
		Rem
		'debug
		currY = GetEntriesRect().GetY()
		For Local i:Int = 0 To GameRules.maxProgrammeLicencesPerFilter
			if i = 0
				Local currSprite:TSprite
				If licences[0].IsPlanned()
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.planned")
				Else
					'switch background to "new" if the licence is a just-added-one
					For Local licence:TProgrammeLicence = EachIn GetPlayer().GetProgrammeCollection().justAddedProgrammeLicences
						If licences[i] = licence
							currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.new")
							Exit
						EndIf
					Next
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.default")
				EndIf

				currY :+ currSprite.area.GetH()
			EndIf
			
			SetColor 0,255,0
			If i mod 2 = 0 then SetColor 255,0,0
			SetAlpha 1.0
			DrawRect(GetEntriesRect().GetX(), currY+1, entrySize.GetX(), 1)
			'we add 1 pixel to y - as we hover between tapes too
			DrawRect(GetEntriesRect().GetX(), currY+1 + entrySize.GetY() - 1, entrySize.GetX(), 1)
			SetAlpha 0.4
			'we add 1 pixel to height - as we hover between tapes too
			DrawRect(GetEntriesRect().GetX(), currY+1, entrySize.GetX(), entrySize.GetY())

			currY:+ entrySize.y

			SetColor 255,255,255
			SetAlpha 1.0
		Next
		endrem
	End Method


	Method UpdateTapes:Int(filterIndex:Int=-1, mode:Int=0)
		'skip doing something without a selected filter
		If filterIndex < 0 Then Return False

		If not owner Then Return False  

		Local currY:Int = GetEntriesRect().GetY()
		Local programmeCollection:TPlayerProgrammeCollection = GetPlayerProgrammeCollection(owner)
		Local filter:TProgrammeLicenceFilter = TProgrammeLicenceFilter.GetAtIndex(filterIndex)
		Local licences:TProgrammeLicence[] = programmeCollection.GetLicencesByFilter(filter)
		if not licences
			SetEntriesPages( 1 )
			return False
		endif
		
		SetEntriesPages( ceil(licences.length / Float(MAX_LICENCES_PER_PAGE)) )

		'handle page buttons (before other click handling here)
		if entriesPages > 1
			if entriesButtonPrev
				entriesButtonPrev.Update()

				if entriesPage = 1
					if entriesButtonPrev.IsEnabled() then entriesButtonPrev.Disable()
				else
					if not entriesButtonPrev.IsEnabled() then entriesButtonPrev.Enable()
				endif

				if entriesButtonPrev.IsClicked()
					entriesPage = Min(entriesPage, entriesPage-1)
					entriesButtonPrev.mouseIsClicked = null
					MouseManager.ResetKey(1)
				endif
			endif

			if entriesButtonNext
				entriesButtonNext.Update()

				if entriesPage = entriesPages
					if entriesButtonNext.IsEnabled() then entriesButtonNext.Disable()
				else
					if not entriesButtonNext.IsEnabled() then entriesButtonNext.Enable()
				endif

				'need to check "hit" - outer rect is checking for hit too
				if entriesButtonNext.IsClicked()
					entriesPage = Max(entriesPage, entriesPage+1)
					entriesButtonNext.mouseIsClicked = null
					MouseManager.ResetKey(1)
				endif
			endif
		endif


		local startIndex:int = (entriesPage-1)*MAX_LICENCES_PER_PAGE
		local endIndex:int = Min(licences.length-1, entriesPage*MAX_LICENCES_PER_PAGE -1)
		For Local i:Int = startIndex to endIndex
			If i = startIndex
				Local currSprite:TSprite
				If licences[startIndex].IsPlanned()
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.planned")
				Else
					'switch background to "new" if the licence is a just-added-one
					For Local licence:TProgrammeLicence = EachIn GetPlayerProgrammeCollection(owner).justAddedProgrammeLicences
						If licences[i] = licence
							currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.new")
							Exit
						EndIf
					Next
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.default")
				EndIf

				currY :+ currSprite.area.GetH()
			EndIf

			'we add 1 pixel to height - to hover between tapes too
			If THelper.MouseIn(int(GetEntriesRect().GetX()), currY+1, int(entrySize.GetX()), int(entrySize.GetY()))
				GetGameBase().cursorstate = 1
				Local doneSomething:Int = False
				'store for sheet-display
				hoveredLicence = licences[i]

				'only interact if allowed
				If clicksAllowed
					If MOUSEMANAGER.IsShortClicked(1)
						If mode = MODE_PROGRAMMEPLANNER
							If licences[i].isSingle()
								'create and drag new block
								local programme:TProgramme = TProgramme.Create(licences[i])
								if programme
									New TGUIProgrammePlanElement.CreateWithBroadcastMaterial( programme, "programmePlanner" ).drag()
									SetOpen(0)
									doneSomething = True
								endif
							Else
								'set the hoveredParentalLicence so the episodes-list is drawn
								hoveredParentalLicence = licences[i]
								SetOpen(3)
								doneSomething = True
							EndIf
						ElseIf mode = MODE_ARCHIVE
							'create a dragged block
							Local obj:TGUIProgrammeLicence = New TGUIProgrammeLicence.CreateWithLicence(licences[i])
							obj.SetLimitToState("archive")
							obj.drag()

							SetOpen(0)
							doneSomething = True
						EndIf

						'something changed, so stop looping through rest
						If doneSomething
							MOUSEMANAGER.resetKey(1)
							Return True
						EndIf
					EndIf
				endif
			EndIf

			'next tape
			currY :+ entrySize.y
		Next


		Return False
	End Method


	Method DrawSubTapes:Int(parentLicence:TProgrammeLicence)
		If Not parentLicence Then Return False

		SetSubEntriesPages( ceil(parentLicence.GetSubLicenceCount() / Float(MAX_LICENCES_PER_PAGE)) )

		Local hoveredLicence:TProgrammeLicence = Null
		Local currSprite:TSprite
		Local currY:Int = GetSubEntriesRect().GetY()
		Local currX:Int = GetSubEntriesRect().GetX()
		Local font:TBitmapFont = GetBitmapFont("Default", 10)


		local startIndex:int = (subEntriesPage-1)*MAX_LICENCES_PER_PAGE
		local endIndex:int = subEntriesPage*MAX_LICENCES_PER_PAGE -1
		'if no paging was used, hide empty slots
		'(to have consistent button coordinates we show empty slots on
		' subsequent pages)
		if subEntriesPage = 1
			endIndex = Min(parentLicence.GetSubLicenceCount()-1, endIndex)
		endif

		For Local i:Int = startIndex to endIndex				
			Local licence:TProgrammeLicence = parentLicence.GetSubLicenceAtIndex(i)

			Local entryPositionType:String = "entry"
			If i = startIndex Then entryPositionType = "first"
			If i = endIndex Then entryPositionType = "last"

			Local entryDrawType:String = "default"
			Local tapeDrawType:String = "default"
			If licence
				'== BACKGROUND ==
				If licence.IsPlanned()
					entryDrawType = "planned"
					tapeDrawType = "planned"
				EndIf
			EndIf

			
			'=== BACKGROUND ===
			'add "top" portion when drawing first item
			'do this in the for loop, so the entrydrawType is known
			'(top-portion could contain color code of the drawType)
			If i = startIndex
				currSprite = GetSpriteFromRegistry("gfx_programmeentries_top."+entryDrawType)
				currSprite.draw(currX, currY)
				currY :+ currSprite.area.GetH()
			EndIf
			GetSpriteFromRegistry("gfx_programmeentries_"+entryPositionType+"."+entryDrawType).draw(currX,currY)


			'=== DRAW TAPE===
			If licence
				'== ADJUST TAPE TYPE ==
				'active - if tape is the currently used
				If i = currentSubEntry Then tapeDrawType = "hovered"
				'hovered - draw hover effect if hovering
				If THelper.MouseIn(currX, currY + 1, int(entrySize.GetX()), int(entrySize.GetY())) Then tapeDrawType="hovered"

				If licence.isSingle()
					GetSpriteFromRegistry("gfx_programmetape_movie."+tapeDrawType).draw(currX + 8, currY+1)
				Else
					GetSpriteFromRegistry("gfx_programmetape_series."+tapeDrawType).draw(currX + 8, currY+1)
				EndIf
				font.drawBlock("(" + (i+1) + "/" + parentLicence.GetSubLicenceCount() + ") " + licence.GetTitle(), currX + 22, currY + 3, 150,15, ALIGN_LEFT_CENTER, TColor.clBlack ,0, True, 1.0, False)
			EndIf


			'advance to next line
			currY:+ entrySize.y

			'add "bottom" portion when drawing last item
			'do this in the for loop, so the entrydrawType is known
			'(top-portion could contain color code of the drawType)
			If i = endIndex
				if subEntriesPages > 1
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_bottomButton."+entryDrawType)
				else
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_bottom."+entryDrawType)
				endif
				currSprite.draw(currX, currY)
				currY :+ currSprite.area.GetH()
			EndIf
		Next

		'handle page buttons
		if subEntriesPages > 1
			local w:int = 0.5 * GetSubEntriesRect().GetW() - 14 - 20
			if not subEntriesButtonPrev
				subEntriesButtonPrev = new TGUIButton.Create(new TVec2D.Init(currX + 5 , currY - 23), new TVec2D.Init(w, 18), "<", "PLANNERLIST_PROGRAMMELIST")
				subEntriesButtonPrev.spriteName = "gfx_gui_button.datasheet"
				'manage on our own
				GuiManager.Remove(subEntriesButtonPrev)
			endif
			if not subEntriesButtonNext
				subEntriesButtonNext = new TGUIButton.Create(new TVec2D.Init(currX + GetSubEntriesRect().GetW() - 7 - w, currY - 23), new TVec2D.Init(w, 18), ">", "PLANNERLIST_PROGRAMMELIST")
				subEntriesButtonNext.spriteName = "gfx_gui_button.datasheet"
				GuiManager.Remove(subEntriesButtonNext)
			endif
			

			local oldAlpha:float = GetAlpha()
			if subEntriesButtonPrev
				if not subEntriesButtonPrev.IsEnabled() then SetAlpha 0.5*oldAlpha
				subEntriesButtonPrev.Draw()
				if not subEntriesButtonPrev.IsEnabled() then SetAlpha oldAlpha
			endif
			if subEntriesButtonNext
				if not subEntriesButtonNext.IsEnabled() then SetAlpha 0.5*oldAlpha
				subEntriesButtonNext.Draw()
				if not subEntriesButtonNext.IsEnabled() then SetAlpha oldAlpha
			endif
			GetBitmapFont("Default", 10).DrawBlock(subEntriesPage+"/" + subEntriesPages, currX, currY - 22, GetSubEntriesRect().GetW(), 20, ALIGN_CENTER_CENTER, TColor.clBlack)
		endif


		Rem
		'debug - hitbox
		currY = GetSubEntriesRect().GetY()
		For Local i:Int = startIndex To endIndex
			Local licence:TProgrammeLicence = parentLicence.GetsubLicenceAtIndex(i)

			If i = startIndex
				Local currSprite:TSprite
				If licence And licence.IsPlanned()
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.planned")
				else
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.default")
				endif
				currY :+ currSprite.area.GetH()
			EndIf


			If THelper.MouseIn(GetSubEntriesRect().GetX(), currY + 1, entrySize.GetX(), entrySize.GetY())
				SetColor 100,255,100
				If i mod 2 = 0 then SetColor 255,100,100
			Else
				SetColor 0,255,0
				If i mod 2 = 0 then SetColor 255,0,0
			EndIf
			SetAlpha 1.0
			DrawRect(GetSubEntriesRect().GetX(), currY + 1, entrySize.GetX(), 1)
			DrawRect(GetSubEntriesRect().GetX(), currY + 1 + entrySize.GetY() - 1, entrySize.GetX(), 1)
			SetAlpha 0.3
			'complete size
			DrawRect(GetSubEntriesRect().GetX(), currY + 1, entrySize.GetX(), entrySize.GetY() - 1)

			currY:+ entrySize.y

			SetColor 255,255,255
			SetAlpha 1.0
		Next
		EndRem
	End Method


	Method UpdateSubTapes:Int(parentLicence:TProgrammeLicence)
		if not parentLicence
			SetEntriesPages( 1 )
			return False
		endif

		SetSubEntriesPages( ceil(parentLicence.GetSubLicenceCount() / Float(MAX_LICENCES_PER_PAGE)) )


		'handle page buttons (before other click handling here)
		if subEntriesPages > 1
			if subEntriesButtonPrev
				subEntriesButtonPrev.Update()

				if subEntriesPage = 1
					if subEntriesButtonPrev.IsEnabled() then subEntriesButtonPrev.Disable()
				else
					if not subEntriesButtonPrev.IsEnabled() then subEntriesButtonPrev.Enable()
				endif

				if subEntriesButtonPrev.IsClicked()
					subEntriesPage = Min(subEntriesPage, subEntriesPage-1)
					subEntriesButtonPrev.mouseIsClicked = null
					MouseManager.ResetKey(1)
				endif
			endif

			if subEntriesButtonNext
				subEntriesButtonNext.Update()

				if subEntriesPage = subEntriesPages
					if subEntriesButtonNext.IsEnabled() then subEntriesButtonNext.Disable()
				else
					if not subEntriesButtonNext.IsEnabled() then subEntriesButtonNext.Enable()
				endif

				'need to check "hit" - outer rect is checking for hit too
				if subEntriesButtonNext.IsClicked()
					subEntriesPage = Max(subEntriesPage, subEntriesPage+1)
					subEntriesButtonNext.mouseIsClicked = null
					MouseManager.ResetKey(1)
				endif
			endif
		endif


		
		Local currY:Int = GetSubEntriesRect().GetY() '+ GetSpriteFromRegistry("gfx_programmeentries_top.default").area.GetH()

		local startIndex:int = (subEntriesPage-1)*MAX_LICENCES_PER_PAGE
		local endIndex:int = Min(parentLicence.GetSubLicenceCount()-1, entriesPage*MAX_LICENCES_PER_PAGE -1)
		For Local i:Int = startIndex to endIndex				
			Local licence:TProgrammeLicence = parentLicence.GetsubLicenceAtIndex(i)

			If i = startIndex
				Local currSprite:TSprite
				If licence And licence.IsPlanned()
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.planned")
				else
					currSprite = GetSpriteFromRegistry("gfx_programmeentries_top.default")
				endif
				currY :+ currSprite.area.GetH()
			EndIf

			
			If licence
				If THelper.MouseIn(int(GetSubEntriesRect().GetX()), currY + 1, int(entrySize.GetX()), int(entrySize.GetY()))
					GetGameBase().cursorstate = 1 'mouse-over-hand

					'store for sheet-display
					hoveredLicence = licence
					
					'only interact if allowed
					If clicksAllowed
						If MOUSEMANAGER.IsShortClicked(1)
							'create and drag new block
							New TGUIProgrammePlanElement.CreateWithBroadcastMaterial( New TProgramme.Create(licence), "programmePlanner" ).drag()
							SetOpen(0)
							MOUSEMANAGER.resetKey(1)
							Return True
						EndIf
					endif
				EndIf
			EndIf

			'next tape
			currY :+ entrySize.y
		Next

		'handle page buttons
		if subEntriesPages > 1
			if subEntriesButtonPrev then subEntriesButtonPrev.Update()
			if subEntriesButtonNext then subEntriesButtonNext.Update()
		endif

		Return False
	End Method


	Method Update:Int(mode:Int=0)
		'gets repopulated automagically if hovered
		hoveredLicence = Null

		'if not "open", do nothing (including checking right clicks)
		If Not GetOpen() Then Return False

		'clicking on the genre selector -> select Genre
		'instead of isClicked (butten must be "normal" then)
		'we use "hit" (as soon as mouse button down)
		Local genresStartY:Int = GetSpriteFromRegistry("gfx_programmegenres_top.default").area.GetH()

		'only react to genre area if episode area is not open
		If openState <3
			If MOUSEMANAGER.IsShortClicked(1) And THelper.MouseIn(int(genresRect.GetX()), int(genresRect.GetY()) + genresStartY, int(genresRect.GetW()), int(genreSize.GetY())*TProgrammeLicenceFilter.GetVisibleCount())
				SetOpen(2)
				Local visibleFilters:TProgrammeLicenceFilter[] = TProgrammeLicenceFilter.GetVisible()
				currentGenre = Max(0, Min(visibleFilters.length-1, Floor((MouseManager.y - (genresRect.GetY() + genresStartY)) / genreSize.GetY())))
				MOUSEMANAGER.ResetKey(1)
			EndIf
		EndIf

		'if the genre is selected, also take care of its programmes
		If Self.openState >=2
			If currentgenre >= 0 Then UpdateTapes(currentgenre, mode)
			'series episodes are only available in mode 0, so no mode-param to give
			If hoveredParentalLicence Then UpdateSubTapes(hoveredParentalLicence)
		EndIf

		'close if clicked outside - simple mode: so big rect
		If MouseManager.isHit(1) ' and mode=MODE_ARCHIVE
			Local closeMe:Int = True
			'in all cases the genre selector is opened
			If genresRect.containsXY(MouseManager.x, MouseManager.y) Then closeMe = False
			'check tape rect
			If openState >=2 And GetEntriesRect().containsXY(MouseManager.x, MouseManager.y) then closeMe = False
			'check episodetape rect
			If openState >=3 And GetSubEntriesRect().containsXY(MouseManager.x, MouseManager.y)  Then closeMe = False

			If closeMe
				SetOpen(0)
				'MouseManager.ResetKey(1)
			EndIf
		EndIf
	End Method


	Method SetOpen:Int(newState:Int)
		newState = Max(0, newState)
		If newState <= 1 Then currentgenre=-1
		If newState <= 2 Then hoveredParentalLicence=Null
		If newState = 0
			enabled = 0
		Else
			enabled = 1

			entriesPage = 1
			subEntriesPage = 1
		EndIf

		Self.openState = newState
	End Method
End Type

