; Script generating Meteograms for RASP BLIPMAPS
; TJ Olney - Tonino Tarsi 2019 - Blipmaps.nl
; Renamed Windgram to Meteogram as much more info is included.

; USAGE: ncl meteogram.ncl DOMAIN=\"yourdomainname\"
; Perhaps you need to change the locations where to find your wrf-data, blipmap parameter-data and sitedata.ncl file
; Change the logo file if you like and check if you use d2.data or need to change to w2.data
; Add your meteogram locations to the sitedata.ncl file, for example 1,Terlet,d2,5.9233,52.0567,

; Document your changes and change the version number. BM stands for Blipmaps
meteogram_version = "20210318"
wrf_version = "3.6.1"

; Changes in BM20210209 - ABC
; -Added non-metric conversion option
; -Added option to use paraglider symbol
; -Modified placement of surface sun and 2m wind speed and direction to allow for changing ptop
; -Corrected 3-digit wind direction to handle 1 digit directions properly
; -Minor spacing corrections in legend

; Changes in BM20210118
; -Added Meteogram version also on plot
; -Changed winddirection @ 2m AGL to always show 3 digits
; -Changed 1,2m/s in legend5 to 1,14m/s
; -Increased locX,LocY gridpointnumbers by +1,+1 only on the Meteogram plot and printout, see explanation below
; -Added PFD to plot
; -Changed font from F14 to F21 Helvetica
; -Changed resolution from 800x800 to 900x900
; -Added "meteogram_" as prefix to output filename
; -Added sunrise and sunset times
; -Added text all times are local

; Earlier changes to https://github.com/ToninoTarsi/windgramtt version Jan 3, 2020
; -Changed bregion into Domain to use the parameter data files
; -Removed tstride for multiple parameters that use data files to get all half hour results shown
; -Removed times to have all WRF data files being used for our model run and changed start_time_margin to 1.5 
; -Added windspeed and winddirection @ 2m AGL at the bottom
; -Moved CAPE values to the top
; -Changed legend text bottom and added legend m/s AMSL on top
; -Slightly darkened the snowflake symbol/0 degree level so that it is visible over white 100% relative humidity/clouds


; TJ Olney's - Tonino Tarsi 2019  windgram local lapserate and lcl generator
; Requires ncl 5.1.1 for addfiles
; Replace your domains regions sites wlats wlons and wgrids for those below
; can invoked without args and will print the default windgram to x11 display
;
; USAGE:  ncl windgramtt.ncl DOMAIN=\"domainname\" [ptop=nn] [rhcut = nn ] [show_[xxx]=[0|1]]
;
; rhcut is a number 1-99 for relative humidity.  Default is 95 so >95%rh gets cross hatched.
; Choose your favorite number to cross hatch the time/heights with high enough rh for clouds 
; if invoked with ncl DOMAIN=\"domainname\"  it will do all the sites in that domain
; ptop is the number of levels, don't go over 3 less than the number of levels in the model, RASP usually 52-3=49
; as is, it calculates lcl three different ways and you must change it in the gsn_csm_addpolymarkers = command if you want to try another
; it has not been completely "error trapped" but it catches some.
;
; New 7/4/2009 posting no blipspots used to gather data, they are recalculated using DrJack functions.
; cldfra_plot added to plot conditionally if there are supposed to be clouds, this is quite experimental, don't know what it will look like in practice.
; hgldj_p used to plot little overturned crescent moons that happen to look a bit like paragliders (couldn't find any better wings) 
; using drjack's lcl measure... quite close to lcl1 from lclvl(). You can plot both simply by uncommenting the line
; define default data source for testing purposes
; add command line cldfra_cut decimal for % at which to say it is cloudy enough to try to plot clouds.
;
; Coordinates space fix for windbarbs added. 2011_08_05
; Andrea Barcellona's fix to correct for the map projection and put windbarbs on a                                       
; N-S vertical E-W horizontal coordinate system when the grid is tilted from due N-S
 
BASEDIR=getenv("BASEDIR")
NCARG_ROOT=getenv("NCARG_ROOT")  

; Options chosen:

show_pfd = 0
non_metric = 0
use_paraglider = 0

if (.not.isvar("DOMAIN")) then
   print("Usage: windgramtt.ncl DOMAIN=domainname SITEDATA=sitedata.ncl [ptop=nn] [rhcut = nn ] [show_[xxx]=[0|1]]")
   exit
end if

;;; Uncomment lines below to show debug print log
if (.not.isvar("debug")) then       ;debug surrounds numerous diagnostic print statements set to anything other than 0 for verbose printing
   debug=0
end if 

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
external NCL_JACK_FORTRAN "$BASEDIR/GM/LIB/ncl_jack_fortran.so"  ;  

dayNames = (/"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"/)


;--------------------------- function for reading data from a blipmap .dat file.  Tonino Tarsi 2019 ---------------


; undef("getblipmap_data")
; function  getblipmap_data(bregion:string,bparam:string ,bnumtimes:integer, bnumy:integer,bnumx:integer)
; local filecommand1,fs,a,i,retData
; begin
;    retData = new( (/bnumtimes,bnumy,bnumx/), float)         ; has a time dimension

;    filecommand1= "ls $BASEDIR/"+bregion+"/OUT/" + bparam + ".curr*.data "  ;
;    fs = systemfunc( filecommand1 )      ; 
   
;    do i=0,bnumtimes-1
;        print("getblipmap_data - Reading :  " + fs(i))
;        ;print(dimsizes(retData))
;        a = readAsciiTable(fs(i),bnumx,"float",4 )
;        ;print(dimsizes(a))
;      retData(i,:,:) = a
;    end do
;    return (retData)
; end

;;; ROUTINE TO SPLIT STRING INTO ARRAY BASED ON INPUT DELIMITER CHARACTER (single character only)
undef("split_string_into_array")
function split_string_into_array( inputstring:string, delimiter:string )
local string_chars, temp_strings, string_array, string_max, nstrings, ichar,ichar1,ichar2
begin
      ;;; convert delimiter-delimited environmental string into parameter array (what a mess!)
      ;4testprint: print ( "INPUTSTRING= "+inputstring )
      string_chars = stringtochar( inputstring )
      string_max  = dimsizes(string_chars)-2
      ;;; temporary array determines maximum parameter names
      temp_strings = new( (/300/), string)
      ichar1=0
      nstrings=-1
      do ichar=1,string_max
         ; allow for either delimiter or no-delimiter at end of string
         if( string_chars(ichar).eq.delimiter .or. ichar.eq.string_max) then
         nstrings = nstrings +1
         if( ichar.eq.string_max) then
            ichar2 = string_max
         else
            ichar2 = ichar-1
         end if
         temp_strings(nstrings) = chartostring( string_chars(ichar1:ichar2) ) 
         ;4testprint: print ( "NAME= "+nstrings+" : "+ichar1+"-"+ichar2+" => "+temp_strings(nstrings) )
         ichar1= ichar+1
         end if
      end do    
      string_array = new( (nstrings+1), string)
      do iname=0,nstrings  
         string_array(iname) = temp_strings(iname)
      end do    
   return(string_array)
end
;;;---------------------------------------------------------------------------------


operator = "aufwin.de"
default_type = "png"
default_ptop = 40                        ; usually 20, I changed for TS upper instability
;                                          Note! changing ptop modifies the y-axis and messes with plot positioning
default_rhcut = 95
tilted_grid=0                             ; set to 1 if your grid is tilted from NS to cover an oblique area like England or Italy.
one_site = False                          ; ??? why needed? see near line 369
testndx=0                                 ; in case a site requested out of range

; Color choice (must be in the palette being used or the closest one will be used) 

foreground_color= "black"
background_color= "white"



;background_color= (/.5, .5, .9 /)         ; color could be set even with RGB triplet (this example is a deep purple-blue)

label_color= foreground_color    
wstar_color= foreground_color
line_color= 10                            
templine_color= 14
colorpalette = ""

;;; options to display or not on the windgram   
;;; the check for existing variable allows them to be passed on the command line.

if (.not.isvar("white_clouds")) then
   white_clouds=1 ; 
end if

if (.not.isvar("use_only_hours")) then
   use_only_hours=0 ; 
end if

if (.not.isvar("tmp_units")) then
   tmp_units = 1		; change to 0 for C for Celsius, 1 for Fahrenheit; only affects the show_temp variable.
end if

if (.not.isvar("show_cutop")) then
   show_cutop = 1		; CUTOP (top of convection level from cumulus par)
end if


if (.not.isvar("show_sun")) then
   show_sun = 1			; "Solar radiation % from Blipmap
end if

if (.not.isvar("show_hct")) then
   show_hct = 0			; "Cloud top height from TEMF PBL" Requite TEMF schema .. expermental
end if

if (.not.isvar("show_od")) then
   show_od = 1
end if

if (.not.isvar("show_blcloudpct")) then
   show_blcloudpct = 1
end if

if (.not.isvar("show_cape")) then
   show_cape = 1
end if

if (.not.isvar("show_cape_3d")) then
   show_cape_3d = 0
end if

if (.not.isvar("show_condense")) then
   show_condense = 0
end if

if (.not.isvar("show_cloudfrac")) then
   show_cloudfrac = 1
end if

if (.not.isvar("show_wind")) then
   show_wind = 1                   ; plot the windbarbs
end if

if (.not.isvar("color_wind_barbs")) then
   if (show_wind.eq.1) then
      color_wind_barbs=0             ; change this if you want the wind barbs to be colored by a scalar of their speed  note units  
   else
      color_wind_barbs=1
   end if
end if 

if (.not.isvar("show_rain")) then
   show_rain=1                    ; change to 1 if you want to show rain. TJ 6/1/2011
   show_this_rain=0
end if

if (.not.isvar("show_lapse")) then
   show_lapse = 1                 ; local level to level lapse rate
end if

if (.not.isvar("show_wing")) then
   show_wing  = 1                 ; hg/pg 225 ft/min (1.2 m/s) soaring level markers
end if

if (.not.isvar("show_lcl")) then
   show_lcl   = 1                 ; little clouds for lifted condensation level
end if

if (.not.isvar("show_snow")) then
   show_snow  = 0                 ; lowest freezing level
end if

if (.not.isvar("show_pbl")) then
   show_pbl   = 1		        ; boundary layer line 
end if

; if ((show_wing.ne.0).or.(show_lcl.ne.0).or.(show_snow.ne.0).or.(show_pbl.ne.0))   ; force lapse if any of the others
;    show_lapse = 0
; end if

if (.not.isvar("hide_lapse_colors")) then
   hide_lapse_colors=0            ; any other value will make all colors transparent for lapse so it doesn't show but still provides scaffold for other stuff.
end if

if (.not.isvar("show_rh")) then
   show_rh     = 1                 ; relative humidity greater than rh_cut, cheap trick for clouds in the BL; TJ use 95%
end if

if (.not.isvar("show_temp")) then
   show_temp   = 1                 ; temperature contours
end if

if (.not.isvar("show_up_vel")) then
   show_up_vel = 1                 ; show vertical velocity W* at top of time column set to 0 if no access to DRJack Fortran modules.
end if

if (.not.isvar("show_z_contour")) then
   show_z_contour = 0              ; draw a contour line for the altitude attaching pressure level in the morning to corresponding altitude in evening
   z_stride=4                      ; extra spacing between altitude contour lines
end if

if (.not.isvar("show_p_contour") .and. show_z_contour.ne.0 ) then
   show_p_contour= 1               ; draw a contour line for the pressure level in the morning to corresponding altitude in evening
   p_stride=z_stride               ; extra spacing between altitude contour lines
else
   show_p_contour= 0
end if

;;;;;
if (.not.isvar("show_sfcwind")) then
   show_sfcwind = 1
end if
;;;;;


;;;;;;;;;;;;;;;;;
if (.not.isvar("show_pfd")) then
   show_pfd = 1
end if
;;;;;;;;;;;;;;;;;


;;; where to find the wrfout files to use as raw data.
;;; don't complain about fallbacks when parameters are out of range.

err = NhlGetErrorObjectId()
setvalues err
   "errLevel" : "Fatal"         ; only report Fatal errors
end setvalues
if (.not.isvar("type")) then
   type = default_type
end if
if (.not.isvar("ptop")) then
   ptop = default_ptop
end if
if (.not.isvar("rhcut")) then
   rhcut = default_rhcut
end if
   
; this only works if domain names have WINDOW or not   

if (isvar("DOMAIN"))
   if (isStrSubset(DOMAIN, "WINDOW"))
         grid="w2"
      else
         grid="d2"
   end if
end if


; generate house keeping data

offsetstring= systemfunc("date +%z")
pstpdt= systemfunc("date +%Z")
mm_dd=systemfunc("date -u +%b-%d")
fcstday=systemfunc("date +%d' '%B' '%Y")
yyyy_mm_dd=systemfunc("date -u +%Y-%m-%d")
offset = stringtoint(offsetstring)/100
xaxis_msg =""

if (debug.ne.0)
   print("")
   print("------------------------")
   print("Windgrams initialization")
   print("------------------------")
   print("offsetstring: "+offsetstring)
   print("pstpdt: "+pstpdt)
   print("mm_dd: "+mm_dd)
   print("fcstday: "+fcstday)
   print("yyyy_mm_dd: "+yyyy_mm_dd)
   print("offset: "+offset)
end if

; Site(s) setup

; domaindata.ncl contains a simple list of domains one per line to be processed and associated with the sites in sitedata.ncl
; PNW-WINDOW
; sitedata.ncl contains long, lat, grid domain and name information each site on a row comma delimted.
; PNW-WINDOW,Iron,w2, -121.94, 48.48,

; must be careful not to let any trailing spaces into sitedata.ncl
; it is read and processed and sorted by region and NS into different arrays by readsitelist.ncl
; I have in the same file a debug mode that generates lists for javascripts and html menus from all the sites to ease web maintenance

if (debug.ne.0)
   print("")
   print("----------------------------------")
   print("Start of readsitelist.ncl printout")
   print("----------------------------------")
end if

;load "readsitelist.ncl"

; _____________________read site list__________________________________________________

sitefile="sitedata.ncl"
if (isvar("SITEDATA"))
   sitefile = SITEDATA
end if
print("Using " + sitefile)

domains = (/ DOMAIN /) 
tmpallsite_params=asciiread(sitefile, -1, "string")
sqsort(tmpallsite_params)
allsite_params=tmpallsite_params
delete(tmpallsite_params)
numdomains=dimsizes(domains)        ;number of domains is number of  lines in the domain file.
numsites=dimsizes(allsite_params)   ; We now have the total number of sites in the database.
print("There are "+numdomains+" domains and a total of "+numsites+" sites in the "+sitefile+" site file.")

site_params=new((/6,numsites /),string)       ; ncl array of the original data plus an index number in zero position
sitedomain_ndx=new(numsites,integer)          ; should have the index number corresponding to the domain from the domains array

j = 0
do i=0,numsites-1
   print(allsite_params(i))
   print(str_index_of_substr(allsite_params(i),"#",0))
   if ( ismissing(str_index_of_substr(allsite_params(i),"#",0) ) ) then 
      site_params(0,j)=j   ; assign a site number and put it in position zero
      site_params(1:,j)=split_string_into_array(allsite_params(i),"," )
      site_params(1,j)= DOMAIN
      j= j+1
   end if 
end do

numsites = j
site_params := site_params(:,:j-1)

site_ndx = stringtointeger(site_params(0,:))  ; make it an integer array for use as a subscript  
sitedomain = site_params(1,:)
sitename = site_params(2,:)
sitegrid = site_params(3,:)
sitelon = stringtofloat( site_params(4,:) )
sitelat = stringtofloat( site_params(5,:) )

domain=sitedomain
sites=sitename
wlats=sitelat
wlons=sitelon
wgrids=sitegrid
regions=sitedomain

sites_in_domain=new(numdomains,integer)

sites_in_domain(0)=numsites

;______________________________________________________________________________________


if (debug.ne.0)
   print("--------------------------------")
   print("End of readsitelist.ncl printout")
   print("--------------------------------")
end if

;delete(SITES)
;delete(locations)                 ; not used so delete

numdomains=dimsizes(domains)
numsites=dimsizes(sites)
numregions=dimsizes(regions)
numsitesperdomain=new(numdomains,integer)
wsites=new(numsites,string)
wlon=new(numsites,float)
wlat=new(numsites,float)

if (debug.ne.0)
   print("")
   print("numdomains: "+numdomains)
   print("numsites: "+numsites)
   print("numregions: "+numregions)
   print("")
end if

do i=0,numdomains-1
   numsitesperdomain(i)=num(regions.eq.domains(i))    ; count the sites in each domain
   if (debug.ne.0) 
      print("domain("+i+") = "+domains(i)+" and it has "+numsitesperdomain(i)+" sites held in numsitesperdomain("+i+")" )
   end if
end do;

; Discover what we are doing and set up looping parameters for it; what about an "all" case

if (isvar("DOMAIN").and.DOMAIN.eq."all")
   if (debug.ne.0) 
      print ("Doing all Domains ") 
   end if
   numloops=numdomains-1      ; set to loop through domains
else
   numloops = 0               ; only using one set of wrfout files
end if

; Begin domains outer loop once for each domain, go through it once if numloops is 0 

do nd=0,numloops

if (debug.ne.0) 
   print("")
   print("-----------------------")
   print("Start outer domain loop")
   print("-----------------------");
   print("")
end if

thisdomain_ndx=nd
region=domains(nd)                          ; regions and domains are the same no window added

if (debug.ne.0)
   print("thisdomain_ndx is "+thisdomain_ndx) 
   print("Top domain: "+region)                ; in RASP each named region may have one or two domains 
end if		 		            ; hi-res grids for domains are designated w2 lo-res d2

; not all but a DOMAIN is being plotted
; code block DOMAIN, extract domain_ndx as pointer 

if (isvar("DOMAIN").and.(DOMAIN.ne."all"))  ; if domain other than all is passed, find it and set region to it

   if (debug.ne.0) 
      print ("A domain has been passed on the command line: "+DOMAIN+", one of "+numdomains+" possible domains")
   end if

   do i=0,numdomains-1
      if ( (DOMAIN .eq. domains(i)).or.(DOMAIN.eq.str_upper(domains(i))) ) then
         region=domains(i) 
         thisdomain_ndx=i

         if (debug.ne.0) 
            print("The domain "+DOMAIN+" was asked for. Its index is now set to "+thisdomain_ndx+" or thisdomain_ndx")
         end if
         break
      end if
      j=i+1
      if (j.eq.numdomains)
         print("There is no domain known by the name of "+DOMAIN+". Did you mean "+DOMAIN+"-WINDOW perhaps ?")
         exit
      end if
   end do;  

end if ; end if (isvar("DOMAIN").and.(DOMAIN.ne."all"))  ; if domain other than all is passed, find it and set region to it.
                                                         ; then do the same for the region

; if a single SITE is passed, find the appropriate members of the arrays
; code block SITE

if (isvar("SITE"))
   do i=0,numsites-1             ; go thru sites until you find the one passed.
      if ( (SITE .eq. sites(i)).or.(SITE.eq.str_upper(sites(i))) ) then
         wsites(0)=sites(i)
         wlon(0)=wlons(i)
         wlat(0)=wlats(i)
         wgrid=wgrids(i)
         region=regions(i)
         DOMAIN=regions(i)
         thissite_ndx=site_ndx(i)
         one_site= True
         numtodo=1       
         loopstart=thissite_ndx

         print("Code block SITE: single site passed "+SITE+" which is site "+sites(site_ndx)+", value of thissite_ndx is "+thissite_ndx)     
         break                      ; found it nothing to gain by carrying on.
      end if  
   end do;
   testndx=i+1
else
   one_site= False
end if                   ; end isvarsite

if (testndx.ge.numsites)
   print("You have entered a request for a site, "+SITE+" not in the sitedata.ncl file. ")
   print(sites)
   exit
end if

; nothing passed, so just do the default to the workstation
; code block NOTHING PASSED DEFAULT WINDGRAM


if (.not.isvar("DOMAIN").and.(.not.isvar("SITE") )) then
   print ("no SITE or DOMAIN variable using defaults to x11 workstation. Default parameters")
	thissite_ndx=34               ; choose the default index set all else from that.
   wsites(0)=sites(thissite_ndx)
   wlon(0)=wlons(thissite_ndx)
	wlat(0)=wlats(thissite_ndx)
	wgrid=wgrids(thissite_ndx)
	region=regions(thissite_ndx)
	DOMAIN=regions(thissite_ndx)
	one_site= True
	numtodo=1
	loopstart=thissite_ndx
   SITE=sites(thissite_ndx)
   if (type.eq."ncgm")
	   type="x11"
	end if
   print("")  
   print("---------------- Running default windgram ----------------");
   print("DOMAIN = "+DOMAIN)
   print("SITE = "+SITE+" whose index is "+thissite_ndx)
   print("")  
   
   ; something was passed to the script so use it to decide what to plot
   ; if DOMAIN, region has already been set if SITE parmams have been set
   ; so remaining case is DOMAIN without SITE so arrays of sites in the domain must be set
   ; DOMAIN is region(domain_ndx) is also region
else   

   print("There is a domain = "+DOMAIN )

   ; no domain so see if there is a site
   ; they are the whole possible arrays but re assign them by checking whether site is in domain

   if (one_site.eq.False) then
      testdomain= DOMAIN

      ; Get new arrays for just this domain/region - Why ???

      jay=0 
      do i=0, numsites-1                ;  must check them all to find which belong
         if (regions(i).eq.region)  then       ; .or.(regions(i)+"-WINDOW".eq.region)) - WINDOW is now part of the domain/region name.
            print("for sitename(i) "+sitename(i)+" site_ndx "+site_ndx(i)+" sitedomain(i) "+sitedomain(i)+" matches "+testdomain+" ")
            wsites(jay)=sites(i)
            print ("sites("+i+")="+sites(i) )
            wlon(jay)=wlons(i)
            wlat(jay)=wlats(i)                   
            wgrid=wgrids(i) 

            if (debug.ne.0) 
               print ("sites("+i+")="+sites(i) )
               print( "wlon(jay)="+wlon(jay)+" wlons(i) = "+wlons(i)+"wlat(jay)="+wlat(jay)+" wlats(i) = "+wlats(i)  )
            end if

            if (jay.eq.0)
               thissite_ndx=i
            end if
            jay=jay+1
         end if

         if (jay.eq.1)
            one_site=True
         end if
      end do;
   end if   
