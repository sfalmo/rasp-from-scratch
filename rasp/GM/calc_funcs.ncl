;
; BLCLOUDPCT
;
function blcloudpct(qvapor, qcloud, tc, pmb, z, ter, pblh, cwbasecriteria, isize, jsize, ksize)
begin
        bparam = new( (/jsize,isize/), float)

        calc_subgrid_blcloudpct_grads( qvapor, qcloud, tc,pmb, z, ter, pblh, cwbasecriteria, isize,jsize,ksize, bparam  )

	; Bombs - Out of Memory - if running X (i.e. runlevel == 5)

	; This is the most *HORRIBLE* hack to reduce CUDA memory usage
	; With 6 large vars, it won't fit
	; So take only the lowest N levels of available 52 :-(
	; Value of N experimentally determined - YUK!
	; N = 33
	; print("*** WARNING: Only " + N + " levels")
        ; calc_subgrid_blcloudpct_grads( qvapor(0:N,:,:), qcloud(0:N,:,:), tc(0:N,:,:), pmb(0:N,:,:), z(0:N,:,:), ter, pblh, cwbasecriteria, isize,jsize,N+1, bparam  )

	return(bparam)
end

;;;;;;;;;;;;;;;;;
; blcwbase calc
;;;;;;;;;;;;;;;;;
function blcwbase(qcloud, z, ter, pblh, isize, jsize, ksize)
begin
	;;; laglcwbase can be either agl (=1) or msl (=0) (flag also changes titles below)
	;agl: laglcwbase = 1
	;msl: laglcwbase = 0
	laglcwbase = 1

	;;; set max cloudbase to allow reasonable contour intervals
	maxcwbasem = 5486.40   ; equals 18000ft
	maxcwbaseft = floattointeger( 3.28084*maxcwbasem )

	bparam = new( (/jsize,isize/), float)
	bparam@_FillValue = -999	; This is only required for V6, as the default is different!

	calc_blcloudbase( qcloud, z, ter, pblh, cwbasecriteria, maxcwbasem, laglcwbase, isize,jsize,ksize, bparam  )

	;4test print ( "POST-SUB: MIN,MAX="+min(bparam)+","+max(bparam) )

	return( bparam )
end

;
; BLICW
;
function blicw(qcloud, ppert, pb, psfc, z, pblh, ter, isize, jsize, ksize)
begin
        ptot = ppert + pb
        bparam = new( (/jsize,isize/), float)

        calc_blinteg_mixratio( qcloud, ptot, psfc, z, ter, pblh, isize,jsize,ksize, bparam )

	return( bparam )
end

;
; BLTOPVARIAB
;
function bltopvariab(thetac, z, pblh, ter, isize, jsize, ksize)
begin
        bparam = new( (/jsize,isize/), float)
        criteriondegc = 1.0
        calc_bltop_pottemp_variability( thetac, z, ter, pblh, isize,jsize,ksize, criteriondegc, bparam )

	return(bparam)
end

;
; BLWINDSHEAR
;
function blwindshear(ua, va, z, ter, pblh, isize, jsize, ksize)
begin
        bparam = new( (/jsize,isize/), float)
        calc_blwinddiff(ua,va,z,ter,pblh, isize,jsize,ksize, bparam )

	return(bparam)
end

;
; BSRATIO
;
function bsratio(blavgwindspeed, wstar)
begin
	;;; BUG: Calculation of bsratio in rasp.bparam_calc.ncl is done twice
	;;; If calculated on its own (and has not been done previously)
	;;; Then wstar is in m/s (wrf units) and blavgwindspeed is in Kt
	;;; BUT
	;;; When calculated as part of wstar_bsratio
	;;; blavgwindspeed is in Kts or m/s
	;;; wstar is in ft/min or cm/sec
	;;; WHO KNOWS which is correct?
	;;;
	;;; EITHER WAY, It contravenes the basic idea that
	;;; Units are a PLOTTING ISSUE
	;;; NOT a calculation issue!


	;;; at present use constant value for bl drag coefficient
	if(UNITS .ne. "metric") then
		tmp = wstar / sqrt( cdbl*((blavgwindspeed * 1.94386) ^ 2) )            ; wstar in m/s ; wind in Kt
		; OR
		; tmp = 196.85 * wstar / sqrt( cdbl*((blavgwindspeed * 1.94386) ^ 2) ) ; wstar in ft/min; wind in Kt 
	else
		tmp = wstar / sqrt( cdbl*(blavgwindspeed ^ 2) )                        ; wstar in m/s; wind in m/s 	
		; OR
		; tmp = 100.0 * wstar / sqrt( cdbl*(blavgwindspeed ^ 2) )              ; wstar in cm/s; wind in m/s 	
	end if

	return(tmp)
end

;
; CAPE
; Outside fortran routine since have ncl skewt functions available
; Very inefficient but leave for now
; Uses sfc humidity as reference, not 100mb avg
;
undef("cape")
function cape(pmb, tc, td, isize, jsize, ksize)
begin
        bparam = new( (/jsize,isize/), float)

	calc_cape2d(pmb,tc,td,isize,jsize,ksize,bparam)

        ; profilep = new( (/ksize/), float)
        ; profiletc = new( (/ksize/), float)
        ; do ii = 0,(isize-1)
        ;       do jj = 0,(jsize-1)
        ;               ;;; following taken from skewt_func.ncl
        ;               ;;; pmb,tc,td index is basis for calc (0=sfc)
        ;               plcl = -999.             ; p (hPa) Lifting Condensation Lvl (lcl)
        ;               tlcl = -999.             ; temperature (C) of lcl
        ;               kzhumidref = 0
        ;               ptlcl_skewt( pmb(kzhumidref,jj,ii),tc(kzhumidref,jj,ii),td(kzhumidref,jj,ii), plcl,tlcl )
        ;               profilepmb = pmb(:,jj,ii)
        ;               profiletc = tc(:,jj,ii)
        ;               bparam(jj,ii) = cape_thermo( profilepmb,profiletc, plcl, 0 )
        ;       end do
        ; end do
        ; delete ( profilepmb )
        ; delete ( profiletc )

	return(bparam)
end

;
; BL CLOUD-CONDENSATION EQUIV. HEAT FLUX
;
function cloudsuck(rqcblten, mu, mub, z, ter, pblh, isize, jsize, ksize) 
begin
	bparam = new( (/jsize, isize/), float)
        calc_qcblhf( rqcblten,mu, z, ter, pblh, isize,jsize,ksize, bparam  )

	return(bparam)
end

;
; DWCRIT
;
function dwcrit(wstar, ter, pblh, isize, jsize)
begin
	bparam = new( (/jsize,isize/), float)
	calc_hcrit( wstar, ter, pblh, isize,jsize, bparam )

	bparam = bparam - ter

	return(bparam)
end

;
; EXPERIMENTAL1
; Presently hcrit based on criteria=175fpm
;
function experimental1(wstar, ter, pblh, isize, jsize)
begin
        bparam = new( (/jsize,isize/), float)
        calc_hlift( 175., wstar, ter, pblh, isize, jsize, bparam )

	return(bparam)
end


;
; EXPERIMENTAL2 
; Presently max of CLDFRA within BL
;
function experimental2(cldfra, z, ter, pblh, isize, jsize, ksize)
begin
        ;;; CLDFRA NOT USED FOR ANY OTHER CALC SO DISCARD AFTER USE

        bparam = new( (/jsize,isize/), float)
        calc_blmax( cldfra, z, ter, pblh, isize,jsize,ksize, bparam  )

        bparam = 100.* bparam ;;; convert to percent
        return (bparam)
end

;
; HGLIDER
;
function hglider(hcrit, zsfclcl, zblcl, isize, jsize)
begin
	bparam = hcrit
	cparam = new( (/jsize,isize/), float)
	cparam = 0.0
	min_2darrays( bparam, cparam, zsfclcl, 1.0, isize, jsize )
	min_2darrays( bparam, cparam, zblcl, 2.0, isize, jsize )

	return(bparam)
end

;
; HWCRIT
;
function hwcrit( wstar, ter, pblh, isize, jsize)
begin
	bparam = new( (/jsize,isize/), float)
	calc_hcrit( wstar, ter, pblh, isize,jsize, bparam )

	return(bparam)
end

;
; WBLMAXMIN
;
function wblmaxmin(wa, z, ter, pblh, isize, jsize, ksize)
begin
	bparam = new( (/jsize,isize/), float )
	calc_wblmaxmin( 0, wa,z,ter,pblh, isize,jsize,ksize, bparam )

	return(bparam)
end

;
; ZWBLMAXMIN
;
function zwblmaxmin(wa, z, ter, pblh, isize, jsize, ksize)
begin
	bparam = new( (/jsize,isize/), float)
	calc_wblmaxmin( 1, wa,z,ter,pblh, isize,jsize,ksize, bparam )

	return(bparam)
end

;
; SWBLMAXMIN
;
function swblmaxmin(wa, z, ter, pblh, isize, jsize, ksize)
begin
	bparam = new( (/jsize,isize/), float)
	calc_wblmaxmin( 2, wa,z,ter,pblh, isize,jsize,ksize, bparam )

	return(bparam)
end

;
; PRESSNNN
;
function press(ter, name_chars, w_plane, u_plane, v_plane, w, ua, va, pmb )

begin
	;;; determine pressure level
 	char_str = stringtocharacter(name_chars)  
	pressure = stringtofloat(charactertostring(char_str(5:)))

	print( "    DOING PRESSURE PLOT of press for mb = "+pressure )

	;;;;;;;;;;
	; Vertically interpolate the selected 3d fields to this pressure surface.
	; Note that DrJack's wrf_user_intrp3d has different arguments (than NCL), which include "terrain"
	;;;;;;;;;;

	u_plane@_FillValue = 0.
	v_plane@_FillValue = 0.
	w_plane@_FillValue = 0.

	if(Jack) then
		u_plane  = wrf_user_intrp3d( ua, pmb, ter, "h", pressure, 0.)
		v_plane  = wrf_user_intrp3d( va, pmb, ter, "h", pressure, 0.)
		w_plane  = wrf_user_intrp3d( w,  pmb, ter, "h", pressure, 0.)

	else ; NCL Version
		u_plane  = wrf_user_intrp3d( ua, pmb, "h", pressure, 0., False)
		v_plane  = wrf_user_intrp3d( va, pmb, "h", pressure, 0., False)
		w_plane  = wrf_user_intrp3d( w,  pmb, "h", pressure, 0., False)

	end if

	print("    press" + pressure +": u_plane min = " + min(u_plane) + " max = " + max(u_plane))
	print("    press" + pressure +": v_plane min = " + min(v_plane) + " max = " + max(v_plane))
	print("    press" + pressure +": w_plane min = " + min(w_plane) + " max = " + max(w_plane))

	return(pressure)
end

;
; RAIN
;
function rain(filename, f, plot_param_chars, nx, ny)
begin
	;; Extract the accumulation time from the parameter name
	acctime = stringtointeger( chartostring( plot_param_chars(4:) ) )

	;; Get filename for the previous forecast. Needed to subtract earlier rain.
	filename_chars = stringtochar( filename )
	len_filename = dimsizes(filename_chars)-2

	; date of current file
	; sdate = string_target_replace(chartostring( filename_chars(len_filename-18:len_filename-6)), "_", "-" )
	sdate = str_sub_str(chartostring( filename_chars(len_filename-18:len_filename-6)), "_", "-" )

	; Allow for ".nc" on the end
	stime = filename_chars(len_filename-7:len_filename-3)

	; date  = stringtointeger(split_string_into_array( sdate,"-" ))
	date  = stringtointeger(str_split( sdate,"-" ))
	; date of previous file
	prevdate  = jul2greg( greg2jul(date(0),date(1),date(2),date(3)) - acctime/24. + 0.00001 )
	sprevdate = sprinti("%d-",prevdate(0)) + sprinti("%02d-",prevdate(1)) + sprinti("%02d_",prevdate(2)) + sprinti("%02d:", prevdate(3)) + stime 
	prevfilename = chartostring( filename_chars(0:len_filename-19)) + sprevdate

	rainc  = f->RAINC
	rainnc = f->RAINNC
	rainc  = rainc > 0.0
	rainnc = rainnc > 0.0

	rainTot = new ( (/ny, nx/), float)

	;; If the previous file exists -> load it, subtract earlier rain, plot it.
	if (isfilepresent(prevfilename)) then
		prevfile = addfile( prevfilename+".nc", "r" )

		prevrainc  = prevfile->RAINC
		prevrainnc = prevfile->RAINNC

		; Use NCL operator > to make sure all values >=0.0
		prevrainc  = prevrainc > 0.0
		prevrainnc = prevrainnc > 0.0

		rainTot = rainc + rainnc - prevrainc - prevrainnc
	else
		rainTot = rainc + rainnc
		print("    prevfilename = " + prevfilename )
		print("    WARNING: No previous file: showing total accumulated rain to " + date(3) + ":" + stime)
	end if
	return(rainTot)
end

;
; SFCSUN
;
function sfcsun(swdown)
begin
	bparam = swdown
	bparam@_FillValue = -999
	return(swdown)
end

;
; SFCSUNPCT
;
function sfcsunpct(jday, gmthr, swdown, pmb, tc, qvapor, isize, jsize, ksize, ter, z, alat, alon)
begin
	bparam = swdown
	bparam@_FillValue = -999
	calc_sfcsunpct( jday, gmthr, alat, alon, ter, z, pmb, tc, qvapor, isize, jsize, ksize, bparam )


	; Another Horrible hack - see BLCLOUDPCT
	; N = 32
	; print("*** WARNING: Only " + N + " levels")
	; calc_sfcsunpct( jday, gmthr, alat, alon, ter, z(0:N,:,:), pmb(0:N,:,:), tc(0:N,:,:), qvapor(0:N,:,:), isize, jsize, N+1, bparam )

	return(bparam)
end

;
; PDFTOT
;
function pfd()
begin
    ; Uses only data files
    ; Must select files with correct date and on full hours (i.e. minutes == 00lst)

    filename_chars = stringtochar(getenv("ENV_NCL_FILENAME"))
    len_filename = dimsizes(filename_chars)-2
    datepart = chartostring(filename_chars(len_filename-18:len_filename-9))
    dateStr = str_split(datepart, "-")
    newdateStr = dateStr(0) + " " + toint(dateStr(1)) + " " + toint(dateStr(2))

    cmd = "grep -l '" + newdateStr + "' " + BaseDir + "/" + Region + "/OUT/wstar.*lst.d2.data"
    wstar_files = systemfunc(cmd)
    nfiles = dimsizes(wstar_files)
    delete(cmd)

    ; Read one file and extract nx & ny
    ; Should be the same as in ENV_NCL_FILENAME but ...
    f = wstar_files(0)
    if(.not. fileexists(f) ) then
        print(f + " does not exist!");
        return(0)   ; pfdtot@valid is false!
    end if
    hdr = readAsciiHead(f, "Day")
    nx = toint(extract_string_field(hdr(2), 11, " "))
    ny = toint(extract_string_field(hdr(2), 13, " "))

    pfdtot = new( (/ny,nx/), float)
    pfdtot = 0.0
    do i = 0, nfiles-2 ; Note: last file (i.e. for latest time) not included
        f = wstar_files(i)
        ; print("i = " + i + " f = " + f)

        wstar = readAsciiTable(f, nx, "integer", 4)
        if(UNITS .eq. "metric")
            wssel = wstar / 100.0 - 1.15 ; Convert from cm/sec & Deduct sink rate
        else
            wssel = (wstar / 196.85039) - 1.15 ; But first convert to m/sec
        end if
        wssel = wssel > 0.0
        dist = ((wssel*(sqrt((-5.21488508245734-wssel)/-0.000302016415111608))) \
               /(2*wssel-2*-5.21488508245734-0.0729181700942301*(sqrt((-5.21488508245734-wssel)\
               /-0.000302016415111608))))/2
        pfdtot = pfdtot + dist
        delete( (/wstar, wssel/) )
    end do  

    pfdtot@valid = True
    return(pfdtot)
end

;
; AVGSTARS
;
function avgstars()
begin
    ; Note uses only data files
    ; Must select files with correct date and on full hours (i.e. minutes == 00lst)

    cmd = "ls -l --time-style=+%F " + BaseDir + "/" + Region + "/OUT/stars.*lst.d2.data"
    star_files = systemfunc(cmd)
    nfiles = dimsizes(star_files)
    delete(cmd)

    ; Read one file to extract date and nx, ny
    ; Assume that a file in the middle has date of interest
    ; May old files from change of DST may exist

    n = string_pattern_grep(star_files(0), " ")
    f = extract_string_field(star_files(nfiles/2), n+1, " ") ; filename only for a file in the middle - note "ls -l" 
    hdr = readAsciiHead(f, "Day")

    yr  = stringtointeger(extract_string_field(hdr(3), 2,  " "))
    mon = stringtointeger(extract_string_field(hdr(3), 3,  " "))
    dom = stringtointeger(extract_string_field(hdr(3), 4,  " "))
    nx  = stringtointeger(extract_string_field(hdr(2), 11, " "))
    ny  = stringtointeger(extract_string_field(hdr(2), 13, " "))

    stars_tot = new( (/ny,nx/), float)
    stars_tot = 0.0
    do i = 0, nfiles-2 ; Note: last file (i.e. for latest time) not included
        F = star_files(i)
        n = string_pattern_grep(F, " ")
        f = extract_string_field(F, n+1, " ") ; full filename only - note "ls -l" above!
        ; print("i = " + i + " f = " + f)

        ; Check date is correct
        hdr = readAsciiHead(f, "Day")
        yr1  = stringtointeger(extract_string_field(hdr(3), 2,  " "))
        mon1 = stringtointeger(extract_string_field(hdr(3), 3,  " "))
        dom1 = stringtointeger(extract_string_field(hdr(3), 4,  " "))
        if(yr1 .ne. yr .or. mon1 .ne. mon .or. dom1 .ne. dom)
            print(f + " has wrong date")
            continue;
        end if

        stars = readAsciiTable(f, nx, "float", 4)
        stars_tot = stars_tot + stars
        delete( stars )
        ; print(max(stars_tot))
    end do  

    stars_tot = stars_tot / (nfiles-1)
    stars_tot@valid = True
    return(stars_tot)
end

;
; STARS
;
; Note that wind is sfcwind (10m) if HGflag==True else blavgwind
function stars(hglider_mag, ter, cu_pot, wind, bsratio_mag, slvl, HGflag) 
local hglider, stars
begin
	; WARNING: params here are in feet & Knots
	; hglider, ter, blavgwind & cu_pot need conversion

	hglider = 3.28084 * hglider_mag ; Convert to feet
	cupot  = 3.28084 * cu_pot      ; Convert to feet
	if(HGflag) then
		wind_local = 2.2369363 * wind	; Convert to mph(!?)
	else
		wind_local = 1.9438445 * wind	; Convert to Kts
	end if

	; Start with hglider
	stars = hglider
	stars = where(hglider .gt. 4000.0, 5000, stars)
	stars = where(hglider .le. 4000.0, 4000, stars)
	stars = where(hglider .le. 3500.0, 3000, stars)
	stars = where(hglider .le. 3000.0, 2000, stars)
	stars = where(hglider .le. 2500.0, 1000, stars)
	stars = where(hglider .lt. 1500.0, 0000, stars)
	; print("stars(hglider): Min = " + min(stars) + " Max = " + max(stars) )

	; If it's the same as the Terrain, rating must be 0
	stars = where(stars .eq. ter * 3.28084, 0, stars)
	; print("stars(ter): Min = " + min(stars) + " Max = " + max(stars) )

	; Apply modification for "small puffy clouds"
	; Criterion is small(ish) clouds if 500 < cu_pot < 5000
	; If cu_pot < 0 => blue
	; print("stars - cupot: Min = " + min(cupot) + " Max = " + max(cupot) )
	stars = where(cupot .gt. 500.0 .and. cupot.lt.5000.0, stars + 500.0, stars)
	stars = where(cupot .lt. 0.0                        , stars - 500.0, stars)
	; print("stars(cu_pot): Min = " + min(stars) + " Max = " + max(stars) )

	; Wind Reduction and bsratio adjustment

	MAXWIND = 15.0	; Winds (Kt) less than this do not reduce rating

	; NB Star ratings are 0 - 5000
	if(HGflag) then
		; updated 16/5/2014 sreduction = 1000.0 * (0.043 * (wind_local ^ 2.0) - 0.71 * wind_local + 3)
		sreduction = where( wind_local .gt. 8.0 , 1000.0 * (0.047 * (wind_local ^ 2.0) - 0.74 * wind_local + 2.9), 0)
	else
		sreduction = where( wind_local .lt. MAXWIND, MAXWIND, wind_local)
		sreduction = 250 * ((sreduction - MAXWIND)^2.0) / sreduction
	end if
	; print ( " stars No Wind "+min(stars)+","+max(stars) ) 
	stars = stars - sreduction
	stars = stars > 0
	; print("stars(wind_local): Min = " + min(stars) + " Max = " + max(stars) )

	;;;;; bsratio Adjustment ;;;;;;
	; stars += (bsratio - 3) * 300
	; 3 is No Adjustment; +/-300 for each integer away from this
	; Max bsratio is 6
	; Min adjustment -900 @ bsratio = 0
	; Max adjustment +900 @ bsratio = 6
	; Note bsratio cannot be < 0!

	MAXBSRATIO = 6.0  ; Very seldom better than this in the UK :-)
	bsadjust = where(bsratio_mag .gt. MAXBSRATIO, MAXBSRATIO, bsratio_mag)
	stars = stars + ((bsadjust - 3.0) * 300)
	stars = stars > 0
	; print("stars(bsratio): Min = " + min(stars) + " Max = " + max(stars) )

	;;; End bsratio adjustment				

	; Pentreath's adjustment
	if( HGflag ) then
		; updated 16 May 2014 sreduction = 0.0077*(slvl-1001)^2 - 0.323*(slvl-1001) + 3.4
		sreduction = 0.0062*(slvl-1002)^2 - 0.29*(slvl-1002) + 3.4
		stars = stars - 1000 * sreduction
		stars = stars > 0
		; print("pentreath: min = "+min(sreduction)+" max = "+max(sreduction))
	end if
	; end Pentreath

	; Spatially filter the Rating
	; Here you can choose your filter :-)
	; Only FIR filters supported
	; N_coeffs should be odd, to avoid shift

	; The coeffs should probably be selected by gridspacingkm,
	; To give similar results for each resolution (??)

	; wgt = (/ 1., 1, 1, 1, 1/) ; Simple (1/n, 1/n, ... ) filter

	; wgt = (/                                  1.,       1.                                      /)	; Don't use N_coeffs is even
	; wgt = (/                              1.,      2.,       1.                                 /)
	; wgt = (/                          1.,     3.,       3.,      1.                             /)	; Don't use N_coeffs is even
	; wgt = (/                      1.,     4.,       6.,      4.,      1.                        /)
	; wgt = (/                  1.,     5.,      10.,     10.,      5.,      1.                   /)	; Don't use N_coeffs is even
	  wgt = (/              1.,     6.,     15.,      20.,     15.,      6.,     1.               /)
	; wgt = (/          1.,    7.,     21.,      35.,      35.,      21.,    7.,      1.          /)	; Don't use N_coeffs is even
	; wgt = (/       1.,    8.,    28.,     56.,      70.,      56.,     28.,     8.,     1.      /)
	; wgt = (/   1.,    9.,    36.,     84.,     126.,     126.,     84.,     36.,    9.,    1.   /)	; Don't use N_coeffs is even
	; wgt = (/1.,   10.,   45.,    120.,    210.,     252.,     210.,    120.,    45.,   10.,   1./)

	; Ensure coeffs sum to 1.0 to avoid scale change
	wgt = wgt / sum(wgt)

	; Filter Horizontally
	; stars = wgt_runave(stars, wgt, -1)	; Cyclic conditions
	stars = wgt_runave(stars, wgt, 0)       ; Unsmoothed beginning and end pts to _FillValue
	; stars = wgt_runave(stars, wgt, 1)	; Reflective (symmetric) conditions
	; print ( " stars Filtered " + min(stars) + "," + max(stars) ) 

	; Transpose array
	stars!0 = "x"
	stars!1 = "y"
	stars_T = stars(y|:, x|:)

	; Filter transposed array (i.e. vertically)
	stars_T = wgt_runave(stars_T, wgt, 0)

	; Transpose back again
	stars_T!0 = "x_T"
	stars_T!1 = "y_T"
	stars_U = stars_T(y_T|:, x_T|:)

	; Normalize to 0 - 5
	stars_U = stars_U / 1000.0

	; print ( " stars_U Filtered " + min(stars_U) + "," + max(stars_U) ) 

	stars_U@_FillValue = 0.0001

	return(stars_U)
