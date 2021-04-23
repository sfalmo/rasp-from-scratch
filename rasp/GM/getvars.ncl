; PART OF plot_parameter() - See plot_param.ncl
; Put in separate file for readability
;
; http://www.mmm.ucar.edu/wrf/users/docs/user_guide_V3/users_guide_chap5.htm#fields
; Shows what is available
; "ncdump - h <wrfout_file> shows what's actually there 

alat     := wrf_user_getvar(f, "XLAT", time)     ; Lat & lon for maps			1
alon     := wrf_user_getvar(f, "XLONG", time)	;					2
ua       = wrf_user_getvar(f, "ua", time)       ; in m/s				U (10)
ua@_FillValue = 0.001
va       = wrf_user_getvar(f, "va", time)	;					V (11)
va@_FillValue = 0.001
wa       = wrf_user_getvar(f, "wa", time)       ; vertical velocity, averaged to mass levels in m/s	W (12)
thetac   = wrf_user_getvar(f, "T", time) + 26.85;					15
mu       = wrf_user_getvar(f, "MU", time)       ; multiplier needed for d(QC)/dt	22
mub      = wrf_user_getvar(f, "MUB", time)      ; multiplier needed for d(QC)/dt	23
ppert    = wrf_user_getvar(f, "P", time)        ; for perturb press in Pa		26
pb       = wrf_user_getvar(f, "PB", time)       ; for base press in Pa			27
tc2      = wrf_user_getvar(f, "T2", time)       ; 2m temp in C				38
; Not used?! t2       = wrf_user_getvar(f, "T2", time)       ; Only == bparam !!			38
psfc     = wrf_user_getvar(f, "PSFC", time)     ; for surface press in Pa		40
rdx      = wrf_user_getvar(f, "RDX", time)      ; inverse x grid length			43
rdy      = wrf_user_getvar(f, "RDY", time)      ; inverse y grid length			44
qcloud   = wrf_user_getvar(f, "QCLOUD", time)   ; NB: sometimes also "rh"!!		52
qvapor   = wrf_user_getvar(f, "QVAPOR", time)   ; water vapor mixing ratio in kg/kg	51
cldfra   = wrf_user_getvar(f, "CLDFRA", time)   ; cloud fraction (0-1)			114
swdown   = wrf_user_getvar(f, "SWDOWN", time)   ; Only == bparam !!			115
rqcblten = wrf_user_getvar(f, "RQCBLTEN", time) ; for d(QC)/dt				133
pblh     = wrf_user_getvar(f, "PBLH", time)     ; bl depth (metres)			141
hfx      = wrf_user_getvar(f, "HFX", time)      ; for sfc. sensible heat flux in w/m2	142
rh       = wrf_user_getvar(f, "rh", time)       ; relative humidity in percent		QVAPOR (51); P (26); PB (27); T (15); 
td2      = wrf_user_getvar(f, "td2", time)      ; 2m dew point temp in C		Q2 (32); P (26); PB (27);
td       = wrf_user_getvar(f, "td", time)       ; dew point temperature (C)		QVAPOR (51); P (26); PB (27); 
tc       = wrf_user_getvar(f, "tc", time)       ; temperature (C)			T (15); P (26); PB (27);
tc@_FillValue = -999.0

if(Jack) then	; DrJack's wrf_user_getvar()
	; uv       = wrf_user_getvar(f, "umeta", time )  ; u,v NOT rotated to grid   in m/s
	uEW      = wrf_user_getvar(f, "umet", time )     ; u,v rotated to earth   in m/s	V (11); U (10)
	vNS      = wrf_user_getvar(f, "vmet", time )     ; u,v rotated to earth   in m/s	V (11); U (10)
	slvl     = wrf_user_getvar(f, "slvl", time)      ; Sea Level Pressurea			T (15); P (26); PB (27); QVAPOR (51); PH (13); PHB (14)
	pmb      = wrf_user_getvar(f, "p", time)         ; press is vertical coordinate in mb	P (26); PB (27);
	z        = wrf_user_getvar(f, "Z", time)	 ;					PH (13); PHB (14);
else        	; NCL wrf_user_getvar()
	uv       = wrf_user_getvar(f, "uvmet", time )    ; u,v NOT rotated to grid   in m/s
	uEW      = uv(0,:,:,:)                           ; u,v rotated to grid   in m/s
	vNS      = uv(1,:,:,:)                           ; u,v rotated to grid   in m/s
	slvl     = wrf_user_getvar(f, "slp", time)       ; Sea Level Pressure
							 ; "slp" should work for both V5 & V6
	pmb      = wrf_user_getvar(f, "pressure", time)  ; press is vertical coordinate in mb
							 ; "pressure" should work for V5 AND V6
	z        = wrf_user_getvar(f,"z", time)
end if

paramdims= dimsizes(z)                                ; Get Dimensions
nz       = paramdims(0)
ny       = paramdims(1)
nx       = paramdims(2)
delete(paramdims)


vhf      = wrf_user_getvar(f, "LH", time)	; Must be after hfx
minlimit2d( vhf, 0.0, nx, ny )

; vhf = where(vhf .lt. 0.0, 0.0, vhf)
vhf = hfx +  0.000245268*(tc(0,:,:)+273.16)*vhf

ter      = wrf_user_getvar(f, "HGT", time)      ; terrain height in meters (2D)
trunc_2darray_min ( ter, nx,ny, 1. )

dx        = f@DX
dy        = f@DY
gridspacing = sqrt(0.5 * (dx^2 + dy^2))
if( gridspacing .lt. 10000. ) then
	gridspacingkm = sprintf ( "%.1f", (0.001*gridspacing) )
else
	gridspacingkm = sprintf ( "%.0f", (0.001*gridspacing) )
end if


projlat1  = f@TRUELAT1
projlat2  = f@TRUELAT2
projlon   = f@STAND_LON
centerlat = f@CEN_LAT
centerlon = f@CEN_LON


; Get Soundings (i,j) from lat & lon spec'd in rasp.region_data.ncl (aka rasp.ncl.region.data)
do idx = 1, info@nsoundings
	locr = wrf_user_find_ij_lat_long(f, info@sounding_lats(idx), info@sounding_lons(idx))
	info@i(idx) = floattointeger(locr(0))	; Note 0 based, but i[0] & j[0] not used here
	info@j(idx) = floattointeger(locr(1))
end do
delete(idx)
if(isvar("locr")) then
	delete(locr)
end if