end if

;  end if (.not.isvar("DOMAIN").and.(one_site.eq.False ))

if (.not.isvar("numtodo"))
   numtodo=sites_in_domain(thisdomain_ndx)
end if
if (numtodo.eq.1)
   one_site=True
end if

if (debug.ne.0) 
   print("")  
   ;print("Generating windgrams for region "+region+", grid "+wgrid+" has "+numtodo+" sites")  
   ;print("domain_ndx = "+domain_ndx)
   print("")  
   print("wsites,wlon,wlat,wgrid,region")
   do i=0,numtodo-1
      print(wsites(i)+","+wlon(i)+","+wlat(i)+","+wgrid+","+region)
   end do;
end if



if (debug.ne.0)
   print(" ")
   print("Plotting parameters: ")
   print(" ")
   print("tilted_grid = "+tilted_grid)
   print("ptop = "+ptop)
   print("Output plot type = "+type)
   print("show_lapse = "+show_lapse)
   print("show_wind = "+show_wind)
   print("color_wind_barbs = "+color_wind_barbs)
   print("show_rh = "+show_rh)
   print("rhcut = "+rhcut)
   print("show_temp = "+show_temp)
   print("debug = "+debug)
   print("tmp_units = "+tmp_units)
   print("show_condense = "+show_condense)
   print("show_rain = "+show_rain)
   print("show_wing = "+show_wing)
   print("show_lcl = "+show_lcl)
   print("show_snow = "+show_snow)
   print("show_pbl = "+show_pbl)
   print("show_cloudfrac = "+show_cloudfrac)
   print("hide_lapse_colors = "+hide_lapse_colors)
   print("show_up_vel = "+show_up_vel)
   print("show_z_contour = "+show_z_contour)
   print("show_p_contour = "+show_p_contour)
end if


; Data ingest from wrfout files and digest

if ( use_only_hours.eq.1 ) then
   filecommand1= "ls $BASEDIR/"+region+"/wrfout_d02_* | egrep -v ':30|:03:|04:|05:|06:|17:|18:'"  ; default CUCCO set at top
else
;   filecommand1= "ls $BASEDIR/"+region+"/wrfout_d02_* | egrep -v ':03:|04:|05:|06:|17:|18:'"  ; default CUCCO set at top
   filecommand1= "ls $BASEDIR/"+region+"/wrfout_d02_* | egrep -v ':03:|04:|05:'"  ; default CUCCO set at top
end if

print("")
print("WRF data files are found as "+BASEDIR+"/"+region+"/wrfout_d02_*")
print("Forecast date is UTC "+yyyy_mm_dd+" "+offset+" to get "+pstpdt )
print("")

; if ( wgrids(idx) .eq. "w2" ) then  ; obsolete
; region=regions(i)+"-WINDOW"
; end if

; set at top


fs = systemfunc( filecommand1 )      ; fs becomes an array of full filenames, no more needs deleting between domains
onefile=fs(0)                        ; get a single file from which to get geographic data, time labels, etc

print("Processing these data files: ")  
print(fs+" ") 
print("")
print("Fixed parameters, ter, z, etc, being looked up in the file :")
print(onefile+" ")

a = addfiles(fs+".nc","r")          ; addfiles grabs all the files in the list above at once.
timesinfiles = a[:]->Times          ; get date & time from wrfout files
b = addfile(onefile+".nc","r")      ; addfiles grabs the file used for fixed parameters

p=a[:]->P                           ; perturbation pressure (Pa) for a time,ptop,long,lat array  
pb=a[:]->PB                         ; base state pressure (Pa) for a time,ptop,long,lat array
press=p                             ; bring along metadata
press = p + pb                      ; total pressure 
pmb=press/100                       ; convert total pressure in hPa

pdims=dimsizes(press)               
numlevels=pdims(1)
numtimes=pdims(0)
numy=pdims(2)
numx=pdims(3)
taus=ispan(0,numtimes-1,1)       ; coordinate variable for Time dimension  
ilevels=ispan( 0,numlevels-1,1)

tkall=a[:]->T                    ; perturbation potential temperature
tkall = tkall + 300              ; as per wrfuser
tk = wrf_tk( press , tkall )     ; temperature Kelvin
tc=tk
tc = tk - 273.16
tc@units = "C" 

ter=a[:]->HGT                    ; meters above sea level 
pblh=a[:]->PBLH                  ; meters pbl thickness 
pblt= ter + pblh	          ; height of top of pbl meters

tmpu =a[:]->U                 
tmpv =a[:]->V                 
u = wrf_user_unstagger(tmpu,tmpu@stagger) 
v = wrf_user_unstagger(tmpv,tmpv@stagger)

QVAPOR = a[:]->QVAPOR         
td=wrf_td(press,QVAPOR)          ; get the dewpoint everywhere, use for all sites
rh = wrf_rh(QVAPOR, press, tk)   ; get the relative humidity everywhere, use for all sites

; PH  = a[:]->PH
; PHB = a[:]->PHB
; PH =  PH + PHB
; PSFC = a[:]->PSFC                                    ; don't use for RASP time 0 is always = 0 
; z = wrf_user_unstagger(PH,PH@stagger)/9.81           ; On full (w) levels

z = wrf_user_getvar(a,"z",-1)   ; ToninoTarsi 2019   Get z direcly from wrf in meters . http://www.ncl.ucar.edu/Document/Functions/WRF_arw/wrf_user_getvar.shtml

dimv = dimsizes(z)

zmeter = z                                           ; used below in meters
zft = z*3.2808
z@units = "m"
z!0 = "Time"
z!1 = "levels"
z!2 = "south_north"
z!3 = "west_east" 
z&Time = taus


zmeter@units = "m"
zmeter!0 = "Time"
zmeter!1 = "levels"
zmeter!2 = "south_north"
zmeter!3 = "west_east" 
zmeter&Time = taus

zft@units = "ft"
zft!0 = "Time"
zft!1 = "levels"
zft!2 = "south_north"
zft!3 = "west_east"
zft&Time = taus

mslp = wrf_slp( zmeter, tk, press, QVAPOR ) 

;mslp = wrf_user_getvar(a,"slp",-1)   ; ToninoTarsi 2019   


if ( show_hct.ne.0) then  ;  ToninoTarsi 2019 check if we run TEMF schema 
   if ( isfilevar(b,"HCT_TEMF") ) then
      hct = a[:]->HCT_TEMF
   else
      show_hct = 0
   end if 
end if 


if ( show_cutop.ne.0) then  ;  ToninoTarsi 2019 check if CUTOP present in WRF data 
   if ( isfilevar(b,"CUTOP") ) then
      cutop = a[:]->CUTOP
      cubot = a[:]->CUBOT
   else
      print("Warning ... CUTOP not founf in WRF output")
      show_cutop = 0
   end if 
end if 


;;;;;;; TIME settings
; Nog veranderen data files zijn in local standard time, wrf files zijn in UTC. Verschil tussen eind tijden bepalen en dan WRF aanpassen

dims = dimsizes(timesinfiles)       
times = new(dims(0),string)                ; string representation of the times in the files 
caption = new(dims(0),integer)
lst = new(dims(0),integer)                 ; put local time into this for labels
lst_string = new(dims(0),string)           ; put local time in string variable for labels  
lst_string_striped = new(dims(0),string)           ; put local time in string variable for labels  
lst_is_hour = new(dims(0),integer)

start_time_margin = 1.5
;start_time_margin = 1.0
;if ( use_only_hours.eq.1 ) then
;   start_time_margin = 0.5
;end if

do i=0,dims(0)-1
    times(i) = chartostring(timesinfiles(i,8:15))
    tmp = chartostring(timesinfiles(i,11:12))
    caption(i) = stringtoint(tmp)            ; +"."+chartostring(t(2,10:12))
    lst(i) = caption(i)+offset              ; convert UTC to local standard time 

   ; make times 12 hour local clock

    if ( lst(i).lt.1 )               ; negative numbers add 24
       lst(i)= lst(i)+24
    end if

   ; add ".00" to local time

   lst_string(i) = sprinti("%0.2i", lst(i)) + ":" + chartostring(timesinfiles(i,14:15))
   lst_string_striped(i) = sprinti("%0.2i", lst(i)) +  chartostring(timesinfiles(i,14:15))
   lst_is_hour(i) = str_index_of_substr(lst_string(i),":00",-1)

;;;;;
; To do: Check if summer/wintertime is correct based on difference WRF (UTC/GMT) time and Parameter data (LST) time
;;;;;

   ora_solare = True


   if ( ora_solare ) then 
      if ( lst_string(i).eq."09:00") then
         start_time_index = i - start_time_margin
      end if
      if ( lst_string(i).eq."18:30") then
         stop_time_index = i + start_time_margin
      end if
   else
      if ( lst_string(i).eq."10:00") then
         start_time_index = i - start_time_margin
      end if
      if ( lst_string(i).eq."19:30") then
         stop_time_index = i + start_time_margin
      end if
   end if
end do


;;;;;; Below changed bregion into "/"+DOMAIN

undef("getblipmap_data")
function  getblipmap_data(DOMAIN:string,bparam:string ,bnumtimes:integer, bnumy:integer,bnumx:integer)
local filecommand1,fs,a,i,retData
begin
   retData = new( (/bnumtimes,bnumy,bnumx/), float)         ; has a time dimension

   do i=0,bnumtimes-1
      filecommand1 = BASEDIR+"/"+DOMAIN+"/OUT/" + bparam + ".curr." + lst_string_striped(i) + "lst.d2.data" 
      print(filecommand1)
      if ( fileexists(filecommand1) ) then 
         a = readAsciiTable(filecommand1,bnumx,"float",4 )
         retData(i,:,:) = a
      else
         retData(i,:,:) = default_fillvalue("float")
         print("no data for "  + bparam + " at " + lst_string_striped(i))
      end if
   end do

   return (retData)
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
undef("getpfd_data")
function  getpfd_data(DOMAIN:string,bparam:string,bnumy:integer,bnumx:integer)
local filecommand2,fs,a,i,retData
begin
   pfdData = new( (/bnumy,bnumx/), float)
      filecommand2 = BASEDIR+"/"+DOMAIN+"/OUT/" + bparam + ".data" 
      print(filecommand2)
      if ( fileexists(filecommand2) ) then 
         a = readAsciiTable(filecommand2,bnumx,"float",4 )
         pfdData(:,:) = a
      else
         pfdData(:,:) = default_fillvalue("float")
         print("no data for "  + bparam)
      end if

  return (pfdData)
end

if (show_pfd.ne.0) then
    pfd_day = getpfd_data(region,"pfd_tot",numy,numx)
end if
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;

if (show_rain.ne.0) then
   rain1_multitime = getblipmap_data(region,"rain1",numtimes, numy,numx)
end if

if (show_sun.ne.0) then
   sfcsunpct_multitime = getblipmap_data(region,"sfcsunpct",numtimes, numy,numx)
end if


if (show_cape_3d.ne.0) then

   c3d = wrf_user_getvar(a,"cape_3d",-1)   ; ToninoTarsi 2019  
   cape3d_multitime = c3d(0,:,:,:,:)
   cin3d_multitime =  c3d(1,:,:,:,:)

   cape2d_multitime = dim_max_n(cape3d_multitime,1)
   cin2d_multitime = dim_max_n(cin3d_multitime,1)


   cinfo = wrf_user_getvar(a,"cape_2d",-1) 
   mcape = cinfo(0,:,:,:)
   mcin  = cinfo(1,:,:,:)
   lcl   = cinfo(2,:,:,:)
   lfc  = cinfo(3,:,:,:)

end if


if (show_cape.ne.0) then
   cape_multitime = getblipmap_data(region,"cape",numtimes, numy,numx)
end if

if (show_blcloudpct.ne.0) then
   blcloudpct_multitime = getblipmap_data(region,"blcloudpct",numtimes, numy,numx)
end if

if ( show_od.ne.0) then
   zblcldif_multitime = getblipmap_data(region,"zblcldif",numtimes, numy,numx)
   zblcl_multitime = getblipmap_data(region,"zblcl",numtimes, numy,numx)
end if

;;;;;
if (show_sfcwind.ne.0) then
   sfcwind0dir_multitime = getblipmap_data(region,"sfcwind0dir",numtimes, numy,numx)
   sfcwind0spd_multitime = getblipmap_data(region,"sfcwind0spd",numtimes, numy,numx)