end

;
; BLWIND
;
procedure blwind(z, ter, pblh, nx, ny, nz, ua, va, windspeed, ublavg, vblavg )
begin
	;;; calc bl avg winds for plotting
	ublavg = new( (/ny,nx/), float)
	calc_blavg(ua,z,ter,pblh, nx,ny,nz, ublavg )

	vblavg = new( (/ny,nx/), float)
	calc_blavg(va,z,ter,pblh, nx,ny,nz, vblavg )

	windspeed = sqrt(ublavg * ublavg + vblavg * vblavg)
end

;
; SFCWIND0 (2m wind)
;
procedure sfcwind0(ua, va, uplot, vplot, mag)
begin
	uplot = ua(0,:,:)
	vplot = va(0,:,:)
	; mag = (uplot ^ 2.0 + vplot ^ 2.0) ^ 0.5
	mag = sqrt(uplot * uplot + vplot * vplot)
end

;
; SFCWIND (10m wind)
;
procedure sfcwind(ua, va, uplot, vplot, mag)
begin
	uplot = ua(1,:,:)
	vplot = va(1,:,:)
	; mag = (uplot ^ 2.0 + vplot ^ 2.0) ^ 0.5
	mag = sqrt(uplot * uplot + vplot * vplot)
end

;
; SFCWIND2 (30m wind)
;
procedure sfcwind2(ua, va, uplot, vplot, mag)
begin
	uplot = ua(2,:,:)
	vplot = va(2,:,:)
	; mag = (uplot ^ 2.0 + vplot ^ 2.0) ^ 0.5
	mag = sqrt(uplot * uplot + vplot * vplot)
