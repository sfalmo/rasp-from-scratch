domainid      = new(1, string)
do_plots      = new(1, logical)
wks           = new(1, graphic)
bg            = new(1, graphic)
borderRet     = new(1, graphic)
alat          = new(1, float)
alon          = new(1, float)
gridspacingkm = new(1, string)
opts_cn       = True
opts_bg       = True
atts          = True
;; Vars for BoxWmax - Real values must be positive
;; Also used for xbl
imaxw = -1
jmaxw = -1
kmaxw = -1
angle =  0.
rad2deg = 45.0/atan(1.0)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLOT VERTICAL VELOCITY AT PRESSURE LEVEL WITH WINDBARBS
;;; Wind Direction & Strength indicated by WindBarb

function plot_wind(wks, bg, u, v, pressure, plot_param, tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt )
local opts_plot
begin
	ldatafmt = 0	; May be overridden 

	opts_plot = True
	
	load "opts_v.ncl"   ;;;; Options for Wind Barbs

        ;;; FOR SITE SUBSTITUTIONS - NOT CURRENTLY IMPLEMENTED
	; opts_w = True
        ; load "rasp.site_load.pressure-level.ncl" ; has opts_w@ContourParameters .....

	if(do_plots .eq. False) then
		return(ldatafmt)
	end if

	; New vars to avoid changing originals
	u4plot = u * 1.9438445	; Wind Barbs always in Kts 
	v4plot = v * 1.9438445
	u4plot@lat2d = alat
	u4plot@lon2d = alon
	v4plot@lat2d = alat
	v4plot@lon2d = alon

        mn = 0
        mx = 0
	levels = 0
	fixedcolor = 0

        opts = doColorLevels(wks, levels, mn, mx)
	if(opts .eq. False) then
		return(ldatafmt)
	end if

	fName = OutDir + plot_param + tail + ".body"
        wks_temp = create fName imageWorkstationClass defaultapp
                "wkFormat" : "newpng"
                "wkHeight" : wkHeight
                "wkWidth"  : wkWidth
		"wkBackgroundColor" : "white"
		"wkBackgroundOpacityF" : 0.0
                "wkForegroundColor" : "black"
                "wkColorMap"        : "BlAqGrYeOrReVi200"
        end create
	copy_VarAtts(opts_bg, opts_plot)
	copy_VarAtts(opts_vc, opts_plot)
        opts_plot@mpOutlineOn         = False

	plot_v = gsn_csm_vector_map(wks_temp, u4plot, v4plot, opts_plot )
	draw(plot_v)

        ; See http://www.ncl.ucar.edu/Support/talk_archives/2006/0750.html
        ; for a not-very-obvious descripion of this twiddle
        NhlChangeWorkstation(bg, wks_temp)
        draw(bg)
        NhlChangeWorkstation(bg, wks)
        frame(wks_temp)
        if(isvar("wks_temp")) then
		delete(wks_temp)        ; Close the file
	end if

	doHeader(plot_param, opts_bparam@MainTitle, Region, gridspacingkm, FMT, tail)
	doLabelBar(plot_param, tail, opts, FMT, opts_bparam@unitString, fixedcolor)

	if(Projection .ne. "lambert") then
		; cmd = CONVERT + " -transparent white -trim " + fName + ".png png32:" + fName + ".png"
		cmd = CONVERT + " -trim " + fName + ".png png32:" + fName + ".png"
		print("    " + cmd)
		system(cmd)
	else
		fName = OutDir + plot_param + tail
		cmd = "montage -tile x3 -geometry +0+0 " + fName + ".head.png " + fName + ".body.png " + fName + ".foot.png " + fName + ".png";
		print("    " + cmd)
		system(cmd)
	end if

	return(ldatafmt)
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
undef("get_intercepts")

;;; NDC Version of wrf_user_set_xy()
function get_intercepts( plot:graphic, xp:numeric, yp:numeric, angle:numeric )

local x,y,slope,intercept,x0,y0,x1,y1,distance,dx,dy,dxy,npts,xy, deg2rad

begin

  deg2rad = atan(1.0) / 45.0
  getvalues plot
     "mpTopMapPosF":	top
     "mpBottomMapPosF":	bottom
     "mpLeftMapPosF":	left
     "mpRightMapPosF":	right
  end getvalues

  ; find intersection of line and domain boundaries

  if ((angle .gt. 315.) .or. (angle .lt. 45.) .or. \
      ((angle .gt. 135.) .and. (angle .lt. 225.)) )  then

       ;  x = y*slope + intercept

       slope = tan ( -deg2rad * (360.-angle) )
       if( angle .lt. 45. ) then
         slope = tan ( deg2rad * angle )
       end if
       if( angle .gt. 135.) then
         slope = tan ( deg2rad * (angle-180.) )
       end if
       intercept = xp - yp*slope

       ; find intersections with domain boundaries

       y0 = bottom
       x0 = y0*slope + intercept

       if( x0 .lt. left) then  ; intersect outside of left boundary
         x0 = left
         y0 =  (x0 - intercept)/slope
       end if
       if( x0 .gt. right) then  ; intersect outside of right boundary
         x0 = right
         y0 =  (x0 - intercept)/slope
       end if

       y1 = top  ;  need to make sure this will be a float?
       x1 = y1*slope + intercept

       if( x1 .lt. left) then  ; intersect outside of left boundary
         x1 = left
         y1 =  (x1 - intercept)/slope
       end if
       if( x1 .gt. right) then  ; intersect outside of right boundary
         x1 = right
         y1 =  (x1 - intercept)/slope
       end if

  else

       ;  y = x*slope + intercept

       slope = tan( deg2rad * (90.-angle) )
       if( angle .gt. 225. ) then
         slope = tan( deg2rad * (270.-angle) )
       end if
       intercept = yp - xp*slope

       ; find intersections with domain boundaries

       x0 = left
       y0 = x0*slope + intercept

       if( y0 .lt. bottom) then  ; intersect outside of bottom boundary
         y0 = bottom
         x0 =  (y0 - intercept)/slope
       end if
       if( y0 .gt. top) then  ; intersect outside of top boundary
         y0 = top
         x0 =  (y0 - intercept)/slope
       end if

       x1 = right ;  need to make sure this will be a float?
       y1 = x1*slope + intercept

       if( y1 .lt. bottom) then  ; intersect outside of bottom boundary
         y1 = bottom
         x1 =  (y1 - intercept)/slope
       end if
       if( y1 .gt. top) then  ; intersect outside of top boundary
         y1 = top
         x1 =  (y1 - intercept)/slope
       end if

  end if  ; we have beginning and ending points

  ;JACK - require cross-section to be left-to-right (except 0=180deg=>bottom-to-top)
  if(  x0 .gt. x1 ) then
    tmp = x0
    x0 = x1
    x1 = tmp
    tmp = y0
    y0 = y1
    y1 = tmp
  end if

  xy = new((/ 2, 3 /),typeof(xp))
  xy(0,:) = (/ x0, xp, x1 /)
  xy(1,:) = (/ y0, yp, y1 /)

  return(xy)

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLOT VERTICAL VELOCITY (Contour), WIND SPEED AT PRESSURE LEVEL AND BOXWMAX LINE (if boxwmax done)
;;; W indicated by colour; Wind Speed by barbs
;;;
; HIERONDER zm, zft TOEGEVOEGD
function plot_barb(wks, bg, mag, u, v, z, pressure, plot_param, tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt )
local opts_plot
begin
	ldatafmt = 0	; May be overridden in rasp.site_load.pressure-level.ncl

	opts_plot = True
	copy_VarAtts(opts_cn, opts_plot)
	
	load "opts_v.ncl"   ;;;; Options for Wind Barbs

	fName = OutDir + plot_param + tail + ".body"
        wks_temp = create fName imageWorkstationClass defaultapp
                "wkFormat" : "newpng"
                "wkHeight" : wkHeight
                "wkWidth"  : wkWidth
		"wkBackgroundColor" : (/1.0, 1.0, 1.0 /)  ; white - Transparent
		"wkBackgroundOpacityF" : 0.0
                "wkForegroundColor" : "black"
                "wkColorMap"        : "BlAqGrYeOrReVi200"
        end create

        ;;; FOR SITE SUBSTITUTIONS
	opts_w = True	; opts_w for wind, if required

        load "rasp.site_load.pressure-level.ncl" ; has opts_w@ContourParameters .....

	if(do_plots .eq. False) then
		return(ldatafmt)
	end if

	fixedcolor = 0
        if( isatt(opts_bparam, "ContourParameters")) then
                levels = opts_bparam@ContourParameters
	end if
	if( isatt(opts_bparam, "ExplicitLevels") ) then	; ExplicitLevels overrides ContourParameters
		opts = True
		opts@cnLevelSelectionMode = "ExplicitLevels"
		opts@cnLevels = opts_bparam@ExplicitLevels
		delete(levels)
		levels = opts@cnLevels
	end if
	if( isatt(opts_bparam, "colorMap") ) then
		gsn_define_colormap( wks_temp, opts_bparam@colorMap );
	end if

	if(isvar("levels")) then
		if(levels(1) .gt. levels(0)) then       ;  Min, Max & Intvl specified
			fixedcolor = 1
		end if
	else
		levels = 0				; Flag to indicate Not Specified
	end if

	; New vars to avoid changing originals
	mag4plot = mag * opts_bparam@mult	; Adjust for UNITS
	u4plot = u * 1.9438445	; Wind Barbs always in Kts 
	v4plot = v * 1.9438445
	mag4plot@lat2d = alat
	mag4plot@lon2d = alon
	u4plot@lat2d   = alat
	u4plot@lon2d   = alon
	v4plot@lat2d   = alat
	v4plot@lon2d   = alon
	if(isatt(mag4plot, "units")) then
		delete_VarAtts(mag4plot, "units")
		delete_VarAtts(u4plot, "units")
		delete_VarAtts(v4plot, "units")
	end if

        mn = min(mag4plot)
        mx = max(mag4plot)

        opts = doColorLevels(wks_temp, levels, mn, mx)
	if(opts .eq. False) then
		return(ldatafmt)
	end if

        copy_VarAtts(opts, opts_plot)

	copy_VarAtts(opts_bg, opts_plot)
        opts_plot@mpOutlineOn         = False
	plot_c = gsn_csm_contour_map(wks_temp, mag4plot, opts_plot)
	plot_v = gsn_csm_vector(wks_temp, u4plot, v4plot, opts_vc )

	overlay(plot_c, plot_v)
	draw(plot_c)

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;; If done boxwmax, add line to plot
	if(imaxw .ge. 0)
		print("    boxwmax / xbl @ " + imaxw + "," + jmaxw + "," + kmaxw)

		x = new(1,float)
		y = new(1,float)

		; Test: draw marker at NW corner
		;siz = dimsizes(mag4plot) ; siz(0) == y_size; siz(1) == x_size
		;datatondc( plot_c, alon(siz(0)- 10,10),alat(siz(0)- 10,10), x,y)
		datatondc( plot_c, alon(jmaxw,imaxw),alat(jmaxw,imaxw), x,y)

		; Add a marker at boxwmax location
		opts_marker                    = True
		opts_marker@gsMarkerColor      = "blue"
; Hieronder thickness gewijzigd van orgineel 15 naar 5
		opts_marker@gsMarkerThicknessF = 5
; Hieronder thickness gewijzigd van orgineel 0.030 naar 0.015
		opts_marker@gsMarkerSizeF      = 0.015
		opts_marker@gsMarkerIndex      = 14
		gsn_polymarker_ndc( wks_temp, x, y, opts_marker )

		; Add the Line
		section = get_intercepts(bg, x, y, angle)

		opts_sectionline                   = True
		opts_sectionline@gsLineColor       = "black"
		opts_sectionline@gsLineDashPattern = 5
; Hieronder linethickness gewijzigd van origineel 5.0 naar 2.0
		opts_sectionline@gsLineThicknessF  = 2.0
		gsn_polyline_ndc(wks_temp, section(0,:),section(1,:), opts_sectionline)
; maskData = plot_c@data
; print(dimsizes(maskData))
; print(getvaratts(maskData))
;maskData = where(maskData.eq.maskData@_FillValue,False,True)

	end if
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ; See http://www.ncl.ucar.edu/Support/talk_archives/2006/0750.html
        ; for a not-very-obvious descripion of this twiddle
        NhlChangeWorkstation(bg, wks_temp)
        draw(bg)
        NhlChangeWorkstation(bg, wks)
        frame(wks_temp)
        if(isvar("wks_temp")) then
		delete(wks_temp)        ; Close the file
	end if

	doHeader(plot_param, opts_bparam@MainTitle, Region, gridspacingkm, FMT, tail)
	if( isatt(opts_bparam, "colorMap") ) then
		opts@colorMap = opts_bparam@colorMap 
	end if
	doLabelBar(plot_param, tail, opts, FMT, opts_bparam@unitString, fixedcolor)

	if(Projection .eq. "lambert") then
		fName = OutDir + plot_param + tail
		cmd = "montage -tile x3 -geometry +0+0 " + fName + ".head.png " + fName + ".body.png " + fName + ".foot.png " + fName + ".png";
		print("    " + cmd)
		system(cmd)
	else
		; cmd = CONVERT + " -transparent white -trim " + fName + ".png png32:" + fName + ".png"
		cmd = CONVERT + " -trim " + fName + ".png png32:" + fName + ".png"
		print("    " + cmd)
		system(cmd)
	end if

	return(ldatafmt)
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLOT CONTOUR
;;; Magnitude indicated by Colour

