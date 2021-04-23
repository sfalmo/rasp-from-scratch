;;; Generate Colour Levels for Contours

function doColorLevels(wks, levels, mn, mx)
;;;;;;;;;;;
; I/P:
;      levels == (min,max,stride) - Display (min-stride) -> (max+strd), step == stride
;             OR Array of ExplicitLevels
;             OR "0" if not specified
;      mn     == min(data)
;      mx     == max(data)
; retn:
;      opts_cn
;;;;;;;;;;;
begin

	getvalues wks
		"wkColorMap" : cmap
	end getvalues
	clen = dimsizes(cmap)	; Includes b/g (0; black) & f/g (1; white)

	if( dimsizes(levels) .eq. 3 ) then              ; Min, Max & Stride Spec'd
		if(levels(0) .ge. levels(1)) then	; Only interval specified
			if(mx-mn .lt. levels(2))	; deal with mn - mx range less than specified interval
				clevels = (/0., 0., 0./)
			else
				nlev = floattointeger(ceil( (mx-mn) / levels(2) ))
				clevels = nice_mnmxintvl(mn,mx,nlev,True)
				if(clevels(0) .lt. 0.)  ;  set a zero contour
					nlev = floattointeger( clevels(0)/levels(2) ) - 1
					clevels(0) = nlev*levels(2)
				end if
				nlev = floattointeger( (clevels(1) - clevels(0)) / levels(2) )
				clevels(1) = clevels(0) + nlev * levels(2)
				clevels(2) = levels(2)
				clevels(0) = clevels(0) + clevels(2)
				clevels(1) = clevels(1) - clevels(2)
			end if
		else  ; min, max and intvl are specified
			clevels = levels
		end if
	else
		if(dimsizes(levels) .eq. 1) then ; levels = 0, so choose nice contour levels
			if(ismissing(mn) .or. ismissing(mx) .or. mn .eq. mx) then	; Catch the "constant field" case
				clevels = (/0., 0., 0./)
			else
				clevels = nice_mnmxintvl(mn, mx, 26, True)	; 26 == Max #levels (inc b/g & f/g)
				clevels(0) = clevels(0) + clevels(2)
				clevels(1) = clevels(1) - clevels(2)
			end if
		end if
	end if
	; clevels is (min, max, stride) with displayed min = (min - stride), max = (max + stride)

	; Choose the set of colours
	; It might ave been easier to produce a new Colour Table!
	; *** ncolors is #COLOURS, i.e #boxes in the labelBar
	; Note that (ncolors+1) labels are needed - see doLabelBar()

	opts_cn = True

	if(isvar("clevels")) then
		if(clevels(2) .ne. 0.) then
			ncolors = floattointeger(((clevels(1) - clevels(0)) / clevels(2))) + 2
			if(ncolors .gt. (clen(0)-2)) then
				print("ERROR: ContourParameters requests more colors (" + ncolors + ") than colorMap (" + (clen(0)-2) + ")"  )
				print("       Possibly a default stride?")
				return(False)
			end if

			print("    plot: NCOLORS,CLEVELS= "+ncolors+" "+clevels(0)+","+clevels(1)+","+clevels(2))
			fill_colors = ispan(2,clen(0),(clen(0)-2)/ncolors)
			; This messing about is due to the stupidities af the way ispan() works
			; (A do loop on integer values)
			; You can sometimes get an extra box
			if(dimsizes(fill_colors) .gt. ncolors) then  ; There's an extra color
				tmp = fill_colors(0:(ncolors-1))
				delete(fill_colors)
				fill_colors = tmp
				delete(tmp)
			end if

			opts_cn@cnLevelSelectionMode = "ManualLevels"
			opts_cn@cnMinLevelValF  = clevels(0)
			opts_cn@cnMaxLevelValF  = clevels(1)
			opts_cn@cnLevelSpacingF = clevels(2)

			opts_cn@cnFillColors = fill_colors
		else
			opts_cn@cnFillColors = 0
		end if
		opts_cn@gsnSpreadColors = False
		return(opts_cn)
	end if

	; Finally get to do ExplicitLevels!
	opts_cn@cnLevelSelectionMode = "ExplicitLevels"
	opts_cn@cnLevels             = levels

	tmp = ispan(2, clen(0), (clen(0)-2)/(dimsizes(levels)-1))
	opts_cn@cnFillColors = tmp(1:dimsizes(tmp)-1) 
	; print(dimsizes(opts_cn@cnFillColors))

	return(opts_cn)
end