end if
;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; To calculate Wstar up velocity
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if ( .not. isvar("vhf") ) then
   if ( .not. isvar("hfx") ) then
      hfx = a[:]->HFX                ;,time) ; for sfc. sensible heat flux in w/m2
   end if
                                 ; convert latent heat flux into additional virtual temperature heat flux
                                 ; 0.61*cp/L=0.61*(1006J/Kkg)/(2.502x106J/kg)=0.000245268
   vhf = a[:]->LH 

   ; DRJACK routines calculate for only one time period so vhf is only 2d, not 3d 
   ; must calculate for each period
   ; hcrit wstar sfclcl directly 

   do i=0,numtimes-1
         NCL_JACK_FORTRAN::minlimit2d( vhf(i,:,:), 0.0, numx,numy )
         vhf(i,:,:) = hfx(	i,:,:) +  0.000245268*(tc(i,0,:,:)+273.16)*vhf(i,:,:)
   end do;      

end if  ; That should fully populate vhf    
      ; s_n w_e

wstar = new( (/numtimes,numy,numx/), float)         ; has a time dimension
wstar_1 =new( (/numy,numx/), float)                 ; no time dimension, returned by NCL_JACK_FORTRAN 
hcrit = new( (/numtimes,numy,numx/), float)         ; has a time dimension
hcrit_1 =new( (/numy,numx/), float)                 ; no time dimension, returned by NCL_JACK_FORTRAN
sfclclheight = new( (/numtimes,numy, numx/), float)
sfclclheight_1 = new( (/numy, numx/), float)
hglider_1 = new( (/numy, numx/), float)
hglider = new( (/numtimes,numy, numx/), float)
	
; NCL_JACK_FORTRAN :: calc_wstar( vhf,pblh, isize,jsize,ksize, wstar )
; use DrJack's 2d functions for other parameters of interest -- loop over numtimes

do i=0,numtimes-1
   if (show_up_vel.ne.0.or.show_wing.ne.0) then
      NCL_JACK_FORTRAN :: calc_wstar( vhf(i,:,:),pblh(i,:,:), numx,numy,numlevels, wstar_1 )
      wstar(i,:,:)=wstar_1                     ; put result for this iteration into the i time slot for all wstar
   end if
   if (show_wing.ne.0) then
      NCL_JACK_FORTRAN :: calc_hcrit( wstar_1, ter(i,:,:), pblh(i,:,:), numx,numy, hcrit_1 )
      hcrit(i,:,:)=hcrit_1
   ; hcrit(i,:,:)=hcrit_1*3.28084             ; to feet ; put result for this iteration into the i time slot

   end if
   if (show_lcl.ne.0 .or. show_wing.ne.0) then    ; need it to calculate hcrit of wing even if lcl not shown
      NCL_JACK_FORTRAN :: calc_sfclclheight( press(i,:,:,:), tc(i,:,:,:), td(i,:,:,:), zmeter(i,:,:,:), ter(i,:,:), pblh(i,:,:), numx,numy,numlevels, sfclclheight_1 )
      sfclclheight(i,:,:)=   sfclclheight_1    ; put result for this iteration into the i time slot
   end if
end do;    


; sfclclheight=sfclclheight*3.28084        ; meters to feet

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Wstar calculated for whole region
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

llres = True
llres@ReturnInt = True                     ; return integer values
llres@MAP_PROJ  =b@MAP_PROJ
llres@TRUELAT1  =b@TRUELAT1
llres@TRUELAT2  =b@TRUELAT2
llres@STAND_LON =b@STAND_LON
llres@DX        = b@DX
llres@DY        = b@DY
XLAT  = b->XLAT(0,:,:)
XLONG = b->XLONG(0,:,:)




day=chartostring(timesinfiles(1,0:9))
plotday=systemfunc("date --date="+day+" +%d' '%b' '%Y")
print ("Plotday is "+plotday)
print ("For day "+day+" for "+region+" numtimes is number of times available = "+numtimes)  ; leave in report


theYear = stringtointeger(chartostring(timesinfiles(1,0:3))) 
theMonth = stringtointeger(chartostring(timesinfiles(1,5:6)))
theDay  = stringtointeger(chartostring(timesinfiles(1,8:9)))

theWeekNumber = day_of_week(theYear,theMonth,theDay)
theDayName = dayNames(theWeekNumber)

feet=new(pdims(1),float)

; End of whole domain definitions 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Setup sites loop pull out bits for the site location
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; debug start ;;;
if (debug.ne.0)
print("top of loop loopstart = "+thissite_ndx+" index of first site in domain after sorting sites by domain, with "+numtodo+" sites in the region to do \n\n"  )
end if 
;;; debug end ;;;

if (numtodo.eq.1) then
   loopstart=thissite_ndx

   ;;; debug start ;;;
   if (debug.ne.0)
      print(" before being used as subscript, loopstart = "+loopstart)
   end if
   ;;; debug end ;;;

   loopend=loopstart                    ; only for onesite case
   wlon(loopstart)=wlons(loopstart)
   wlat(loopstart)=wlats(loopstart)
   wsites(loopstart)=sites(loopstart)
   print ("Running a one_site case for site "+thissite_ndx+",  "+wsites(loopstart) )
else
   loopstart=thissite_ndx
   loopend=loopstart+numtodo-1
   print ("Running a domain case for "+region)
end if

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Actual start of do loop for sites in one region
; ns tracks which site  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

do ns=loopstart,loopend               ; for one loxY locX at a time.

   outdir=BASEDIR+"/"+region+"/OUT/"   ; windgram output directory, 
   wpt_code := str_split(sites(ns), " ")
   if ( dimsizes(wpt_code).eq.0 ) then
      continue
   end if 
;windgram=outdir+wpt_code(0)
;Added meteo_ as prefix to file
   windgram=outdir+"meteogram_"+wpt_code(0)

   ;windgram=outdir+day+"_"+sites(ns)

   ;;; debug start ;;;
   if (debug.ne.0) then
   print("   ")
      print("   ")
      print(" loopstart = "+loopstart)
      print("--------------------top of loop---------------------")
      print(" loopend =  "+loopend)
      print("   ")
      print("   ")
      print("windgram fullpathname = "+windgram+" output to "+type)
   end if
   ;;; debug end ;;;

   ; Set up the Workstation for this site
   ; must be destroyed at end of loop must be within the loop color array can be outside though
   ; wks = gsn_open_wks(type , windgram) ; open a workstation as type with constructed name

   type@wkWidth = 900
   type@wkHeight = 900

   wks = gsn_open_wks(type, windgram)

   ; create an array to be the colors each triplet is a color and the index of the triplet is the reference to that color 
   ; multiply the array by 1.0 to turn it into float values 
   ; then divide by 255 to put them in the required 0-1 range.
   ; note these colors were chosen for 1) ability to tell color changes 2)symbolism of the colors red=hot and danger
   ; orange not so much
   ; pink and purple are perfect
   ; light colors are light lift
   ; matching the background is stable
   ; greys are inversion dark times for soaring pilots.

   if (colorpalette.eq."")
      updcolors=(/ (/255,255,255/),\
         (/128,128,230/),\
         (/255,255,255/),\
         (/250,240,230/),\
         (/200,255,200/),\
         (/120,255,120/),\
         (/21,255,21/),\
         (/255,187,255/),\
         (/204,191,255/),\
         (/255,204,0/),\
         (/255,153,0/),\
         (/255,61,61/),\
         (/230,230,230/),\
         (/204,204,204/),\
         (/153,153,153/),\
         (/0,0,0/),\
         (/255,  56,  255/),\     
         (/255,  150, 255/),\      
         (/255,  196, 255/),\      
         (/255,  216, 255/),\      
         (/255,  236, 255/),\      
         (/255,  248, 255/),\      
         (/255,  248, 255/),\      
         (/255,  248, 255/),\
         (/255,  255, 0/)/) * 1.0      

      ; last index is 24 is yellow for contrasting fonts

      updcolors=updcolors/255                      ; but they must be in 0-1 range
   else
      updcolors=colorpalette
   end if

   ;;; Colors by TJ

   ; gsn_define_colormap(wks, updcolors)          ; generate new color map
   ;   setvalues wks
   ;    "wkForegroundColor" : foreground_color   ; set at top  
   ;    "wkBackgroundColor" : background_color   ; set at top
   ; end setvalues 

   ;;; Colors by TT

   gsn_define_colormap(wks,"rainbow")  ; use customized color map from my RASP installation
   setvalues wks
   "wkColorMap": "rainbow"
   "wkForegroundColor" : "black"
   "wkBackgroundColor" : "white"             
   end setvalues
   newindex = NhlNewColor(wks,1.0,0.0,1.0)     ; 190 Magenta for Paraglider
   newindex = NhlNewColor(wks,0.4,0.4,0.6)     ; 191 Dark Grey for BL Top
   newindex = NhlNewColor(wks,0.9,0.9,0.9)     ; 192 Grey for cloud
;   newindex = NhlNewColor(wks,1.0,1.0,1.0)     ; 193 White for snowflake
   newindex = NhlNewColor(wks,0.8,0.8,0.8)     ; 193 White for snowflake

   ; Start with definitions for each site in the domain

   ;;; debug start ;;; 
   if (debug.ne.0) then
      print("Site loop counter = "+thissite_ndx)
   end if
   ;;; debug end ;;;
   
   locij = wrf_user_ll_to_ij(b, wlons(ns),wlats(ns), llres)
   locij = locij - 1        ; array pointers in NCL space one less than wrf space.
   
   locX = locij(0)
   locY = locij(1)

   ;;; debug start ;;;
   if (debug.ne.0) then
      print(" ")
      print ("                       at wlons("+ns+") = "+wlons(ns)+" which gives locY = "+locY)
      print ("                       at wlats("+ns+") = "  +wlats(ns)+" which gives locX = "+locX)
      print(" ")
   end if
   ;;; debug end ;;;

   ; Pressure levels

   maxp = max(press(:,:,locY,locX))/100 
   minp = min(press(:,:ptop-1,locY,locX))/100
   startp = round(press(0,0,locY,locX)+.5,0)/100

   plevels = round((press(0,:,locY,locX)/100)+.5,0)           ; array contains actual levels taken from wrfout file == rounded
   theselevels = plevels(0:ptop-1)                            ; theselevels contain only the levels up to ptop 
   z&levels = plevels                                         ; don't have plevels until locY locX  use as coordinate variable for z

   zhere = round(zft(:,:ptop-1,locY,locX)+.5,0)               ; create an array for only the levels to be plotted.
   zhere!0 = "Time"			                   ; label dimensions
   zhere!1 = "plevels"                          
   zhere&Time = taus                                          ; set coordinate variables for each named dimension
   zhere&plevels = theselevels                                ; 

   zhere_m = round(zmeter(:,:ptop-1,locY,locX)+.5,0)          ; metric height same process as above
   zhere_m!0 = "Time"
   zhere_m!1 = "plevels"
   zhere_m&Time = taus 
   zhere_m&plevels = theselevels

   zfeets = zhere+"'"                                         ; zfeets used for labels is a string by adding the '
   zmeters = zhere_m+"m"                                      ; zmeters+"m"  ;string for labels
   meters = zmeters(0,:)                                      ; get one dimensional array with these labels 
   feets = zfeets(0,:)			                   ; 
   feets!0 = "plevels"			                   ; name the dimension
   feets&plevels = theselevels                                ; add coordinate variable

   h = ter(0,locY,locX)      	                           ; terrain model height in meters
   hft = h*3.2808					           ; terrain model height in feets

   ; this goes to stdout therefore part of rasp.regionxyz.printout, change elevation units if desired.

   print(" ")

;;;;
;At blipmaps.nl we also run a click-on-the-map Blipspot to see the parameter data values behind the maps
;The Lat,Lon of the Blipspot and the Meteogram are the same and the data derived from the parameter data files is also the same
;But the locX,locY gridpointnumbers of Meteogram are -1,-1 compared to the Blipspot
;Therefore the gridpointnumbers are increased +1,+1 only on the Meteogram plot
;Nothing is changed in locX,locY in the process of deriving the parameter data values
;;;;;
lokY = locY+1
lokX = locX+1
;;;;;





print ("Meteogram for "+sites(ns)+" site:ns="+ns+" from the "+region+" "+wgrid+" region, Gridpoint: "+lokX+","+lokY+" Lat,Lon: "+wlats(ns)+","+wlons(ns)+" Model elevation: "+round(h,0)+"m AMSL" )
if (non_metric.eq.1) then
   fth = h * 3.28084
   print ("Meteogram for "+sites(ns)+" site:ns="+ns+" from the "+region+" "+wgrid+" region, Gridpoint: "+lokX+","+lokY+" Lat,Lon: "+wlats(ns)+","+wlons(ns)+" Model elevation: "+round(fth,0)+"ft AMSL" )
end if
;   print ("Meteogram for "+sites(ns)+" site:ns="+ns+" from the "+region+" "+wgrid+" grid at point "+locY+" "+locX+" "+wlons(ns)+" "+wlats(ns)+" model elevation:"+round(h,0)+"m ASL" )
   print("Pressure surface p "+round(maxp+.5,0)+"mb or "+round(h+.5,0)+"m up to ptop min  p value   "+minp)

;;;;;;;;;;;;;;;;;;;;;;;;;;



   ; print the z and pressure levels at which blip winds are being reported.

   ; do i=0,3
   ;    print("press level "+i+" ---> "+theselevels(i)+"mb at time "+lst(i)+":00 lst"  )
   ; end do

   ; extract measures for this site location from larger arrays, local variables start with l

   tkloc=tk(:,:,locY,locX)       	                 ; fill the temperature array at locY locX  tkloc  ...was tkall
   lp=press(:,:,locY,locX)       	                 ; local point press over time
   lqv=QVAPOR(:,:,locY,locX)                       ; 
   ltd = td(:,:,locY,locX)                         ; pull out dewpoints at this location
   ltd = ltd +273.3           	                 ; lclvl wants Kelvin dewpoint, so convert
   lmslp = mslp(:,locY,locX)                       ; sea level pressure in hPa

   ; l_cldfra = cldfra(:,:ptop-1,locY,locX)         ; cloud fraction for this location

   ;;; Cloud Fraction

   if (show_cloudfrac.ne.0) then
      cldfra = a[:]->CLDFRA

      ; now just at the focal point
      cldfrapoint = cldfra(:,:,locY,locX)

      ; and grid it, so it is only up to ptop with Time as rightmost dimension for plotting 

      cldfragrid = cldfrapoint(bottom_top|:ptop,Time|:)  
      cldfragrid@description ="Cloud Fraction"
   end if

   ;;; Top BL

   if (show_pbl.ne.0) then

      ;  lpblt=pblt(:,locY,locX)      ; point top of boundary layer in meters over time 1 dimension 
      ;  lpblt!0 = "time"                                     
      ;  lpblt&time = taus
      
      ;  lpblt_p = lmslp-(lpblt/32)
      ;  lpblt_p!0 = "time"                                     
      ;  lpblt_p&time = taus

      lpblt=pblt(:,locY,locX)         ; point top of boundary layer in meters

      ; Calculate pressure levels using z and interpolation

      lpblt_p = new(numtimes,float)

      do i=0,numtimes-1
         lpblt_p(i) = linint1_Wrap (round(z(0,:,locY,locX),0),plevels, False, lpblt(i), 0)
         if (ismissing(lpblt_p(i)))
            lpblt_p(i) = plevels(0)
         end if
      ; print("lpblt("+i+") = "+lpblt(i)+" lpblt_p = "+lpblt_p(i))

      end do
   end if

   if (show_up_vel.ne.0) then

      lwstar=floattointeger(round(wstar(:,locY,locX),0))
      mwstar=decimalPlaces((wstar(:,locY,locX)), 1, True)  ; shea utils has this function decimalplaces(x,places,true for round false for truncate)