end

;
; BLTOPWIND
;
procedure bltopwind(ua, va, z, ter, pblh, isize, jsize, ksize, uplot, vplot, mag)	; Wind at BL top
begin
	calc_bltopwind(ua,va,z,ter,pblh, isize,jsize,ksize, uplot,vplot )

	mag = sqrt(uplot * uplot + vplot * vplot)
end


;
; WRF=<param>
; Plot an arbitrary 2d/3d parameter name
;  2D paramname = "wrf=FILEparameterNAME" where FILEparamNAME is name used for NetCDF WRF output file
;  3D paramname = "wrf=FILEparameterNAME=level#" where level#=0 for lowest atm (highest soil) level
;     (note that 3D level is at constant model level, NOT constant MSL, AGL, or pressure)
;
function wrf(a, plot_param)
begin
	; param_array = split_string_into_array( plot_param, "=" )
	param_array = str_split( plot_param, "=" )
	dims = dimsizes(param_array)
        data = wrf_user_getvar(a, param_array(1), time)
        if( dims .eq. 2 ) then        ; 2D array
                bparam = data
        else ;;; **** NOT TESTED **** ;;; 3D array
                ;;; *NB* WARNING TOP-MOST LEVEL IN SOME ARRAYS HAS MISSING VALUES THERE ! eg qcloud
                ;;; 3D SIZES CHECKED SAME FOR Z,T,uz,wa,qcloud,
                datadims = dimsizes(data)
                kkdata = datadims(0)
                jjsize = datadims(1)
                iisize = datadims(2)
                if ( ismissing(iisize) ) then
                        print( "*** REQUESTED ARRAY "+plot_param+" IS NOT 3D - DIMS="+datadims )
                        exit
                else
                        level=  stringtointeger( param_array(2) )
                        bparam = data(level,:,:)
                end if
        end if
        delete ( data )

	return(bparam)
