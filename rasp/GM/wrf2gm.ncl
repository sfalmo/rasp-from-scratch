;;; PLOT LAMBERT-CONFORMAL PROJECTION WRF DATA AS MERCATOR PROJECTION IMAGE

;;; PAULS - developed from ...
;;; JACK - altered from http://www.ncl.ucar.edu/Support/talk_archives/2006/1026.html
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Determine Version of NCL we are running
nclv = get_ncl_version()                  ; returns string like 6.0.0 or 5.2.1
nclv_c = stringtochar(nclv)               ; create array of chars
vnum=stringtoint(chartostring(nclv_c(0))) ; turn first char turns into an int

;;; Load NCL scripts
;;;
;;; Must use loadscript() - not load() - as in a condtional
;;; Load Order is significant
if(vnum .lt. 6) then
	print("NCL VERSION 5")
	print("*** THIS CODE REQUIRES NCL V6")
	print("*** RASP supplies V5")
	print("V6 may be avaliable in your distro")
	print("Try 'yum list ncl' or equivalent")
	exit
else
	loadscript("$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl")
	loadscript("$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl")
	loadscript("$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl")
	loadscript("$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl")
end if

; Flag for those who do not use curr+1 etc
; If missing, or == 0, Use curr+n
curr_only =  getenv("CURR_ONLY")

getvar = getenv("GETVAR")
if(ismissing(getvar)) then
	Jack = True
else
	if(getvar .eq. "DRJACK") then
		Jack = True
	else
		Jack = False
	end if
end if

if(Jack) then
	loadscript("wrf_user_mass.ncl")	; Required if using DrJack's wrf_user_getvar()
else
	print("*** WARNING: Using NCL wrf_user_getvar()")
	; Built into NCL
end if

; external NCL_JACK_FORTRAN "./ncl_jack_fortran.so"
; test_cuda = False
; NCL_JACK_FORTRAN :: cuda_set_debug(0)
;  NCL_JACK_DEBUG_MEMTIME	2  
;  NCL_JACK_DEBUG_CUDA_MALLOC	4
;  NCL_JACK_DEBUG_COMPARE	8
;  NCL_JACK_DEBUG_DIM		16
;  NCL_JACK_DEBUG_ALL		255
; test_cuda = True
; NCL_JACK_FORTRAN :: cuda_set_debug(255)

;;; *****************************************************************************************
;;; GLOBAL VARIABLES
;;; NB: Global variables MUST appear before any Functions / Procedures in which they are used
;;;     Beware: due to Call By Reference, the func/proc can change value(s)

;;;
;;; Constants for the Whole Run
;;;

CONVERT = getenv("CONVERT") ; Now uses "gm convert" if available, else "convert", as set in runGM script

BaseDir = getenv("BASEDIR")
Region  = getenv("ENV_NCL_REGIONNAME")
Files   = getenv("ENV_NCL_FILENAME")
Projection = str_lower(getenv("PROJECTION"))

if(ismissing(Files)) then
	delete(Files)
	if( ismissing(Region) .or. ismissing(BaseDir)) then
		print("You must export BASEDIR and REGION")
		print("Files looked for in $BASEDIR/$REGION")
		print("Alternatively, export ENV_NCL_FILENAME (full pathname)")
		exit
	end if
	FileDir = BaseDir + "/" + Region + "/"
	cmd = "ls " + FileDir + "wrfout_d02*"
	Files = systemfunc(cmd)
	delete(cmd)
end if

OutDir  = getenv("ENV_NCL_OUTDIR")
if(ismissing(OutDir)) then
	print("WARNING: No ENV_NCL_OUTDIR")
	print("         Using '.' for OutDir")
	print("         Export ENV_NCL_OUTDIR to change")
	OutDir = "."
else
	print("Output files in " + OutDir)
end if
OutDir = OutDir + "/"

;;;; Get Output Type
;;   Options are "x11", "ncgm" or "png"
FMT = getenv("FMT")
if(ismissing(FMT)) then
	FMT = "png"
end if

; Specifiy (maximum) Image Width and Height in Pixels
; GMIMAGESIZE should be passed in from GM.pl
img_size = stringtofloat(getenv("GMIMAGESIZE"))
if( ismissing(img_size) ) then
	wkHeight = 1600.0
	wkWidth  = 1600.0
	print( "Using default GMIMAGESIZE = " + wkWidth)
else
	wkHeight = img_size
	wkWidth  = img_size
	print( "Using specified GMIMAGESIZE = " + img_size)
end if

;; Other Constants
time = 0	; Seems time is always 0 for DrJack's code
cdbl = 0.003	; Coefficient of Drag for Boundary Layer 
cwbasecriteria = 0.000010	; Cloud Water criterion

UNITS = "american"	; default value - updated by getRegionData() below

opts_ter                 = True
; If you really want terrain contour lines on your plot, uncomment this line
; opts_ter@cnLinesOn       = True
; But if you _don't_ want terrain contour line Labels, also uncomment this line
; opts_ter@cnLineLabelsOn =  False

; ***********************************************************************************
;;; Load our scripts
;;; Order significant :-(

load "utils.ncl"
load "skewt_func.ncl"
load "calc_funcs.ncl"
load "colourlevels.ncl"
load "wks.ncl"
load "labelbar.ncl"
load "header.ncl"
load "wrf_plot.ncl"
load "plot_funcs.ncl"

regionInfo = getRegionData(Region)
UNITS = regionInfo@UNITS

ParamList = getParams( getenv("ENV_NCL_PARAMS"))
print("ENV_NCL_PARAMS:")
do p = 0,dimsizes(ParamList)-1
	print("    " + ParamList(p))
end do
;****************************************************************

do fnum = 0, dimsizes(Files)-1
	print("*** Doing " + Files(fnum))
	plot_parameters(Files(fnum) + ".nc", ParamList, regionInfo)
	print("*** Done " + Files(fnum))
end do

; Now do params that run once only for the whole F/C
do p = 0, dimsizes(ParamList)-1
	if(ParamList(p) .eq. "avgstars")
		print("*** Doing avgstars")
		do_avgstars()
	end if
	if(ParamList(p) .eq. "pfd_tot")
		print("*** Doing pfd_tot")
		do_pfd()
	end if
end do

print("NORMAL END of wrf2gm.ncl")

; NCL_JACK_FORTRAN :: ncl_jack_cleanup()

quit