;      mwstar=decimalPlaces((wstar(:,locY,locX)), 1, True)+" m/s"   ; shea utils has this function decimalplaces(x,places,true for round false for truncate) 
      ftwstar=decimalPlaces((wstar(:,locY,locX)*196.85), 0, True)

      swstartxt=mwstar

      if (non_metric.eq.1) then
        swstartxt=ftwstar
      end if

      ; swstartxt=mwstar+"m/s"                       ; choose your units for top of columns.
      ; swstartxt=lwstar+"fpm"                       ; choose fpm unit

   end if

   lsfclclheight=sfclclheight(:,locY,locX)       ;


   if (show_wing.ne.0) then
      lhcrit=hcrit(:,locY,locX)
      lhglider=lhcrit                               ; transfer metadata alter below 

      do i=0,numtimes-1
         if (lhcrit(i).le.lsfclclheight(i))
            lhglider(i)=lhcrit(i)
         else
            lhglider(i)=lsfclclheight(i)
         end if
      end do;
   end if

  

   lclj_p   =  lmslp-(lsfclclheight*3.28084/32)          ; approx mb from ft, remaining approximations...
   hgldj_p  =  lmslp-(lhglider*3.28084/32)               ; approx mb from ft, these are always approximations anyway, so being off a few feet is irrelevant



   ;;; Find lowest freezing level .lt. ptop

   if (show_snow.ne.0)
      freezelevel=new(numtimes,float)
      do j=0,numtimes-1 
         do i=0,ptop-1
            if (tkloc(j,i).le.273.15)                 ; find the level where temp falls below freezing
               freezelevel(j)=theselevels(i)            ; assign it to the scalar freezelevel for this time 
               break                                    ; once found do it for the next time 
            end if
         end do;
      end do;
   end if

   ;;; Condensation level

   if (show_condense.ne.0)
      condense=new((/numtimes, numlevels/) ,float)  		 ; try a condensation level by dewpoint=temp
      do j=0,numtimes-1 
         do i=0,ptop-1
            if (tkloc(j,i).le.(ltd(j,i)+.01))                 ; find any levels where temp "really close" to dewpoint call for condensation.
               condense(j,i)=1                               ; assign it to condense as 1 or 0 this time and altitude
         else
            condense(j,i)=0                               ; condense is a grid treat the same as rh.
            end if
         end do;
      end do;
   end if		     

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Calculate the lcl for clouds markers
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   lcl1=new(numtimes,float)        ; generate a variable with the dimensions of time and pressure 

   lcl1=lclvl(lp(:,0),tkloc(:,0) ,ltd(:,0))   ; calculates sfc LCL 
   lcl1=lcl1/100    
   lcl1=round(lcl1+.5,0)

   lp=lp/100
   lcl1@description="lifted condensation level"
   lcl1@units= "hPa"
   
   lcl4=(tkloc(:,0)-ltd(:,0))*400      ; alternate rule of thumb lcl
   lcl4=theselevels(0) - (lcl4/32)     ; back into pressure sort of..


   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; No draw cloud marker if CU potential < 0
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   do i=0,numtimes-1
      if (lcl1(i) .lt. lpblt_p(i))
         lcl1(i) = 0
      end if 
   end do






   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Calculate "local" lapse rates
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   if (isvar("lapseptop"))               ; when looping through sites this is needed to keep from generating coordinate variable errors 
      delete(lapseptop)
   end if

   if (isvar("ftdiffs"))
      delete(ftdiffs)
   end if

   lapseptop=press(:,:ptop-1,locY,locX)  ; create and bring along metadata from pressure
   lapseptop!0 = "Time"
   lapseptop!1 = "levels"
   lapseptop&levels = theselevels
   lapseptop&Time = taus

   
   ; heights_0 = press(:,:,locY,locX)                ; parent array for heights and diffs below
   ; heights_0=heights_0/100            		; convert to millibars -- hPa
   ; heights_1=heights_0(:,1:ptop)  			; keep the same dimensions but offset the matrix by 1
   ; height_zero=heights_0(:,0:ptop-1)     		; chop it down to the relevant range
   ; hdiffs=heights_1-height_zero        		; height differences in millibars

   ; ; note: the choice to present lapse as C/1000 ft is an arbitrary one based on the "inherited" pilot practices in the region where I live tjo

   ; ftdiffs=hdiffs*-32                              ; ftdiffs=hdiffs*-32
   ; ftdiffs=ftdiffs/1000             	        ; convert it to thousand of feet
   ; t_0=tkloc(:,0:ptop-1)              	        ; now create two temperature matricies
   ; t_1=tkloc(:,1:ptop)            		        ; t_1 is offset up one level
   ; tdiffs=t_1-t_0       			        ; and get the difference between them as deltaT  units are K but same size as C

   ;lapseptop= tdiffs/ftdiffs       	        ; this is now a matrix of time x height up to ptop of local lapse rates.

   lapseptop@units = "C/1000ft"

   lapseptop = center_finite_diff_n(tc(:,:ptop-1,locY,locX), zmeter(:,:ptop-1,locY,locX), False, 0, 1)   ; ToninoTarsi 2019 - Use buildin gradient function
   lapseptop = lapseptop*100
   lapseptop@units = "C/100m"

   lapseptop@description= "Local lapse rate"


 
   lgrid = lapseptop({levels|:},Time|:)            ; reverse x and y axis on this too. it is already constrained to ptop-1
   lgrid@description=""                            ; make it blank or a default it gets printed on the output
   lgrid@units=""  
   lgrid!0="levels"
   lgrid!1="Time"
   lgrid&levels=theselevels
   lgrid&Time=taus

   ;;;;;;;;;;;;;;;;
   ; Start windgram
   ;;;;;;;;;;;;;;;;

   u_point   = u(:,:,locY,locX)
   v_point   = v(:,:,locY,locX)

   if (tilted_grid.eq.1) then

      ; Andrea Barcelona's fix to correct for the map projection and put windbarbs on a 
      ; N-S vertical E-W horizontal coordinate system when the grid is tilted from due N-S
      ; where cosalpha and sinalpha are obtained from the wrfout file (b), they are the same for all times 

      cosalpha = b->COSALPHA(0,:,:)
      sinalpha = b->SINALPHA(0,:,:)
      u_point   = u_point*cosalpha(locY,locX) - v_point*sinalpha(locY,locX)
      v_point   = u_point*sinalpha(locY,locX) + v_point*cosalpha(locY,locX)
   end if

   ugrid     = u_point(bottom_top|:ptop-1,Time|:)*3.6                ; *3.6 is to convert from m/s to km/h
   vgrid     = v_point(bottom_top|:ptop-1,Time|:)*3.6                

   ; now give all the labels and things the same coordinate variable plevels

   plevels!0 = "levels"
   plevels&levels = plevels                ; it is its own coordinate variable hmmm.

   stplevels=flt2string(plevels)+" mb"     ; string plevels for pressure level labels
   stplevels!0="levels"
   stplevels&levels = plevels

   ; these were created reversed so time in in 2nd position.

   ugrid!0="levels"
   ugrid!1="Time"
   ugrid&levels=theselevels
   ugrid&Time=taus

   vgrid!0="levels"
   vgrid!1="Time"
   vgrid&levels=theselevels
   vgrid&Time=taus



   xaxis_msg= ""                                 ; default xaxis message becomes part of tiXAxisString

   ;;; Set basic text resources

   lbtxtres                    = True
   lbtxtres@txtFontQuality     = "High"
   lbtxtres@tiXAxisFont        = 21              ; Helvetica
   lbtxtres@txFuncCode         = "~"
   lbtxtres@txFontHeightF      = 0.013
   lbtxtres@txJust             = "CenterLeft"

   ;;; Set res2D resources

   res2D = True                                 ; res2D set basic resources for most other plots  

   ; gsn resources

   res2D@gsnDraw              = False           ; Don't draw individual plot.
   res2D@gsnFrame             = False           ; Don't advance frame.

   ; Viewport resources

; res2D@vpXF changes how windgram is positioned on total figure
;   res2D@vpXF                 = 0.10            ; .1 x location
   res2D@vpXF                 = 0.09            ; .1 x location
   res2D@vpYF                 = 0.92            ; y location
; res2D@vpWidthF changes the spacing between the results. Enlarged this to clearly show half hour results. Also enlarged type@wkWidth
;  res2D@vpWidthF             = 0.78            ; .82 width big!
   res2D@vpWidthF             = 0.82            ; .82 width big!
   res2D@vpHeightF            = 0.80            ; .8 was windgram alone  height

   ; Title resources 
   res2D@tiXAxisFuncCode       = "~"
   res2D@tiMainFont            = 21             ; helvetica
   res2D@tiXAxisFont           = 21            
   res2D@tiYAxisFont           = 21            
   ; res2D@tiXAxisOffsetYF       = .005           ; -.02 ; 16  ; '-' moves it slightly down, while '+' moves up ; .02 makes it nicely close to the time tickmarks
   ; res2D@tiYAxisOffsetXF       = -.06           ; moves it slightly to the left
   res2D@tiXAxisOffsetYF       = -.013
   res2D@tiYAxisOffsetXF       = -.02
   res2D@tiXAxisString         = xaxis_msg
   res2D@tiYAxisString         = " "
   res2D@tiXAxisFontHeightF   = 0.014
   res2D@tiYAxisFontHeightF   = 0.015
   res2D@tiMainFontHeightF    = 0.02
;   res2D@tiMainString         = sites(ns)+ " (" + round(h+.5,0)+ "m)" + " - " + theDayName + " " + plotday
   res2D@tiMainString         = sites(ns)+ " - " + theDayName + " " + plotday
   res2D@tiMainOffsetYF       = -0.01 

   ; Transformation resources

   ; res2D@trXMinF               = -0.5
   ; res2D@trXMaxF               = numtimes-0.5  
   res2D@trXMinF               = start_time_index  ; ToninoTarsi 2019
   res2D@trXMaxF               = stop_time_index  

   
   res2D@trYMinF               = min(theselevels)
   res2D@trYMaxF               = max(theselevels)


   ; theselevels_irregular = new(ptop,float)
   ; theselevels_irregular = ( ( sqrt( (theselevels - min(theselevels)) / (max(theselevels)- min(theselevels)) ) ) * (max(theselevels)- min(theselevels)) ) + min(theselevels)
   ; res2D@trYAxisType  = "IrregularAxis"               ; ToninoTarsi 2019 -- Use an irregular Y axis to emphasize usefull heigth 
   ; res2D@trYCoordPoints   = theselevels_irregular


   ; Text resources

   res2D@txtFontQuality="High"
   
   ; Label bar resources

   res2D@lbTitleFont = 21
   res2D@lbAutoManage = False                         ; test tjo see discussion on ncl-talk
   res2D@lbRightMarginF = 0.0
   res2D@lbJustification = "topleft"
   res2D@lbLeftMarginF = 0.0
   res2D@lbTopMarginF = 0.0 
   res2D@lbTitlePosition =  "Bottom"
   res2D@lbLabelPosition = "Top"
   res2D@lbLabelOffsetF = .01
   ; res2D@lbFontHeightF = .016                         ; default is .02
   res2D@lbLabelFontColor = label_color               ; default is foreground (white here)
   res2D@lbBoxMinorExtentF = .23                      ; .33 is default
   ; res2D@lbTitleOffsetF  = .05
   ; res2D@lbTitleExtentF = .05
   ; res2D@lbBoxMinorExtentF =                          ;  default is 1.0

   ; Graphic style resources

   res2D@gsFontQuality = "High"

   ; Set tickmark tstride based on resolution

   if (use_only_hours.eq.1)
      tstride=1
   else
      tstride=2
   end if



   ; Bottom tickmark resources


   res2D@tmXBOn                  = True
   res2D@tmXBBorderOn            = True
   res2D@tmXBLabelsOn            = True
   res2D@tmEqualizeXYSizes       = False
   res2D@tmXUseBottom            = False                       ; needed so top labels and ticks can be different from bottom
   res2D@tmXBMode                = "Explicit"

   res2D@tmXBValues              = taus(::tstride)
   res2D@tmXBLabels              = lst_string(::tstride)       ; times pst pdt??
   ;res2D@tmXBLabels           = lst(::tstride)   ;       gp aggiunge :00 alla fine   times   pst pdt??

   if ( use_only_hours.ne.1) then
      res2D@tmXBMinorValues      = taus
      res2D@tmXBMinorLengthF        = .01
      res2D@tmXBMinorOutwardLengthF = .01
   end if


   res2D@tmXBMajorLengthF        = .01
   res2D@tmXBMajorOutwardLengthF = .01
   res2D@tmXBLabelJust           = "CenterCenter"
   res2D@tmXBLabelFont           = 21
   res2D@tmXBLabelFontHeightF    = .011

   ; Top tickmark resources 

; Removed tstride below to show thermal velocity every half hour on top
   if (show_up_vel.ne.0) then
      res2D@tmXTOn                  = True
      res2D@tmXTBorderOn            = True
      res2D@tmXTLabelsOn            = True                  ; plot the wstar
      res2D@tmXTMinorOn             = False
      ;  res2D@tmXTMajorLineColor      = line_color
      res2D@tmXTMajorLengthF        = .01
      res2D@tmXTMajorOutwardLengthF = .01
      res2D@tmXTMode                = "Explicit"
;      res2D@tmXTValues              = taus(::tstride)
      res2D@tmXTValues              = taus

;      res2D@tmXTLabels 	         = swstartxt(::tstride)  ; wstar string form as top label
      res2D@tmXTLabels 	         = swstartxt  ; wstar string form as top label
      res2D@tmXTLabelFontColor      = wstar_color
      res2D@tmXTLabelFontHeightF    = .012
      res2D@tmXTLabelFont           = 21
      res2D@tmXTLabelJust           = "BottomCenter"
      res2D@tmXTLabelDeltaF         = -0.8
   end if

   res2D@tmXBLabelFont        = 21
   res2D@tmXBLabelJust        = "CenterCenter"
   res2D@tmXBLabelFontHeightF = .012
   res2D@tmXBMajorLengthF     = .01

   ; Left Y axis

   ystride=floattointeger(round(ptop/9,0))  ; generate reasonable stride value much closer than automatic 

   res2D@tmYLLabelFuncCode    = "~"
   res2D@tmYLLabelFont        = 21                               ; helvetica http://www.ncl.ucar.edu/Document/Graphics/font_tables.shtml
   res2D@tmYLLabelFontColor   = label_color
   res2D@tmYLMajorLengthF     = .01   
   res2D@tmYLLabelDeltaF      = .01
   res2D@tmYLOn               = True
   res2D@tmYLLabelsOn         = True
   res2D@tmYLMode             = "Explicit"
   res2D@tmYLBorderOn         = True
;  res2D@tmYLLabels           = stplevels(:ptop-1:ystride)+"~C~"+meters(:ptop-1:ystride) ; TJ
   res2D@tmYLLabels           = stplevels(:ptop-1:ystride)
   res2D@tmYLValues           = theselevels(::ystride)           ; plevels ;(::ystride)
   res2D@tmYLLabelFontHeightF = .012
   res2D@tmYLLabelDeltaF      = -0.2

   ; Right Y axis

   y_meters = ispan (0,10000,500)
   y_meters_p = linint1_Wrap (round(z(0,:,locY,locX),0),plevels, False, y_meters, 0)
   y_meters_minor = ispan(0,10000,100)
   y_meters_minor_p = linint1_Wrap (round(z(0,:,locY,locX),0),plevels, False, y_meters_minor, 0)

   y_feet = ispan (0,30000,500)
   y_feet_p = linint1_Wrap (round(zft(0,:,locY,locX),0),plevels, False, y_feet, 0)
   y_feet_minor = ispan(0,10000,250)
   y_feet_minor_p = linint1_Wrap (round(zft(0,:,locY,locX),0),plevels, False, y_feet_minor, 0)

   res2D@tmYRLabelFuncCode    = "~"
   res2D@tmYRLabelFont        = 21
   res2D@tmYROn               = True
   res2D@tmYRLabelsOn         = True
   res2D@tmYRMode             = "Explicit"
   res2D@tmYRBorderOn         = True
   ;  res2D@tmYRLabels           = feets(:ptop-1:ystride) ; TJ
   if (non_metric.eq.0) then
      res2D@tmYRLabels           = y_meters+" m"
      res2D@tmYRValues           = y_meters_p
      res2D@tmYRMinorValues      = y_meters_minor_p
   end if

   if (non_metric.eq.1) then
      res2D@tmYRLabels           = y_feet+"'"
      res2D@tmYRValues           = y_feet_p
      res2D@tmYRMinorValues      = y_feet_minor_p
   end if

   ;  res2D@tmYRValues           = theselevels(::ystride) ; plevels;(::ystride) ; TJ
   res2D@tmYRLabelFontHeightF = .012
   res2D@tmYRMajorLengthF     = .01
   res2D@tmYRLabelDeltaF      = -0.2        ; TJ
   res2D@tmYUseLeft           = False       ; necessary for right labels to work at all ; TJ




   ; XY plot resources

   xy_res=res2D

   ; Title resources

   xy_res@tiMainString	       = ""
   xy_res@tiXAxisString        = ""
   xy_res@tiYAxisString        = ""

   ; Transformation and XY resources

   ; X = new(ptop,float)
   ; X = ( ( sqrt( (theselevels - min(theselevels)) / (max(theselevels)- min(theselevels)) ) ) * (max(theselevels)- min(theselevels)) ) + min(theselevels)



   xy_res@trYReverse           = True
   xy_res@xyYIrregularPoints   =  theselevels
   xy_res@xyYStyle             = "Irregular"

   ; Tickmark resources

   xy_res@tmYROn               = False
   xy_res@tmYLOn               = False
   xy_res@tmXBOn               = False
   xy_res@tmXBLabelsOn         = False
   xy_res@tmXTOn               = False
   xy_res@tmXTLabelsOn         = False




   ;;;;;;;;;;;;;;;;;;;;;;;;
   ; Check rain in forecast
   ;;;;;;;;;;;;;;;;;;;;;;;;

   rain1= new(numtimes,float)
   if (show_rain.ne.0) then
      
      rain1 = rain1_multitime(:,locY,locX)
      if ( (.not.ismissing(max(rain1))) .and. (.not.(max(rain1).gt.0)) ) then
         show_this_rain=0
         print("No rain in the forecast for "+sites(ns)+".")
      else
         show_this_rain=1
         ;print("Rain in forecast for "+sites(ns)+".")
         if ( debug.ne.0) then
            print("rain ="+rain)
         end if
      end if
   else
       show_this_rain = 0
   end if

   sfcsunpct =  new(numtimes,float)
   if (show_sun.ne.0) then
      sfcsunpct = sfcsunpct_multitime(:,locY,locX)
   end if


   if (show_cape.ne.0) then
      cape = new(numtimes,float)
      cape = cape_multitime(:,locY,locX)
   end if

   if (show_cape_3d.ne.0) then
      cape2d = new(numtimes,float)
      cape2d = cape2d_multitime(:,locY,locX)
      ;lcl2=lcl(:,locY,locX)
      ;print(lcl2)
      ;cape2d=mcape(:,locY,locX)
      cin2d = new(numtimes,float)
      cin2d = cin2d_multitime(:,locY,locX)


      el_level = new(numtimes,integer)  ; equilibrium level
      el_p = new(numtimes,float)  ; equilibrium level pressure
      do i=0,numtimes-1
         ;print(cape3d_multitime(i,:,locY,locX))
         do l=1,numlevels-1
            el_level(i) = -1
            if (.not.ismissing(cape3d_multitime(i,numlevels-l-1,locY,locX))) then
               el_level(i) =  numlevels-l-1
               el_p(i) = plevels(el_level(i))
               break
            end if
         end do
      end do



      ;print(z(12,:ptop-1,locY,locX))
      ;print(cape3d_multitime(10,:,locY,locX))
      ;print(cinfo(:,12,locY,locX))
      ;exit

   end if

   ;;;;;;;;;;;;;;;;;;;;;;;;
   ; Check BL Cloud cover percentage
   ;;;;;;;;;;;;;;;;;;;;;;;;


   if ( show_hct.ne.0) then  ;  ToninoTarsi 2019 check if we run TEMF schema 
      hct_loc = hct(:,locY,locX)
      ; print(hct_loc)
      ; ;exit
   end if 

   if ( show_cutop.ne.0) then  ;  
      cutop_loc = cutop(:,locY,locX)
      cubot_loc = cubot(:,locY,locX)
      cudiff_loc = cutop_loc - cubot_loc
   end if 


   if (show_blcloudpct.ne.0) then
      blcloudpct= new(numtimes,float)
      blcloudpct = blcloudpct_multitime(:,locY,locX)
      blcloudpct_text = new(numtimes,string)
      blcloudpct_text = where(.not.ismissing(blcloudpct),sprintf("%.0f%%",blcloudpct),"")
   end if
   
   if ( show_od.ne.0) then
      zblcldif= new(numtimes,float)
      zblcl= new(numtimes,float)
      zblcldif = zblcldif_multitime(:,locY,locX)
      zblcl = zblcl_multitime(:,locY,locX)
      zblcl_p   =  lmslp-(zblcl*3.28084/32)  
      zblcl_p = where(zblcldif.gt.0,zblcl_p,0)    
   end if