function plot_contour(wks, bg, mag, plot_param, tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
local opts_plot
begin
	if(isatt(mag, "description")) then
		delete_VarAtts(mag, "description")
	end if
	if(isatt(mag, "units")) then
		delete_VarAtts(mag, "units")
	end if
	mag@lat2d = alat
	mag@lon2d = alon

	opts_plot = True
	copy_VarAtts(opts_cn, opts_plot)

	fixedcolor = 0

	fName = OutDir + plot_param + tail + ".body"
	wks_temp = create fName imageWorkstationClass defaultapp
		"wkFormat" : "newpng"
		"wkHeight" : wkHeight
		"wkWidth"  : wkWidth
		"wkBackgroundColor" : (/1.0, 1.0, 1.0 /)  ; White
		"wkBackgroundOpacityF" : 0.0		  ; Transparent
		"wkForegroundColor" : "black"
		"wkColorMap"        : "BlAqGrYeOrReVi200"
	end create

	;;; FOR SITE SUBSTITUTIONS (may override defaults)
	load "rasp.site_load.contour-parameter.ncl"	; Has opts_bparam@ContourParameters(...)

	if(do_plots .eq. False) then
		return(ldatafmt)	; may be changed by rasp.site_load...
	end if

	if(isvar("levels")) then
		delete(levels)
	end if

	; Use new variable to avoid changing mag
	mag4plot = mag * opts_bparam@mult
	copy_VarAtts(mag, mag4plot)

	if( isatt(opts_bparam, "ContourParameters")) then
		levels = opts_bparam@ContourParameters
		if(levels(0) .ne. levels(1)) then       ;  Min, Max & Intvl specified
			fixedcolor = 1
		end if
	end if

	if( isatt(opts_bparam, "ExplicitLevels") ) then	; ExplicitLevels overrides ContourParameters
		opts = True
		opts@cnLevelSelectionMode = "ExplicitLevels"
		opts@cnLevels = opts_bparam@ExplicitLevels
		delete(levels)
		levels = opts@cnLevels
	end if
	if( isatt(opts_bparam, "colorMap") ) then
		gsn_define_colormap( wks_temp, opts_bparam@colorMap );
	end if

	mn = min(mag4plot)
	mx = max(mag4plot)

	if( all(ismissing(mag4plot)) .or. mn .eq. mx) then	; Catch all-same / all-missing
		print("    All values missing / same")
		if(isvar("levels")) then
			delete(levels)
		end if
		levels = 0
		mag4plot = 0
	end if

	; This does not allow for Min, Max to be specified - Why would you want to?
	if(plot_param .eq. "mslpress") then
		if(ismissing(opts_bparam@ContourParameters(2))) then
			step = 2.0
		else
			step = opts_bparam@ContourParameters(2)
		end if
	        t1 = floor(min(mag) / step) * step  ; Display mslp on "step" boundaries
        	t2 = ceil( max(mag) / step) * step
	        levels = (/ t1 + step, t2 - step, step /)
	end if

	print("    plot_contour: " + plot_param + " min = " + mn + " max = " + mx)

	if(.not. isvar("levels")) then
		levels = 0
	end if

	opts = doColorLevels(wks_temp, levels, mn, mx)
	if(opts .eq. False) then
		return(ldatafmt)
	end if

	copy_VarAtts(opts, opts_plot)

	copy_VarAtts(opts_bg, opts_plot)
	opts_plot@mpOutlineOn         = False

	plot = gsn_csm_contour_map(wks_temp, mag4plot, opts_plot)

	draw(plot)

	; See http://www.ncl.ucar.edu/Support/talk_archives/2006/0750.html
	; for a not-very-obvious descripion of this twiddle
	NhlChangeWorkstation(bg, wks_temp)
	draw(bg)
	NhlChangeWorkstation(bg, wks)
	frame(wks_temp)

	if(isvar("wks_temp")) then
		delete(wks_temp)	; Close the file
	end if

	doHeader(plot_param, opts_bparam@MainTitle, Region, gridspacingkm, FMT, tail)
	if( isatt(opts_bparam, "colorMap") ) then
		opts@colorMap = opts_bparam@colorMap;
	end if
	doLabelBar(plot_param, tail, opts, FMT, opts_bparam@unitString, fixedcolor)

	if(Projection .eq. "lambert") then
		fName = OutDir + plot_param + tail
		cmd = "montage -tile x3 -geometry +0+0 " + fName + ".head.png " + fName + ".body.png " + fName + ".foot.png " + fName + ".png";
		print("    " + cmd)
		system(cmd)
	else
		; cmd = CONVERT + " -transparent white -trim " + fName + ".png png32:" + fName + ".png"
		cmd = CONVERT + " -trim " + fName + ".png png32:" + fName + ".png"
		print("    " + cmd)
		system(cmd)
	end if

	return(ldatafmt)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     PLOT SOUNDING

function plot_sounding(FMT[1]:string, \
 	s[1]:integer,                  \
 	info[1]:logical,               \
 	pmb[*][*][*]:numeric,          \
 	tc[*][*][*]:numeric,           \
 	td[*][*][*]:numeric,           \
 	z[*][*][*]:numeric,            \
 	uEW[*][*][*]:numeric,          \
 	vNS[*][*][*]:numeric,          \
 	qcloud[*][*][*]:numeric,       \
 	cldfra[*][*][*]:numeric,       \
 	psfc[*][*]:numeric,            \
 	ter[*][*]:numeric,             \
	tail                           )
begin

	psfcmb = psfc * 0.01
	if( UNITS .ne. "metric" ) then
		uraw =  uEW * 1.94386
		vraw =  vNS * 1.94386
	else
		uraw =  uEW
		vraw =  vNS
	end if

	load "opts_sounding.ncl"

	ENV_NCL_ID = getenv("ENV_NCL_ID")
	if ( .not. ismissing(ENV_NCL_ID) ) then
		; ENV_NCL_ID = trim_string( ENV_NCL_ID )
		ENV_NCL_ID = str_strip( ENV_NCL_ID )
		if( .not. isatt(opts_soundingloc,"txFuncCode") ) then
			;;; if name not plotted on map, include integer in title

			loc_str = "#" + s + ": " + info@sounding_ids(s)             \
			   + " ~I~" + info@sounding_lats(s) + "~F34~0~F21~,"        \
			   + info@sounding_lons(s) + "~F34~0~F21~ ("                \
			   + (info@j(s)+1) + "," + (info@i(s)+1)                    \
			   + ")~P~" + "   "+ENV_NCL_ID
		else
			loc_str = info@sounding_ids(s)+" ~I~"                       \
			   + info@sounding_lats(s)+"~F34~0~F21~,"                   \
			   + info@sounding_lons(s) + "~F34~0~F21~,"                 \
			   + info@j(s) + "," + info@i(s)                            \
			   + ")~P~" + "   " + ENV_NCL_ID
		end if
		skewtOpts@tiMainString      = loc_str
		print ( "    SOUNDING: "+loc_str )
	end if


	;        Get the skew-T background
        if( FMT .eq. "png" ) then
                wksSnd = create (OutDir + "sounding" + s + tail ) imageWorkstationClass defaultapp
                "wkHeight"          : wkHeight
                "wkWidth"           : wkWidth
                "wkBackgroundColor" : "white"
                "wkForegroundColor" : "black"
                "wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
                end create
        end if
	if(FMT .eq. "x11") then
		wksSnd = create "sounding" xWorkstationClass defaultapp
			"wkHeight" : wkHeight
			"wkWidth"  : wkWidth
			"wkBackgroundColor" : "white"
			"wkForegroundColor" : "black"
			"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
		end create
	end if


	skewt_bkgd                 = skewT_BackGround (wksSnd, skewtOpts)

	;;; FOR SITE SUBSTITUTIONS  (jack: if alter filename also change BLIP/PLOT/filename)
	load "rasp.site_load.skewt.ncl"

	; Draw the skew-T plot
	draw (skewt_bkgd )

	;;; DANGER - NOTE REVERSAL OF SIGN FOR U,V HERE, WHICH WORKS FOR LOCAL skewt_func.ncl VERSION
	;;;          BUT _NOT_ FOR LATEST SHEA VERSION - SO NEED TO USE _LOCAL_ skewt_func.ncl FILE

	; print ( "    "+info@sounding_ids(s)+" loc="+info@i(s)+","+info@j(s)+" P2m,0= " \
	;       + psfcmb(info@i(s),info@j(s))+","+pmb(0,info@i(s),info@j(s)) \
	;       + " Zsfc,0= "+ter(info@i(s),info@j(s))+","+z(0,info@i(s),info@j(s)) )

	;sanity check
	if( psfcmb(info@i(s),info@j(s)) .lt. pmb(0,info@i(s),info@j(s)) ) then
		print ( "**WARNING - Psfc < P0" )
	end if

	;;; PLOT SKEWT
	skewT_data = skewT_PlotData(wksSnd, skewt_bkgd, \
	                   pmb(   :,info@i(s), info@j(s)),      \
	                   tc(    :,info@i(s), info@j(s)),      \
	                   td(    :,info@i(s), info@j(s)),      \
	                   z(     :,info@i(s), info@j(s)),      \
	                   -uraw( :,info@i(s), info@j(s)),      \
	                   -vraw( :,info@i(s), info@j(s)),      \
	                   qcloud(:,info@i(s), info@j(s)),      \
	                   cldfra(:,info@i(s), info@j(s)),      \
	                   psfcmb(  info@i(s), info@j(s)),      \
	                   tc(   0, info@i(s), info@j(s)),      \
	                   td(   0, info@i(s), info@j(s)),      \
	                   dataOpts                             )

	;;; FINALLY, DRAW FRAME
	frame(wksSnd)
	return(wksSnd)	; Not needed, but prevents wks (and defaultapp) from going to the garbage collector!
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLOT CONTOUR with STIPPLE
;;; Only used for wstar_bsratio
;;; Mag1 indicated by Colour  (wstar)
;;; Mag2 indicated by Stipple (bsratio)

function plot_stipple(wks, bg, mag1, mag2, plot_param, tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
local opts_plot
begin
	mag1@lat2d = alat
	mag1@lon2d = alon
	mag2@lat2d = alat
	mag2@lon2d = alon


        fName = OutDir + plot_param + tail + ".body"
        wks_temp = create fName imageWorkstationClass defaultapp
                "wkFormat" : "newpng"
                "wkHeight" : wkHeight
                "wkWidth"  : wkWidth
		"wkBackgroundColor" : (/1.0, 1.0, 1.0 /)  ; white - Transparent
		"wkBackgroundOpacityF" : 0.0
                "wkForegroundColor" : "black"
                "wkColorMap"        : "BlAqGrYeOrReVi200"
        end create

	opts_plot = True
	copy_VarAtts(opts_cn, opts_plot)

	;;; FOR SITE SUBSTITUTIONS (may override defaults)
	load "rasp.site_load.contour-parameter.ncl"	; Has opts_bparam@ContourParameters(...)

	if( isatt(opts_bparam, "ExplicitLevels") ) then	; ExplicitLevels overrides ContourParameters
		opts = True
		opts@cnLevelSelectionMode = "ExplicitLevels"
		opts@cnLevels = opts_bparam@ExplicitLevels
		delete(levels)
		levels = opts@cnLevels
	end if
	if( isatt(opts_bparam, "colorMap") ) then
		gsn_define_colormap( wks_temp, opts_bparam@colorMap );
	end if

	if(do_plots .eq. False) then
		return(ldatafmt)
	end if

        fixedcolor = 0
        if( isatt(opts_bparam, "ContourParameters")) then
                levels = opts_bparam@ContourParameters
        end if  
	if(isvar("levels")) then
		if(levels(1) .gt. levels(0)) then       ;  Min, Max & Intvl specified
			fixedcolor = 1
		end if
	else
		levels = 0				; Flag to indicate Not Specified
	end if

	; New variable to avoid changing orig
	mag1plot = mag1 * opts_bparam@mult
	copy_VarAtts(mag1, mag1plot)

	mn = min(mag1plot)
	mx = max(mag1plot)
	print("    " + plot_param + "(mag): Min, Max = " + mn + "," + mx )
	opts_1 = doColorLevels(wks, levels, mn, mx)
	if(opts_1 .eq. False) then
		return(ldatafmt)
	end if
	copy_VarAtts(opts_1, opts_plot)
	copy_VarAtts(opts_bg, opts_plot)
	opts_plot@mpOutlineOn         = False

	contour = gsn_csm_contour_map(wks_temp, mag1plot, opts_plot)	; Make the Contour Map

	; Done the BG contour - Now do the stipple
	opts_2                      = True
	opts_2@cnFillMode           = "AreaFill"
	opts_2@cnMonoFillScale      = False
	opts_2@cnLevelSelectionMode = "ExplicitLevels"
	; Stipple levels of dense (0 - 3); sparse (3 - 6); None ( >6)
	; If change, change also "Force one Contour..." & "stipple1 = ..." lines below
	opts_2@cnLevels             = (/0.0, 3.0, 6.0, 100.0/)
	opts_2@cnFillScales         = (/1.0,  0.5, 1.0, 100, 2.0 /)
	                            ; (/St,   0-3, 3-6,  >6, End /)
	opts_2@cnFillDotSizeF       = 3.0 / 1600.0	; Size of Stipple dots
	                                                ; 3 pixels on a 1600px display
	                                                ; Should really be wkHeight/Width
	opts_2@cnLinesOn            = True              ; False for no stipple contour lines (it's a good diagnostic)
	opts_2@cnLineLabelsOn       = False
	opts_2@cnInfoLabelOn        = False
	opts_2@gsnDraw              = False
	opts_2@gsnFrame             = False

	; Force at least one contour interval
	if(max(mag2) .le. 3.0) then 
		opts_2@cnFillScales =  (/ 0.5, 0.5, 0.5, 0.5, 0.5 /)
	end if 

	; Make the bsratio map
	stipple = gsn_csm_contour(wks_temp, mag2, opts_2)

	; Shade bsratio with the Stipple
	; See http://www.ncl.ucar.edu/Document/HLUs/Classes/Workstation.shtml#NhlTFillIndex
	opt_shd = True	                       ; Options for Stipple Shading
	opt_shd@gsnShadeFillType = "Pattern"
	opt_shd@gsnShadeFillScaleF   = 0.5     ; add extra density
	opt_shd@gsnShadeFillDotSizeF = 0.002   ; make dots larger
	opt_shd@gsnShadeLow      = 17	       ; Stipple
	opt_shd@gsnShadeMid      = 17	       ; Stipple
	opt_shd@gsnShadeHigh     = 17	       ; Stipple
 	opt_shd@gsnDraw          = False       ; Don't Draw it yet
	opt_shd@Frame            = False       ; Don't "Advance Frame"

	stipple1 = gsn_contour_shade(stipple, 6.0, 10.0, opt_shd)   ; Shade it
	overlay(contour, stipple1)                                  ; Add stipple to contour

	draw(contour)

	; See http://www.ncl.ucar.edu/Support/talk_archives/2006/0750.html
	; for a not-very-obvious descripion of this twiddle
	NhlChangeWorkstation(bg, wks_temp)
	draw(bg)
	NhlChangeWorkstation(bg, wks)
	frame(wks_temp)
	if(isvar("wks_tmp")) then
		delete(wks_temp)        ; Close the file
	end if

	doHeader(plot_param, opts_bparam@MainTitle, Region, gridspacingkm, FMT, tail)
	if( isatt(opts_bparam, "colorMap") ) then
		opts_1@colorMap = opts_bparam@colorMap;
	end if
	doLabelBar(plot_param, tail, opts_1, FMT, opts_bparam@unitString, fixedcolor)

	if(Projection .ne. "lambert") then
		; cmd = CONVERT + " -transparent white -trim " + fName + ".png png32:" + fName + ".png"
		cmd = CONVERT + " -trim " + fName + ".png png32:" + fName + ".png"
		print("    " + cmd)
		system(cmd)
	else
		fName = OutDir + plot_param + tail
		cmd = "montage -tile x3 -geometry +0+0 " + fName + ".head.png " + fName + ".body.png " + fName + ".foot.png " + fName + ".png";
		print("    " + cmd)
		system(cmd)
	end if

	return(ldatafmt)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLOT VERTICAL SECTION
;;; Vertical velocity (W) indicated by colour-filled contours
;;; Potential temp (thetac == default or RH) indicated by contour lines (selectable in rasp.site_load.xbl.ncl)
;;; Cloud (cldfra) by stipple

procedure plot_section(plot_param, tail, wa, thetac, rh, z, ter, cldfra, dx, x, y, ang, alat, alon)
local opts_plot
begin

	opts_w      = True
	opts_rh     = True
	opts_thetac = True
	opts_cld    = True
	opts_var    = True

	lat = alat(y,x)
	lon = alon(y,x)

	if(do_plots .eq. False) then
		return
	end if

	span = 30  ; Span (Km) (+ve & -ve) of X-Section - Reduced if exceeds bounds
	contourLines = "thetac"	; default - can be overridden by "load" below

	if(FMT .eq. "png") then
		fName = OutDir + plot_param + tail
		wks_xbl = create fName imageWorkstationClass defaultapp
			"wkFormat"          : "newpng"
			"wkHeight"          : wkHeight
			"wkWidth"           : wkWidth
			"wkBackgroundColor" : "white"
			"wkForegroundColor" : "black"
			"wkColorMap"        : "BlAqGrYeOrReVi200"
		end create
        end if
	if(FMT .eq. "x11") then
		wks_xbl = create "section" xWorkstationClass defaultapp
		"wkHeight" : wkHeight
		"wkWidth"  : wkWidth
		"wkBackgroundColor" : "white"
		"wkForegroundColor" : "black"
		"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
		end create
	end if

	plane = new(2, float)
	plane = (/x, y/)	; horizontal point section is to pass through

	;;; Adjust span for angles near 45 deg, when d is ~1.4x greater
	;   This is going to be difficult
	;   as dx varies over N-S and E-W due to reprojection
	;   and wind angle is wrt N-S (i.e. the map)
	;   and not wrt grid axes
	;   For now, settle for d = dx :-)
	d = dx

	span_x = floattointeger((span * 1000) / d)   ; # points for specified span (+ and -)

	; Determine the location of x,y point in interpolated data
	dummy = new(dimsizes(wa), float)
	dummy = 0.0
	dummy(20,y,x) = 100.0
	dummy_plane           = wrf_user_intrp3d(dummy , z, ter, "v", plane, ang)
	max_dummy = max(dummy_plane)
	S = dimsizes(dummy_plane)
	do xx = 0,S(1)-1
	    do yy = 0,S(0)-1
		if(.not. ismissing(dummy_plane(yy,xx)) \
		   .and. dummy_plane(yy,xx) .eq. max_dummy)
			xpos = xx
		end if
	    end do	
	end do
	
print("span_x = " + span_x)

print("S = " + S)
	if(xpos .lt. span_x)
		span_x = xpos
	end if
	if(xpos + span_x .ge. S(1)-1)
		span_x = S(1)-1-xpos
	end if

	xmin = xpos - span_x
	xmax = xpos + span_x
print("span_x = " + span_x)
print("xmin = " + xmin + " xmax = " + xmax)

	x_min = x-span_x
	x_max = x+span_x

	w_plane               = wrf_user_intrp3d(wa,     z, ter, "v", plane, ang)
	c_plane               = wrf_user_intrp3d(cldfra, z, ter, "v", plane, ang)
	if(UNITS .ne. "metric") then
		opts_w@UnitLabel      = "Vertical Velocity [ft/min]"
		opts_w@tiYAxisString  = "Height [Kft MSL]" ; Label for the Y axis
		blsectionztop         = 18.   ; Kft; May be overridden in rasp.site_load.xbl.ncl
		minZ                  = 0.0032808 * min(z) ; in kFT !
		maxZ                  = 0.0032808 * max(z) ; in kFT !
		w_plane               = 196.85039 * w_plane
		print( "    BL CROSS-SECTION: Vertical Velocity [ft/min] MIN,MAX= "+min(w_plane)+"  "+max(w_plane) )
	else
		opts_w@UnitLabel      = "Vertical Velocity [cm/s]"
		opts_w@tiYAxisString  = "Height [km MSL]" ; Label for the Y axis
		blsectionztop         = 6.   ; Km; May be overridden in rasp.site_load.xbl.ncl
		minZ                  = 0.001 * min(z) ; in KM !
		maxZ                  = 0.001* max(z) ; in KM !
		w_plane               = 100 * w_plane
		print( "    BL CROSS-SECTION: W [cm/s] MIN,MAX= "+min(w_plane)+"  "+max(w_plane) )
	end if
	opts_w@tiXAxisString  = "Distance [km]"   ; Label for the X axis

	load "rasp.site_load.xbl.ncl"
	var = contourLines
	load "opts_xbl.ncl"

	if(var .eq. "rh") then
		v_dummy = rh
		msg = "                      RH [%] MIN,MAX= "
	else
		v_dummy = thetac
		msg = "                      Theta [C] MIN,MAX= "
	end if
	var_plane = wrf_user_intrp3d(v_dummy, z, ter, "v", plane, ang)
	print(msg +min(var_plane)+"  "+max(var_plane))

	if( isatt(opts_w, "ExplicitLevels") ) then	; ExplicitLevels overrides ContourParameters
		opts = True
		opts@cnLevelSelectionMode = "ExplicitLevels"
		opts@cnLevels = opts_bparam@ExplicitLevels
		delete(levels)
		levels = opts@cnLevels
	end if
	if( isatt(opts_w, "colorMap") ) then
		gsn_define_colormap( wks_xbl, opts_w@colorMap );
	end if

	w_plane@_MinX    = -span_x * d / 1000 ; m -> km
	w_plane@_MaxX    =  span_x * d / 1000
	w_plane@_MinY    = minZ
	w_plane@_MaxY    = maxZ
	var_plane@_MinX  = w_plane@_MinX
	var_plane@_MaxX  = w_plane@_MaxX
	var_plane@_MinY  = w_plane@_MinY
	var_plane@_MaxY  = w_plane@_MaxY
	c_plane@_MinX    = w_plane@_MinX
	c_plane@_MaxX    = w_plane@_MaxX
	c_plane@_MinY    = w_plane@_MinY
	c_plane@_MaxY    = w_plane@_MaxY


	opts_w@trXMinF   = w_plane@_MinX
	opts_w@trXMaxF   = w_plane@_MaxX
	opts_w@trYMinF   = 0.
	opts_w@trYMaxF   = blsectionztop

	opts_cld@trYMinF = 0.
	opts_cld@trYMaxF = blsectionztop

	opts_var@trYMinF = 0.
	opts_var@trYMaxF = blsectionztop
	; Fix height of line-label numbers
	opts_var@cnLineLabelFontHeightF = 0.0005

	if(isatt(w_plane, "description")) then
		delete_VarAtts(w_plane, "description")
	end if

	mainvpwidth = 0.9
	mainvpheight = 0.70
	mainvpx = (1. - mainvpwidth) / 2.
	mainvpy = 0.85

	contour_w   = wrf_new_fill_contour( wks_xbl, w_plane(:,xmin:xmax), opts_w,   \
	                                    mainvpx,mainvpy,mainvpwidth,mainvpheight )

	contour_var = wrf_new_line_contour( wks_xbl, var_plane(:,xmin:xmax), opts_var, \
	                                    mainvpx,mainvpy,mainvpwidth,mainvpheight )

	stipple     = wrf_new_fill_contour( wks_xbl, c_plane(:,xmin:xmax), opts_cld, \
	                                    mainvpx,mainvpy,mainvpwidth,mainvpheight )

	; Overlay the fields on the background
	overlay(contour_w,contour_var)
	overlay(contour_w, stipple)

	; Add Markers to indicate location
	xM = 0.
	opts_M                    = True
	opts_M@gsMarkerIndex      = 7                        ; bottom marker style (triangle)
	opts_M@gsMarkerSizeF      = 20.                      ; marker size
	opts_M@gsMarkerColor      = "red"                    ; marker color
	opts_M@gsMarkerThicknessF = 5.                       ; marker line thickness
	yM                        = 0.35
	val = gsn_add_polymarker(wks_xbl, contour_w, xM, yM, opts_M); Add the bottom marker

	opts_M@gsMarkerIndex      = 8                        ; polymarker style (inverted triangle)
	yM                        = blsectionztop - 0.35
	val1 = gsn_add_polymarker(wks_xbl, contour_w, xM, yM, opts_M); Add the top marker


	;;; FINALLY, Show it
	draw(contour_w)
	frame(wks_xbl)

	; Remove the dummy stuff
	delete(wks_xbl)
	delete(contour_var)
	delete(contour_w)
	delete(var_plane)
	delete(w_plane)
	delete(opts_w)
	delete(opts_cld)
	delete(opts_var)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PLOT CONTOUR with STREAMLINES
;;; Magnitude indicated by Colour
;;; Direction indicated by Streamline

function plot_streamline(wks, bg, u, v, mag, plot_param, tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
local opts_plot
begin

	delete_VarAtts(u, -1)
	delete_VarAtts(v, -1)
	delete_VarAtts(mag, -1)

	u@lat2d = alat
	u@lon2d = alon
	v@lat2d = alat
	v@lon2d = alon
	mag@lat2d = alat
	mag@lon2d = alon

	opts_plot = True
	copy_VarAtts(opts_cn, opts_plot)

        fName = OutDir + plot_param + tail + ".body"
        wks_temp = create fName imageWorkstationClass defaultapp
                "wkFormat"             : "newpng"
                "wkHeight"             : wkHeight
                "wkWidth"              : wkWidth
		"wkBackgroundColor"    : "white"
		"wkBackgroundOpacityF" : 0.0
                "wkForegroundColor"    : "black"
                "wkColorMap"           : "BlAqGrYeOrReVi200"
        end create

	load "opts_ws.ncl"      ;;;; Options for WindSpeed

        ;;; FOR SITE SUBSTITUTIONS
	opts_ws = True
        load "rasp.site_load.wind.ncl" ; Has opts_ws@ContourParameters = (...)

	if(do_plots .eq. False) then
		return(ldatafmt)
	end if

        fixedcolor = 0
        if( isatt(opts_bparam, "ContourParameters")) then
                levels = opts_bparam@ContourParameters
        end if  
        if( isatt(opts_ws, "ContourParameters")) then
                levels = opts_ws@ContourParameters
        end if  
	if( isatt(opts_ws, "colorMap") ) then
		gsn_define_colormap( wks_temp, opts_ws@colorMap );
	end if
	if(isvar("levels")) then
		if(levels(1) .gt. levels(0)) then       ;  Min, Max & Intvl specified
			fixedcolor = 1
		end if
	else
		levels = 0				; Flag to indicate Not Specified
	end if


	; New vars to avoid changing originals
	mag4plot = mag * opts_bparam@mult
	u4plot = u * opts_bparam@mult
	v4plot = v * opts_bparam@mult
	copy_VarAtts(mag, mag4plot)
	copy_VarAtts(u, u4plot)
	copy_VarAtts(v, v4plot)

	mn = min(mag4plot)
	mx = max(mag4plot)

        print("    plot_streamline: " + plot_param + " MIN,MAX = " + mn + " " + mx)
	opts = doColorLevels(wks_temp, levels, mn, mx)
	if(opts .eq. False) then
		return(ldatafmt)
	end if

	copy_VarAtts(opts, opts_plot)

        copy_VarAtts(opts_bg, opts_plot)
        opts_plot@mpOutlineOn         = False

	plot = gsn_csm_contour_map(wks_temp, mag4plot, opts_plot) ; Do it!
	plot_st = gsn_csm_streamline(wks_temp, u4plot, v4plot, opts_st) ; Do it!
	overlay(plot, plot_st)
	draw(plot)

	; See http://www.ncl.ucar.edu/Support/talk_archives/2006/0750.html
	; for a not-very-obvious descripion of this twiddle
	NhlChangeWorkstation(bg, wks_temp)
	draw(bg)
	NhlChangeWorkstation(bg, wks)
	frame(wks_temp)
	if(isvar("wks_temp")) then
		delete(wks_temp)        ; Close the file
	end if

	doHeader(plot_param, opts_bparam@MainTitle, Region, gridspacingkm, FMT, tail)
	if( isatt(opts_ws, "colorMap") ) then
		opts@colorMap = opts_ws@colorMap;
	end if
	doLabelBar(plot_param, tail, opts, FMT, opts_bparam@unitString, fixedcolor)

	if(Projection .ne. "lambert") then
		; cmd = CONVERT + " -transparent white -trim " + fName + ".png png32:" + fName + ".png"
		cmd = CONVERT + " -trim " + fName + ".png png32:" + fName + ".png"
		print("    " + cmd)
		system(cmd)
	else
		fName = OutDir + plot_param + tail
		cmd = "montage -tile x3 -geometry +0+0 " + fName + ".head.png " + fName + ".body.png " + fName + ".foot.png " + fName + ".png";
		print("    " + cmd)
		system(cmd)
	end if

	return(ldatafmt)
end

;;;;;;;;;;;;;;;;; WRITE OUT DATAFILE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	No datafile if "_" or "mask" in param name
;	Here: No bparam         => No datafile
;	      No ENV_NCL_DATIME => No datafile
;	Requires ENV_NCL_DATIME

procedure write_datafile(param, bparam, opts_bparam, ldatafmt)
begin
	qdatimeinfo = getenv("ENV_NCL_DATIME")
	if(ismissing(qdatimeinfo)) then
		return	; Skip writing datafile
	end if

	unit = opts_bparam@unitString

	qdatatitle = str_sub_str(                                      \
		       str_sub_str(                                    \
		       opts_bparam@MainTitle + " [" + unit + "] " +      \
		       getenv("ENV_NCL_ID"), "~I~", "" ) , "~P~", "" )

	qgridinfo = "Model= RASP Region= " + Region                                                   \
		    + " Grid= " + domainid + " Reskm= "  + bparam@gridspacingkm                       \
		    + " Indexs=" + " 1 "  + sprinti("%i", bparam@nx) + " 1 "+sprinti("%i", bparam@ny) \
		    + " Proj= lambert" + sprintf(" %.0f", bparam@dx) + sprintf(" %.0f", bparam@dy)    \
		    + sprintf(" %.4f", bparam@projlat1) + sprintf(" %.4f", bparam@projlat2)           \
		    + sprintf(" %.4f", bparam@projlon) + sprintf(" %.4f", bparam@centerlat)           \
	            + sprintf(" %.4f", bparam@centerlon)

	; Write out spd & direction datafile for *wind* - i.e. if udata & vdata exist
	; Note that this includes pressNNN and windNNN
	if( isatt(bparam, "udata") .and. isatt(bparam, "vdata")) then
		qdatatitle = opts_bparam@MainTitle + " Direction [deg] " + getenv("ENV_NCL_ID")
                qparaminfo = "Param= " + param + " Direction Unit= " + unit + " Mult= 1"

		if(bparam@plot_param_chars(0:4) .eq. "press") then
			qdatafile = OutDir + param + "wdir" + bparam@tail + ".data"
		else
			qdatafile = OutDir + param + "dir" + bparam@tail + ".data"
		end if

		Wdir = 180.0 + rad2deg * atan2(bparam@udata, bparam@vdata)
		output_mapdatafile( qdatafile,          \
				qdatatitle,             \
				qgridinfo,              \
				qdatimeinfo+qparaminfo, \
				Wdir,                   \
				bparam@nx, bparam@ny,   \
				ldatafmt )
		if(isvar("Wdir")) then
			delete(Wdir)
		end if

		if(bparam@plot_param_chars(0:4) .eq. "press") then
			qdatafile = OutDir + param + "wspd" + bparam@tail + ".data"
		else
			qdatafile = OutDir + param + "spd" + bparam@tail +".data"
		end if

		press_wspd = sqrt(bparam@udata * bparam@udata + bparam@vdata * bparam@vdata)
		if(UNITS .ne. "metric") then
			qdatatitle = opts_bparam@MainTitle + " Speed [kt] " + getenv("ENV_NCL_ID")
			qparaminfo = "Param= " + param + " Speed Unit= kt Mult= 1"
			press_wspd = press_wspd * 1.9438445
		else
			qdatatitle = opts_bparam@MainTitle + " Speed [m/sec] " + getenv("ENV_NCL_ID")
			qparaminfo = "Param= " + param + "Speed Unit= m/s Mult= 1"
		end if
		output_mapdatafile( qdatafile,              \
				    qdatatitle,             \
				    qgridinfo,              \
				    qdatimeinfo+qparaminfo, \
				    press_wspd,             \
				    bparam@nx, bparam@ny,   \
				    ldatafmt )
		if(isvar("press_wspd")) then
			delete(press_wspd)
		end if
		if(bparam@plot_param_chars(0:4) .ne. "press") then
			;print(" ")	; CR!
			return
		end if
	end if

	; Write out datafile for all the others - includes pressNNN
	qdatafile = OutDir + param + bparam@tail + ".data"
	qparaminfo = "Param= " + param + " Unit= " + unit + " Mult= 1"
	output_mapdatafile( qdatafile,                \
			    qdatatitle,               \
			    qgridinfo,                \
			    qdatimeinfo+qparaminfo,   \
			    bparam * opts_bparam@mult,\
			    bparam@nx, bparam@ny,     \
			    ldatafmt )

	;print(" ")	; CR!
end
;;;;;;;;;;;;;;;;; END WRITE OUT DATAFILE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;; PLOT PARAMETERS SPECIFIED IN "PARAMS" ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure plot_parameters(filename, params, info)
local plot_param_chars
begin

	;*******************************************
	; Open File and plot data
	;*******************************************

	f = addfile( filename, "r" )
	i2  = str_index_of_substr(filename, "wrfout", -1)
	currtest1 = substring(filename, i2-3, i2-3)
	currtest2 = substring(filename, i2-2, i2-2)
	if ( (currtest1 .eq. "+") .and. (stringtoint(currtest2)) ) then
		currvalue = ".curr+" + currtest2 + "."
	else
		currvalue = ".curr."
	end if
	i3 = str_index_of_substr(filename, "WINDOW", -1)
	if ( .not. ismissing( i3 )) then
		tailstr = "w2"
	else
		i3 = str_index_of_substr(filename, "d1", -1)
		if ( .not. ismissing( i3 )) then
			tailstr = "d1"
		else
			tailstr = "d2"
		end if
	end if

	gmthr = new(1, float)
	jday  = new(1, integer)
	getfiledate(filename, jday, gmthr, domainid)
	; Set local time for o/p filenames
	ENV_NCL_ID = getenv("ENV_NCL_ID")
	if ( .not. ismissing(ENV_NCL_ID) ) then
		hour = str_split(ENV_NCL_ID, " ")
		local_hr = hour(1)
		if( ismissing(curr_only) .or. curr_only .eq. "0" ) then
			tail = currvalue + local_hr + "lst." + tailstr   ;; USE THIS IF YOU HAVE "curr+N."
		else
			tail = ".curr."  + local_hr + "lst." + tailstr   ;; USE THIS IF YOU USE ONLY "curr."
		end if
	else
		local_offset = stringtofloat(systemfunc("date +%z"))
		hr = gmthr + (local_offset/100)
		if (hr .lt. 0 ) then
			hr = hr + 24
		end if
		if(hr .gt. 24) then
			hr = hr - 24
		end if
		local_hr = sprintf("%02.0f", hr) + sprintf("%02.0f", (hr - floor(hr))*60)
		print("using date string ")
		print("gmthr = " + gmthr+ " local_hr = " + local_hr + " local_offset = " + local_offset)
		tail = ".curr." + sprintf("%02.0f", gmthr) + sprintf("%02.0f", (gmthr - floor(gmthr)) * 60) + "lst." + tailstr
	end if

	; Do Plots ONLY on the Hour
	; Always make data files
	local_mins = str_split_by_length(local_hr, 2)
	do_plots = True ; Default is to do plots
;	if(local_mins(1) .ne. "00") then
;		print("*** Data Files only - Time == " + local_hr + "!!")
;		do_plots = False
;	end if

	load "getvars.ncl"	; Inline code, so variables are local => discarded on exit from procedure
				; New wrfout file will reload

	load "opts_bg.ncl"	; Plotting options for Background Map
        load "opts_cn.ncl"	; Contour Options

        ;;; SET (RE-)PROJECTION INFO
	if(ismissing(Projection)) then
		print("*** WARNING - No Projection specified - Using Mercator ***")
		Projection = "mercator"
	end if
		
        if(Projection .eq. "mercator" ) then
	        lon_min = min(alon)
                lon_max = max(alon)
                lon_ctr = (lon_min + lon_max) / 2.0
                lat_min = min(alat)
                lat_max = max(alat)
                lat_ctr = (lat_min + lat_max) / 2.0

		print("")
		print("*** Add this to corners.js")
		print("    corners.Bounds[" + sprintf("%.0f", gridspacing / 1000.) + "] = new google.maps.LatLngBounds(")
		print("        new google.maps.LatLng(" + sprintf("%.7f", lat_min) + ", " + sprintf("%.7f", lon_min) + "), // SW")
		print("        new google.maps.LatLng(" + sprintf("%.7f", lat_max) + ", " + sprintf("%.7f", lon_max) + ")  // NE")
		print("    );")
		print("    corners.Centre[" +  sprintf("%0.f", gridspacing / 1000.) + \
		  "] = new google.maps.LatLng(" + sprintf("%.7f", lat_ctr) + ", " + sprintf("%.7f", lon_ctr) + ");")

                print("")
                print("*** Latitude Data:")
                print("    min=" + sprintf("%.7f", lat_min) + " max=" + sprintf("%.7f", lat_max) + " ctr=" + sprintf("%.7f", lat_ctr))
                print("*** Longitude Data:")
                print("    min=" + sprintf("%.7f", lon_min) + " max=" + sprintf("%.7f", lon_max) + " ctr=" + sprintf("%.7f", lon_ctr))
                print("")

                opts_bg@mpProjection        = "Mercator"
                opts_bg@mpLimitMode         = "Corners"             ; Set extent of map
                opts_bg@mpLeftCornerLatF    = lat_min
                opts_bg@mpLeftCornerLonF    = lon_min
                opts_bg@mpRightCornerLatF   = lat_max
                opts_bg@mpRightCornerLonF   = lon_max
        else
                if(Projection .eq. "lambert" ) then
                        opts_bg@mpProjection        = "LambertConformal"
                        opts_bg@mpLimitMode         = "Corners"             ; Set extent of map
                        opts_bg@mpLambertParallel1F = projlat1
                        opts_bg@mpLambertParallel2F = projlat2
                        opts_bg@mpLambertMeridianF  = projlon
                        opts_bg@mpLeftCornerLatF    = alat(0,0)
                        opts_bg@mpLeftCornerLonF    = alon(0,0)
                        opts_bg@mpRightCornerLatF   = alat(ny-1,nx-1)
                        opts_bg@mpRightCornerLonF   = alon(ny-1,nx-1)
                else
                        print(Projection + " Projection not implemented")
                        exit
                end if
        end if

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Build the Background - If you want contours, See wrf2gm.ncl
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	print("*** Making Background")
        print("    Width = " + wkWidth + " Height = " + wkHeight)
	if(FMT .eq. "png") then
		wks = create "BG" imageWorkstationClass defaultapp
			"wkFormat" : "newpng"
			"wkHeight" : wkHeight
			"wkWidth"  : wkWidth
			"wkBackgroundColor" : "white"
			"wkForegroundColor" : "black"
			"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
		end create
	else
		if(FMT .eq. "x11") then
			wks = create "BG" xWorkstationClass defaultapp
				"wkHeight" : wkHeight
				"wkWidth"  : wkWidth
				"wkBackgroundColor" : "white"
				"wkForegroundColor" : "black"
				"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
			end create
		end if
		if(FMT .eq. "ncgm") then
			wks = create "BG" ncgmWorkstationClass defaultapp
				"wkHeight" : wkHeight
				"wkWidth"  : wkWidth
				"wkBackgroundColor" : "white"
				"wkForegroundColor" : "black"
				"wkColorMap"        : "BlAqGrYeOrReVi200"      ; probably best by DrJack
			end create
		end if
	end if

	;;; INCREASE WORKSPACE SIZE ABOVE DEFAULTS
	; See http://www.ncl.ucar.edu/Document/Graphics/Resources/ws.shtml
	setvalues NhlGetWorkspaceObjectId()
		; "wsMaximumSize":	1073741824	; 1.0 GiB   (0x40000000) WORKSTATIONSPACE     
		; "wsThresholdSize":	 536870912	; 0.5 GiB   (0x20000000) WORKSTATIONTHRESHOLD
		; "wsMaximumSize":	 536870912	; 0.5 GiB   (0x20000000) WORKSTATIONSPACE     
		; "wsThresholdSize":	 268435456 	; 0.25GiB   (0x10000000) WORKSTATIONTHRESHOLD
		; "wsMaximumSize":	 268435456 	; 0.25GiB   (0x10000000) WORKSTATIONSPACE     
		; "wsThresholdSize":	 134217728	; 0.125GiB  (0x08000000) WORKSTATIONTHRESHOLD
		"wsMaximumSize":	 134217728	; 0.125GiB  (0x08000000) WORKSTATIONSPACE     
		; "wsThresholdSize":	 134217728	; 0.0625GiB (0x04000000) WORKSTATIONTHRESHOLD
	end setvalues

	bg = gsn_csm_map(wks, opts_bg)                 ; Makes a Blank Map, with Coastline

	; Make opts_ter and opts_ter both "true" in wrf2gm.ncl if you want terrain contours
	if(isatt(opts_ter, "cnLinesOn") .and. opts_ter@cnLinesOn .eq. True) then
		opts_ter@cnLineDrawOrder = "PostDraw"
		opts_ter@gsnDraw         = False
		opts_ter@gsnFrame        = False

		bg_ter                   = ter
		bg_ter@lat2d             = alat
		bg_ter@lon2d             = alon

		if(UNITS .ne. "metric") then
			bg_ter = 3.28084 * ter
			opts_ter@cnLevelSpacingF = 500.
			opts_ter@cnMinLevelValF  = opts_ter@cnLevelSpacingF
		else
			opts_ter@cnMinLevelValF  = 200.
			opts_ter@cnMinLevelValF  = opts_ter@cnLevelSpacingF
		end if

		plot_ter = gsn_csm_contour(wks, bg_ter, opts_ter)
		overlay(bg, plot_ter)
	end if

	borderRet = addBorder(wks, bg, alat, alon)           ; borderRet not used, but keeps return value
	print("*** Done")
	print("") ; CR

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; create plots
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	mag = new ( (/ny, nx/), float)
	mag@lat2d = alat
	mag@lon2d = alon

	u = new ( (/ny, nx/), float)
	v = new ( (/ny, nx/), float)

	; Parameters for all params - Used for datafile write
	atts = True
	atts@nx = nx
	atts@ny = ny
	atts@dx = dx
	atts@dy = dy
	atts@projlat1 = projlat1
	atts@projlat2 = projlat2
	atts@projlon = projlon
	atts@centerlat = centerlat
	atts@centerlon = centerlon
	atts@tail = tail
	atts@gridspacingkm = gridspacingkm

	if(isvar("start_time")) then
		delete(start_time)
	end if
	do p = 0, dimsizes(params)-1

		if(isvar("start_time")) then
			;; Print out Time to Plot
			end_time = systemfunc("date +%s")
			duration = stringtoint(end_time) - stringtoint(start_time)
			print("    Parameter " + params(p-1) + " took " + duration / 60 + ":" + duration % 60 + " mins")
			print(" ")	; CR!
		end if
		if( p .ge. dimsizes(params)) then
			break
		end if 

		start_time = systemfunc("date +%s")

; PFD_TOT
		if(params(p) .eq. "pfd_tot") then
			continue
		end if

		print("*** Doing parameter: " + params(p) + " at " + systemfunc("date"))

		if(isvar("plot_param_chars")) then
			delete(plot_param_chars)
		end if
		plot_param_chars = stringtocharacter(params(p))

		; Ensure no leftovers
		if(isvar("bparam")) then
			delete(bparam)
		end if

		if(isatt(atts, "plot_param_chars")) then
			delete(atts@plot_param_chars)
		end if
		atts@plot_param_chars = plot_param_chars

		if(isvar("opts_bparam")) then
			delete(opts_bparam)
		end if
		opts_bparam = True
		opts_bparam@mult = 1.0	; Default value; overidden as required
		ldatafmt = 0		; Overridden as required

; SOUNDING
		if( dimsizes(plot_param_chars) .gt. 9 .and. plot_param_chars(0:7) .eq. "sounding") then
			if(do_plots .eq. False) then
				continue
			end if

			;;; determine sounding number
			char_str = chartostring( plot_param_chars(8:) )
			if( plot_param_chars(8:8) .ne. "0" ) then
				snum = stringtointeger( char_str )
			else
				;;; treat special case with input lat,lon = sounding0_id_lat_lon
				snum = 0
				param_array = str_split( params(p),"_" )
				info@sounding_ids(0) = param_array(1)
				info@sounding_lats(0) = stringtofloat(param_array(2))
				info@sounding_lons(0) = stringtofloat(param_array(3))
				locr = wrf_user_find_ij_lat_long(f, info@sounding_lats(0), info@sounding_lons(0))
				info@i(0) = floattointeger(locr(0))   ; Note 0 based
				info@j(0) = floattointeger(locr(1))
			end if
			;;; check that valid data available
			if( snum .gt. info@nsoundings ) then
				print( "*** SKIPPING SOUNDING *** missing region data for sounding" + snum )
				continue
			end if

			if(info@j(snum) .le. 1 .or. (nx-1) .le. info@j(snum) .or. info@i(snum) .le. 1 .or. (ny-1) .le. info@i(snum) ) then
				print( "* SKIPPING SOUNDING * " + info@sounding_ids(snum)                 \
				       + "lon,lat "+info@sounding_lons(snum)+","+info@sounding_lats(snum) \
				       + " outside domain => I,J=" + info@j(snum) + "," + info@i(snum)    \
				       + " for dims= " + nx + "," + ny )
				continue
			end if

			print("    Sounding #" + snum + ": lat,lon = " + info@sounding_lats(snum) + "," + info@sounding_lons(snum) \
			      + " i,j = " + (info@j(snum)+1) + "/" + nx + "," + (info@i(snum)+1) + "/" + ny)
			ret = plot_sounding(FMT, snum, info, pmb, tc, td, z, uEW, vNS, qcloud, cldfra, psfc, ter, tail)

			continue
		end if

; RAIN
	        if( plot_param_chars(0:3) .eq. "rain" ) then
			acctime = stringtointeger( chartostring( plot_param_chars(4:) ) )
			opts_bparam@ContourParameters = (/0.2, 4.8, 0.2/)
			opts_bparam@MainTitle = sprinti("%d", acctime) + "Hr Accumulated Rain"
			opts_bparam@unitString = "mm"
			if(isvar("acctime")) then
				delete(acctime)
			end if

			ldatafmt = 2
			rain_mag = rain(filename, f, plot_param_chars, nx, ny)
			ldatafmt = plot_contour(wks, bg, rain_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = rain_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; ZBLCL
		if( params(p) .eq. "zblcl" ) then
			opts_bparam@MainTitle = "OvercastDevelopment Cloudbase ~I~(BL CL)~P~"
			if(UNITS .ne. "metric") then
				opts_bparam@ContourParameters = (/0., 0., 500. /)
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
			else
				opts_bparam@unitString = "m"
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
			end if

			zblcl_mag = zblcl( qvapor, z, ter, pblh, pmb, tc, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, zblcl_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = zblcl_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; ZBLCLDIF
		if( params(p) .eq. "zblcldif" ) then
			opts_bparam@MainTitle = "OvercastDevelopment Potential"
			if( UNITS .ne. "metric" ) then
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@ContourParameters = (/ 0.,0., 500. /)
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				 qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				; No default in rasp.bparam_resources.ncl!!
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("zblcl_mag")) then
				print("    zblcldif: doing zblcl")
				zblcl_mag = zblcl( qvapor, z, ter, pblh, pmb, tc, nx, ny, nz)
			end if
			zblcldif_mag = zblcldif(ter, pblh, zblcl_mag)
			ldatafmt = plot_contour(wks, bg, zblcldif_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = zblcldif_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; ZBLCLMASK
		if( params(p) .eq. "zblclmask" ) then
			opts_bparam@MainTitle = "OD Cloudbase ~I~where OD Potential > 0~P~"
			if( UNITS .ne. "metric" ) then
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@ContourParameters = (/ 0.,0., 500. /)
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				; No default ContourParameters in rasp.bparam_resources.ncl!!
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("zblcl_mag")) then
				print("    zblclmask: doing zblcl")
				zblcl_mag = zblcl( qvapor, z, ter, pblh, pmb, tc, nx, ny, nz)
			end if
			if( .not. isvar("zblcldif_mag")) then
				print("    zblclmask: doing zblcldif")
				zblcldif_mag = zblcldif(ter, pblh, zblcl_mag)
			end if
			zblcl_mask = mask(zblcl_mag, (zblcldif_mag .ge. 0), True)
			ldatafmt = plot_contour(wks, bg, zblcl_mask, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
;Hieronder toegevoegd als test
			bparam = zblcl_mask
			copy_VarAtts(atts, bparam)
			bparam@_FillValue = -999999
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)
;Hierboven toegevoegd als test
			continue
		end if

; XBL
		if(plot_param_chars(0:2) .eq. "xbl") then
			xfield = extract_string_field(params(p), 2, "_")
			yfield = extract_string_field(params(p), 3, "_")
			anglefield = extract_string_field(params(p), 4, "_")

			if(xfield .eq. "" .or. yfield .eq. "") then
				print("Error: No lat-lon/x-y specified for xbl; No plot possible!")
				continue
			end if

			if( string_pattern_grep(xfield,".").gt.0 \
			    .and. string_pattern_grep(yfield,".").gt.0 ) then          		; Lon / Lat
				xfloat   = stringtofloat(xfield)
				yfloat   = stringtofloat(yfield)
				locn = wrf_user_find_ij_lat_long(f, yfloat, xfloat)		; 0 based => +1
				xsection := floattointeger(locn(1)+1)				; Note ":=" operator requires NCL >= V6.1.2
				ysection := floattointeger(locn(0)+1)
                        else
				xsection = stringtointeger(xfield)				; x & y indices
				ysection = stringtointeger(yfield)
			end if

			; Sane?
			if(xsection .le. 0 .or. xsection .gt. nx .or. \
			   ysection .le. 0 .or. ysection .gt. ny)     then
				print("Error: xbl locn ("+xsection+","+ysection+") outside map area")
				continue
			end if

			if(anglefield .ne. "") then		; Note we use meteorological wind direction here
				if(anglefield .eq. "windk")						; Windk
					windk = stringtointeger(extract_string_field(params(p), 5, "_"))
					angle = atan2(uEW(windk,ysection,xsection), vNS(windk,ysection,xsection)) * rad2deg + 180.
				else
					ang_chars = stringtochar(anglefield)
					if(sizeof(ang_chars) .gt. 6 .and. ang_chars(0:4) .eq. "press") ; ang_chars has terminating NULL
						pressure = stringtofloat(charactertostring(ang_chars(5:)))
						u_wind = wrf_user_intrp3d(uEW, pmb, ter, "h", pressure, 0.)
						v_wind = wrf_user_intrp3d(vNS, pmb, ter, "h", pressure, 0.)
						angle = atan2(u_wind(ysection, xsection), v_wind(ysection, xsection)) * rad2deg + 180.
					else
						angle = stringtofloat(anglefield)
					end if
					delete(ang_chars)
				end if
			else
				print("Error: No angle specified for xbl!")
				continue
			end if

			print("    XBL at "+xsection+","+ysection+" angle="+angle \
			      + " lat,lon = " + alon(ysection, xsection) + "," + alat(ysection,xsection)) 

			; Save location so line is drawn on pressure level plots (like boxwmax)
			imaxw = xsection	; Note angle is done
			jmaxw = ysection	; kmaxw is not required

			plot_section(params(p), tail, wa, thetac, rh, z, ter, cldfra, dx,\
			             xsection, ysection, angle,  \
			             alat, alon)

			continue
		end if

; BOXWMAX
		if(params(p) .eq. "boxwmax") then
			boxframe = 10
			boximin = boxframe
			boximax = nx-boxframe
			boxjmin = boxframe
			boxjmax = ny-boxframe
			boxkmin = 5
			boxkmax = nz-2

			wmax  = new( 1, float)
			find_boxmax3d( wa,               \
			               boximin,boximax, \
			               boxjmin,boxjmax, \
			               boxkmin,boxkmax, \
			               nx,ny,nz,        \
			               wmax,imaxw,jmaxw,kmaxw )
			; NB: meteorological wind direction angle
			angle = 45.0 * atan2(uEW(kmaxw,jmaxw,imaxw), vNS(kmaxw,jmaxw,imaxw)) / atan(1.0) + 180.

			; Only needed for printout
			latmaxw = sprintf ( "%.2f", alat(jmaxw,imaxw) )
			lonmaxw = sprintf ( "%.2f", alon(jmaxw,imaxw) )
			zmaxw = floattointeger( z(kmaxw,jmaxw,imaxw) )

			print("    boxwmax@" + lonmaxw + "," + latmaxw     + \
			           "(i=" + imaxw + "/" + nx + ",j=" + jmaxw + "/" + ny + ",k=" + kmaxw + "/" + nz + \
                                   ") angle: " + angle                     + \
			           " val = " + wa(kmaxw,jmaxw,imaxw))
			plot_section(params(p), tail, wa, thetac, rh, z, ter, cldfra, dx,\
			             imaxw, jmaxw, angle,   \
			             alat, alon)

			continue
		end if

; ZSFCLCL
		if( params(p) .eq. "zsfclcl" ) then
			opts_bparam@MainTitle = "Cu Cloudbase ~I~(Sfc. LCL)~P~"
			if( UNITS .ne. "metric") then
				opts_bparam@ContourParameters = (/ 0.,0., 500. /) ; Lge value to reduce plot time
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				; No default in rasp.bparam_resources.ncl!!
				opts_bparam@unitString = "m"
			end if

			zsfclcl_mag = zsfclcl(pmb, tc, td, z, ter, pblh, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, zsfclcl_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = zsfclcl_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; ZSFCLCLDIF
		if( params(p) .eq. "zsfclcldif" ) then
			opts_bparam@MainTitle = "Cu Potential"
			if( UNITS .ne. "metric") then
				opts_bparam@ContourParameters = (/ 0.,0., 500. /) ; Lge value to reduce plot time
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				; No default ContourParams in rasp.bparam_resources.ncl!!
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("zsfclcl_mag")) then
				print("    zsfclcldif: doing zsfclcl")
				zsfclcl_mag = zsfclcl(pmb, tc, td, z, ter, pblh, nx, ny, nz)
			end if
			zsfclcldif_mag = zsfclcldif(ter, pblh, zsfclcl_mag)
			ldatafmt = plot_contour(wks, bg, zsfclcldif_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = zsfclcldif_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; ZSFCLCLMASK
		if( params(p) .eq. "zsfclclmask" ) then
			opts_bparam@MainTitle = "Cu Cloudbase ~I~where Cu Potential > 0~P~"
			if( UNITS .ne. "metric") then
				opts_bparam@ContourParameters = (/ 0.,0., 500. /) ; Lge value to reduce plot time
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				; No default in rasp.bparam_resources.ncl!!
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("zsfclcl_mag")) then
				print("    zsfclclmask: doing zsfclcl")
				zsfclcl_mag = zsfclcl(pmb, tc, td, z, ter, pblh, nx, ny, nz)
			end if
			copy_VarAtts(mag, zsfclcl_mag)
			if( .not. isvar("zsfclcldif_mag")) then
				print("    zsfclclmask: doing zsfclcldif")
				zsfclcldif_mag = zsfclcldif(ter, pblh, zsfclcl_mag)
			end if
			copy_VarAtts(mag, zsfclcldif_mag)
			zsfclcl_mask = mask(zsfclcl_mag, (zsfclcldif_mag .ge. 0), True)
			ldatafmt = plot_contour(wks, bg, zsfclcl_mask, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
;Hieronder toegevoegd als test
			bparam = zsfclcl_mask
			copy_VarAtts(atts, bparam)
			bparam@_FillValue = -999999
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)
;Hierboven toegevoegd als test
			continue
		end if

; CLOUDSUCK
		if( params(p) .eq. "cloudsuck" ) then
			cloudsuck_mag = cloudsuck(rqcblten, mu, mub, z, ter, pblh, nx, ny, nz)
			opts_bparam@MainTitle = "Cloud Condensation Equiv Heat"
			opts_bparam@unitString= " "
			ldatafmt = plot_contour(wks, bg, cloudsuck_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = sfcshf_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; ABOVEBLICW
		if( params(p) .eq. "aboveblicw" ) then
			opts_bparam@unitString = "g"
                        opts_bparam@MainTitle = "Integrated Cloud Water Above BL"
			qparaminfo = "Param= "+params(p)+" Unit= g Mult= 1"
			aboveblicw_mag = aboveblicw(qcloud, ppert, pb, z, ter, pblh, nx, ny, nz)
                        ldatafmt = plot_contour(wks, bg, aboveblicw_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = aboveblicw_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
                end if

; SFCSHF
		if( params(p) .eq. "sfcshf" ) then
			opts_bparam@unitString = "W/m~S~2~N~"
			opts_bparam@MainTitle = "Sfc. Heating"
			sfcshf_mag = hfx
			ldatafmt = plot_contour(wks, bg, sfcshf_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = sfcshf_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; HBL
		if( params(p) .eq. "hbl" ) then
			opts_bparam@MainTitle = "Height of BL Top"
			if( UNITS .ne. "metric" ) then
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@ContourParameters = (/0., 0., 500. /)
				opts_bparam@mult = 3.28084 ; ft
				opts_bparam@unitString = "ft"
			else
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				; No default in rasp.bparam_resources.ncl!!
				opts_bparam@unitString = "m"
			end if

			hbl_mag = pblh + ter
			ldatafmt = plot_contour(wks, bg, hbl_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = hbl_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; BLCLOUDPCT
		if( params(p) .eq. "blcloudpct" ) then
			opts_bparam@ContourParameters = (/ 5., 95., 5. /)
			opts_bparam@MainTitle = "BL Cloud Cover"
			qparaminfo = "Param= "+params(p)+" Unit= % Mult= 1"
			opts_bparam@unitString = "%"

			blcldpct_mag = blcloudpct(qvapor, qcloud, tc, pmb, z, ter, pblh, cwbasecriteria, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, blcldpct_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = blcldpct_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; GRIDPTS - Draw Grid Pt locations on blank map
;           Unusable for 2km!
		if( params(p) .eq. "gridpts" ) then
			opts_bparam@MainTitle = "Grid Point Locations"

			fName = OutDir + params(p) + tail + ".body"
			wks_temp = create fName imageWorkstationClass defaultapp
				"wkFormat" : "newpng"
				"wkHeight" : wkHeight
				"wkWidth"  : wkWidth
				"wkBackgroundColor" : (/1.0, 1.0, 1.0 /)  ; white - Transparent
				"wkBackgroundOpacityF" : 0.0
				"wkForegroundColor" : "black"
				"wkColorMap"        : "BlAqGrYeOrReVi200"
			end create

			opts_plot = True
			copy_VarAtts(opts_bg, opts_plot)
			opts_plot@cnInfoLabelOn		= False
			mag = new ( dimsizes(alat), float)
			mag = 0;
			mag(1,1) = 1
			mag@lat2d = alat
			mag@lon2d = alon

			plot = gsn_csm_contour_map(wks_temp, mag, opts_plot)

			pmres = True
			pmres@gsMarkerIndex = 1   ; small dot
			pmres@gsMarkerColor = "red"
			pmres@gsMarkerSizeF = 4.0/1600.0 ; 0.0004
			points = gsn_add_polymarker(wks_temp, plot, alon, alat, pmres)

			draw(plot)
			frame(wks_temp)
			if(isvar("wks_temp")) then
				delete(wks_temp)        ; Close the file
			end if

			continue
		end if

; BLICW
		if( params(p) .eq. "blicw" ) then
			opts_bparam@unitString = "g"
			opts_bparam@MainTitle = "BL Integrated Cloud Water"
			qparaminfo = "Param= "+params(p)+" Unit= g Mult= 1"

			blicw_mag = blicw(qcloud, ppert, pb, psfc, z, pblh, ter, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, blicw_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = blicw_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; BLTOPVARIAB
		if( params(p) .eq. "bltopvariab" ) then
			opts_bparam@MainTitle = "BL Top Uncertainty/Variability ~I~(for +1degC)~P~"
			if( UNITS .ne. "metric" ) then
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@mult = 3.28084
				opts_bparam@ContourParameters = (/0., 0., 500. /)
				opts_bparam@unitString = "ft"
			else
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				opts_bparam@unitString = "m"
			end if

			bltopvariab_mag = bltopvariab(thetac, z, pblh, ter, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, bltopvariab_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = bltopvariab_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; BLWINDSHEAR
		if( params(p) .eq. "blwindshear" ) then
			opts_bparam@MainTitle = "BL Vertical Wind Shear"
			opts_bparam@ContourParameters = (/0., 0., 2. /)
			if(UNITS .ne. "metric") then
				qparaminfo = "Param= "+params(p)+" Unit= kt Mult= 1"
				opts_bparam@mult = 1.9438445
				opts_bparam@unitString = "kt"
			else
				qparaminfo = "Param= "+params(p)+" Unit= m/s Mult= 1"
				opts_bparam@unitString = "cm/sec"
			end if

			blwindshear_mag = blwindshear(ua, va, z, ter, pblh, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, blwindshear_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = blwindshear_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; WSTAR
		if( params(p) .eq. "wstar" ) then
			opts_bparam@ContourParameters = (/ 0.,0., 50. /)
			opts_bparam@MainTitle = "Thermal Updraft Velocity ~I~(W*)~P~"
			if(UNITS .ne. "metric") then
				opts_bparam@mult = 196.85
				opts_bparam@unitString = "ft/min"
				qparaminfo = "Param= "+params(p)+" Unit= ft/min Mult= 1"
			else
				opts_bparam@mult = 100.0
				qparaminfo = "Param= "+params(p)+" Unit= cm/s Mult= 1"
				opts_bparam@unitString = "cm/sec"
			end if

			if( .not. isvar("wstar_mag")) then
				wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc )	; in m/sec
			end if
			ldatafmt = plot_contour(wks, bg, wstar_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = wstar_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; EXPERIMENTAL2 Presently max of CLDFRA within BL
		if( params(p) .eq. "experimental2" ) then
			opts_bparam@ContourParameters = (/ 5., 95., 5. /)
			opts_bparam@MainTitle = "BL Cloud Fraction"
			qparaminfo = "Param= "+params(p)+" Unit= % Mult= 1"
			opts_bparam@unitString = "%"

			experimental2_mag = experimental2(cldfra, z, ter, pblh, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, experimental2_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = experimental2_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; EXPERIMENTAL1 Presently Hlift for 175fpm criteria
		if( params(p) .eq. "experimental1" ) then
			opts_bparam@MainTitle = "H_lift for 175fpm sinkrate"
			if( UNITS .ne. "metric" ) then
				opts_bparam@mult = 3.28084 ; ft
				opts_bparam@ContourParameters = (/ 0.,0., 500. /)
				opts_bparam@unitString = "ft"
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
			else
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("wstar_mag")) then
				print("    experimental1: doing wstar")
				wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc )	; in m/sec
			end if
			experimental1_mag = experimental1(wstar_mag, ter, pblh, nx, ny)
			ldatafmt = plot_contour(wks, bg, experimental1_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = experimental1_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; HWCRIT
		if( params(p) .eq. "hwcrit" ) then
			opts_bparam@MainTitle = "Height of Critical Updraft Strength ~I~(Hcrit)~P~"
			if( UNITS .ne. "metric" ) then
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@mult = 3.28084 ; ft
				opts_bparam@unitString = "ft"
				opts_bparam@ContourParameters = (/0., 0., 500. /)
			else
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				; No default in rasp.bparam_resources.ncl!!
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("hwcrit_mag") )then
				if( .not. isvar("wstar_mag")) then
					print("    hwcrit: doing wstar")
					wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc )	; in m/sec
				end if
				hwcrit_mag = hwcrit(wstar_mag, ter, pblh, nx, ny)
			end if
			ldatafmt = plot_contour(wks, bg, hwcrit_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = hwcrit_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; HGLIDER
		if( params(p) .eq. "hglider" ) then
			opts_bparam@MainTitle = "Thermalling Height"
			if( UNITS .ne. "metric") then
				opts_bparam@ContourParameters = (/ 0.,0., 500. /)
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				; No default in rasp.bparam_resources.ncl!!
				opts_bparam@ContourParameters = (/ 0.,0., 100. /)
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("hglider_mag") ) then
				if( .not. isvar("hwcrit_mag")) then
					if( .not. isvar("wstar_mag")) then
						print("    hglider: doing wstar")
						wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc ) ; in m/sec
					end if
					hwcrit_mag = hwcrit(wstar_mag, ter, pblh, nx, ny)
				end if
				if( .not. isvar("zsfclcl_mag")) then
					print("    hglider: doing zsfclcl")
					zsfclcl_mag = zsfclcl(pmb, tc, td, z, ter, pblh, nx, ny, nz)
				end if
				if( .not. isvar("zblcl_mag")) then
					print("    hglider: doing zblcl")
					zblcl_mag = zblcl( qvapor, z, ter, pblh, pmb, tc, nx, ny, nz)
				end if
				hglider_mag = hglider(hwcrit_mag, zsfclcl_mag, zblcl_mag, nx, ny)
			end if
			ldatafmt = plot_contour(wks, bg, hglider_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = hglider_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; DGLIDER
		if( params(p) .eq. "dglider" ) then
			opts_bparam@MainTitle = "Thermalling Depth"
			if( UNITS .ne. "metric") then
				opts_bparam@ContourParameters = (/ 0.,0., 500. /)
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				; No default in rasp.bparam_resources.ncl!!
				opts_bparam@ContourParameters = (/ 0.,0., 100. /)
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("dglider_mag") ) then
				if( .not. isvar("hwcrit_mag")) then
					if( .not. isvar("wstar_mag")) then
						print("    dglider: doing wstar")
						wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc ) ; in m/sec
					end if
					hwcrit_mag = hwcrit(wstar_mag, ter, pblh, nx, ny)
				end if
				if( .not. isvar("zsfclcl_mag")) then
					print("    dglider: doing zsfclcl")
					zsfclcl_mag = zsfclcl(pmb, tc, td, z, ter, pblh, nx, ny, nz)
				end if
				if( .not. isvar("zblcl_mag")) then
					print("    dglider: doing zblcl")
					zblcl_mag = zblcl( qvapor, z, ter, pblh, pmb, tc, nx, ny, nz)
				end if
				dglider_mag = dglider(hwcrit_mag, zsfclcl_mag, zblcl_mag, ter, nx, ny)
			end if
			ldatafmt = plot_contour(wks, bg, dglider_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = dglider_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; SFCWIND0
		if( params(p) .eq. "sfcwind0" ) then
			opts_bparam@ContourParameters = (/0., 0., 2. /)
			opts_bparam@MainTitle = "Wind at 2m"
			if(UNITS .ne. "metric") then
				opts_bparam@mult = 1.9438445
				opts_bparam@unitString = "kt"
			else
				opts_bparam@unitString = "m/sec"
			end if

			u0 = new ( (/ny, nx/), float)
			v0 = new ( (/ny, nx/), float)
			wind0_mag = new ( (/ny, nx/), float)
			sfcwind0(uEW, vNS, u0, v0, wind0_mag )

			copy_VarAtts(mag, wind0_mag)
			copy_VarAtts(u, u0)
			copy_VarAtts(v, v0)
			ldatafmt = plot_streamline( wks, bg, u0, v0, wind0_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = wind0_mag
			bparam@udata = u0
			bparam@vdata = v0
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; SFCWIND
		if( params(p) .eq. "sfcwind" ) then
			opts_bparam@ContourParameters = (/0., 0., 2. /)
			opts_bparam@MainTitle = "Wind at 10m"
			if(UNITS .ne. "metric") then
				opts_bparam@mult = 1.9438445
				opts_bparam@unitString = "kt"
			else
				opts_bparam@unitString = "m/sec"
			end if

			u1 = new ( (/ny, nx/), float)
			v1 = new ( (/ny, nx/), float)
			wind1_mag = new ( (/ny, nx/), float)
			sfcwind(uEW, vNS, u1, v1, wind1_mag )

			copy_VarAtts(mag, wind1_mag)
			copy_VarAtts(mag, u1)
			copy_VarAtts(mag, v1)
			ldatafmt = plot_streamline( wks, bg, u1, v1, wind1_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = wind1_mag
			bparam@udata = u1
			bparam@vdata = v1
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; SFCWIND2
		if( params(p) .eq. "sfcwind2" ) then
			opts_bparam@ContourParameters = (/0., 0., 2. /)
			opts_bparam@MainTitle = "Wind at 30m"
			if(UNITS .ne. "metric") then
				opts_bparam@mult = 1.9438445
				opts_bparam@unitString = "kt"
			else
				opts_bparam@unitString = "m/sec"
			end if

			u2 = new ( (/ny, nx/), float)
			v2 = new ( (/ny, nx/), float)
			wind2_mag = new ( (/ny, nx/), float)
			sfcwind2(uEW, vNS, u2, v2, wind2_mag )

			copy_VarAtts(mag, wind2_mag)
			copy_VarAtts(mag, u2)
			copy_VarAtts(mag, v2)
			ldatafmt = plot_streamline( wks, bg, u2, v2, wind2_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = wind2_mag
			bparam@udata = u2
			bparam@vdata = v2
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; BLTOPWIND
		if( params(p) .eq. "bltopwind" ) then
			opts_bparam@ContourParameters = (/0., 0., 2. /)
			opts_bparam@MainTitle = "Wind at BL Top"
			if(UNITS .ne. "metric") then
				opts_bparam@mult = 1.9438445
				opts_bparam@unitString = "kt"
			else
				opts_bparam@unitString = "m/sec"
			end if

			ut = new ( (/ny, nx/), float)
			vt = new ( (/ny, nx/), float)
			windt_mag = new ( (/ny, nx/), float)
			bltopwind(uEW, vNS, z, ter, pblh, nx, ny, nz, ut, vt, windt_mag )

			copy_VarAtts(mag, windt_mag)
			copy_VarAtts(mag, ut)
			copy_VarAtts(mag, vt)
			ldatafmt = plot_streamline( wks, bg, ut, vt, windt_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = windt_mag
			bparam@udata = ut
			bparam@vdata = vt
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; BLWIND
		if( params(p) .eq. "blwind" ) then
			opts_bparam@ContourParameters = (/0., 0., 2. /)
			opts_bparam@MainTitle = "BL Avg Wind"
			if(UNITS .ne. "metric") then
				opts_bparam@mult = 1.9438445
				opts_bparam@unitString = "kt"
			else
				opts_bparam@unitString = "m/sec"
			end if

			blavgwind = new ( (/ny, nx/), float)	; in kt!!!
			blwind(z, ter, pblh, nx, ny, nz, uEW, vNS, blavgwind, u, v)

			copy_VarAtts(mag, blavgwind)
			copy_VarAtts(mag, u)
			copy_VarAtts(mag, v)
			ldatafmt = plot_streamline( wks, bg, u, v, blavgwind, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = blavgwind
			bparam@udata = u
			bparam@vdata = v
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; BSRATIO
		if( params(p) .eq. "bsratio" .or. params(p) .eq. "bsratio_bsratio") then
			opts_bparam@unitString = "~K~Truncated at 10~P~"
			; Should be opts_bparam@ContourParameters =(/ MAXBSRATIO/20., MAXBSRATIO/20., MAXBSRATIO - MAXBSRATIO/20. /)
			opts_bparam@MainTitle = "Buoyancy/Shear Ratio"
			qparaminfo = "Param= "+params(p)+" Unit= nondim Mult= 1"

			if( .not. isvar("blavgwind")) then
				if( .not. isvar("u")) then
					u = new ( (/ny, nx/), float)
				end if
				if( .not. isvar("v")) then
					v = new ( (/ny, nx/), float)
				end if
				if( .not. isvar("blavgwind")) then
					blavgwind = new ( (/ny, nx/), float)
				end if
				print("    bsratio: doing blwind")
				blwind(z, ter, pblh, nx, ny, nz, uEW, vNS, blavgwind, u, v)
			end if
			if( .not. isvar("wstar_mag")) then
				wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc )	; in m/sec
			end if
			bsratio_mag = bsratio(blavgwind, wstar_mag)
			tmp = bsratio_mag < 10	; should be MAXBSRATIO
			if(params(p) .eq. "bsratio_bsratio") then          ; Diagnostic Plot
				opts_bparam@mult = 1
				tmp = bsratio_mag < 10
				ldatafmt = plot_stipple(wks, bg, tmp, tmp, "bsratio_bsratio", tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			else
				ldatafmt = plot_contour(wks, bg, tmp, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
				bparam = tmp
				copy_VarAtts(atts, bparam)
				write_datafile(params(p), bparam, opts_bparam, ldatafmt)
			end if

			continue
		end if

; WBLMAXMIN
		if( params(p) .eq. "wblmaxmin" ) then
			opts_bparam@MainTitle = "BL Max. Up/Down Motion"
			if(UNITS .ne. "metric") then
				qparaminfo = "Param= "+params(p)+" Unit= ft/min Mult= 1"
				; opts_bparam@mult = 196.85	; It looks like NCL_JACK_FORTRAN :: calc_wblmaxmin() returns result in cm/s !?!
				opts_bparam@mult = 1.9685
				opts_bparam@unitString = "ft/min"
			else
				qparaminfo = "Param= "+params(p)+" Unit= cm/s Mult= 1"
				; opts_bparam@mult = 100.0	; See above - already cm/s
				opts_bparam@mult = 1.0
				opts_bparam@unitString = "cm/sec"
			end if

			wblMxMn = wblmaxmin(wa, z, ter, pblh, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, wblMxMn, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = wblMxMn
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; ZWBLMAXMIN
		if( params(p) .eq. "zwblmaxmin" ) then
			opts_bparam@MainTitle = "MSL Height of maxmin Wbl"
			if( UNITS .ne. "metric") then
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@ContourParameters = (/ 0.,0., 500. /) ; Lge value to reduce plot time
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
			else
				opts_bparam@unitString = "m"
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				opts_bparam@ContourParameters = (/ 0.,0., 250. /)  ; Lge value to reduce plot time
			end if

			zwblMxMn = zwblmaxmin(wa, z, ter, pblh, nx, ny, nz)
			ldatafmt = plot_contour(wks, bg, zwblMxMn, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = zwblMxMn
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; MSLPRESS
		if( params(p) .eq. "mslpress" ) then
			opts_bparam@MainTitle = "Mean Sea Level Pressure"
			opts_bparam@ContourParameters = (/ 0, .0, 2.0 /)
			opts_bparam@unitString = "mb"

			ldatafmt = plot_contour(wks, bg, slvl, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = slvl
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; CAPE
		if( params(p) .eq. "cape" ) then
			opts_bparam@MainTitle = "Convective Available Potential Energy (CAPE)"
			qparaminfo = "Param= "+params(p)+" Unit= J/kg Mult= 1"
			opts_bparam@unitString = "J/kg"

			cape_mag = cape(pmb, tc, td, nx,ny,nz)
			ldatafmt = plot_contour(wks, bg, cape_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = cape_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; SFCTEMP
		if( params(p) .eq. "sfctemp" ) then
			opts_bparam@MainTitle = "Surface Temperature ~I~(2m AGL)~P~"
			if( UNITS .eq. "american" ) then
				qparaminfo = "Param= "+params(p)+" Unit= F Mult= 1"
				opts_bparam@unitString = "F"
			else
				qparaminfo = "Param= "+params(p)+" Unit= C Mult= 1"
				opts_bparam@unitString = "C"
			end if

			sfctemp = tc2 - 273.16
			if( UNITS .eq. "american") then
				sfctemp = 32. + 1.8 * sfctemp   ; Fahrenheit
			end if

			ldatafmt = plot_contour(wks, bg, sfctemp, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = sfctemp
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; SFCDEWPT
		if( params(p) .eq. "sfcdewpt" ) then
			opts_bparam@MainTitle = "Surface Dew Point Temperature ~I~(2m AGL)~P~"
			if( UNITS .eq. "american" ) then
				qparaminfo = "Param= "+params(p)+" Unit= F Mult= 1"
				opts_bparam@unitString = "F"
			else
				qparaminfo = "Param= "+params(p)+" Unit= C Mult= 1"
				opts_bparam@unitString = "C"
			end if

			sfcdewpt = td2
			if( UNITS .eq. "american") then
				sfcdewpt = 32. + 1.8 * sfcdewpt   ; Fahrenheit
			end if
			ldatafmt = plot_contour(wks, bg, sfcdewpt, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = sfcdewpt
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; DBL
		if( params(p) .eq. "dbl" ) then
			opts_bparam@MainTitle = "BL Depth"
			if( UNITS .ne. "metric" ) then
				opts_bparam@mult = 3.28084 ; ft
				opts_bparam@unitString = "ft"
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@ContourParameters = (/0., 0., 500. /)
			else
				opts_bparam@unitString = "m"
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
			end if

			dbl_mag = pblh
			ldatafmt = plot_contour(wks, bg, dbl_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = dbl_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; SFCSUN
		if( params(p) .eq. "sfcsun" ) then
			opts_bparam@unitString = ""
			opts_bparam@MainTitle = "Sfc. Solar Radiation"
			qparaminfo = "Param= "+params(p)+" Unit= % Mult= 1"

			sfcsun_mag = sfcsun(swdown)
			ldatafmt = plot_contour(wks, bg, sfcsun_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = sfcsun_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; SFCSUNPCT
		if( params(p) .eq. "sfcsunpct" ) then
			opts_bparam@ContourParameters = (/ 5., 95., 5. /)
			opts_bparam@unitString = "%"
			opts_bparam@MainTitle = "Normalized Sfc. Solar Radiation"
			qparaminfo = "Param= "+params(p)+" Unit= % Mult= 1"

			sfcsunpct_mag = sfcsunpct(jday,  gmthr, swdown, pmb, tc, qvapor, nx, ny, nz, ter, z, alat, alon )
			ldatafmt = plot_contour(wks, bg, sfcsunpct_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = sfcsunpct_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; DWCRIT
		if( params(p) .eq. "dwcrit" ) then
			opts_bparam@MainTitle = "Depth of Critical Updraft Strength ~I~(AGL Hcrit)~P~"
			if( UNITS .ne. "metric") then
				qparaminfo = "Param= "+params(p)+" Unit= ft Mult= 1"
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft"
				opts_bparam@ContourParameters = (/0., 0., 500. /)
			else
				qparaminfo = "Param= "+params(p)+" Unit= m Mult= 1"
				opts_bparam@ContourParameters = (/ 0.,0., 250. /)  ; Lge value to reduce plot time
				opts_bparam@unitString = "m"
			end if

			if( .not. isvar("wstar_mag")) then
				wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc )	; in m/sec
			end if
			dwcrit_mag = dwcrit(wstar_mag, ter, pblh, nx, ny)
			ldatafmt = plot_contour(wks, bg, dwcrit_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = dwcrit_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; BLCWBASE
		if( params(p) .eq. "blcwbase" ) then
			;;; MORE DEVELOPMENT NEEDED - AGL /MSL etc
			opts_bparam@MainTitle = "BL Explicit Cloud Base [AGL] ~I~(CloudWater>"+cwbasecriteria+")~P~"
			if(UNITS .ne. "metric") then
				qparaminfo = "Param= "+params(p)+" Unit= ftAGL Mult= 1"
				opts_bparam@mult = 3.28084
				opts_bparam@unitString = "ft AGL"
				opts_bparam@ContourParameters = (/0., 0., 500. /)
			else
				opts_bparam@unitString = "m AGL"
				qparaminfo = "Param= "+params(p)+" Unit= mAGL Mult= 1"
			end if

			blcwbase_mag = blcwbase( qcloud, z, ter, pblh, nx, ny, nz)
			ldatafmt = plot_contour( wks, bg, blcwbase_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = blcwbase_mag
			copy_VarAtts(atts, bparam)
			bparam@_FillValue = -999999
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; CFRACL
		if( params(p) .eq. "cfracl" ) then
			opts_bparam@ContourParameters = (/ 5., 95., 5. /)
			opts_bparam@MainTitle = "Cloud Fraction - Low"
			opts_bparam@unitString = "%"
			qparaminfo = "Param= "+params(p)+" Unit= % Mult= 1"

			cfracl = cfrac(0,:,:) * 100
			ldatafmt = plot_contour(wks, bg, cfracl, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = cfracl
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; CFRACM
		if( params(p) .eq. "cfracm" ) then
			opts_bparam@ContourParameters = (/ 5., 95., 5. /)
			opts_bparam@MainTitle = "Cloud Fraction - Mid"
			opts_bparam@unitString = "%"
			qparaminfo = "Param= "+params(p)+" Unit= % Mult= 1"

			cfracm = cfrac(1,:,:) * 100
			ldatafmt = plot_contour(wks, bg, cfracm, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = cfracm
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; CFRACH
		if( params(p) .eq. "cfrach" ) then
			opts_bparam@ContourParameters = (/ 5., 95., 5. /)
			opts_bparam@MainTitle = "Cloud Fraction - High"
			opts_bparam@unitString = "%"
			qparaminfo = "Param= "+params(p)+" Unit= % Mult= 1"

			cfrach = cfrac(2,:,:) * 100
			ldatafmt = plot_contour(wks, bg, cfrach, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = cfrach
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; WRF=<wrf_parameter>
		if( string_pattern_grep(params(p),"wrf=").gt.0 ) then
			print ( "    WRF Parameter: " + params(p) )
			wrf_mag = wrf(f, params(p))
			if(wrf_mag@units .ne. "") then
				opts_bparam@unitString= wrf_mag@units
				opts_bparam@mult = 1.0
				if(wrf_mag@units .eq. "m") then
					if( UNITS .ne. "metric" ) then
						opts_bparam@mult = 3.28084
						opts_bparam@unitString= "ft"
					end if
				end if
			else
				opts_bparam@unitString= ""
				opts_bparam@mult = 1.0
			end if
			opts_bparam@MainTitle = wrf_mag@description
			ldatafmt = 2
			ldatafmt = plot_contour(wks, bg, wrf_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = wrf_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; WINDnnn
		if(dimsizes(plot_param_chars) .gt. 3 .and. plot_param_chars(0:3) .eq. "wind") then
			pressure = stringtofloat(charactertostring(plot_param_chars(4:)))
			print( "    DOING WIND BARB PLOT at mb = "+pressure )

			opts_bparam@MainTitle = "Wind barbs at " + pressure + "mb"
			opts_bparam@unitString = "Kt"
			opts_bparam@mult = 1
			u@lat2d = alat
			u@lon2d = alon
			v@lat2d = alat
			v@lon2d = alon

			; Vertically interpolate the selected 3d fields to this pressure surface.
			; Note that DrJack's wrf_user_intrp3d has different arguments (than NCL), which include "terrain"

			u@_FillValue = 0.
			v@_FillValue = 0.

			u  = wrf_user_intrp3d( uEW, pmb, "h", pressure, 0., False)
			v  = wrf_user_intrp3d( vNS, pmb, "h", pressure, 0., False)

			print("    press" + pressure +": u min = " + min(u) + " max = " + max(u))
			print("    press" + pressure +": v min = " + min(v) + " max = " + max(v))

			ldatafmt = plot_wind(wks, bg, u, v, pressure, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = u	; Not used
			bparam@udata = u
			bparam@vdata = v
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; PRESSnnn
		if(dimsizes(plot_param_chars) .gt. 4 .and. plot_param_chars(0:4) .eq. "press") then
			pressure = stringtofloat(charactertostring(plot_param_chars(5:)))
			opts_bparam@MainTitle = "Vertical Velocity & Wind [kt] at " + pressure + "mb"
			if( UNITS .ne. "metric" ) then
				opts_bparam@mult = 196.85039 ; ft/min
				opts_bparam@unitString = "ft/min"
			else
				opts_bparam@mult = 100.
				opts_bparam@unitString = "cm/sec"
			end if

			u@lat2d = alat
			u@lon2d = alon
			v@lat2d = alat
			v@lon2d = alon
			pressure = press(ter, params(p), mag, u, v, wa, uEW, vNS, pmb )
			ldatafmt = plot_barb(wks, bg, mag, u, v, z, pressure, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = mag
			bparam@udata = u
			bparam@vdata = v
			copy_VarAtts(atts, bparam)
			bparam@_FillValue = -999999

			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if

; WSTAR_BSRATIO
		if( params(p) .eq. "wstar_bsratio") then
			opts_bparam@ContourParameters = (/ 0.,0., 50. /)
			opts_bparam@MainTitle = "Thermal Updraft Velocity ~I~(W*)~P~"
			if(UNITS .ne. "metric") then
				opts_bparam@mult = 196.85
				opts_bparam@unitString = "ft/min"
				qparaminfo = "Param= "+params(p)+" Unit= ft/min Mult= 1"
			else
				opts_bparam@mult = 100.0
				qparaminfo = "Param= "+params(p)+" Unit= cm/s Mult= 1"
				opts_bparam@unitString = "cm/sec"
			end if

			if( .not. isvar("wstar_mag")) then
				print("    wstar_bsratio: doing wstar")
				wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc )	; in m/sec
			end if
			if( .not. isvar("bsratio_mag")) then
				if( .not. (isvar("blavgwind"))) then
					if( .not. isvar("u") ) then
						u = new ( (/ny, nx/), float)
					end if
					if( .not. isvar("v") ) then
						v = new ( (/ny, nx/), float)
					end if
					print("    wstar_bsratio: doing blwind")
					blavgwind = new ( (/ny, nx/), float)	; in kt!!!
					blwind(z, ter, pblh, nx, ny, nz, uEW, vNS, blavgwind, u, v)
				end if
				bsratio_mag = bsratio(blavgwind, wstar_mag)
			end if
			wstar_mag@lat2d = alat
			wstar_mag@lon2d = alon
			bsratio_mag@lat2d = alat
			bsratio_mag@lon2d = alon
			ldatafmt = plot_stipple(wks, bg, wstar_mag, bsratio_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)

			continue
		end if

; STARS
		if( .not. ismissing(str_match_ic(params(p), "stars"))) then
			if( .not. ismissing(str_match_ic(params(p), "hg"))) then
				HG = True
				opts_bparam@MainTitle = "Star Rating - FL"
			else
				HG = False
				opts_bparam@MainTitle = "Star Rating"
			end if
			if(params(p) .eq. "avgstars") then
				continue
			end if

			opts_bparam@unitString = "Stars"
			ldatafmt = 2
			opts_bparam@ContourParameters = (/ 1., 5., 1. /)


			if( .not. isvar("bsratio_mag")) then	; Order of tests significant: Dependencies
				if( .not. isvar("blavgwind") ) then
					if( .not. isvar("u") ) then
						u = new ( (/ny, nx/), float)
					end if
					if( .not. isvar("v") ) then
						v = new ( (/ny, nx/), float)
					end if
					blavgwind = new ( (/ny, nx/), float)	; in kt!!!
					print("    stars: doing blwind")
					blwind(z, ter, pblh, nx, ny, nz, uEW, vNS, blavgwind, u, v)
				end if
				if( .not. isvar("wstar_mag") ) then
					print("    stars: doing wstar")
					wstar_mag = wstar(nx, ny, nz, vhf, pblh, hfx, tc )	; in m/sec
				end if
				print("    stars: doing bsratio")
				bsratio_mag = bsratio(blavgwind, wstar_mag)
			end if
			if( .not. isvar("hglider_mag")) then
				if( .not. isvar("hwcrit_mag") ) then
					print("    stars: doing hwcrit")
					hwcrit_mag = hwcrit(wstar_mag, ter, pblh, nx, ny)
				end if
				if( .not. isvar("zsfclcl_mag") ) then
					print("    stars: doing zsfclcl")
					zsfclcl_mag = zsfclcl(pmb, tc, td, z, ter, pblh, nx, ny, nz)
				end if
				if( .not. isvar("zblcl_mag") ) then
					print("    stars: doing zblcl")
					zblcl_mag = zblcl( qvapor, z, ter, pblh, pmb, tc, nx, ny, nz)
				end if
				print("    stars: doing hglider")
				hglider_mag = hglider(hwcrit_mag, zsfclcl_mag, zblcl_mag, nx, ny)
			end if
			if( .not. isvar("zsfclcldif_mag")) then
				print("    stars: doing zsfclcldif")
				zsfclcldif_mag = zsfclcldif(ter, pblh, zsfclcl_mag)
			end if
			if(HG .eq. True) then
				if( .not. isvar("wind1_mag")) then
					u1 = new ( (/ny, nx/), float)
					v1 = new ( (/ny, nx/), float)
					wind1_mag = new ( (/ny, nx/), float)
					print("    stars: doing sfcwind")
					sfcwind(uEW, vNS, u1, v1, wind1_mag )
				end if
				stars_mag = stars(hglider_mag, ter, zsfclcldif_mag, wind1_mag, bsratio_mag, slvl, HG)
			else
				stars_mag = stars(hglider_mag, ter, zsfclcldif_mag, blavgwind, bsratio_mag, slvl, HG)
			end if

			ldatafmt = plot_contour(wks, bg, stars_mag, params(p), tail, alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
			bparam = stars_mag
			copy_VarAtts(atts, bparam)
			write_datafile(params(p), bparam, opts_bparam, ldatafmt)

			continue
		end if
	end do
end

; PFD_TOT
procedure do_pfd()
local bparam, pfd_mag
begin
	; Ensure no leftovers
	if(isvar("bparam")) then
		delete(bparam)
	end if

	if(isvar("opts_bparam")) then
		delete(opts_bparam)
	end if
	opts_bparam = True
	opts_bparam@mult = 1.0	; Default value; overidden as required
	ldatafmt = 0		; Overridden as required

	print("*** Doing PFD")
	opts_bparam@MainTitle = "Potential Flight Distance (Discus, 100 kg ball.)"
	if( UNITS .eq. "american" ) then
		opts_bparam@UnitLabel = "[mi]"
		opts_bparam@unitString = "mi"
		opts_bparam@ContourParameters = (/ 100., 400., 100. /)
		qparaminfo = "Param= pfd_tot Unit= mi Mult= 1"
		opts_bparam@mult = 0.621371192237 ; Convert to miles
	else
		opts_bparam@UnitLabel = "[km]"
		opts_bparam@unitString = "km"
		opts_bparam@ContourParameters = (/ 100., 900., 100. /)
		qparaminfo = "Param= pfd_tot Unit= km Mult= 1"
		opts_bparam@mult = 1.0
	end if

	pfd_mag = pfd()

	if(.not. isatt(pfd_mag, "valid") .or. pfd_mag@valid .ne. True)
		print("*** PFD error: result not plotted!")
		return
	end if

	ldatafmt = plot_contour(wks, bg, pfd_mag, "pfd_tot", "", alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
	bparam = pfd_mag
	copy_VarAtts(atts, bparam)
	bparam@tail = ""
	write_datafile("pfd_tot", bparam, opts_bparam, 0)

end

; AVGSTARS
procedure do_avgstars()
local bparam, avgstars_mag
begin
	; Ensure no leftovers
	if(isvar("bparam")) then
		delete(bparam)
	end if

	if(isvar("opts_bparam")) then
		delete(opts_bparam)
	end if
	opts_bparam = True
	opts_bparam@mult = 1.0	; Default value; overidden as required
	ldatafmt = 0		; Overridden as required

	opts_bparam@MainTitle = "Average Star Rating for Day"
	opts_bparam@unitString = "Stars"
	ldatafmt = 2
	opts_bparam@ContourParameters = (/ 1., 5., 1. /)

	avgstars_mag = avgstars()

	if(.not. isatt(avgstars_mag, "valid") .or. avgstars_mag@valid .ne. True)
		print("*** AVGstars error: result not plotted!")
		return
	end if

	ldatafmt = plot_contour(wks, bg, avgstars_mag, "avgstars", "", alat, alon, gridspacingkm, opts_cn, opts_bparam, opts_bg, ldatafmt)
	bparam = avgstars_mag
	copy_VarAtts(atts, bparam)
	bparam@tail = ""
	write_datafile("avgstars_tot", bparam, opts_bparam, 0)

end