end

;
; WSTAR
;
function wstar(xsiz, ysiz, zsiz, vhf, pblh, hfx, tc)
local wstar
begin
	wstar = new( (/ysiz, xsiz/), float)

	calc_wstar( vhf, pblh, xsiz, ysiz, zsiz, wstar )

	return(wstar)
end

;
; ZBLCL
;
function zblcl(qvapor, z, ter, pblh, pmb, tc, isize, jsize, ksize)
begin
	qvaporblavg = new( (/jsize,isize/), float)
	calc_blavg(qvapor,z,ter,pblh, isize,jsize,ksize, qvaporblavg )

        bparam = new( (/jsize,isize/), float)
        calc_blclheight( pmb, tc, qvaporblavg, z, ter, pblh, isize,jsize,ksize, bparam )

	return(bparam)
end

;
; ZBLCLDIF
;
function zblcldif(ter, pblh, zblcl_mag)
begin
	return(pblh + ter - zblcl_mag)
end

;
; ZSFCLCL
;
function zsfclcl(pmb, tc, td, z, ter, pblh, isize, jsize, ksize)
begin
        bparam = new( (/jsize,isize/), float)
        calc_sfclclheight( pmb, tc, td, z, ter, pblh, isize,jsize,ksize, bparam )
	; Bombs - Out of CUDA Memory

	; Another Horrible hack - see BLCLOUDPCT
	; N = 41
	; print("*** WARNING: Only " + N + " levels")
        ; calc_sfclclheight( pmb(0:N,:,:), tc(0:N,:,:), td(0:N,:,:), z(0:N,:,:), ter, pblh, isize,jsize,N+1, bparam )

	return(bparam)
end

;
; ZSFCLCLDIF
;
function zsfclcldif(ter, pblh, zsfclcl_mag)
begin

	tmp = (pblh + ter - zsfclcl_mag)
	return(tmp)
end

;
; ABOVEBLWICW
;
function aboveblicw(qcloud, ppert, pb, z, ter, pblh, isize, jsize, ksize)
begin
        ptot = ppert + pb
	bparam = new( (/jsize,isize/), float)
	calc_aboveblinteg_mixratio( qcloud, ptot, z, ter, pblh, isize,jsize,ksize, bparam )

	return(bparam)
end