;;;;;
   if (show_sfcwind.ne.0) then
      sfcwind0dir= new(numtimes,float)
      sfcwind0dir = sfcwind0dir_multitime(:,locY,locX)
      sfcwind0spd= new(numtimes,float)
      sfcwind0spd = sfcwind0spd_multitime(:,locY,locX)*3.6  ;m/s to km/h
      if (non_metric.eq.1) then
         sfcwind0spd = sfcwind0spd_multitime(:,locY,locX)*2.23694 ;m/s to mph
      end if
   end if
;;;;; 


;;;;;;;;;;;;;;;;;;;;;;;
   if (show_pfd.ne.0) then
      pfd = pfd_day(locY,locX)
   end if
;;;;;;;;;;;;;;;;;;;;;;;

   if (show_this_rain.ne.0) then                    ; this might be generalizable to all getblips, but for now make it specific to rain1
      do i=0,numtimes-1
         if (ismissing(rain1(i))) then 
            rain1(i)=0
         end if
      end do
   

      ;;;;;;;;;;;;;;;;;;;;;;;;;
      ; Resources for rain plot
      ;;;;;;;;;;;;;;;;;;;;;;;;;

      rain_res                           = res2D

      ; gsn resources

      rain_res@gsnXYBarChart             = True
      rain_res@gsnXYBarChartBarWidth     = 0.15       ; change bar widths
      rain_res@gsnXYBarChartColors       = (/6/)      ; choose color from those available
      ;rain_res@gsnXYBarChartPatterns     = (/17/)     ; choose 
      rain_res@gsnRightString            = ""

      ; transformation resources

      rain_res@trYMinF                   = 0.0
      rain_res@trYMaxF                   = 20.0
      rain_res@trYReverse                = True

      ; title resources

      rain_res@tiMainString	      = ""
      rain_res@tiXAxisString             = ""
      rain_res@tiYAxisString             = ""

      ; tickmark resources                                                                                           

      ;  rain_res@tmXTValues                = bliptaus       ; res2D@tmXTValues = taus(::tstride) just use whatever res2d had.  
      rain_res@tmYROn                    = False
      rain_res@tmYLOn                    = False
      rain_res@tmXBOn                    = False
      rain_res@tmXBLabelsOn              = False
      rain_res@tmXTOn                    = False
      rain_res@tmXTLabelsOn              = False

   

      ;;;;;;;;;;;;;;;;
      ; Rain resources   
      ;;;;;;;;;;;;;;;;

      rain_res@tmYROn          = False
      rain_res@tmYLOn          = False
      rain_res@tmXBOn          = False
      rain_res@tmXBLabelsOn    = False
      rain_res@tmXTOn          = False
      rain_res@tmXTLabelsOn    = False

      rain_plot = gsn_csm_xy(wks,taus,rain1,rain_res)


   end if             ; end of if (show_rain)

   if (show_rh.ne.0) then

      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ; Begin defining the relative humidity plot resources only plot if gt 95%, use small cross hatch
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

      rhpoint = rh(:,:,locY,locX)            

      ; now just at the focal point
      ; and grid it so it is only up to ptop with Time
      ; as rightmost dimension for plotting 

      rhgrid  = rhpoint(bottom_top|:ptop,Time|:)  
      rhgrid@description = "Relative Humidity"

      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ; define plotting resources for the relative humidity plot with only 2 levels below and above rhcut (default 95%)
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

      hum_res=res2D

      ;;; Title resources
      hum_res@tiMainString         = ""
      hum_res@tiXAxisString        = ""
      hum_res@tiYAxisString        = ""

      ;;; Tickmark resources

      hum_res@tmYROn               = False
      hum_res@tmYLOn               = False
      hum_res@tmXBOn               = False
      hum_res@tmXBLabelsOn         = False
      hum_res@tmXTOn               = False
      hum_res@tmXTLabelsOn         = False

      ;;; Scalar field resources

      hum_res@sfYArray             = theselevels
      
      ;;; Label bar resources

      hum_res@lbLabelFontHeightF   = 0.002

     ;;; Contour resources

      hum_res@cnLevelSelectionMode = "ExplicitLevels"
      hum_res@cnLevels             = (/ rhcut /)    ; set at top of script or command line  eg. rhcut=.98 
      hum_res@cnFillOn             = True
      if ( white_clouds.eq.1) then
         hum_res@cnFillColors         = (/-1,0/)       ; white crosshatching
      else
         hum_res@cnFillColors         = (/-1,1/)       ; white crosshatching
      end if
      hum_res@cnFillScaleF         = .3             ; .3
      hum_res@cnFillPattern        = 16             ; 6 crosshatch  17 is stipple 
      hum_res@cnFillDotSizeF       = 0.04            ; default is 0.0              
      hum_res@cnLinesOn            = False
      hum_res@cnLineLabelsOn       = False
      hum_res@cnInfoLabelOn        = False
      hum_res@cnConstFLabelString  = ""

      ; Create the plot object 
      rel_humd=gsn_contour(wks,rhgrid,hum_res)

   ; End of relative humidity section 
   end if

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Resources for local lapse rate contour plot
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   lapse_res = res2D

   ;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Scalar fields resources
   ;;;;;;;;;;;;;;;;;;;;;;;;;

   lapse_res@sfYArray   = theselevels
   lapse_res@sfXCStartV = 0
   lapse_res@sfXCEndV   = numtimes-1

   ;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Transformation resources
   ;;;;;;;;;;;;;;;;;;;;;;;;;;

   lapse_res@trYReverse = True                           ; double checked should be false here for ilevels but true for plevels coordinates

   ;;;;;;;;;;;;;;;;;;;
   ; Contour resources
   ;;;;;;;;;;;;;;;;;;;
   
   ; lapse_res@cnFillPalette = "GMT_seis"
   ; lapse_res@cnLevelSelectionMode = "ManualLevels"
   ; lapse_res@cnMinLevelValF = -0.98 ;-- minimum contour level
   ; lapse_res@cnMaxLevelValF = 0.2 ;-- maximum contour level
   ; lapse_res@cnLevelSpacingF = 0.01 ;-- contour level spacing
   ; lapse_res@lbBoxLinesOn = False ; turn off labelbar box lines

   ; lapse_res@cnLevelSelectionMode = "ExplicitLevels"
   ; lapse_res@cnFillColors =   (/ 189,173,157,141,125,77,61,15,2 /)
   ; lapse_res@cnLevels =       (/ -0.98,-0.82,-0.65,-0.48,-0.32,-0.16,0.0,0.20 /) ; Tonino Tarsi 2019


   lapse_res@cnLevelSelectionMode = "ExplicitLevels"
   ;lapse_res@cnFillColors =   (/ 189,187,186,184,183,181,179,178,176,175,173,171,170,168,167,165,163,162,160,159,157,155,154,152,151,149,147,146,144,143,141,139,138,136,135,133,131,130,128,127,125,120,115,111,106,101,96,91,87,82,77,75,74,72,71,69,67,66,64,63,61,56,52,47,43,38,33,29,24,20,15,2 /)
   ;lapse_res@cnLevels =      (/ -0.980,-0.964,-0.948,-0.932,-0.916,-0.900,-0.884,-0.868,-0.852,-0.836,-0.820,-0.803,-0.786,-0.769,-0.752,-0.735,-0.718,-0.701,-0.684,-0.667,-0.650,-0.633,-0.616,-0.599,-0.582,-0.565,-0.548,-0.531,-0.514,-0.497,-0.480,-0.464,-0.448,-0.432,-0.416,-0.400,-0.384,-0.368,-0.352,-0.336,-0.320,-0.304,-0.288,-0.272,-0.256,-0.240,-0.224,-0.208,-0.192,-0.176,-0.160,-0.144,-0.128,-0.112,-0.096,-0.080,-0.064,-0.048,-0.032,-0.016,0.000,0.020,0.040,0.060,0.080,0.100,0.120,0.140,0.160,0.180,0.200 /) ; Tonino Tarsi 2019
   lapse_res@lbBoxLinesOn = False

   ; more colors ToninoTarsi 2019
   lapse_res@cnFillColors =   (/ 189,188,188,187,187,186,185,185,184,183,183,182,182,181,180,180,179,179,178,177,177,176,175,175,174,174,173,172,172,171,171,170,169,169,168,167,167,166,166,165,164,164,163,163,162,161,161,160,159,159,158,158,157,156,156,155,155,154,153,153,152,151,151,150,150,149,148,148,147,147,146,145,145,144,143,143,142,142,141,140,140,139,139,138,137,137,136,135,135,134,134,133,132,132,131,131,130,129,129,128,127,127,126,126,125,123,121,119,118,116,114,112,110,108,107,105,103,101,99,97,95,94,92,90,88,86,84,83,81,79,77,76,76,75,75,74,73,73,72,71,71,70,70,69,68,68,67,67,66,65,65,64,63,63,62,62,61,59,57,56,54,52,50,49,47,45,43,42,40,38,36,34,33,31,29,16,14,12,10,8,6,3,2/)
   lapse_res@cnLevels =      (/ -1.000,-0.993,-0.986,-0.979,-0.972,-0.965,-0.958,-0.952,-0.945,-0.938,-0.931,-0.924,-0.917,-0.910,-0.903,-0.896,-0.889,-0.882,-0.875,-0.868,-0.862,-0.855,-0.848,-0.841,-0.834,-0.827,-0.820,-0.814,-0.808,-0.802,-0.795,-0.789,-0.783,-0.777,-0.771,-0.765,-0.758,-0.752,-0.746,-0.740,-0.734,-0.728,-0.722,-0.715,-0.709,-0.703,-0.697,-0.691,-0.685,-0.678,-0.672,-0.666,-0.660,-0.653,-0.647,-0.640,-0.634,-0.627,-0.621,-0.614,-0.608,-0.601,-0.595,-0.588,-0.582,-0.575,-0.568,-0.562,-0.555,-0.549,-0.542,-0.536,-0.529,-0.523,-0.516,-0.510,-0.503,-0.497,-0.490,-0.486,-0.482,-0.478,-0.475,-0.471,-0.467,-0.463,-0.459,-0.455,-0.452,-0.448,-0.444,-0.440,-0.436,-0.432,-0.428,-0.425,-0.421,-0.417,-0.413,-0.409,-0.405,-0.402,-0.398,-0.394,-0.390,-0.381,-0.372,-0.363,-0.355,-0.346,-0.337,-0.328,-0.319,-0.310,-0.302,-0.293,-0.284,-0.275,-0.266,-0.257,-0.248,-0.240,-0.231,-0.222,-0.213,-0.204,-0.195,-0.187,-0.178,-0.169,-0.160,-0.154,-0.148,-0.142,-0.135,-0.129,-0.123,-0.117,-0.111,-0.105,-0.098,-0.092,-0.086,-0.080,-0.074,-0.068,-0.062,-0.055,-0.049,-0.043,-0.037,-0.031,-0.025,-0.018,-0.012,-0.006,0.000,0.006,0.012,0.018,0.025,0.031,0.037,0.043,0.049,0.055,0.062,0.068,0.074,0.080,0.086,0.092,0.098,0.105,0.111,0.117,0.123,0.129,0.135,0.142,0.148,0.16 /)
   ;lapse_res@cnLevels =      (/ -1.000,-0.988,-0.977,-0.965,-0.954,-0.942,-0.931,-0.919,-0.908,-0.896,-0.885,-0.873,-0.862,-0.850,-0.838,-0.827,-0.815,-0.804,-0.792,-0.781,-0.769,-0.758,-0.746,-0.735,-0.723,-0.712,-0.700,-0.696,-0.692,-0.688,-0.685,-0.681,-0.677,-0.673,-0.669,-0.665,-0.662,-0.658,-0.654,-0.650,-0.646,-0.642,-0.638,-0.635,-0.631,-0.627,-0.623,-0.619,-0.615,-0.612,-0.608,-0.604,-0.600,-0.558,-0.515,-0.473,-0.431,-0.388,-0.346,-0.304,-0.262,-0.219,-0.177,-0.135,-0.092,-0.050,-0.008,0.035,0.077,0.119,0.162,0.204,0.246,0.288,0.331,0.373,0.415,0.458,0.500,0.496,0.492,0.488,0.485,0.481,0.477,0.473,0.469,0.465,0.462,0.458,0.454,0.450,0.446,0.442,0.438,0.435,0.431,0.427,0.423,0.419,0.415,0.412,0.408,0.404,0.400,0.378,0.357,0.335,0.314,0.292,0.271,0.249,0.228,0.206,0.185,0.163,0.142,0.120,0.098,0.077,0.055,0.034,0.012,-0.009,-0.031,-0.052,-0.074,-0.095,-0.117,-0.138,-0.160,-0.154,-0.148,-0.142,-0.135,-0.129,-0.123,-0.117,-0.111,-0.105,-0.098,-0.092,-0.086,-0.080,-0.074,-0.068,-0.062,-0.055,-0.049,-0.043,-0.037,-0.031,-0.025,-0.018,-0.012,-0.006,0.000,0.006,0.012,0.018,0.025,0.031,0.037,0.043,0.049,0.055,0.062,0.068,0.074,0.080,0.086,0.092,0.098,0.105,0.111,0.117,0.123,0.129,0.135,0.142,0.148,0.16 /)
   
   lapse_res@cnFillOn = True
   lapse_res@cnLinesOn = False
   lapse_res@cnLineLabelsOn = False
   lapse_res@cnInfoLabelOn = False

   ;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Lapse tickmack resources
   ;;;;;;;;;;;;;;;;;;;;;;;;;;

   lapse_res@tmXTLabelsOn = False
   lapse_res@tmXBLabelsOn = False
   lapse_res@tmXTOn       = False
   lapse_res@tmXBOn       = False

   ;;;;;;;;;;;;;;;;
   ; Title resource
   ;;;;;;;;;;;;;;;;

   lapse_res@tiMainString	= ""
   lapse_res@tiXAxisString      = ""
   lapse_res@tiYAxisString      = ""

   lapse_res@trYMinF    = min(theselevels)               ; minp
   lapse_res@trYMaxF    = max(theselevels)               ; p

   if (hide_lapse_colors.ne.0) then
      lapse_res@cnFillColors         =  (/ -1,-1,-1,-1,-1,-1,-1,-1,-1 /)           ; all transparent so lapse rate doesn't show.
   end if
      
   ;;;;;;;;;;;;;;;;;;;;;
   ; Label bar resources
   ;;;;;;;;;;;;;;;;;;;;;

   lapse_res@lbLabelFontHeightF = 0.012

   lapse_res@pmLabelBarOrthogonalPosF = 0.06      ; 0.036
   lapse_res@pmLabelBarHeightF = 0.15             ; Default: 0.6 (for a viewport height of 0.6)
   lapse_res@lbLabelsOn = False
   lapse_res@lbBottomMarginF = 1.5


   ;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Resources for lcl markers
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;

   ; Add some cloud markers to plot all markers are plotted with a contour plot, not a vector plot:
   ; Create a cloud marker.
   ; Set some marker resources.
   ; Attach markers to "plot" using gsn_add_polymarker
   ; Font 37 has a cloud for the letter k, 19 / is a "paraglider", 20 E static = C, 20 / a blipspot, 20 6 a crescent moon angle, 270 is a paraglider
   ; 34 E is a blipspot, 34 D is an Xspot, 36 ) is turbulence, 37 B 180deg rogallo wing, 37 g raindropblown, 35 < ... 
   ; 37 F lightning, g and o Rain, q snowflake, r fastcloud, k puffycloud  
   
   mstring      = "k"
   fontnum      = 37
   xoffset      = 0.0
   yoffset      = 0.0
   tallyoffset  = 0.5
   ratio        = .75
   tall         = 1.5
   size         = 1.4   ; 2 if sparse
   angle        = 0.0
   
   ; Cloud marker

   cloud       = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, ratio, size, angle)      ; puffy cloud
   ceilingmrk  = NhlNewMarker(wks, "U", 19, xoffset, yoffset, ratio, 1.5, angle)
   rogallo     =NhlNewMarker(wks, "B", 37, xoffset, yoffset,   1, 1, 180)  			 ; rogallo wing head on
   if (use_paraglider.eq.1) then
      paragl     = NhlNewMarker(wks, "6", 20, xoffset, yoffset, tall, 0.5, 270)
   end if
   snowflake   = NhlNewMarker(wks, "q", 37, xoffset, tallyoffset, 1, 1, 0)

   sun   = NhlNewMarker(wks, "l", 37, xoffset, tallyoffset, 1, 1, 0)
   sun0   = NhlNewMarker(wks, "R", 37, xoffset, tallyoffset, 1, 1, 0)
   sun0p   = NhlNewMarker(wks, "S", 37, xoffset, tallyoffset, 1, 1, 0)
   sun25   = NhlNewMarker(wks, "T", 37, xoffset, tallyoffset, 1, 1, 0)
   sun25p   = NhlNewMarker(wks, "U", 37, xoffset, tallyoffset, 1, 1, 0)
   sun50   = NhlNewMarker(wks, "V", 37, xoffset, tallyoffset, 1, 1, 0)
   sun50p   = NhlNewMarker(wks, "W", 37, xoffset, tallyoffset, 1, 1, 0)
   sun75   = NhlNewMarker(wks, "X", 37, xoffset, tallyoffset, 1, 1, 0)
   sun75p   = NhlNewMarker(wks, "Y", 37, xoffset, tallyoffset, 1, 1, 0)
   sun100   = NhlNewMarker(wks, "Z", 37, xoffset, tallyoffset, 1, 1, 0)

   ;darkcloud   = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, 1, 3, angle)  ; big puffy cloud for coloring dark dewpt=tmp
   ;cloudfast = NhlNewMarker(wks, "r", 37, xoffset, tallyoffset, tall, size, 0)          ;wind blown cloud
   mkres1                    = True
   mkres1@gsClipOn	      = False         
   mkres1@gsMarkerIndex      = cloud
   mkres1@gsMarkerSizeF      = 0.03   
   mkres1@gsMarkerThicknessF = 2
   mkres1@gsMarkerColor      = "white"    

   ; BL Top marker

   mkres2                    = True
   ;   mkres2@gsMarkerColor      = 191
   ;   mkres2@gsMarkerThicknessF = 6  
   ;   mkres2@gsMarkerIndex      = ceilingmrk
   mkres2@gsLineDashPattern  = 1.                     ; solid line
;   mkres2@gsLineThicknessF   = 6.                     ; line thicker
   mkres2@gsLineThicknessF   = 4.                     ; line thicker
   mkres2@gsLineColor        = "blue"                 ; line color

   ; hglider

   mkres3                    = mkres1
   mkres3@gsMarkerSizeF      = 0.025   
   mkres3@gsMarkerColor      = "blue"
   mkres3@gsMarkerThicknessF = 3
   if (use_paraglider.eq.1) then
      mkres3@gsMarkerIndex      = paragl
   else
      mkres3@gsMarkerIndex      = rogallo
   end if

   ; Freezing level marker

   mkres4                    = mkres1
   mkres4@gsMarkerSizeF      = 0.020   
   mkres4@gsMarkerColor      = 193
   mkres4@gsMarkerThicknessF = 4
   mkres4@gsMarkerIndex      = snowflake


   ; Dark cluds
   mkres5                    = mkres1
   mkres5@gsMarkerColor      = "dimgray"    
   mkres5@gsMarkerSizeF      = 0.035  


   ; Cloud txt
   cloudtextres = True
   cloudtextres@txtFontQuality = "High"
   cloudtextres@txFuncCode    = "~"  
   cloudtextres@txFontHeightF = 0.009                 
   cloudtextres@txJust = "CenterCenter"  




   ; Other marker

   ; darkcloud   = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, 1, 3, angle)      ; big puffy cloud for coloring dark dewpt=tmp
   ; cloudfast   = NhlNewMarker(wks, "r", 37, xoffset, tallyoffset, tall, size, 0)         ; wind blown cloud
   ; raindrop    = NhlNewMarker(wks, "g", 37, xoffset, yoffset,   1, .2, 0)		; raindrop thing curved

   ; mkres                    = True
   ; mkres@gsClipOn           = False         ;symbols may overhang edges of the viewport.
   ; mkres@gsMarkerIndex      = cloud
   ; mkres@gsMarkerSizeF      = 0.03
   ; mkres@gsMarkerThicknessF = 2
   ; mkres@gsMarkerColor      = "white"

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Vector plot resources for windgram 
   ; most tick mark labels come from here
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   uv_res = res2D
   uv_res@tmYUseLeft           	   = False  	 
   uv_res@vcRefAnnoOn      	   = False                             ; turns off the ref vector
   uv_res@vcRefAnnoOrthogonalPosF = 0.07
   uv_res@vcRefAnnoString2On  = True
   uv_res@vcRefAnnoString1 = "15 km/h"
   if (non_metric.eq.1) then
        uv_res@vcRefAnnoString1 = "13-17 kts"
   end if
   uv_res@vcRefAnnoString2  = "Wind"
   uv_res@vcRefAnnoExplicitMagnitudeF = 15
   uv_res@vcRefLengthF     	   = 0.025                             ; .04 set length of ref vector
   uv_res@vcGlyphStyle     	   = "WindBarb"                        ; turn on wind barbs
   uv_res@vcWindBarbColor          = "Black"  
   uv_res@vcLevelSelectionMode     = "ExplicitLevels"                  ; will explicitly set the levels
   uv_res@vcWindBarbLineThicknessF = 2                               ; has been 3 set the wind barb thickness 3 works well for png output
   uv_res@vcLevels                 = (/ 5.,10.,15.,20.,25.,30.,35. /)  ; color by 5 km/h increments
 

   uv_res@vcMinDistanceF          = 0.025                             ; thin out windbarbs

   uv_res@vcMapDirection           = False                             ; needed to disassociate the coordinate plane from the wind barbs, thanks Andrea Barcellona
   uv_res@vcLevelColors  	   = (/2,3,4,5,6,7,8,9,10/) 
;  uv_res@vcMonoFillArrowEdgeColor = True
;  uv_res@vcFillArrowEdgeColor     = "black"

   uv_res@tmYLOn  		   = True
;  uv_res@tmYROn 		   = True
   uv_res@tmYLValues               = theselevels(::ystride)   
;  uv_res@tmYRValues               = theselevels(::ystride)                      ; theselevels is plevels up to ptop-1   
   uv_res@tmYLLabelsOn 		   = True
;  uv_res@tmYRLabelsOn 		   = True
   uv_res@tmYLLabels               = stplevels(:ptop-1:ystride)+"~C~"+meters(:ptop-1:ystride)
;  uv_res@tmYRLabels               = feets(:ptop-1:ystride)   
   uv_res@trYMinF   		   = min(theselevels)                            ; minp
   uv_res@trYMaxF   		   = max(theselevels)                            ; p
   uv_res@trYReverse 		   = False                                       ; checked must be false here.  
   
   ; The end of main site loop plots what has been set up

   ;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; set basic text resources
   ;;;;;;;;;;;;;;;;;;;;;;;;;;

   lbtxtres = True
   lbtxtres@txtFontQuality = "High"
   lbtxtres@txFuncCode    = "~"  
   lbtxtres@txFontHeightF = 0.015                  
   lbtxtres@txJust = "CenterLeft"                     

   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; create a Time Stamp for the plot -- when it was plotted
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Draws box around legend
   cirx = (/ 0.1, 0.8, 0.8 , 0.1 , 0.1/)
;   ciry = (/ 0.1, 0.1, 0.038, 0.038, 0.1/)
   ciry = (/ 0.114, 0.114, 0.038, 0.038, 0.1/)
;   gsres = True             ; Indicate you want to set some resources.
;   gsres@gsFill = False
;   gsn_polyline_ndc(wks,cirx,ciry,gsres)  ; Draw a filled polygon.

;   wrf_version_file = BASEDIR + "/bin/WRF_VERSION.txt"
;   wrf_version = ""
;   if ( fileexists(wrf_version_file) ) then 
;      wrf_version = readAsciiHead(wrf_version_file,1)
;   end if 


   timestamp=systemfunc("date +%d' '%b' '%Y' at '%H:%M' '%Z")
   timestamp="~F21~~Z65Q~Produced on "+timestamp+" - aufwin.de - WRF"+wrf_version+" - Meteogram: "+meteogram_version
   timestampxNDC = .100     
   timestampyNDC = .010


;;;;
;At blipmaps.nl we also run a click-on-the-map Blipspot to see the parameter data values behind the maps
;The Lat,Lon of the Blipspot and the Meteogram are the same and the data derived from the parameter data files is also the same.
;But the locX,locY gridpointnumbers of Meteogram are -1,-1 compared to the Blipspot
;Therefore the gridpointnumbers are increased +1,+1 only on the Meteogram plot
;Nothing is changed in locX,locY in the process of deriving the parameter data values
;;;;;
lokY = locY+1
lokX = locX+1
;;;;;

;   timestamp2="~F21~~Z40Q~Lat: "+wlats(ns)+" - Long: "+wlons(ns)+" - Quota modello: "+round(h,0)+"m AMSL"
 timestamp2="~F21~~Z50Q~Meteogram for "+sites(ns)+" from the "+region+" "+wgrid+" region, Gridpoint: "+lokX+","+lokY+" Lat,Lon: "+wlats(ns)+","+wlons(ns)+" Model elevation: "+round(h,0)+"m AMSL"
 if (non_metric.eq.1) then
    timestamp2="~F21~~Z50Q~Meteogram for "+sites(ns)+" from the "+region+" "+wgrid+" region, Gridpoint: "+lokX+","+lokY+" Lat,Lon: "+wlats(ns)+","+wlons(ns)+" Model elevation: "+round(fth,0)+"ft AMSL"
 end if

   timestamp2xNDC = .100
   timestamp2yNDC = .030

;   legend1="~F21~~Z65Q~CAPE values >300 show on top        300-1000                                  1000-2000                                   >2000"
;   gsn_text_ndc(wks,legend1,0.11,0.105,lbtxtres)
;   legend2="~F21~~Z65Q~                      Thunderstorm(s):      Isolated temporary    Good chance of well developed    High possibility (strong)"
;   gsn_text_ndc(wks,legend2,0.11,0.09,lbtxtres)
;   legend3="~F21~~Z65Q~xx% = Normalised Surface Sun                     Cloudbase: White = Cumulus    Dark = OvercastDevelopment"
;   gsn_text_ndc(wks,legend3,0.11,0.075,lbtxtres)
;   legend4="~F21~~Z65Q~xx% = Boundarylayer Cloudcover                  m = lift<1,14m/s incl.cloudbase limits *excl.cloudsuck"
;   if (non_metric.eq.1) then
;      legend4="~F21~~Z65Q~xx% = Boundarylayer Cloudcover                  m = lift<220 fpm incl.cloudbase limits *excl.cloudsuck"
;   end if
;   gsn_text_ndc(wks,legend4,0.11,0.06,lbtxtres)
;   legend5= "~F21~~Z65Q~xxx/xx = winddirection/windspeed in km/h @ 2m AGL"
;   if (non_metric.eq.1) then
;     legend5= "~F21~~Z65Q~xxx/xx = winddirection/windspeed in mph @ 7ft AGL"
;   end if
;   gsn_text_ndc(wks,legend5,0.11,0.045,lbtxtres)

   ; windbarb5=NhlNewMarker(wks, "b", 37, 0, 0,   1, 1, 0)  			 
   ; mkresWindBarb5            = True
   ; mkresWindBarb5@gsMarkerSizeF      = 0.014   
   ; mkresWindBarb5@gsMarkerColor      = "black" 
   ; mkresWindBarb5@gsMarkerThicknessF = 3
   ; mkresWindBarb5@gsMarkerIndex      = windbarb5
   ; gsn_polymarker_ndc(wks,0.90,0.115,mkresWindBarb5)
   ; gsn_text_ndc(wks,"=5km/h",0.915,0.115,lbtxtres)


   ; Draw the timestamp  

   lbtxtres@txFontHeightF = 0.015
   gsn_text_ndc(wks,timestamp,timestampxNDC,timestampyNDC,lbtxtres)
; Turned second timestamp on
   gsn_text_ndc(wks,timestamp2,timestamp2xNDC,timestamp2yNDC,lbtxtres)

; Add extra legend for vertical velocity and altitude levels
   timestamp3="~F21~~Z65Q~m/s"
   if (non_metric.eq.1) then
      timestamp3="~F21~~Z65Q~fpm"
   end if
   timestamp3xNDC = .905
   timestamp3yNDC = .938
   gsn_text_ndc(wks,timestamp3,timestamp3xNDC,timestamp3yNDC,lbtxtres)

; Add extra legend with potential flight distance
   if ( show_pfd.ne.0) then
     timestamp4="~F21~~Z70Q~PFD"
     timestamp4xNDC = .920
     timestamp4yNDC = .060
     gsn_text_ndc(wks,timestamp4,timestamp4xNDC,timestamp4yNDC,lbtxtres)
     timestamp5="~F21~~Z70Q~"+pfd+" km"
     if (non_metric.eq.1) then
        pfd_miles = pfd/1.6
        timestamp5="~F21~~Z70Q~"+pfd_miles+" M"
     end if
     timestamp5xNDC = .920
     timestamp5yNDC = .042
     gsn_text_ndc(wks,timestamp5,timestamp5xNDC,timestamp5yNDC,lbtxtres)
   end if
   timestamp6="~F21~~Z65Q~AMSL"
   timestamp6xNDC = .920
   timestamp6yNDC = .120
   gsn_text_ndc(wks,timestamp6,timestamp6xNDC,timestamp6yNDC,lbtxtres)
   timestamp7="~F21~~Z65Q~Local time"
   timestamp7xNDC = .920
   timestamp7yNDC = .098
   gsn_text_ndc(wks,timestamp7,timestamp7xNDC,timestamp7yNDC,lbtxtres)


;;;;;;;;;;;;;;;;;;;;;;
;SUNRISESET Compute apparent sunrise and sunset times in seconds.
; Richard Droste reverse engineered the NOAA Excel:
; (https://www.esrl.noaa.gov/gmd/grad/solcalc/calcdetails.html)
; 
; The formulas are from:
; Meeus, Jean H. Astronomical algorithms. Willmann-Bell, Incorporated, 1991.

PI  = 3.141592653589793 ;get_pi("double")
deg2rad = PI/180
rad2deg = 180/PI

; Process input
lat = wlats;     ; Latitude
lng = wlons;     ; Longitude
UTCoff = offset;          ; UTC offset

print ("**********")
;;;Date for which sunrise and sunset is calculated
print ("Date for which sunrise and sunset is calculated")
print ("theYear = "+theYear)
print ("theMonth = "+theMonth)
print ("theDay = "+theDay)
;print ("the site = "+sites(ns))
;print ("lat = "+lat)
;print ("lon = "+lng)

J30dec1899 = greg2jul (1899,12,30,0)
Jdate = greg2jul (theYear,theMonth,theDay,0)
print ("Jdate = "+Jdate)
nDays = Jdate-J30dec1899
print ("nDays = "+nDays)

; Letters correspond to colums in the NOAA Excel
E = 0.5 ; 12:00:00 Time (hrs past local midnight) is 0.5 Julianday
print ("E = "+E)

F = nDays+2415018.5+E-UTCoff/24;
print ("F = "+F)

;F = greg2jul (year,month,day,hour)
;print ("F = "+F)

G = (F-2451545)/36525;
print ("G = "+G)

I = mod(280.46646+G*(36000.76983+G*0.0003032),360);
print ("I = "+I)

J = 357.52911+G*(35999.05029-0.0001537*G);
print ("J = "+J)

K = 0.016708634-G*(0.000042037+0.0000001267*G);
print ("K = "+K)

L = sin(deg2rad*(J))*(1.914602-G*(0.004817+0.000014*G))+sin(deg2rad*(2*J))*(0.019993-0.000101*G)+sin(deg2rad*(3*J))*0.000289;
print ("L = "+L)

M = I+L;
print ("M = "+M)

P = M-0.00569-0.00478*sin(deg2rad*(125.04-1934.136*G));
print ("K = "+K)

Q = 23+(26+((21.448-G*(46.815+G*(0.00059-G*0.001813))))/60)/60;
print ("Q = "+Q)

R = Q+0.00256*cos(deg2rad*(125.04-1934.136*G));
print ("R = "+R)

T = rad2deg*(asin(sin(deg2rad*(R))*sin(deg2rad*(P))));
print ("T = "+T)

U = tan(deg2rad*(R/2))*tan(deg2rad*(R/2));
print ("U = "+U)

V = 4*rad2deg*(U*sin(2*deg2rad*(I))-2*K*sin(deg2rad*(J))+4*K*U*sin(deg2rad*(J))*cos(2*deg2rad*(I))-0.5*U*U*sin(4*deg2rad*(I))-1.25*K*K*sin(2*deg2rad*(J)));
print ("V = "+V)

W = rad2deg*(acos(cos(deg2rad*(90.833))/(cos(deg2rad*(lat(ns)))*cos(deg2rad*(T)))-tan(deg2rad*(lat(ns)))*tan(deg2rad*(T))));
print ("W = "+W)

X = (720-4*lng(ns)-V+UTCoff*60)/1440;
print ("X = "+X)
;X = (720-4*lng-V+UTCoff*60)*60
;print ("X = "+X)

Y = (X*1440-W*4)/1440
print ("Y = "+Y)

Z = (X*1440+W*4)/1440
print ("Z = "+Z)

AB = Y*86400
print ("AB = "+AB)

AC = AB/(60*60)
print ("AC = "+AC)

AD = tointeger(AC)
print ("AD = "+AD)

AE = AB-(AD*60*60)
print ("AE = "+AE)

AF = AE/60
print ("AF = "+AF)

AG = tointeger(AF)
print ("AG = "+AG)

AH = AB-(AD*60*60)-AG*60
print ("AH = "+AH)

AI = round(AH,0)
print ("AI = "+AI)

BB = Z*86400
print ("BB = "+BB)

BC = BB/(60*60)
print ("BC = "+BC)

BD = tointeger(BC)
print ("BD = "+BD)

BE = BB-(BD*60*60)
print ("BE = "+BE)

BF = BE/60
print ("BF = "+BF)

BG = tointeger(BF)
print ("BG = "+BG)

BH = BB-(BD*60*60)-BG*60
print ("BH = "+BH)

BI = round(BH,0)
print ("BI = "+BI)

print ("Sunrise = "+AD+":"+AG+":"+AI)
print ("Sunset = "+BD+":"+BG+":"+BI)


; Add extra legend for sunrise and sunset
   timestamp8="~F21~~Z65Q~Sunrise"
   timestamp8xNDC = .920
   timestamp8yNDC = .074
   gsn_text_ndc(wks,timestamp8,timestamp8xNDC,timestamp8yNDC,lbtxtres)
if (AG.le.9) then
   timestamp9= "~F21~~Z65Q~0"+AD+":0"+AG
else
   timestamp9= "~F21~~Z65Q~0"+AD+":"+AG
end if
   timestamp9xNDC = .920
   timestamp9yNDC = .056
   gsn_text_ndc(wks,timestamp9,timestamp9xNDC,timestamp9yNDC,lbtxtres)
   timestamp10="~F21~~Z65Q~Sunset"
   timestamp10xNDC = .920
   timestamp10yNDC = .038
   gsn_text_ndc(wks,timestamp10,timestamp10xNDC,timestamp10yNDC,lbtxtres)
if (BG.le.9) then
   timestamp11= "~F21~~Z65Q~"+BD+":0"+BG
else
   timestamp11= "~F21~~Z65Q~"+BD+":"+BG
end if
   timestamp11xNDC = .920
   timestamp11yNDC = .020
   gsn_text_ndc(wks,timestamp11,timestamp11xNDC,timestamp11yNDC,lbtxtres)
;;;;;;;;;;;;;;;;;;;;;;

   ; Create the lapse_plot object, colored backgrounds

   ;lapse_plot=gsn_csm_contour(wks,lgrid,lapse_res)

   ; Create the wind_gram object --- wind barbs

   wind_gram = gsn_vector(wks, ugrid, vgrid, uv_res)

   ; Draw markers

   x = (/ 0, 1 /)
   y = (/ 1, 2 /)

   xy_plot = gsn_csm_xy(wks, x, y, xy_res)

   ; if we are coloring in the lapse rate this section applies

   if (show_lapse.ne.0) then
      if ((hide_lapse_colors.ne.0).or.(color_wind_barbs.eq.1)) then

         ;  uv_res@vcMonoFillArrowFillColor = False
         uv_res@vcMonoWindBarbColor      = False              ; if set True, they get lost in the lapse colors

         ;;; debug start ;;;
         if (debug.ne.0) then
            print(" hide_lapse_colors = "+hide_lapse_colors+" or color_wind barbs ="+color_wind_barbs+" and therefore monoWindbarb color set to False there should have been colors")
         end if
         ;;; debug end ;;;
      else
         ;;; debug start ;;;
         if (debug.ne.0) then 
            print(" hide_lapse_colors = "+hide_lapse_colors+" or color_wind barbs ="+color_wind_barbs+" and therefore monoWindbarb color set to False there should NOT NOT have been colors")
         end if
         ;;; debug end ;;;

         uv_res@vcMonoWindBarbColor      = True     ; make default monochrome windbarbs False ; False they get lost in the lapse colors
         ;  uv_res@vcMonoFillArrowFillColor = False

      end if  

      lapse_plot=gsn_csm_contour(wks,lgrid,lapse_res)



      draw(lapse_plot)

   end if

   if ( show_cutop.ne.0) then
      mkres_cutop = mkres5
      mkres_cutop@gsMarkerColor = "gray"
      mkres_cutop@gsMarkerOpacityF = 0.70
      mkres_cutop@gsMarkerSizeF      = 0.026
      do i=2,numtimes-2
         if ( cudiff_loc(i).gt.0) then
            l_start = floattointeger(cubot_loc(i))
            l_stop = floattointeger(cutop_loc(i))
            if ( l_stop.ge.ptop ) then
               l_stop = ptop-1
            end if
            if ( l_start.lt.0 ) then
               l_start = 0
            end if
            do l=l_start,l_stop
               gsn_polymarker(wks,xy_plot,i,theselevels(l),mkres_cutop) 
            end do
         end if 
      end do
   end if


; deleted tstride below to get info shown per half hour

;   if ( show_od.ne.0) then
;      marker5 = gsn_add_polymarker(wks,xy_plot,taus(::tstride),zblcl_p(::tstride),mkres5)  
;      ; cloudtextres_white = cloudtextres
;      ; cloudtextres_white@txFontColor = "white"
;      ; label2 = gsn_add_text(wks,xy_plot,zblcldif,taus,zblcl_p,cloudtextres_white)  
;   end if

   if ( show_od.ne.0) then
      marker5 = gsn_add_polymarker(wks,xy_plot,taus,zblcl_p,mkres5)  
      ; cloudtextres_white = cloudtextres
      ; cloudtextres_white@txFontColor = "white"
      ; label2 = gsn_add_text(wks,xy_plot,zblcldif,taus,zblcl_p,cloudtextres_white)  
   end if

;   if (show_lcl.ne.0) then
;      marker1 = gsn_add_polymarker(wks,xy_plot,taus(::tstride),lcl1(::tstride),mkres1)            ; DR Jack's lcl calc was lcl4 --- These are all pretty darn close to lclvl()
;   end if

   if (show_lcl.ne.0) then
      marker1 = gsn_add_polymarker(wks,xy_plot,taus,lcl1,mkres1)            ; DR Jack's lcl calc was lcl4 --- These are all pretty darn close to lclvl()
   end if

   if (show_blcloudpct.ne.0) then
      label1 = gsn_add_text(wks,xy_plot,blcloudpct_text,taus,lcl1,cloudtextres)
   end if

;;;;;

;   if (show_wing.ne.0  ) then
;      marker3 = gsn_add_polymarker(wks,xy_plot,taus(::tstride),hgldj_p(::tstride),mkres3)         ; hgldj_p max soar w/clouds sideways crescent moons
;   end if

   if (show_wing.ne.0  ) then
      marker3 = gsn_add_polymarker(wks,xy_plot,taus,hgldj_p,mkres3)         ; hgldj_p max soar w/clouds sideways crescent moons
;      print ("PG X = "+taus+" PG Y = "+hgldj_p) ; find me here
   end if

   if (show_pbl.ne.0) then
      marker2 = gsn_add_polyline(wks,xy_plot,taus,lpblt_p,mkres2)
   end if


   if (show_snow.ne.0) 
      marker4 = gsn_add_polymarker(wks, xy_plot, taus, freezelevel, mkres4) ; lowest freezing level snowflakes
   end if

   

 


   if (show_condense.ne.0) then
      condenselevels=gsn_contour(wks,condense,hum_res)  
      draw(condenselevels)  
   end if

   txres = True
   txres@txFontHeightF = 0.009
   txres@txPerimOn     = True
   txres@txBackgroundFillColor = "white"
   ;txres@txFontColor = "white"

   ;---Add rain labels
   ; if (show_rain.ne.0) then
   ;    do i=0,numtimes-1
   ;          if ( .not.ismissing(rain1(i)).and.rain1(i).ne.0 ) then
   ;             id = gsn_add_text(wks,xy_plot,sprintf("%.1f mm",rain1(i)),taus(i),theselevels(ptop-2),txres)
   ;          end if
   ;    end do
   ; end if

 


   ;  Cape marker

   capeflake                 = NhlNewMarker(wks, "f", 37, xoffset, tallyoffset, 1, 1, -20)
   mkresT                    = True
   mkresT@gsClipOn	      = False         
   mkresT@gsMarkerIndex      = capeflake
   mkresT@gsMarkerSizeF      = 0.055   
   mkresT@gsMarkerThicknessF = 3
   mkresT@gsMarkerColor      = "white"  



   ;draw(xy_plot)

   if (show_rh.ne.0)
;    rhmsg="~F21~~Z65Q~RH Cut "+rhcut+"%"
;    gsn_text_ndc(wks,rhmsg,.800,timestampyNDC,lbtxtres )
      rel_humd=gsn_contour(wks,rhgrid,hum_res)
      draw(rel_humd)
   end if

 


   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   ; Begin defining the cloud fraction plot resources 
   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   if (show_cloudfrac.ne.0) then

      cldfra_res                         = res2D

      ; Title resources  

      cldfra_res@tiMainString	      = ""
      cldfra_res@tiXAxisString            = ""
      cldfra_res@tiYAxisString            = ""

      ; Tickmark resources

      cldfra_res@tmYROn                   = False
      cldfra_res@tmYLOn                   = False
      cldfra_res@tmXBOn                   = False
      cldfra_res@tmXBLabelsOn             = False
      cldfra_res@tmXTOn                   = False
      cldfra_res@tmXTLabelsOn             = False

      ; Scalar field resources

      cldfra_res@sfYArray                 = theselevels

      ; Label bar resources

      cldfra_res@lbLabelFontHeightF       = 0.002

      ; Contour resources

      cldfra_res@cnLevelSelectionMode       = "ExplicitLevels"
      cldfra_res@cnLevels                   = (/ 0.01,0.3,0.5,0.7,1 /)     	                           ; set at top of script or command line
      cldfra_res@cnFillPatterns             = (/ -1,16,16,16,0,0 /)     	                           ; white crosshatching
      cldfra_res@cnFillColors               = (/"white","grey20","grey15","grey10","grey5","black" /)  ; white crosshatching
      cldfra_res@cnFillScales               = (/ -1,0.3,0.3,0.3,0.3,0.2 /)                             ; white crosshatching
      cldfra_res@cnFillScaleF               = .3
      cldfra_res@cnFillOn                   = True
      cldfra_res@cnMonoFillPattern          = False
      cldfra_res@cnMonoFillScale            = False
      if ( white_clouds.eq.1) then
         cldfra_res@cnMonoFillColor            = True
      else
         cldfra_res@cnMonoFillColor            = False
      end if
      cldfra_res@cnFillColor                = "white"
      cldfra_res@cnFillPattern              = 16        
      cldfra_res@cnFillDotSizeF             = 0.04    
      cldfra_res@cnLinesOn                  = False
      cldfra_res@cnLineLabelsOn             = False
      cldfra_res@cnInfoLabelOn              = False
      cldfra_res@cnConstFLabelFontHeightF = 0.0 

      cldfra_plot = gsn_contour(wks,cldfragrid,cldfra_res)
      draw(cldfra_plot)
   end if


   if (show_wind.ne.0)
      wind_gram = gsn_vector(wks,ugrid,vgrid,uv_res)
      draw(wind_gram)
   end if  

;;;
   mkresWind                    = mkres1
   mkresWind@gsClipOn	        = False         
   mkresWind@gsMarkerIndex      = sun
   mkresWind@marker = "CenterCenter" 

   txresWind = True
   txresWind@txtFontQuality = "High"
   txresWind@txFuncCode    = "~"  
   txresWind@txFontHeightF = 0.009                 
   txresWind@txJust = "CenterCenter"  


;;;


  ;---Add rain and sun if present 
   mkresSun                    = mkres1
   mkresSun@gsClipOn	        = False         
   mkresSun@gsMarkerIndex      = sun
   mkresSun@marker = "CenterCenter" 

   txresSun = True
   txresSun@txtFontQuality = "High"
   txresSun@txFuncCode    = "~"  
   txresSun@txFontHeightF = 0.009                 
   txresSun@txJust = "CenterCenter"  
   

   do i=0,numtimes-1
      if ( .not.ismissing(rain1(i)).and.rain1(i).ne.0 ) then

         ;id = gsn_add_text(wks,xy_plot,sprintf("%.1f mm",rain1(i)),taus(i),theselevels(ptop-2),txres)
         ;gsn_text(wks,xy_plot,sprintf("%.1f mm",rain1(i)),taus(i),theselevels(ptop-2),txres)
;;         gsn_text(wks,rain_plot,sprintf("%.2f mm",rain1(i)),taus(i),rain1(i)+0.3,txres)
         gsn_text(wks,rain_plot,sprintf("%.2f",rain1(i)),taus(i),rain1(i)+0.4,txres)
      else  ; If rain is present no sun displayed
         if ( .not.ismissing(sfcsunpct(i)) ) then
; Commented lines below to don't show circle with yellow and increasing grey showing sunpct
            mkresSun@gsMarkerIndex      = sun100
            mkresSun@gsMarkerColor      = "gray" 
            mkresSun@gsMarkerSizeF      = 0.032
            gsn_polymarker(wks,xy_plot,taus(i),theselevels(ptop-round((ptop/10),3)),mkresSun)
            mkresSun@gsMarkerSizeF      = 0.03
            mkresSun@gsMarkerColor      = "yellow" 
            mkresSun@gsMarkerIndex      = sun0
            if ( sfcsunpct(i).gt.10 ) then 
               mkresSun@gsMarkerIndex      = sun0p
            end if 
            if ( sfcsunpct(i).gt.20 ) then 
               mkresSun@gsMarkerIndex      = sun25
            end if 
            if ( sfcsunpct(i).gt.30 ) then 
               mkresSun@gsMarkerIndex      = sun25p
            end if 
            if ( sfcsunpct(i).gt.40 ) then 
               mkresSun@gsMarkerIndex      = sun50
            end if 
            if ( sfcsunpct(i).gt.50 ) then 
               mkresSun@gsMarkerIndex      = sun50p
            end if           
            if ( sfcsunpct(i).gt.60 ) then 
               mkresSun@gsMarkerIndex      = sun75
            end if  
            if ( sfcsunpct(i).gt.70 ) then 
               mkresSun@gsMarkerIndex      = sun75p
            end if  
            if ( sfcsunpct(i).gt.80 ) then 
               mkresSun@gsMarkerIndex      = sun100
            end if 
            gsn_polymarker(wks,xy_plot,taus(i),theselevels(ptop-round((ptop/10),3)),mkresSun)

; Added next line
; when missing (-999 in blipspot) set it to zero!
            if ( sfcsunpct(i).eq.-999 ) then 
               sfcsunpct(i) = 0
            end if 

            sfcsuntxt_y = theselevels(ptop-round((ptop/10),3)) - ((round((ptop/10),3) -1 ) * 5) ; adjust text offset for level size
            gsn_text(wks,xy_plot,sprintf("%.0f%%",sfcsunpct(i)),taus(i),sfcsuntxt_y,txresSun)
         end if
      end if
   end do


;;; Add sfcwind to windgram
   txresSfcwind = True
   txresSfcwind@txAngleF = 45
   txresSfcwind@txFontHeightF = 0.008
   txresSfcwind@txPerimOn     = True
   txresSfcwind@txBackgroundFillColor = "white"
   txresSfcwind@gsClipOn           = False         ;symbols may overhang edges of the viewport.

   if (ptop.lt.40) then
      txresSfcwinf_y_offset = (theselevels(0) - theselevels(1)) *0.5
   else
      txresSfcwinf_y_offset = 0
   end if

   do i=0,numtimes-1
       if (show_sfcwind.ne.0) then
           if ( .not.ismissing(sfcwind0dir(i)).and.sfcwind0dir(i).ge.0.and.sfcwind0dir(i).le.360 )then 
             if ( .not.ismissing(sfcwind0dir(i)).and.sfcwind0dir(i).le.9 ) then
               gsn_text(wks,xy_plot,"00"+sprintf("%.0f",sfcwind0dir(i))+"/"+sprintf("%.0f",sfcwind0spd(i)),taus(i),(theselevels(1)+txresSfcwinf_y_offset),txresSfcwind)
             else
               if ( .not.ismissing(sfcwind0dir(i)).and.sfcwind0dir(i).le.99 ) then
	         gsn_text(wks,xy_plot,"0"+sprintf("%.0f",sfcwind0dir(i))+"/"+sprintf("%.0f",sfcwind0spd(i)),taus(i),(theselevels(1)+txresSfcwinf_y_offset),txresSfcwind)
               else
	         gsn_text(wks,xy_plot,sprintf("%.0f",sfcwind0dir(i))+"/"+sprintf("%.0f",sfcwind0spd(i)),taus(i),(theselevels(1)+txresSfcwinf_y_offset),txresSfcwind)
               end if
             end if
           end if
       end if
   end do

   ; Draw the instability caption (.102 .024 puts the caption at left border of colored bar) 

   instability_caption = "~F21~~Z65Q~Unstable                                          Conditional Instability                                             Stable                                             Inverted"
   lbtxtres@txFontHeightF = 0.015
   gsn_text_ndc ( wks, instability_caption, .106, .05, lbtxtres )  ; was .113, .024 for bottom of box

   ; Temperature contour lines if desired.

   if (show_temp.ne.0) then
      if (non_metric.eq.1) then 
         tcloc=((tkloc-273.15)*1.8)+32         ; Farenheight, set tmp_units=0 for Celsius
      else
         tcloc=tkloc-273.15                    ; Celsius
      end if  

      tcloc!0="Time"
      tcloc!1="bottom_top"
      tcgrid=tcloc(bottom_top|:ptop,Time|:)   ; reverse X and Y trick to get time on horizontal axis

      tc_res                = res2D
      tc_res@cnLevelSelectionMode = "ExplicitLevels"	; manually set the contour levels with the following 3 resources
      if (non_metric.eq.1) then
         tc_res@cnLevels    = (/ 20.,30.,40.,50.,60.,70.,80.,90.,100./)   ; set non-metric levels
      else
         tc_res@cnLevels    = (/ -10.,0.0,10.,20.,30./)   ; set levels
      end if 
      tc_res@cnLineLabelInterval        = 1 
      tc_res@cnExplicitLineLabelsOn = True
      if (non_metric.eq.1) then
         tc_res@cnLineLabelStrings  = (/ "20~S~o","30~S~o","40~S~o","50~S~o","60~S~o","70~S~o","80~S~o","90~S~o","100~S~o"/)
      else
         tc_res@cnLineLabelStrings  = (/ "-10~S~o","0~S~o","10~S~o","20~S~o","30~S~o"/)
      end if
      tc_res@cnLineDashSegLenF          = 0.18          ; assist in controlling concentration
      tc_res@cnLineLabelBackgroundColor = -1
      tc_res@cnLineLabelFontColor  = "white"
      tc_res@cnLineLabelDensityF = 0
      tc_res@sfYArray       = theselevels
      tc_res@cnFill         = False
      tc_res@cnLinesOn      = True
      tc_res@cnLineLabelsOn = True
      tc_res@cnLineColor    = templine_color
      tc_res@tmXBLabelsOn   = False
      tc_res@cnInfoLabelOn  = False
      tc_res@tiMainString   = ""
      tc_res@tiXAxisString  = ""
      tc_res@tiYAxisString  = ""

      showtemp = gsn_contour(wks,tcgrid,tc_res)
      draw(showtemp)
      delete(showtemp)

   end if



   ; use real altitude for right hand labels!
   ; zhere is the msl altitude in meters at each pressure level at each time at this location

   if (show_z_contour.ne.0)   then
      zgrid=zhere(plevels|:ptop-1,Time|:)
      ;;;;;;;;;;;;
      ; z contours
      ;;;;;;;;;;;;

      z_res=res2D
      z_res@sfYArray = theselevels

      ; z_res@cnFill = False

      z_res@cnLinesOn            = True
      z_res@cnLineLabelsOn       = True               ; very busy if True
      z_res@tmXBLabelsOn         = False
      z_res@tmYLLabelsOn         = False
      z_res@tmYRLabelsOn         = False
      z_res@cnInfoLabelOn        = False
      z_res@tiMainString         = ""
      z_res@tiXAxisString        = ""
      z_res@tiYAxisString        = ""
      z_res@trYReverse           = True
      z_res@cnLevelSelectionMode = "ExplicitLevels"    ; will explicitly set the levels

      ; z_res@cnLevels            = zhere(numtimes-1,plevels|:ptop-1:ystride*4) ; will explicitly set the levels
      ; z_res@cnLevels            = zhere(numtimes-1:,plevels:ystride*4)        ; will explicitly set the levels

      zlevels=zhere(numtimes-1,:)
      z_res@cnLevels            = zlevels(:ptop-1)                    ; will explicitly set the levels stride for p and z must match
      showz=gsn_contour(wks,zgrid,z_res)
      draw(showz)
      delete(showz)
   end if

   if (show_p_contour.ne.0)  then

      ; create a set of pressure lines to show changes in pressure during the day

      phere=pmb(:,:,locY,locX)
      phere!0 = "Time"
      phere&Time = taus
      phere!1 = "levels"
      phere&levels = plevels
      pgrid=phere(levels|:ptop-1,Time|:)
      p_res=z_res
      p_res@cnLineColor = "red" 
      p_res@cnLevels = plevels(:ptop-1)   ; will explicitly set the levels stride, must match z_res stride
      showp=gsn_contour(wks,pgrid,p_res)
      draw(showp) 

      ; write_matrix(pgrid, "24f5.0", False)

   end if

   ; has to be last to show at all.
   ; avoid fatal error above and set to 0 if no rain in forecast.

   if (show_this_rain.ne.0)
      draw(rain_plot) 
   end if

   draw(xy_plot)


   if (show_cape_3d.ne.1.and.show_cape.ne.0) then 
      do i=0,numtimes-1
         if ( .not.ismissing(cape(i)).and.cape(i).ge.2500 ) then          ; 2500-5300=strong 
            mkresT@gsMarkerColor      = "red" 
            mkresT@gsMarkerSizeF      = 0.065
            ;gsn_polymarker(wks,xy_plot,taus(i),lcl1(i)+50,mkresT)
            gsn_text (wks,xy_plot,sprintf("%.0f",cape(i)),taus(i),theselevels(ptop-1),txres)
;            gsn_text (wks,xy_plot,sprintf("cape=%.0f",cape(i)),taus(i),theselevels(1),txres)
         else 
            if ( .not.ismissing(cape(i)).and.cape(i).ge.1000) then      ; 1000-2500=moderate
               mkresT@gsMarkerColor      = "blue"  
               mkresT@gsMarkerSizeF      = 0.045
               ;gsn_polymarker(wks,xy_plot,taus(i),lcl1(i)+38,mkresT)
               gsn_text (wks,xy_plot,sprintf("%.0f",cape(i)),taus(i),theselevels(ptop-1),txres)
;               gsn_text (wks,xy_plot,sprintf("cape=%.0f",cape(i)),taus(i),theselevels(1),txres)
            else
               if ( .not.ismissing(cape(i)).and.cape(i).ge.500) then    ; 300-1000=weak
                  mkresT@gsMarkerColor      = "green" 
                  mkresT@gsMarkerSizeF      = 0.025        
                  ;gsn_polymarker(wks,xy_plot,taus(i),lcl1(i)+26,mkresT)     
                  gsn_text (wks,xy_plot,sprintf("%.0f",cape(i)),taus(i),theselevels(ptop-1),txres)
;                  gsn_text (wks,xy_plot,sprintf("cape=%.0f",cape(i)),taus(i),theselevels(1),txres)
               else
                  if ( .not.ismissing(cape(i)).and.cape(i).ge.300) then    ; 300-1000=weak      
                     gsn_text (wks,xy_plot,sprintf("%.0f",cape(i)),taus(i),theselevels(ptop-1),txres)
;                     gsn_text (wks,xy_plot,sprintf("cape=%.0f",cape(i)),taus(i),theselevels(1),txres)
                  end if
               end if
            end if
         end if
      end do
   end if

   if (show_cape_3d.ne.0) then 
      mkresTopCloud = mkres4
      mkresTopCloud@gsMarkerColor = "black"
      gsn_polymarker(wks, xy_plot, taus, el_p, mkresTopCloud) ; lowest freezing level snowflakes
      ;gsn_polyline(wks,xy_plot,taus,el_p,mkres2)

      do i=0,numtimes-1
         if ( .not.ismissing(lst_is_hour(i))) then
            if ( .not.ismissing(cape2d(i))) then
               if ( cape2d(i).ge.2500 ) then          ; 2500-5300=strong 
                  mkresT@gsMarkerColor      = "red" 
                  mkresT@gsMarkerSizeF      = 0.065
                  gsn_polymarker(wks,xy_plot,taus(i),lcl1(i)+50,mkresT)
                  gsn_text (wks,xy_plot,sprintf("cape3d=%.0f",cape2d(i)),taus(i),theselevels(ptop-1),txres)
               else 
                  if (cape2d(i).ge.1000) then      ; 1000-2500=moderate
                     mkresT@gsMarkerColor      = "blue"  
                     mkresT@gsMarkerSizeF      = 0.045
                     gsn_polymarker(wks,xy_plot,taus(i),lcl1(i)+38,mkresT)
                     gsn_text (wks,xy_plot,sprintf("cape3d=%.0f",cape2d(i)),taus(i),theselevels(ptop-1),txres)
                  else
                     if (cape2d(i).ge.500) then    ; 300-1000=weak
                        mkresT@gsMarkerColor      = "green" 
                        mkresT@gsMarkerSizeF      = 0.025        
                        gsn_polymarker(wks,xy_plot,taus(i),lcl1(i)+26,mkresT)     
                        gsn_text (wks,xy_plot,sprintf("cape3d=%.0f",cape2d(i)),taus(i),theselevels(ptop-1),txres)
                     else
                        if (cape2d(i).ge.300) then    ; 300-1000=weak   
                           gsn_text (wks,xy_plot,sprintf("cape3d=%.0f",cape2d(i)),taus(i),theselevels(ptop-1),txres)
                        end if
                     end if
                  end if
               end if
            end if
         end if
      end do
   end if

   ; print debug info ToninoTatsi
   ; do l=0,ptop-1
   ;    gsn_text(wks,xy_plot,tcloc(0,l),1,theselevels(l),lbtxtres) 
   ; end do




   if (debug.ne.0) then
      thisdebug = True
      print("The following is the output from list_hlus ")
      list_hlus()
      print(" ")
      print(" ")
      print(" ")
      print("The following is the output from list_files")
      list_files()
      print(" ")
      print(" ")
      print(" ")
      print("The following is the output from list_vars")
      list_vars()
      print(" ")
      print(" ")
      print(" ")

      print("There are these gsn objects being created by the program")
      print(" ")
      findgsn="egrep '=.*gsn' windgramtjac.ncl |egrep -v '^ *;'"
      gsnlist=systemfunc( findgsn )
      print(gsnlist)
      print(" ")

      bb= NhlGetBB((/rel_humd,lapse_plot,wind_gram/))

      ;bb= NhlGetBB((/rel_humd,timestamp,lapse_plot,wind_gram,raspmsg,marker/))

      print("the bounding boxes of the various plotted items are below ")
      print(bb)
            
      print("begin res2D")
      print_opts(res2D, res2D, thisdebug)
      print(" ")
      print(" ")

      print("begin lapse_res")
      print_opts(lapse_res, lapse_res, thisdebug)
      print(" ")
      print(" ")

      print("begin hum_res")
      print_opts(hum_res, hum_res, thisdebug)
      print (" ")
      print (" ")

      print("begin uv_res")
      print_opts(uv_res, uv_res, thisdebug)
      print(" ")
      print(" ")

      do i=0,numtimes-1
         print ("lcl1("+i+") ="+lcl1(i)+" hPa ")
      end do;

      do j=0,ptop-1
         do i=0,numtimes-1
            print ("rhgrid("+j+","+i+") ="+rhgrid(j,i))
         end do;
      end do;

      do i=0,numtimes-1
         print("At "+lst_string(i)+" press at surface = "+(press(i,0,locY,locX)/100)+" hPa - press at top of the region = "+(press(i,ptop,locY,locX)/100)+" hPa")
      end do;
         print("HGT = "+hft+" feets - Z lowest surface = "+z(0,0,locY,locX)+" ?unit? ")
   end if

   frame(wks)                            ; now frame the plot   
   delete(wks)

   nclv=get_ncl_version()                       ; returns string like 6.0.0 or 5.2.1
   nclv_c = stringtochar(nclv)                  ; creates an array of character types 
   vnum=stringtoint(chartostring(nclv_c(0)))    ; takes first element of above and turns it into an integer
   delete(nclv)
   delete(nclv_c)

   ; deal with ncl png naming issue 5.1 5.2 goes away in 6.0.0. so only try if vnum < 6

   if ( type .eq. "png" )
      cmd = "composite -geometry 70x60+5+5  logo.svg " + windgram + ".png " +  windgram + ".png "
      ;print(cmd)
      system(cmd)   
   end if

   ;destroy(wks)





end do;             




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; end of site loop is doing a region we loop through here once for each site in the region keeping data intact
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; delete site loop variables
; must delete domain specific variables that have dimensions
; to avoid dimension mismatch on next loop  the error it avoids is:   
; Fatal:Dimension sizes of left hand side and right hand side of assignment do not match
; NCL promises a better way to do this soon.  As is, if you try to delete a nonexisting variable you get a fatal error.

if (isvar("DOMAIN"))

if ((DOMAIN.eq."all").or.(DOMAIN.eq."ALL"))

;;; debug start ;;;
if (debug.ne.0)
   print (" ")
   print ("Deleting Arrays and resources so we can do another Domain")
   print (" ")
end if
;;; debug end ;;;

 thissite_ndx=ns+1 ;increment this  from the inner site loop counter

 if (isvar("SITE"))
   delete(SITE)
end if

delete(ns)

        delete(a)
        delete(b)
        delete(caption)

        delete(day)
        delete(fs)
        delete(onefile)

if (isvar("zmeters"))
 delete(zmeters)
end if 

if (isvar("zhere"))
 delete(zhere)
end if 

if (isvar("zhere_m"))
delete(zhere_m)
end if 

if (isvar("zmeter"))
delete(zmeter)
end if

if (isvar("zmeters"))
delete(zmeters)
end if

if (isvar("z"))
delete(z)
end if

if (isvar("zfeet"))
        delete(zfeet)
end if 

if (isvar("feets"))
        delete(feets)
end if

        delete(filecommand1)
        delete(filecommand2)
        delete(freezelevel)
        delete(fs)

if (isvar("ftdiffs"))
        delete(ftdiffs)
end if
if (isvar("hdiffs"))
        delete(hdiffs)
end if
        delete(hfx)
        delete(h)

        delete(lapseptop)
        delete(lcl1)
        delete(lcl4)
	delete(lclj_p)
	delete(bltj_p)
	delete(hgldj_p)

        delete(plevels)
        delete(theselevels)
        delete(lgrid)
        delete(locij)
        delete(lp)
        delete(lpblt)
        delete(lpblt_p)
        delete(lqv)
	delete(lmslp)
	delete(lhcrit)
	delete(lsfclclheight)
	delete(lhglider)
        delete(lst)
        delete(ltd)
        delete(maxp)
        delete(minp)
        delete(mslp)
        delete(p)
        delete(numx)
	delete(numy)
	delete(numlevels)

        delete(pb)
        delete(PH)
        delete(PHB)
        delete(press)
        delete(pmb)
        delete(pblh)
        delete(pblt)
	
        delete(PSFC)
        delete(QVAPOR)
        delete(rh)
        delete(rhpoint)
        delete(rhgrid)
        delete(t_0)
        delete(t_1)
        delete(taus)
        delete(bliptaus)
        delete(tc)
        delete(tcloc)
        delete(tcgrid)
        delete(td)
        delete(tdiffs)
        delete(ter)
        delete(times)
        delete(timesinfiles)
        delete(tk)
        delete(tkall)
        delete(tkloc)
        delete(tmp)
        delete(tmpu)
        delete(tmpv)
        delete(u)
        delete(ugrid)
        delete(u_point)
        delete(v)
        delete(vhf)
        delete(vgrid)
        delete(v_point)
        delete(XLAT)
        delete(XLONG)
        delete(wstar)
        delete(lwstar)
        delete(wstar_1)
        delete(mwstar)
        delete(swstartxt)
        
	delete(hcrit)
	delete(hcrit_1)
	delete(sfclclheight)
	delete(sfclclheight_1)
	delete(hglider_1)
	delete(hglider) 
	delete(zgrid)

; must delete domain specific variables that have dimensions
; delete the resources as well

        delete(res2D)
        delete(lbtxtres)
        delete(lapse_res)
        delete(hum_res)
        delete(mkres)
        delete(mkres2)
        delete(mkres3)
        delete(mkres4)
        delete(llres)
        delete(uv_res)
        delete(tc_res)
        delete(z_res)

end if

;;; debug start ;;;
if (debug.ne.0)
 print (" ")
 print ("End of outside do loop going to next region if there is one. ")
 print (" ")
end if 
;;; debug end ;;;
end if 

end do;

;;; debug start ;;;
if (debug.ne.0)
print ("All done looping. ")
end if
;;; debug end ;;;

exit

