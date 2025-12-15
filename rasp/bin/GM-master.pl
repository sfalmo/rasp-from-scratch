#! /usr/bin/perl -w

# PAULS === NCL TIMEOUT now set to 90 Mins
#           $gridcalctimeoutsec is now  (9*3600) [9 hours!);
#           This is total run time, inc copying, archiving, etc
#           $cycle_waitsec = 3 *60; # Was 3 mins
#           27 Dec 2012:
#           Fixed Rerun on failed NCL
#           Fixed year error when curr+n crosses year boundary

#### 11 July 2015
# Add fixes for end of fttprd as per
# http://www.drjack.info/cgi-bin/WEBBBS/rasp-forum_config.pl/read/5978#5978
# and ff.
# Tanks to Alan C!!

###>>>>>>>>>>>> VERSION: $Revision: 2.136 $ $Date: 2008/09/15 00:27:34 $Z <<<<<<<<<<<<###
########## TO-DO: ######################################################
########################################################################
#########################################################################################
###  RASP (Regional Atmospheric Soaring Predictions) COMPUTER PROGRAM
###  Original Creator:  Dr. John W. (Jack) Glendening, Meterologist  2005
###  Script copyright 2005-2006  by Dr. John W. Glendening  All rights reserved.
###  External credits:
###    utilizes Weather Research and Forecasting (WRF) meteorological model
###    utilizes National Center for Atmospheric Research (NCAR) graphics
###    utilizes model output from the National Center for Environmental Prediction (NCEP)
#########################################################################################
### rasp.pl runs weather prediction model, producing soaring info from model output
### Written by Jack Glendening <glendening@drjack.info>, Jan 2005+
  if ( $#ARGV < 1 || $ARGV[0] eq '-?' ) {
  print "RASP:  \n";
  print "< \$1: => JOBARG (eg  ALL|PANOCHE|WILLIAMS|CANV|SW_SOOUTHAFRICA|GREATBRITAIN|REGIONXYZ) > \n";
  print "< \$2: =>               > \n";
  print "<    -t jday => test with no init,getgrib,ftpmail,save for specified julianday<_year> (0=today) \n";
  print "<    -T jday => test with no testsection modification - flags vary   > \n";
  print "<    -p jday => init+model for specified julianday<_year> (0=today) - lgetgrib=1,send=0 lsave=0 - output to terminal > \n";
  print "<    -P jday => init+model for specified julianday<_year> (0=today) - lgetgrib=1 - output to file > \n";
  print "<    -q jday => quick init (skip grib_prep) + model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  print "<    -Q jday => quick init (skip grib_prep) + model for specified julianday<_year> (0=today) - lgetgrib=0 - output to file > \n";
  print "<    -r jday => rerun model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  print "<    -R jday => rerun model for specified julianday<_year> (0=today) - lgetgrib= - output to file > \n";
  print "<    -b => batch with getgrib,init+modelrun,save but NO ftpmail        > \n";
  print "<    -m => batch with getgrib,init+modelrun,ftpmail=2(NOprev.day),save > \n";
  print "<    -M => batch with getgrib,init+modelrun,ftpmail,save               > \n";
  print "<    -n => ala -m but no getgrib > \n";
  print "<    -N => ala -M but no getgrib > \n";
  print "KILL SIGNALS:  STOP=-23  CONTINUE=-25  END(+final_processing)=-2 \n";
  exit 0; }
############## PROGRAM COPYRIGHT NOTICE #################################
##
##   PROGRAM COPYRIGHT NOTICE
##
##   RASP (Regional Atmospheric Soaring Predictions) COMPUTER PROGRAM
##   Version: $Revision: 2.136 $ $Date: 2008/09/15 00:27:34 $
##   Original Creator: Dr. John W. (Jack) Glendening, Meteorologist (drjack@drjack.info)
##   Copyright 2005-2006  by John W. Glendening   All rights reserved.
## 
## This program is at present NOT in the public domain and is intended
## to be utilized only by the copyright holder or those specifically
## designated by him to run local versions for regional forecasting.
## It is not be be used, copied, modified, or distributed without the
## written permission of the copyright holder.
##
## The copyright holder will not be liable for any direct, indirect, 
## or consequential damages arising out of any use of the program or
## documentation.
## 
## Title to copyright in this program and any associated documentation
## will at all times remain with copyright holder.
##
## However, in the event of the death of the original creator, this program
## and all RASP and BLIP programs, scripts, data and information are to be
## released under the terms of version 2 of the GNU General Public License.
## A copy of that license should be in the "gnu_gpl_license.txt" file,
## but a copy of the GNU General Public License can also be 
## obtained from the Free Software Foundation, Inc., 59 Temple Place -
## Suite 330, Boston, MA 02111-1307, USA, or, on-line at
## http://www.gnu.org/copyleft/gpl.html.
##
#########################################################################
#############################################################################
###################  USAGE NOTES  ###########################################
#############################################################################
#########  TO RUN "WINDOW-ONLY" (stage2) JOB  #####################
### MUST HAVE ALREADY RUN SUCCESSFUL STAGE1 ( REGIONXYZ) CASE 
###    since its output file needed for input to stage2
### SETUP JOB FILE rasp.run.parameters.REGIONXYZ-WINDOW ala rasp.run.parameters.REGIONXYZ
###    EXCEPT set $LRUN_WINDOW{REGIONXYZ}=1
### RUN ALA "rasp.pl REGIONXYZ-WINDOW -m" or "rasp.pl REGIONXYZ-WINDOW -q jjj" where jjj is that used for REGIONXYZ run
###    but no downloading done
### NOTE THAT COULD SET $LRUN_WINDOW{REGIONXYZ}=1 in rasp.run.parameters.REGIONXYZ and use,
###    but use of rasp.run.parameters.REGIONXYZ-WINDOW helps prevents confusion
###################################################################
#############################################################################
########## PROGRAMMING NOTES: ###########################################
##  BASIC DECISION: SHOULD JOB BASIS BE "ALL FORECASTS FOR SAME SOARING DAY" OR "ALL GRIB FILES ON SAME JULIAN DAY"
##                 here is latter primarily for historical reasons but former might be better
##  ASSUMES THAT WILL NEVER ASK FOR FILE WITH INIT(ANAL) TIME BEYOND CURRENT JULIAN DAY !
##  GRIB FILES GENERALLY TREATED INDEPENDENTLY, YET ARE ACTUALLY NEEDED IN SEPARATE GROUPINGS
#########################################################################
#############################################################################
###### forXItest: USE FOR RUNS ON XI
### FOR XI, SET $LMODELINIT=0 TO AVOID INITIALIZATION
### FOR XI, WHEN INITIALIZING ($LMODELINIT=1) WITHOUT DOWNLOAD ($LGETGRIB=0) MUST
### PRESENT AVAILBLE XI TEST INITIALIZATIONS
###  Run by modifying rasp.run.parameter.REGION variables as below, if necessary, then call with proper day ala "rasp.pl PANOCHE -q 92_2005" for RUCH
#############################################################################
###### TRACING INITIALIZATION ERRORS  eg "died ./wrfprep.pl line 693"
### CHECK FOR FTP ERROR
### CHECK GRIB PREP RESULTS:
##     in .../WRF/WRFSI/EXTDATA/log - in latest gp_RUCH.yyyymmddhh.log (only available for _last_ grib file processed) look for "Normal termination of program grib_prep" 
##     in .../WRF/WRFSI/EXTDATA/extprd should have files ala RUCH:yyyy-mm-dd_hh 
### CHECK WRF PREP RESULTS:
##     in .../WRF/WRFSI/domains/REGIONXYZ/log - in latest yyyymmddhh.wrfprep look for "wrfprep.pl ended normally" - if not found, also look for error messages in other logs 
##     errors can be caused by non-matching (1) init.model as $GRIBFILE_MODEL & in a wrfsi.nl (2) $GRIBFILES_PER_FORECAST_PERIOD{REGION} & @{$GRIBFILE_DOLIST{REGION}} for init.model
#############################################################################
####### FOR DEBUG MODE: run with -d flag  (but not for neptune)
### In debug mode, set package name + local variables so X,V don't show "main" variables, ie:
### To enable verbose diagnostics (but not for CRAY):
### To restrict unsafe constructs (vars,refs,subs)
###    vars requires variables to be declared with "my" or fully qualified or imported
###    refs generates error if symbolic references uses instead of hard refs
###    subs requires subroutines to be predeclared
### To provide aliases for buit-in punctuation variables (p403)
      use English;
####### FOR GRIB ARCHIVE RUN   GFS(1x1deg-180hrmax)/ETA(~11Mb-12km-60hrmax)/RUC(20km-12hrmax) archives at https://nomads.ncdc.noaa.gov/data.php
###     BUT ARCHIVE RUC CANNOT INIT (missing cloud/rain/ice/snow/graupel/soil/etc parameters)
###         with RUCH Vtable failed at wrfprep: hinterp log has zero length & with RUCP Vtable failed at wrfprep: hinterp log says "no valid landmask found!", no soil height interpolation, etc. and later fails
### download grib files for necessary date and times
###    e.g. "wget https://nomads.ncdc.noaa.gov/data/gfs-avn-hi/200602/20060219/gfs_3_20060219_1200_012.grb"
###    e.g. "wget https://nomads.ncdc.noaa.gov/data/meso-eta-hi/200602/20060219/nam_218_20060219_1200_012.grb"
### create links in GRIB directory to expected file names for all necessary times
###    e.g. "ln -s gfs_3_20060219_1200_012.grb gfs.t12z.pgrb2f12"
###    e.g. "ln -s nam_218_20060219_1200_012.grb nam.t12z.awip3d12.tm00"
### possbily create special rasp.run.parameters file for different $GRIBFILE_MODEL/$LRUN_WINDOW/%GRIBFILE_DOLIST
###    e.g. rasp.run.parameters.PANOCHE-TEST
### possibly move old output directory(s) to temporary name (so can easily save output directory with new name)
###    e.g. "mv PANOCHE PANOCHE-OLD" & "mv PANOCHE-WINDOW PANOCHE-WINDOW-OLD"
### run with julian date specification
###    e.g.  "rasp.pl PANOCHE-TEST -q 050_2006"
### possibly save output directory(s) with new name
###    e.g. "mv PANOCHE PANOCHE-19FEB2006" & "mv PANOCHE-WINDOW PANOCHE-WINDOW-19FEB2006"
###########  EXTERNAL PROGRAMS:  ########################################
  ## Unix Shell Commands:  echo, rm, cp, mv, date, grep, ps, sleep, ftp, Mail
  ## My Unix Scripts:      jdate2date
  ## Scripts for ftp file transfer (with password!):  gribftpget, ftp/cp,rasp.multiftp/cp,blipmap.ftp/cp2previousday curl
  ## Graphics programs:  ncl(NCARG), ctrans(NCARG), convert(ImageMagick)/imcopy(SDSC)
  ## Model: WRF preprocessing+run scripts
  ## Graphics scripts: plt_chars.pl(uses plt_chars.exe), no_blipmap_available.pl (uses no_blipmap_available.exe)
  ## Compresssion program:  gzip(GNU)/zip
  ## Required non-standard perl modules: Proc::Background
####################  ERROR MESSAGES  #####################################
  ##  UNMATCHED PARENS BETWEEN BACKSLASHS:  sh: -c: line 1: unexpected EOF while looking for matching `"' sh: -c: line 2: syntax error: unexpected end of file
  ##  nan IN PLOT DATA FILE (at data line 115): ERROR - lsli=-12 reading 2D data:  112 115
########## COMMENTED-OUT ALTERNATIVES #####################################
#################  NOTES  ##############################################
##########  PROCESSING INFO  ###########################################
### TIME STEP
### 2005-01-05: used dt=60s for first cases, but test with 2005-01-05-0Z+12h init went never-never-land after 45 iters so changed to dt=30s (non-hydro,rk=3) SM2.8Pentium=>~35min(40x49x30)
#########################################################################
### GRIB FILENAMES
  ## 32km ETA(NAM) (grid221) ~89Mb files on NCEP server ftpprd.ncep.noaa.gov
  ##   nam.tiiz.awip32pp.tm00.grib2 at directory pub/data/nccf/com/nam/prod/nam.YYYYMMDD 
  ## 40km ETA(NAM) (grid212) ~15Mb files on NCEP server ftpprd.ncep.noaa.gov
  ##   nam.tiiz.awip3dpp.tm00 at directory pub/data/nccf/com/nam/prod/nam.YYYYMMDD 
  ##   #eta-grib1 nam.tiiz.awip3dpp.tm00 at directory pub/data/nccf/com/nam/prod/nam.YYYYMMDD 
  ## ALTERNATE 40km ETA(NAM) files on NWS server  tgftp.nws.noaa.gov
  ##   fh.00pp_tl.press_gr.awip3d at directory SL.us008001/ST.opnl/MT.nam_CY.ii/RD.yyyymmdd/PT.grid_DF.gr1
  ## 20km(<-13km) FSL RUCH ~52Mb on server gsdftp.fsl.noaa.gov
  ##   yyjjjhh0000pp.grib at 13kmruc/maps_fcst20
  ##   #old-20km ~55Mb yyjjjhh0000pp.grib at 20kmruc/maps_fcst
  ## 13km FSL RUCH ~120Mb on server gsdftp.fsl.noaa.gov
  ##   yyjjjhh0000pp.grib at 13kmruc/maps_fcst
  ## GFSN = 0.5degx0.5deg GFS GRIB2 files on NCEP server  ftpprd.ncep.noaa.gov
  ##   gfs.t00z.pgrb2f00 at directory pub/data/nccf/com/gfs/prod/gfs.YYYYMMDDCC  (CC=cycle, eg 00)
  ##     levels= 1000,975,950,925,900,850,800,750,700,650,600,550,500,450,400,350,300,250,200,150,100,70,50,30,20,10 mb
  ##     289 variables
  ## *NO* ALTERNATE GFS 0.5degx0.5deg GFS GRIB2 files on NWS server   tgftp.nws.noaa.gov
  ##   (??  at directory SL.us008001/ST.opnl/MT.gfs_CY.ii/RD.20050218/PT.grid_DF.gr1)
  ## GFSA = LimitedArea 0.5degx0.5deg GFS GRIB1 files on NOMADS server 'https://nomad1.ncep.noaa.gov/cgi-bin/ftp2u_gfs0.5.sh
  ## AVN = LimitedArea 1degx1deg GFS GRIB files on NOMADS server  ftpprd.ncep.noaa.gov
  ##   grib1=gfs.t00z.pgrbf00 grib2=gfs.t00z.pgrb2f00 at directory pub/data/nccf/com/gfs/prod/gfs.YYYYMMDDCC  (CC=cycle, eg 00)
  ##     levels= 1000,975,950,925,900,850,800,750,700,650,600,550,500,450,400,350,300,250,200,150,100,70,50,30,20,10 mb
  ##     320 variables
  ## ALTERNATE AVN 1degx1deg GFS GRIB1 files on NWS server   tgftp.nws.noaa.gov
  ##   fh.00pp_tl.press_gr.onedeg at directory SL.us008001/ST.opnl/MT.gfs_CY.ii/RD.20050218/PT.grid_DF.gr1
##########  INSTALL NOTES  ###########################################
################### NAMES CONSIDERED ##################################
#########################################################################
######### SET DATA ###########
### perl modules needed
  use POSIX qw(mktime);
### TO ALLOW FLAGS IN waitpid
  use POSIX "sys_wait_h";
### for parallel ftping in background - see https://search.cpan.org/~bzajac/Proc-Background-1.08/lib/Proc/Background.pm
  use Proc::Background ;
###### SET PROCESS ID
  $RUNPID = $$ ;
###### SET PROGRAM NAME
  $program = $0;
  $program =~ s|$ENV{'PWD'}/||;
  $program  =~ s|\.pl$||;
###### SET BASIC DIRECTORIES
### SET BASE DIRECTORY for local "DRJACK" directory setup, based on location of this program
  if( $0 =~ m|^/| ) { ( $RUNDIR = "${0}" ) =~ s|/[^/]*$|| ; }
  else              { ( $RUNDIR = "$ENV{'PWD'}/${0}" ) =~ s|[\./]*/[^/]*$|| ; }
### run subdirectory - PRESENTLY HARDWIRED TO STATIC VALUE, NOT TO $JOBARG
####### FIRST ARGUMENT IS JOBARG
### idea of JOBARG is distinguish/identify a job
### but due to simultaneous need of same grib file, CANNOT simulataneously run 2 same GRIBFILE_MODEL jobs even with different JOBARG
###    To allow separate jobs should use RUNDARG to set $RUNDIR BELOW (which also distinguishes curls from different JOBARG jobs)
###     which would separate everything by JOBARG _EXCEPT_ $SAVEDIR (so files would be saved to common directory)
###     BUT GRIB link in grib_prep.nl NOT separate so above not be sufficent to separate jobs
###     (once thought to have two jobs running each with different JOBARG )
###     (but would need to keep changing grib_prep.nl to keep grib file separate so not done)
## PRESENT THOUGHT IS THAT SHOULD PLAN TO JUST HAVE A SINGLE JOB RUNNING
## SO CAN NOW TREAT REGIONS BY PUTTING EACH INTO A SEPARATE THREAD/JOB
##      (this also allows a single grib get for all regions)
  $JOBARG = $ARGV[0];
  shift;
### REQUIRE JOBARG TO BE IN CAPS
  $JOBARG =~ tr/a-z/A-Z/;
#############################################
##########  OVERRIDE NORMAL CHOMP  ##########
### must be set here to avoid compile warning "jchomp() called too early to check prototype"
### but then edpsub macro cuts off lines above from narrowed region
sub jchomp(@)
### DELETES ENDING NEWLINE ALA REGULAR CHOMP
{
  if ( $_[0] =~ m/(^.*)\n$/ ) { $_[0] = $1; }
  return  ;
}
############################################
###############################################################################################
#################################  FLAGS  #####################################################
### LPRINT:     >0 output to std.out,  <0 output to file $program.printout
###             |$LPRINT|=4 for most output,  2=normal, 1=minimal,  0=none
### LGETGRIB:   0= skip grib get & prep
###             1= run grib_prep.pl for existing grib files
###             2= get new grib files at scheduled times
###             3= get new grib files via ls query
###            -1= grib file name specified
### LSEND:      0= images produced only in local "RASP/RUN/OUT" subdirectory
###             1= copy images to web directory using filenames pre-pended with "test"
###             2= copy images to web directory using normal filenames
###             -1,-2 => ftp images to remote server (NOT OPERATIONALLY TESTED)
###             3= also do firstofday processing (NOT IMPLEMENTED)
### LSAVE:      0= nosave 1= save plot data files 2= also save plot images 3=also save init files
### LMODELINIT: 1= do wrfsi initialization 0=none
### LMODELRUN:  2= run all  1= skip wrf.exe  0= no_run
################################################################################################
###### PARSE ARGUMENT AND SET FLAGS
  ## -t jday => test with testsection & no init,getgrib,degrib,ftpmail,save  for specified julianday<_year> (0=today)
  ## -T jday => test with no testsection <for specified julianday<_year> - flags vary
  ## -q jday => init+model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  ## -Q jday => init+model for specified julianday<_year> (0=today) - lgetgrib=0 - output to file > \n";
  ## -r jday => rerun model for specified julianday<_year> (0=today) - lgetgrib=0,send=0 lsave=0 - output to terminal > \n";
  ## -R jday => rerun model for specified julianday<_year> (0=today) - lgetgrib=0 - output to file > \n";
  ## -b => batch with getgrib,modelrun,save but NO FTP/MAIL
  ## -m => batch with getgrib,modelrun,ftpmail,save but no firstofday processing       
  ## -M => batch with getgrib,modelrun,ftpmail,save and firstofday processing    
  if ( $ARGV[0] eq '-t' ) {
    $RUNTYPE = '-t';
    ###### INTENDED FOR XI RUNS 
    ###### MUST ALSO SETUP TEST PARAMETER SECTION
    ### LMODELINIT=0 INHIBITS MODEL INITIALIZATION
    $LMODELINIT = 0 ;
    $LMODELINIT = 1 ; 
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-T' ) {
    $RUNTYPE = '-T';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 0; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-p' ) {
    $RUNTYPE = '-p';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT get new files from website
    $LGETGRIB = 1;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-P' ) {
    $RUNTYPE = '-P';
    ### TERMINAL print DEBUGS
    $LPRINT = -3;
    ### DONT get new files from website
    $LGETGRIB = 1;
    ### DONT/DO send ftp/mail 
    ### DONT/DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-q' ) {
    $RUNTYPE = '-q';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-Q' ) {
    $RUNTYPE = '-Q';
    ### TERMINAL print DEBUGS
    $LPRINT = -3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    ### DONT/DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-r' ) {
    $RUNTYPE = '-r';
    ### TERMINAL print DEBUGS
    $LPRINT = +3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    $LSEND = 0;
    ### DONT/DO save final info to storage file
    $LSAVE = 0;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 0; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-R' ) {
    $RUNTYPE = '-R';
    ### TERMINAL print DEBUGS
    $LPRINT = -3;
    ### DONT/DO get new files from website
    $LGETGRIB = 0;
    ### DONT/DO send ftp/mail 
    ### DONT/DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 0; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### SET JULIAN DAY BASED ON ARGUMENT
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
  }
  elsif ( $ARGV[0] eq '-b' ) {
    $RUNTYPE = '-b';
    ### FILE print DEBUGs
    $LPRINT = -3;
    ### DO get new files from website
    $LGETGRIB = 2;
    ### NO  send ftp/mail !!!
    $LSEND = 0;
    ### DO save final info to storage file
    $LSAVE = 3;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
  }
  elsif ( $ARGV[0] eq '-m' || $ARGV[0] eq '-n' ) { 
    $RUNTYPE = '-m';
    ### FILE print DEBUGs
    $LPRINT = -3;
    ### DO get new files from website
    if ( $ARGV[0] eq '-m'  ) {
      $LGETGRIB = 2;
    }
    elsif ( $ARGV[0] eq '-n'  ) {
      $LGETGRIB = 0;
    }
    ### FULL send ftp/mail but _dont_ create a "first" file
    $LSEND = 2;
    ### DO save final info to storage file
    $LSAVE = 3;
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
  }
  elsif ( $ARGV[0] eq '-J' ) {
    if  ( $#ARGV <0 ) { die 'Must specifiy a julian date for this option'; }
    $julianday_forced = $ARGV[1];
    $RUNTYPE = '-M';
    $LGETGRIB = 2 ; 	# Get new files from website
    $LMODELINIT = 1;	# LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELRUN = 2;		# LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LPRINT = -3;		# $LPRINT=-3 prints to output file
    ###!!!### SITE-SPECIFIC PARAMETER: $LSEND=2 copies images to web directory
    ### $LSEND=-2 ftp images to server specified in $UTILDIR/rasp.multiftp - must also modify that file appropriately (NOT OPERATIONALLY TESTED)
    ###!!!### SITE-SPECIFIC PARAMETER: $LSAVE=3 saves image files (a single forecast hour only) and initial condition files to a storage directory
    ### $LSAVE=0 inhibits all such saves, preserving disk space
    ### $LSAVE=1 saves images only, using much less disk space than $LSAVE=2
  }
  elsif ( $ARGV[0] eq '-M' || $ARGV[0] eq '-N' ) {
    $RUNTYPE = '-M';
    ### DO get new files from website
    if ( $ARGV[0] eq '-M'  ) {
      $LGETGRIB = 2 ;
    }
    elsif ( $ARGV[0] eq '-N'  ) {
      $LGETGRIB = 0;
    }
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
    ### $LPRINT=-3 prints to output file
    $LPRINT = -3;
    ###!!!### SITE-SPECIFIC PARAMETER: $LSEND=2 copies images to web directory
    ### $LSEND=-2 ftp images to server specified in $UTILDIR/rasp.multiftp - must also modify that file appropriately (NOT OPERATIONALLY TESTED)
    ###!!!### SITE-SPECIFIC PARAMETER: $LSAVE=3 saves image files (a single forecast hour only) and initial condition files to a storage directory
    ### $LSAVE=0 inhibits all such saves, preserving disk space
    ### $LSAVE=1 saves images only, using much less disk space than $LSAVE=2
  }
### TREAT GRIB FILE INPUT CASE
### WARNING: IF RUN WHILE EXISTING JOB USING SAME JOBARG RUNNING, THIS WILL KILL THAT EXISTING JOB
### WARNING: WILL HAVE WRONG FORECAST PERIOD IF FILE FROM ONE CURRENT DAY RUN ON A DIFFERENT CURRENT DAY
  elsif ( $ARGV[0] !~ m|^-m| ) { 
    $specifiedfilename = $ARGV[0] ;
    $RUNTYPE = '-m';
    ### FILE print DEBUGs
    $LPRINT = -3;
    ### do NOT get new files from website - -1 INDICATES THAT FILENAME IS SPECIFIED
    $LGETGRIB = -1;
    ### FULL send ftp/mail but _dont_ create a "first" file
    ### DO save final info to storage file
    ### LMODELINIT=0 INHIBITS MODELINITIALIZATION
    $LMODELINIT = 1; 
    ### LMODELRUN=0 INHIBITS MODEL RUN + PLOTTING TO ALLOW FILE PROCESSING LOGIC CHECKS
    $LMODELRUN = 2; 
  }
  else {
    print "$program ERROR EXIT: bad argument 1 = $RUNTYPE \n";
    exit 2;
  }
### AS SOON AS LPRINT IS SET, SET PRINTING FILEHANDLES
### ALL TEST OUTPUT SENT TO STDERR
### printfh used for perl print comands
### printpipe used for shell echo commands - no longer used normally, kept for possible test prints
### (output doesnt appear anywhere if use $PRINTPIPE = '';)
  if ( $LPRINT >=0 ) {
    ### FOR $LPRINT>=0, FILE $PRINTFH,$PRINTPIPE PRINT TO TERMINAL
    ### FOR TEST PRINT STDOUT TO TERMINAL
    $printoutfilename = "&1";
    ### for child processes which must have an actual file to write to
    $childprintoutfilename = "${RUNDIR}/LOG/${program}.ftpchild_printout";
    $PRINTPIPE = ' 1>&2';
    $PRINTFH = 'STDOUT';
  }
  elsif ( $LPRINT <0 ) {
    ### FOR $LPRINT<0, FILE HANDLE $PRINTFH,$PRINTPIPE PRINT TO A FILE
    ### NOW MAKE LPRINT POSTITIVE TO ALLOW SAME TESTS FOR DIFFERENT FILEHANDLES
    $LPRINT = abs( $LPRINT );
    $PRINTFH = 'FILEPRINT';
    ### set printout filename
    $printoutfilename = "${RUNDIR}/LOG/${program}.printout";
    `rm -f ${RUNDIR}/LOG/$printoutfilename`;
    ### for child processes which must have an actual file to write to
    $childprintoutfilename = $printoutfilename ;
    open ($PRINTFH, ">>$printoutfilename");
    $PRINTPIPE = ">> $printoutfilename";
  }
### PREVENT PRINT BUFFERING
  use FileHandle;
### must do STDOUT _last_
  select $PRINTFH; $|=1;
  select $PRINTPIPE; $|=1;
  select STDERR; $|=1;
  select STDOUT; $|=1;

#######################################################################
####################  START OF SET RUN PARAMETERS  ####################
### USE JOBARG TO CREATE griddolist
### READ PARAMETERS FROM EXTERNAL FILE IF IT EXISTS
  if ( -s "rasp.run.parameters.${JOBARG}" ) { 
    $externalrunparamsfile = "rasp.run.parameters.${JOBARG}" ;
    ### PREVENT PERL WARNINGS from certain parameters set in rasp.run.parameters... file
    %SAVE_PLOT_HHMMLIST = %PLOT_IMAGE_SIZE = ();
    require $externalrunparamsfile  ;
  }
  else {
    print $PRINTFH "ERROR EXIT: no rasp run parameters file found for $JOBARG\n"; exit 1;
  }
  ##########  PARAMETER ALTERATIONS  ##########
  ### SET WINDOW LOOP LIMITS BASED ON $LRUN_WINDOW
  foreach $regionkey (@REGION_DOLIST) {
    if( $LRUN_WINDOW{$regionkey} < 2 ) {
      $iwindowstart{$regionkey} = $iwindowend{$regionkey} = $LRUN_WINDOW{$regionkey} ; }
    else {
      $iwindowstart{$regionkey} = 0; $iwindowend{$regionkey} = 1 ;
    }
  }
### $LWINDOWRESTART=1 FOR RESTART FROM NON-WINDOW IC/BC WITH PRE-EXISTING GRIB FILE USED FOR NEEDED LANDUSE, ETC DATA
###                   (ALSO NEED BELOW: HARD-WIRED DAY/TIME FOR AN EXISTING GRIB FILE & START/END TIME ALTERATIONS)
###11feb2006  !!! I NO LONGER REMEMBER WHAT THIS SECTION (INVOKED BY SETTING $LWINDOWRESTART=1) IS ABOUT !!!
  $LWINDOWRESTART = 0;  
  ### SETUP FOR PANOCHE-WINDOW RESTART CASE
  if( $LWINDOWRESTART == 1 && $JOBARG eq 'PANOCHE-WINDOW' ) {
      $DOMAIN1_STARTHH{$JOBARG}[1] = '18';          # must have grib file available at or prior to this time
      $FORECAST_PERIODHRS{$JOBARG}[1] = 6;       
      # $BOUNDARY_UPDATE_PERIODHRS{$JOBARG}[1] = 1;     
      eval "\$DOMAIN2_START_DELTAMINS{\$JOBARG}[1] = 0" ;     # if non-zero, must set namelist.template INPUT_FROM_FILE=false
      eval "\$DOMAIN3_START_DELTAMINS{\$JOBARG}[1] = 0" ;     # if non-zero, must set namelist.template INPUT_FROM_FILE=false
      eval "\$DOMAIN2_END_DELTAMINS{\$JOBARG}[1] = 0" ;     # relative to domain1
      eval "\$DOMAIN3_END_DELTAMINS{\$JOBARG}[1] = 0" ;     # relative to domain1
      @{$PLOT_HHMMLIST{$JOBARG}[1]} = ( '1800','2100','0000' ); 
      print $PRINTFH "   PANOCHE-WINDOW WINDOW *RE*START starts at $DOMAIN1_STARTHH{$JOBARG}[1] with $FORECAST_PERIODHRS{$JOBARG}[1] hr period \n"; 
      ### END PANOCHE-WINDOW restart case
  }
  elsif( $LWINDOWRESTART == 1 ) {
    print $PRINTFH "$program ERROR EXIT: WINDOW RESTART NOT SETUP FOR JOBARG $JOBARG\n"; exit 1;
  }
##########  FOR BACKWARDS COMPATABILITY  ##########
if( $GRIBFILE_MODEL eq 'GFS' ) { $GRIBFILE_MODEL = 'GFSN'; } 
###############################################################

#############################################################
####################  END OF SET RUN PARAMETERS  ####################
#####################################################################
###### SET OTHER DIRECTORIES
### WRF base directory (WRFV2+WRFSI are subdirectories)
  $WRFBASEDIR="$RUNDIR";

### directory for grib file - *** MUST AGREE WITH VALUE IN WRFSI/extdata/static/grib_prep.nl
  $GRIBFILE_MODELDIR = "${RUNDIR}";
  $GRIBDIR = "$GRIBFILE_MODELDIR/GRIB";
### directory for saved files (uses separate subdirectorys for each grid
  $SAVEDIR = "${RUNDIR}/HTML/ARCHIVE";
### directory for temporary plot, ftp/cp files
  $OUTDIR = "$RUNDIR/OUT";

### WRF NCL DIRECTORY contains ncl plotting stuff
#  $NCLDIR = "$WRFBASEDIR/NCL";
#  Google Maps
  $NCLDIR = "$RUNDIR/GM";
####### HTML BASE DIRECTORY - where plot images sent to
# Note that this is now in the Region directory, as a link to the real place
  $HTMLBASEDIR = "$RUNDIR/HTML"; 
###### SET FILENAME INFO
### tmp filenames for gribftpget ftp output
  $GRIBFTPSTDOUT = "$RUNDIR/LOG/gribftpget.stdout"; 
  $GRIBFTPSTDERR = "$RUNDIR/LOG/gribftpget.stderr";
### tmp filename for gribftpls output for directory1
  $LSOUTFILE1 = "$RUNDIR/LOG/gribftpls.stdout1"; 
### tmp filename for gribftpls output for directory2
  $LSOUTFILE2 = "$RUNDIR/LOG/gribftpls.stdout2"; 
### tmp filename for gribftpls error output
  $LSOUTFILEERR = "$RUNDIR/LOG/gribftpls.stderr"; 
###### SET CYCLE CONTROL PARAMETERS
### SWITCHING TIME SETS *GMT* AFTER WHICH CYCLE ENDED AND PROGRAM TERMINATES FOR -M/-m RUNS
### SHOULD BE TIME BEYOND WHICH EXPECT NEW JOB TO START (with some padding) IE COMPARE TO CRONTAB TIME
##_for_next_day_switchingtime: 
  $switchingtimehrz{'ETA'}= 1.7;
  $switchingtimehrz{'GFSN'}= 1.7;
  $switchingtimehrz{'GFSA'}= 1.7;
  $switchingtimehrz{'AVN'}= 1.7;
  $switchingtimehrz{'RUCH'}= 1.7;
##_for_same_day_switchingtime: $switchingtimehrz = 23.7;
### SET MINIMUM FTP,CALC TIMES USED TO DETERMINE WHEN ANOTHER ITERATION POSSIBLE
  $minftpmin{'ETA'}=20; 
  $minftpmin{'GFSN'}=20; 
  $minftpmin{'GFSA'}=20; 
  $minftpmin{'AVN'}=20; 
  $minftpmin{'RUCH'}=20; 
  $mincalcmin{'ETA'}=5; 
  $mincalcmin{'GFSN'}=5; 
  $mincalcmin{'GFSA'}=5; 
  $mincalcmin{'AVN'}=5; 
  $mincalcmin{'RUCH'}=5; 
###### SET GRIB GET PARAMETERS
### set max waits for ftpget but should never be reached since file exists
### set max ftp time for grib get
  $getgrib_waitsec = 2 *60;                # sleep time, _not_ a timeout time
  ### GRIBAVAILHRZOFFSET USED TO _ADD_ CUSHION TO ACTUAL EXPECTED AVAILABILTY
  ### must treat gfsa/avn separately since cannot request before available (no date identifiation by ftp2u!)
  ### for test purposes, can be overridden by specifying $gribavailhrzoffset in rasp.run.parameters or rasp.site.parameters
  $gribavailhrzoffset{ETA} = -0.05; 
  $gribavailhrzoffset{RUCH} = -0.05; 
  $gribavailhrzoffset{GFSN} = -0.05; 
  $gribavailhrzoffset{GFSA} = +0.0; 
  $gribavailhrzoffset{AVN} = +0.6; 
### SET LS FTP TIMEOUT TIMES
### time for ls of grib file directory
### *NB* should match that used for curl in gribftpls
### ($gribgetftptimeoutmaxsec set further below, since differs for different models)
  $lsgetftptimeoutsec = 2 *60;
### CYCLE_WAITSEC IS SECONDS BETWEEN CYCLES WITH NO AVAILABLE FILES TO PROCESS
  # PAULS $cycle_waitsec = 3 *60;
  $cycle_waitsec = 30;
### CYCLE_MAX_RUNHRS = MAX HOURS FOR SCRIPT TO RUN (runaway script prevention) (not affected by day of start)
  $cycle_max_runhrs = 23.6 ;
### now use 2 min instead of cycle_waitsec since that is iter time when have ftp ls failure due to server being down
       $cycle_max = int( ($cycle_max_runhrs*3600.)/(2*60) );
### SET GRID CALC TIMEOUT TIME
### to avoid any possible hangup in model init/run section, set to 6 hr
### but some runs can extend longer if next time slot not fully loaded
  # $gridcalctimeoutsec = int( 8 *3600 );
  $gridcalctimeoutsec = int( 9 *3600 );

### SET NCL PLOT TIMEOUT TIME
  #PAULS $ncltimeoutsec = int( 60 *60 );          
  # This now the *total* plot time for all times
  # On a test, it took around 1:37:00 for 2Km domain
  # Provide a little leeway!
  $ncltimeoutsec = int( 180*60 );

### SET FTP TIMEOUT TIME (only used when $LSEND<0)
  my $ftptimeoutsec = int( 6 *60 );
### time for initial setup,renames on webbnet files (usually takes 3 mins) 
### should span internal iteration#*sleepsec in blipmap.ftp2previousday
###       (presently primarymaxiter=3 primarysleepsec=60)
### normal CA-NV (13 times) run time is ~3-4 min for blipmap.ftp2previousday
  $previousdayftptimeoutsec = 15 *60;
### SET GRIBGET PARAMETERS
### expect following statuses to be > $maxattempts, so then no files no longer available for processing
  $status_processed = 9;
  $status_skipped = 8;
  $status_problem = 7;
### for LGETGRIB=2 cases, set max scheduled attempts
  $max_schedgrib_attempts = 1;
### SET SLEEP TIME FOR MAIN THREAD FINISH/PLOT LOOP
  ### MUST ALLOW ENOUGH START-UP TIME FOR PREVIOUS wrfout FILES TO BE RE-NAMED
  if( $RUNTYPE eq '-T' || $RUNTYPE eq '-t' ) {
    $finishloopsleepsec = 10 ;
  }
  ### dont make so short that plotting finds wrfout... files created in REGIONXYZ-WINDOW during stage2-only initialization
  elsif ( $JOBARG =~ '-WINDOW' ) {
    $finishloopsleepsec = 300 ;
  }
  ### don't make more than 10 mins as 1-stage job can forecast 3hrs in ~10min
  elsif( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' ){
    $finishloopsleepsec = 180 ;
  }
  else {
    $finishloopsleepsec = 180 ;
  }
###### STORED IMAGE IDs
  $dow_localid = '36x18';
  $day_localid = '36x18';
  $mon_localid = '36x18';
###### SET BLANK DEFAULT $ADMIN_EMAIL_ADDRESS
### must be overriden by rasp.site.parameters since also used for anonymous login password
  $ADMIN_EMAIL_ADDRESS = ''; 
###### SET USERNAME
  $USERNAME = $ENV{'LOGNAME'};
###    These are empirically obtained values - might also depend on no. of model levels ?
#      The correct value is now determined automatically - See below
  $num_metgrid_levels{'GFSN'} = 27 ;
  $num_metgrid_levels{'GFSA'} = 48 ;   # Assumes Additional Parameters are also downloaded
  $num_metgrid_levels{'AVN'}  = 40 ;
  $num_metgrid_levels{'ETA'}  = 40 ;
  $num_metgrid_levels{'RUCH'} = 40 ;
### SET PARAMETER INFORMATION NAMES USED FOR IMAGE LOOP TITLE - note "~" escape NOT recognized by plt_text.exe 
  $paraminfo{'hglider'}       = 'Maximum Thermalling Height' ;
  $paraminfo{'dbl'}           = 'BL Depth' ;
  $paraminfo{'sfcshf'}        = 'Sfc. Heating' ;
  $paraminfo{'vhf'}           = 'Sfc. Virtual Heat Flux' ;
  $paraminfo{'sfcsun'}        = 'Sfc. Solar Radiation' ;
  $paraminfo{'sfcsunpct'}     = 'Normalized Sfc. Solar Radiation' ;
  $paraminfo{'wstar'}         = 'Thermal Updraft Velocity' ;
  $paraminfo{'hglider'}       = 'Thermalling Height' ;
  $paraminfo{'hbl'}           = 'Height of BL Top' ;
  $paraminfo{'hwcrit'}        = 'Height of Critical Updraft Strength' ;
  $paraminfo{'dwcrit'}        = 'Depth of Critical Updraft Strength' ;
  $paraminfo{'wblmaxmin'}     = 'BL Max. Up/Down Motion' ;
  $paraminfo{'zwblmaxmin'}    = 'MSL Height of maxmin Wbl' ;
  $paraminfo{'swblmaxmin'}    = 'AGL Height of maxmin Wbl' ;
  $paraminfo{'pwblmaxmin'}    = 'Depth of maxmin Wbl' ;
  $paraminfo{'blicw'}         = 'BL Integrated Cloud Water' ;
  $paraminfo{'aboveblicw'}    = 'Above-BL Integrated Cloud Water' ;
  $paraminfo{'blcwbase'}      = 'BL CloudWater Base' ;
  $paraminfo{'cwbase'}        = 'CloudWater Base' ;
  $paraminfo{'rhblmax'}       = 'BL Max. Relative Humidity' ;
  $paraminfo{'blcloudpct'}    = 'BL Cloud Cover' ;
  $paraminfo{'zsfclcl'}       = 'Cu Cloudbase' ;
  $paraminfo{'zsfclcldif'}    = 'Cu Potential' ;
  $paraminfo{'zblcl'}         = 'OvercastDevelopment Cloudbase' ;
  $paraminfo{'zblcldif'}      = 'OvercastDevelopment Potential' ;
  $paraminfo{'bsratio'}       = 'Buoyancy/Shear Ratio' ;
  $paraminfo{'blwindshear'}   = 'BL Vertical Wind Shear' ;
  $paraminfo{'sfctemp'}       = 'Surface Temperature' ;
  $paraminfo{'sfcdewpt'}      = 'Surface Dew Point Temperature' ;
  $paraminfo{'bltopvariab'}   = 'BL Top Uncertainty/Variability' ;
  $paraminfo{'cape'}          = 'CAPE' ;
  $paraminfo{'blwind'}        = 'BL Wind' ;
  $paraminfo{'sfcwind'}       = 'Surface Wind' ;
  $paraminfo{'bltopwind'}     = 'Wind at BL Top' ;
  $paraminfo{'wstar_bsratio'} = 'Thermal Updraft Velocity + B/S stipple' ;
  $paraminfo{'zsfclclmask'}   = 'Cu Cloudbase  where Cu Potential > 0' ;
  $paraminfo{'zblclmask'}     = 'OD Cloudbase  where OD Potential > 0' ;
  $paraminfo{'boxwmax'}       = 'Cross-Section at max vert. motion' ;
  $paraminfo{'press850'}      = '850 mb Constant Pressure Level' ;
  $paraminfo{'press700'}      = '700 mb Constant Pressure Level' ;
  $paraminfo{'press500'}      = '500 mb Constant Pressure Level' ;
##############################################################
###### SET NON-ARGUMENT FLAGS
### SET WHETHER MULTIPLE REGIONS WILL BE RUN SERIALLY (0) OR IN PARALLEL (1)
### AND WHETHER OUTPUT PLOT ALL DONE AT END (0) OR SOON AFTER THEY ARE PRODUCED (1)
###   (IF RUN WITH SINGLE THREAD ($LTHREADEDREGIONRUN=0) THEN IMAGES NOT GENERATED UNTIL END !)
###   ($LTHREADEDREGIONRUN=0 intended for testing so domain to be plotted hard-wired into &output_model_results_hhmm)
### MANUALLY SPECIFY LTHREADEDREGIONRUN  HERE
  # $LTHREADEDREGIONRUN = 1;
  $LTHREADEDREGIONRUN  = 0 ;

# Set a null proxy URL, which can be overridden in rasp.site.parameters if needed
$PROXY = "";

###### FINALLY, IF SITE PARAMETER FILE EXISTS THEN ALTER PARAMETERS SET ABOVE
  if ( -s "rasp.site.parameters" ) { 
    $externalsitefile = "rasp.site.parameters" ;
    require $externalsitefile  ;
  }

### SET RASP ENVIRONMENTAL PARAMETERS
  $ENV{'RASP_ADMIN_EMAIL_ADDRESS'} =  $ADMIN_EMAIL_ADDRESS ;
  if( ! defined $ADMIN_EMAIL_ADDRESS || $ADMIN_EMAIL_ADDRESS =~ m|^\s*$| ) {
    die "*** ERROR EXIT - parameter ADMIN_EMAIL_ADDRESS must not be blank or null"; exit 1;
  }

####################################################################################
#### DETECT AND KILL PREVIOUSLY RUNNING BATCH JOB
  if ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' ) { 
    jchomp( my $jobps=`ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID} .*${0}  *$JOBARG  *-[Mm]" | grep "$USERNAME .*${0}  *$JOBARG  *-[Mm]"` );
    ### be sure to eliminate present job !
    ### FIRST TRY "SOFT" KILL USING SIGNAL 2 
    jchomp( $previousjobps=`ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID} .*${0}  *$JOBARG  *-[Mm]" | grep "$USERNAME .*${0}  *$JOBARG  *-[Mm]"` );
    if ( $previousjobps ne "" ) {
      ### IF INTERACTIVE JOB, MAKE SURE I WANT TO DO THE KILL !
      if ( defined $ENV{TERM} ) {
        print $PRINTFH ">> Found existing job $previousjobps \n>>  should it be killed ?? [CR/y=YES, n=NO] >> ";
        print ">> Found existing job $previousjobps \n>>  should it be killed ?? [CR/y=YES, n=NO] >> ";
        ( my $char1 = substr( <STDIN>, 0, 1) ) =~ tr/A-Z/a-z/ ;
        if ( $char1 eq 'n' ) { goto SKIPSTARTINGKILL; }
      }
      $previousjobpid = ( split /  */, $previousjobps )[1];
      if ($LPRINT>1) { print $PRINTFH "*** pid= $$ START SOFT KILL of existing job with PID= $previousjobpid \n"; }
      jchomp( my $killout=`kill -2 $previousjobpid` );
      sleep 60;
      if ($LPRINT>1) { print $PRINTFH "*** SOFT KILLLED EXISTING JOB $previousjobpid => $killout \n"; }
    }
    ### IF ABOVE SOFT KILL DOESNT WORK, USE "HARD" KILL USING SIGNAL 9
    jchomp( $previousjobps=`ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID} .*${0}  *$JOBARG  *-[Mm]" | grep "$USERNAME .*${0}  *$JOBARG  *-[Mm]"` );
    if ( $previousjobps ne "" ) {
      if ($LPRINT>1) { print $PRINTFH "*** pid= $$ START HARD KILL of existing job+children from PID= $previousjobpid PS= $previousjobps \n"; }
      $previousjobpid = ( split /  */, $previousjobps )[1];
      my $killout = &kill_pstree( $previousjobpid );
      sleep 60;
      if ($LPRINT>1) { print $PRINTFH "*** HARD KILLED EXISTING JOB $previousjobpid PS TREE => $killout \n"; }
    }
    ### MAKE DOUBLY SURE THAT ANY LEFT-OVER CURL JOBS ARE KILLED
    ### be sure to eliminate present job !
    jchomp( $previousjobpids = `ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID}" | grep "$USERNAME .* curl .*${JOBARG}" | tr -s ' ' | cut -f2 -d' ' | tr '\n' ' '` );
    if ( $previousjobpids !~ m|^\s*$| ) {
      if ($LPRINT>1) { print $PRINTFH "*** !!! OLD CURL JOBS FOUND SO KILLED !!!  PID= $previousjobpids \n"; }
      ### send stderr to stdout as once tried to kill non-existent job
      jchomp( my $killout = `kill -9 $previousjobpids 2>&1` );
      sleep 60;
      if ($LPRINT>1) { print $PRINTFH "*** KILLED EXISTING CURL JOBS $previousjobpids \n"; }
    }
    SKIPSTARTINGKILL:
  }
### KILL ANY EXISTING FTP JOBS - UNTESTED !!!
### set test filename tail
  $filenamehead{ 'test' } = 'test.grib';
  $filetimes{ 'test' } = '';
### CALL TO SET  MODEL-DEPENDENT LGETGRIB AND SCHEDULING PARAMETERS
  &setup_getgrib_parameters;
### INITIALIZATION
### NB mon{01}=Jan !
  my %mon = ( '01','Jan', '02','Feb', '03','Mar', '04','Apr', '05','May', '06','Jun',
              '07','Jul', '08','Aug', '09','Sep', '10','Oct', '11','Nov', '12','Dec' );
  @dow = ( "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" );
### GET ZULU RUNDAYS MONTH,DAY,YEAR
### need julian date for 20kmRUC
### use date -u when start before midnight local time
  $julianday = `date -u +%j` ; jchomp($julianday);
### dont use date -u if may start after 00Z
  $startzuluhr = `date -u +%H` ; jchomp($startzuluhr);
### 4TESTMODE - force $julianday here when using existing data files
  if( defined $julianday_forced ) {
    ### allow specification of year with julian date
    if( $julianday_forced =~ m|_| ) { 
      ( $julianday,$julianyear_forced ) = split ( /_/, $julianday_forced );
    }
    elsif ( $julianday_forced != 0 ) {
      $julianday = $julianday_forced;
    }
    print "   vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv   \n";
    print ">>> *WARNING* FORCED JULIANDAY_YEAR = $julianday_forced => julianday= $julianday <<< \n";
    print "   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   \n";
  }
### FOR EVENING TESTS, AUTOMATICALLY USE PREVIOUS JULIAN DATE
### require 3 digit julian date with leading zeros for filenames
  $julianday = sprintf( "%03d",$julianday );
### SET CURRENT JULIAN MONTH,DAY,YR
  if( ! defined $julianyear_forced ) {
    $iyr2runday = `date -u +%y` ; jchomp($iyr2runday);
  }
  else {
    $iyr2runday = $julianyear_forced ;
  }
  ### this section & UTIL/jdate2date only valid until 2099 - i can't believe this code will still be running then, but ...
  if( $iyr2runday == 0 ) { print $PRINTFH "*** ERROR EXIT - sorry, only coded to be valid until 2099\n"; exit 1; }

  jchomp( $string = `jdate2date $julianday $iyr2runday` );
  ($jmo2,$jda2,$jyr2) = split ( m|/|, $string );
  $jyr4 = $jyr2 + 2000 ;
  $validdow{'curr.'} = $dow[ &dayofweek( $jda2, $jmo2, $jyr4 ) ]; # uses Date::DayOfWeek
  $validdow{''} = $validdow{'curr.'};
  $validdateprt{'curr.'} = "${jmo2}/${jda2}";
  $validdateprt{''} = $validdateprt{'curr.'};
  $validmon{'curr.'} = $mon{$jmo2};
  $validmon{''} = $validmon{'curr.'} ;
  $validda1{'curr.'} = &strip_leading_zero( $jda2 ); 
  $validda1{''} = $validda1{'curr.'}; 
  $yymmdd{'curr.'} = "${jyr2}${jmo2}${jda2}";
  $yymmdd{''} = $yymmdd{'curr.'};
  $juliandayprt = "${validdow{'curr.'}} ${jda2} ${mon{$jmo2}} ${jyr4}";
  $julianyyyymmddprt{'curr.'} = "${jyr4}-${jmo2}-${jda2}";
  $julianyyyymmddprt{''} = $julianyyyymmddprt{'curr.'} ;
### NOW SET "RUNDAY" BASED ON JULIANDAY (SO ALTERED BY ANY ALTERATIONS TO IT)
  my $yymmddrunday = $yymmdd{''};
  $rundayprt = $juliandayprt;

### SET PREVIOUS JULIAN MONTH,DAY,YR
  $juliandaym1 = $julianday - 1;
  jchomp( $string = `jdate2date $juliandaym1 $iyr2runday` );
  my ($jmo2m1,$jda2m1,$jyr2m1) = split ( m|/|, $string );
  $jyr4m1 = $jyr2m1 + 2000 ;

### SET CURRENT+1 JULIAN MONTH,DAY,YR
  $juliandayp1 = $julianday + 1;
  jchomp( $string = `jdate2date $juliandayp1 $iyr2runday` );
  my ($jyr2p1);
  ($jmo2p1,$jda2p1,$jyr2p1) = split ( m|/|, $string );
  $jyr4p1 = $jyr2p1 + 2000 ;
  $validdow{'curr+1.'} = $dow[ &dayofweek( $jda2p1, $jmo2p1, $jyr4p1 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+1.'} = "${jmo2p1}/${jda2p1}";
  $validmon{'curr+1.'} = $mon{$jmo2p1};
  $validda1{'curr+1.'} = &strip_leading_zero( $jda2p1 ); 
  $yymmdd{'curr+1.'} = "${jyr2p1}${jmo2p1}${jda2p1}";
  $julianyyyymmddprt{'curr+1.'} = "${jyr4p1}-${jmo2p1}-${jda2p1}";

### SET CURRENT+2 JULIAN MONTH,DAY,YR
  $juliandayp2 = $julianday + 2;
  my ($jyr2p2);
  jchomp( $string = `jdate2date $juliandayp2 $iyr2runday` );
  ($jmo2p2,$jda2p2,$jyr2p2) = split ( m|/|, $string );
  my $jyr4p2 = $jyr2p2 + 2000 ;
  $validdow{'curr+2.'} = $dow[ &dayofweek( $jda2p2, $jmo2p2, $jyr4p2 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+2.'} = "${jmo2p2}/${jda2p2}";
  $validmon{'curr+2.'} = $mon{$jmo2p2};
  $validda1{'curr+2.'} = &strip_leading_zero( $jda2p2 ); 
  $yymmdd{'curr+2.'} = "${jyr2p2}${jmo2p2}${jda2p2}";
  $julianyyyymmddprt{'curr+2.'} = "${jyr4p2}-${jmo2p2}-${jda2p2}";

### SET CURRENT+3 JULIAN MONTH,DAY,YR
  $juliandayp3 = $julianday + 3;
  my ($jyr2p3);
  jchomp( $string = `jdate2date $juliandayp3 $iyr2runday` );
  ($jmo2p3,$jda2p3,$jyr2p3) = split ( m|/|, $string );
  my $jyr4p3 = $jyr2p3 + 2000 ;
  $validdow{'curr+3.'} = $dow[ &dayofweek( $jda2p3, $jmo2p3, $jyr4p3 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+3.'} = "${jmo2p3}/${jda2p3}";
  $validmon{'curr+3.'} = $mon{$jmo2p3};
  $validda1{'curr+3.'} = &strip_leading_zero( $jda2p3 ); 
  $yymmdd{'curr+3.'} = "${jyr2p3}${jmo2p3}${jda2p3}";
  $julianyyyymmddprt{'curr+3.'} = "${jyr4p3}-${jmo2p3}-${jda2p3}";

### SET CURRENT+4 JULIAN MONTH,DAY,YR
  $juliandayp4 = $julianday + 4;
  my ($jyr2p4);
  jchomp( $string = `jdate2date $juliandayp4 $iyr2runday` );
  ($jmo2p4,$jda2p4,$jyr2p4) = split ( m|/|, $string );
  my $jyr4p4 = $jyr2p4 + 2000 ;
  $validdow{'curr+4.'} = $dow[ &dayofweek( $jda2p4, $jmo2p4, $jyr4p4 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+4.'} = "${jmo2p4}/${jda2p4}";
  $validmon{'curr+4.'} = $mon{$jmo2p4};
  $validda1{'curr+4.'} = &strip_leading_zero( $jda2p4 ); 
  $yymmdd{'curr+4.'} = "${jyr2p4}${jmo2p4}${jda2p4}";
  $julianyyyymmddprt{'curr+4.'} = "${jyr4p4}-${jmo2p4}-${jda2p4}";

### SET CURRENT+5 JULIAN MONTH,DAY,YR
  $juliandayp5 = $julianday + 5;
  my ($jyr2p5);
  jchomp( $string = `jdate2date $juliandayp5 $iyr2runday` );
  ($jmo2p5,$jda2p5,$jyr2p5) = split ( m|/|, $string );
  my $jyr4p5 = $jyr2p5 + 2000 ;
  $validdow{'curr+5.'} = $dow[ &dayofweek( $jda2p5, $jmo2p5, $jyr4p5 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+5.'} = "${jmo2p5}/${jda2p5}";
  $validmon{'curr+5.'} = $mon{$jmo2p5};
  $validda1{'curr+5.'} = &strip_leading_zero( $jda2p5 ); 
  $yymmdd{'curr+5.'} = "${jyr2p5}${jmo2p5}${jda2p5}";
  $julianyyyymmddprt{'curr+5.'} = "${jyr4p5}-${jmo2p5}-${jda2p5}";

### SET CURRENT+6 JULIAN MONTH,DAY,YR
  $juliandayp6 = $julianday + 6;
  my ($jyr2p6);
  jchomp( $string = `jdate2date $juliandayp6 $iyr2runday` );
  ($jmo2p6,$jda2p6,$jyr2p6) = split ( m|/|, $string );
  my $jyr4p6 = $jyr2p6 + 2000 ;
  $validdow{'curr+6.'} = $dow[ &dayofweek( $jda2p6, $jmo2p6, $jyr4p6 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+6.'} = "${jmo2p6}/${jda2p6}";
  $validmon{'curr+6.'} = $mon{$jmo2p6};
  $validda1{'curr+6.'} = &strip_leading_zero( $jda2p6 ); 
  $yymmdd{'curr+6.'} = "${jyr2p6}${jmo2p6}${jda2p6}";
  $julianyyyymmddprt{'curr+6.'} = "${jyr4p6}-${jmo2p6}-${jda2p6}";

### SET CURRENT+7 JULIAN MONTH,DAY,YR
  $juliandayp7 = $julianday + 7;
  my ($jyr2p7);
  jchomp( $string = `jdate2date $juliandayp7 $iyr2runday` );
  ($jmo2p7,$jda2p7,$jyr2p7) = split ( m|/|, $string );
  my $jyr4p7 = $jyr2p7 + 2000 ;
  $validdow{'curr+7.'} = $dow[ &dayofweek( $jda2p7, $jmo2p7, $jyr4p7 ) ]; # uses Date::DayOfWeek
  $validdateprt{'curr+7.'} = "${jmo2p7}/${jda2p7}";
  $validmon{'curr+7.'} = $mon{$jmo2p7};
  $validda1{'curr+7.'} = &strip_leading_zero( $jda2p7 ); 
  $yymmdd{'curr+7.'} = "${jyr2p7}${jmo2p7}${jda2p7}";
  $julianyyyymmddprt{'curr+7.'} = "${jyr4p7}-${jmo2p7}-${jda2p7}";

### CALL TO SET  FTP PARAMETERS
### but for NWS must later override directories since since depends on initialization time
  &setup_ftp_parameters;
  my ($dummy,$dum);
  $lalldone = 1;
######## 4TESTMODE : SET ANY FINAL FLAGS HERE PRIOR TO FIRST SCRIPT PRINT ########
#### ARGUMENT FLAGS
#### NON-ARGUMENT FLAGS
### SCRIPT START-UP PRINTS
  $startdate = `date '+%b %d'` ; jchomp($startdate);
  $starttime = `date +%H:%M` ; jchomp($starttime);
  if ($LPRINT>1) {
    print $PRINTFH "START: $program @ARGV at $starttime $startdate for $rundayprt : process $$ & perl $] & ",'$Revision: 2.136 $ $Date: 2008/09/15 00:27:34 $Z',"\n";
    print $PRINTFH "FLAGS:  LPRINT=${LPRINT}  LGETGRIB=${LGETGRIB}  LMODELINIT=${LMODELINIT}   LMODELRUN=${LMODELRUN}  LSEND=${LSEND}  LSAVE=${LSAVE}\n";
    print $PRINTFH "VARS:   RUNDIR=${RUNDIR} \n";
    if( defined $externalrunparamsfile ) {
      print $PRINTFH "--- Run parameters were read from file:  $externalrunparamsfile \n";
      ### LIST RUN PARAMETERS
      @externalrunparams = `cat $externalrunparamsfile | sed 's/^/  >  /'`;
      print $PRINTFH "@externalrunparams";
    }
    else { print $PRINTFH "** INTERNAL run parameters used, NOT read from file\n"; }
    if( ! defined $externalsitefile ) { print $PRINTFH "** INTERNAL run parameters used with NO site alterations \n\n"; }
    else { 
     print $PRINTFH "--- SITE ALTERATIONS were read from file: $externalsitefile \n";
     ### LIST RUN PARAMETERS
     @externalsiteparams = `cat $externalsitefile | sed 's/^/  >  /'`;
     print $PRINTFH "@externalsiteparams";
    }
  }
  if ($LPRINT>1) {print $PRINTFH ("RUNDATE= $rundayprt  JULIANDAY= $julianday \n" );}
  if ($LPRINT>1) {
    foreach $regionkey (@REGION_DOLIST) {
      printf $PRINTFH "  %4s  GRIBFILE_DOLIST= ( %s )\n",$regionkey,"@{$GRIBFILE_DOLIST{$regionkey}}";
    }
  }
####### CONSISTENCY/SANITY CHECKS
# foreach $regionkey (@REGION_DOLIST) {
#   ### REQUIRE CONSISTENCY OF $GRIBFILE_MODEL & INIT_ROOT,LBC_ROOT in WRF/WRFSI/domains/REGIONXYZ/static/wrfsi.nl
#   ### must allow for existence of ETAP in wrfsi when ETA model used
#   chomp ($testconsistency = `stat --format="%N" Vtable | grep -c GFS` );
#   if ( $testconsistency eq '' ) {
#     print $PRINTFH  "ERROR EXIT: NO Vtable file in $RUNDIR; \n"; exit 1;
#   }
#   elsif ( $testconsistency ne '1' ) {
#       print $PRINTFH "ERROR EXIT: Vtable not linked to ../VariableTables/Vtable.GFS \n" ; exit 1;
#   }
# }

    ### PLOT FILENAME LENGTH now 256 characters instead of old 80 character NCARG plot filename limit
### SET FULL FILE DO LIST (order determines overall processing priority) (lower-priority duplicates eliminated later)
### PRESENT PRIORITY: @ GRIBFILE_DOLIST
  @filedolist = ();
  $sumblipmapfiledolists = 0;
  foreach $regionkey (@REGION_DOLIST) {
    push @filedolist, @{$GRIBFILE_DOLIST{$regionkey}};
    $sumblipmapfiledolists += $#{$GRIBFILE_DOLIST{$regionkey}} +1; 
  }
### ELIMINATE ANY DUPLICATE REQUESTED FILENAMES
  $dofilecount = 0;
  foreach $ifile (@filedolist) {
    ($ifilegreptest = $ifile ) =~ s/\+/\\\+/g;
    ### eliminate any duplicate (with lower priority) requested filenames
    ### here filevalidtimes is just a dummy - overwritten later
    if( ! defined($filevalidtimes{$ifile}) ) {
      push ( @editedfiledolist, $ifile );
      $dofilecount = $dofilecount +1;
      $filevalidtimes{$ifile} = 1;
    }
  }
  @filedolist = @editedfiledolist;
  ### this used for printing of summary times and again
  @validdaylist = ( "curr.", "curr+1.", "curr+2.", "curr+3.", "curr+4.", "curr+5.", "curr+6" );
### START OF SET FILENAME ANAL/FCST/VALID TIME ARRAYS
  $avgextendedvalidtime = 0 ; 
  $nfiles = 0 ; 
  foreach $ifile (@filedolist) {
    $nfiles += 1; 
    ### extract analysis and forecast times from file specifier
    ### allow leading - to use previous julian day
    if ( substr($ifile,0,1) ne '-' && substr($ifile,0,1) ne '+' ) {
      $julianday{$ifile} = ${julianday}; 
      $julianyear{$ifile} = ${jyr2}; 
      ($fileanaltime,$ftime) = split( /Z\+/, $ifile );
      $analtime = $fileanaltime;
    }
    ### allow leading - to use previous julian day
    elsif ( substr($ifile,0,1) eq '-' ) {
      $julianday{$ifile} = $juliandaym1; 
      ### require 2,3 digit julian year,day with leading zeros for filenames
      $julianday{$ifile} = sprintf( "%03d",$julianday{$ifile} );
      $julianyear{$ifile} = ${jyr2m1}; 
      ($fileanaltime,$ftime) = split( /Z\+/, substr($ifile,1) );
      $analtime = $fileanaltime - 24.;
    }
    ### allow leading + to use next julian day
    elsif ( substr($ifile,0,1) eq '+' ) {
      $julianday{$ifile} = $juliandayp1; 
      ### require 2,3 digit julian year,day with leading zeros for filenames
      $julianday{$ifile} = sprintf( "%03d",$julianday{$ifile} );
      $julianyear{$ifile} = ${jyr2p1}; 
      ($fileanaltime,$ftime) = split( /Z\+/, substr($ifile,1) );
      $analtime = $fileanaltime + 24.;
    }
    else {
      print $PRINTFH "*** ERROR EXIT: BAD FORMAT FOR $ifile\n";
      exit 1;
    }
    ### PARTIAL SPECIFICATION OF MODEL GRIB FILENAME HERE
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2 DUE TO THIS CODE SEGMENT
    if ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' ) { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'fh.00%02d_tl.press_gr.awip3d',$ftime;   
    }
    elsif ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' ) { 
        $filenamehead{$ifile} = '';
        $filetimes{$ifile} = sprintf 'fh.00%02d_tl.press_gr.onedeg',$ftime;
    }
    elsif ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' ) {
      print $PRINTFH "*** ERROR EXIT - Limited Area GFS file not available from NWS\n";
      exit 1;
    }
    elsif ( $gribftpsite1 eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' ) {
      print $PRINTFH "*** ERROR EXIT - truncated AVN file not available from NWS\n";
      exit 1;
    }
    elsif ( $gribftpsite1 eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'RUCH' ) { 
      ### break fsl filename into 2 parts (head+time) so can delete old grib files using wildcard+latter
      $filenamehead{$ifile} = sprintf '%02d%03d',($jyr2,$julianday);
      $filetimes{$ifile} = sprintf '%02d%06d.grib',($fileanaltime,$ftime);
    }
    elsif ( $gribftpsite1 eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' ) { 
      $filenamehead{$ifile} = '';
      $filetimes{$ifile} = sprintf 'nam.t%02dz.awip3d%02d.tm00.grib2',$fileanaltime,$ftime;  
    }
    elsif ( $gribftpsite1 eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' ) { 
      $filenamehead{$ifile} = '';
      $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrb2.0p50.f%03d',$fileanaltime,$ftime;
    }
    elsif ( $gribftpsite1 eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' ) { 
      $filenamehead{$ifile} = '';
      # $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrbf%02d',$fileanaltime,$ftime; # Change to new filenames 14 Jan 2014
      # $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrb2.0p25.f%03d',$fileanaltime,$ftime; # Use 0.25deg data for GFSA
      $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrb2.0p25.f%03d',$fileanaltime,$ftime; # Change to new data and filenames 12 Jun 2019
    }
    elsif ( $gribftpsite1 eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' ) {
      $filenamehead{$ifile} = '';
      $filetimes{$ifile} = sprintf 'gfs.t%02dz.pgrbf%02d',$fileanaltime,$ftime;
    }
    if ( $ftime eq 'nl' ) {
      $ftime = '00';
    }
    ### require analysis time to have leading zero
    if( length($analtime)==1 ) { $fileanaltime = "0${fileanaltime}"; }
    ### remove any leading zero from forecast time (but dont remove single 0)
    $ftime =~ s/^0[^0]// ;
    $fileanaltimes{$ifile} = $fileanaltime ;
    $filefcsttimes{$ifile} = $ftime ;
    $validtime = $analtime + $ftime ;
    ### allow leading + to be next julian day
    ### set extended valid time which includes 24hr for each day (needed for eta)
    $fileextendedvalidtimes{$ifile} = $validtime; 
    ### average validtime to use as "current day" indicator
    $avgextendedvalidtime += $validtime ; 
    ### determine file day and adjust filevalidtime
    if ( $GRIBFILE_MODEL eq 'ETA' || $GRIBFILE_MODEL eq 'RUCH' || $GRIBFILE_MODEL eq 'GFSN' || $GRIBFILE_MODEL eq 'GFSA' || $GRIBFILE_MODEL eq 'AVN' ) {
      $filevaliddays{$ifile} = 'curr.';
    }
    else {
      $filevaliddays{$ifile} = '';
    }
    if ( $validtime <= 0 ) {
      $filevalidtime = $validtime +24;
    }
    elsif ( $validtime <= 23 ) {
      ### now use null to indicate current day ala present maps useage
      $filevalidtime = $validtime;
    }
    elsif ( $validtime <= 47 ) {
      $filevaliddays{$ifile} = 'curr+1.';
      $filevalidtime = $validtime - 24;
    }
    elsif ( $validtime <= 71 ) {
      $filevaliddays{$ifile} = 'curr+2.';
      $filevalidtime = $validtime - 48;
    }
    elsif ( $validtime <= 95 ) {
      $filevaliddays{$ifile} = 'curr+3.';
      $filevalidtime = $validtime - 72;
    }
    elsif ( $validtime <= 119 ) {
      $filevaliddays{$ifile} = 'curr+4.';
      $filevalidtime = $validtime - 96;
    }
    elsif ( $validtime <= 143 ) {
      $filevaliddays{$ifile} = 'curr+5.';
      $filevalidtime = $validtime - 120;
    }
    elsif ( $validtime <= 167 ) {
      $filevaliddays{$ifile} = 'curr+6.';
      $filevalidtime = $validtime - 144;
    }
    else {
      print $PRINTFH "BLIP ERROR EXIT: bad filevalidtime= $filevalidtime\n";
      exit 1;
    } 
    $filevalidtimepluses{$ifile} = $filevalidtime ;
    if ( $filevalidtimepluses{$ifile} > 23 ) {
      $filevalidtimepluses{$ifile} = $filevalidtimepluses{$ifile} - 24;
    }
    if ( $filevalidtime > 23 ) {
      $filevalidtime = $filevalidtime - 24;
    }
    $filevalidtimes{$ifile} = $filevalidtime ;
    ### initialize latest fcst time 
    $latestfcsttime[$fileextendedvalidtimes{$ifile}] = 999; 
    ### SET SCHEDULED AVAILABILITY TIMES IF NEEDED
    if ( $LGETGRIB == 2 ) {
      $gribavailadd = $gribavailhrzinc * $ftime;
      ### note that fileanaltime is 2 digit ie 00,... not 0,...
      $gribavailhrz{$ifile} = $gribavailhrzoffset + $gribavailhrz0{$fileanaltime} + $gribavailadd ;
      if ($LPRINT>1) { printf $PRINTFH "   Scheduled availability: %7s @ %5sZ\n",$ifile,&hour2hhmm($gribavailhrz{$ifile}); }
    }
    $filevalidday = $filevaliddays{$ifile} ;
    ### CALC FINAL PROCESSING SUMMARY PRESENTATION TIMES (part1)
    if ( ! grep( /^${filefcsttimes{$ifile}}$/, @{$fcsttimelist{$filevalidday}} ) ) {
      push @{$fcsttimelist{$filevalidday}}, $filefcsttimes{$ifile} ;  
    }
    if ( ! grep( /^${filevalidtimes{$ifile}}$/, @{$validtimelist{$filevalidday}} ) ) {
      push @{$validtimelist{$filevalidday}}, $filevalidtimes{$ifile} ;  
    }
  }
### END OF SET FILENAME ANAL/FCST/VALID TIME ARRAYS

### CALC FINAL PROCESSING SUMMARY PRESENTATION TIMES (part2) & INITIALIZE SUMMARY VALUES
### overkill as many unused indexs initialized - but ensures all values initialized
  foreach $validday (@validdaylist) {
    ### order with largest fcst times first
    if( $#{$fcsttimelist{$validday}} > -1 ) {
      @{$fcsttimelist{$validday}} = sort { $b <=> $a } @{$fcsttimelist{$validday}} ;
    }
  }
  $avgextendedvalidtime = nint( $avgextendedvalidtime / $nfiles ) ; 

### CREATE LIST OF UNIQUE _BLIPMAP_ VALIDATION TIMES TO BE DONE FOR EACH GRID
### used for clearing blipmap gifs
### and create inclusive one for all regions - used for aging of degrib subdirectories
  @blipmapvalidtimelist = ();
  foreach $regionkey (@REGION_DOLIST) {
     $#{$blipmapvalidtimes{$regionkey}} = -1;
     foreach $file (@{$GRIBFILE_DOLIST{$regionkey}}) {
       if ( ! grep(/^${filevalidtimes{$file}}$/,@{$blipmapvalidtimes{$regionkey}}) ) {
         push ( @{$blipmapvalidtimes{$regionkey}}, $filevalidtimes{$file} ); 
       }
       ### create inclusive one for all regions - note is array whereas regional is a hash
       if ( ! grep(/^${filevalidtimes{$file}}$/,@blipmapvalidtimelist) ) {
         push ( @blipmapvalidtimelist, $filevalidtimes{$file} ); 
       }
     }
  }
### CREATE INITIAL ARRAY OF RECEIVED FILE FLAGS
  foreach $regionkey (@REGION_DOLIST) {
     for ( $iifile=0; $iifile<=$#{$GRIBFILE_DOLIST{$regionkey}}; $iifile++ ) {
       $blipmapfilereceivedflag{$regionkey}[$iifile] = 0;
     }
  }
### OPEN THREAD TIME SUMMARY FILES
  foreach $regionkey (@REGION_DOLIST) {    
    $SUMMARYFH{$regionkey} = *${regionkey} ;
    open ( $SUMMARYFH{$regionkey}, ">>LOG/summary.gridcalctimes.${regionkey}" ) ;
    printf { $SUMMARYFH{$regionkey} } "\n%s: ", $rundayprt  ;
  }    
### CREATE DO LIST CONTAINING _entire_ FILENAME - also status array
  @filenamedolist = ();
  foreach $ifile (@filedolist) {
    ### add filename do list
    ### PARTIAL SPECIFICATION OF MODEL GRIB FILENAME HERE
    if ( $GRIBFILE_MODEL eq 'ETA' || $GRIBFILE_MODEL eq 'GFSN' || $GRIBFILE_MODEL eq 'GFSA' || $GRIBFILE_MODEL eq 'AVN' ) {
      $filename = $filenamehead{$ifile} . $filetimes{$ifile} ;
      ### select directory based on init.time - 1=present vs 2=previous jdate
      if ( $ifile =~ /^ *\-/ ) {
        $filenamedirectoryno{$ifile} = 0 ;
      }
      elsif ( $ifile =~ /^ *\+/ ) {
        $filenamedirectoryno{$ifile} = 2 ;
      }
      else {
        $filenamedirectoryno{$ifile} = 1 ;
      }
    }
    elsif ( $GRIBFILE_MODEL eq 'RUCH'  ) {
        $filename = $filenamehead{$ifile} . $filetimes{$ifile} ;
        $filenamedirectoryno{$ifile} = 1 ; 
    }
    push ( @filenamedolist, $filename );
    if ($LPRINT>1) {printf $PRINTFH ("   filenamedolist= %7s => %s %s\n",$ifile,$gribftpdirectory[$filenamedirectoryno{$ifile}],$filename);}
    ### set filestatus for files to be processed
    $filestatus{$ifile} = -1;
  }
  if ($LPRINT>1) {printf $PRINTFH ("FILENAMEdolist   count = %s\n",$dofilecount);}
  $ii=-1;
  foreach $ifile (@filedolist) {
    $ii=$ii+1;
    $filename = $filenamedolist[$ii];
    print $PRINTFH "   filename= $ii $ifile $filenamedirectoryno{$ifile} $gribftpdirectory[$filenamedirectoryno{$ifile}] $filename\n";
  }
  if ($LPRINT>1) {print $PRINTFH ("Begin CYCLE loop over Time/Filename\n" );}

### ENSURE THAT ALL NEEDED OUT BLIPMAP REGION DIRECTORIES EXIST
# foreach $regionname (@REGION_DOLIST) {
#   $mkdirstring .= "$regionname ";
#   ### include stage2-only case
#   if( $LRUN_WINDOW{$regionname} > 0 ) {
#     $mkdirstring .= "${regionname}-WINDOW ";
#   }
# }  
# if ( $mkdirstring !~ m/^ *$/ ) {
#   `cd $OUTDIR ; mkdir -p $mkdirstring`;
# }

### ENSURE THAT NEEDED SAVE DIRECTORIES EXIST
  # Create FCST dir if needed
  foreach $regionname (@REGION_DOLIST) {
    if( ! -d "${HTMLBASEDIR}/${regionname}/FCST" ){
      `mkdir -p $HTMLBASEDIR/${regionname}/FCST 2> /dev/null`;
       if ($LPRINT>1) { printf $PRINTFH ("   Created HTML directory $HTMLBASEDIR/${regionname}/FCST \n" ); }
    }
  }

  ### save directory based on region-specific julian date intended to represent soaring day
  if ( $LSAVE >0 ) {
    my  $localmin  ;
    foreach $regionname (@REGION_DOLIST) {
      ($gribanalhr,$gribfcstperiod) = split /Z\+/, $GRIBFILE_DOLIST{$regionname}[0] ;    
      ( $localyyyy,$localmm,$localdd,$localhh, $localmin ) = &GMT_plus_mins( $jyr4, $jmo2, $jda2, $gribanalhr, 0, (60*($gribfcstperiod+$LOCALTIME_ADJ{$regionname})) );
      ### with added year subdirectory to allow archiving alternatives
      $savesubdir{$regionname} = sprintf "%s/%s/%4d/%4d%02d%02d",$SAVEDIR,$regionname,$localyyyy,$localyyyy,$localmm,$localdd;
      `mkdir -p $savesubdir{$regionname} 2>/dev/null`;
      if ($LPRINT>1) { printf $PRINTFH ("   Created SAVE directory $savesubdir{$regionname} \n" ); }
    }  
  }
####### START CYCLE LOOP OVER TIME #######
  my $max_dom;
  $runstartsec = time();
  $runstarttime = `date +%H:%M` ; jchomp($runstarttime);
  $elapsed_runhrs = 0.;
  $icycle = 0;
  $foundfilecount = 0;
  $filename = 'INITIAL_VALUE';
  $lastfilename = '';
  $successfultimescount = 0;
  $nextskipcount = 0;
  $oldtimescount = 0;
  CYCLE: while ( $elapsed_runhrs < $cycle_max_runhrs && $icycle < $cycle_max ) {
    ####### INTERRUPT SIGNAL (Ctrl-C) WILL END CYCLE AND SKIP TO END PROCESSING #######
    $SIG{'INT'} = \&signal_endcycle;
    $icycle = $icycle + 1;
    $cycletime = `date +%H:%M:%S` ;  jchomp($cycletime);
    if ($LPRINT>1) {printf $PRINTFH ("CYCLE: TOP %d/%d %4.1f/%4.1fhr %02d(%02d/%02d) - last= %s at %s\n", $icycle,$cycle_max,$elapsed_runhrs,$cycle_max_runhrs,$foundfilecount,$successfultimescount,$dofilecount,$lastfilename,$cycletime);}
    $elapsed_runhrs = (time ()- $runstartsec ) / 3600. ;
    ### printout process info, incl. memory usage, to track possible probs
    $psout = `ps --no-header -o pid,priority,nice,%cpu,%mem,size,rss,sz,tsiz,vsize  $$`;
    jchomp( $psout ); 
    if ($LPRINT>1) { print $PRINTFH "   PS: $psout\n"; }
    ### CALL TO GET GRIB ALA CHOSEN LGETGRIB
    &do_getgrib_selection;
    ### DOWNLOAD GRIB FILE
    $ftptime0{$ifile} = `date +%H:%M:%S` ;
    jchomp($ftptime0{$ifile});
    if ( $LGETGRIB > 1 && $LMODELRUN > 0 ) {
      ### -i argument allows killing existing job, changing code, removing all old grib files, and restarting with appends to existing grib files
      if( $RUNTYPE ne '-i' ) {
        # $rmout = `rm -v ${GRIBDIR}/*${filetimes{$ifile}} 2>&1`;
        # Since each REGION now has its own GRIB directory, can remaove all old files
        $rmout = `rm -v ${GRIBDIR}/* 2>&1`;
      }
      ### parallel-ftp gribftpget.pl does _not_ delete any grib files
      if ($LPRINT>2) { print $PRINTFH "${ifile}: pre-grib-download rm of previous grib file:\n$rmout\n"; }
      ### now adjust $gribgetftptimeoutsec sent to routine so should end ftp+calc prior to switching time
      if( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' ) {
        $sec2finalcalcstart =  3600.*( &zulu2local( $switchingtimehrz{$GRIBFILE_MODEL} ) - &hhmm2hour( $ftptime0{$ifile} ) ) - 60.*$mincalcmin{$GRIBFILE_MODEL};
        if ( $sec2finalcalcstart < 0 ) {
          $sec2finalcalcstart += 24*3600 ;
        }
        if ( $sec2finalcalcstart < $gribgetftptimeoutmaxsec ) {
          $gribgetftptimeoutsec = $sec2finalcalcstart ;
        }
        else {
          $gribgetftptimeoutsec = $gribgetftptimeoutmaxsec ; 
        }
      }
      else {
        $gribgetftptimeoutsec = $gribgetftptimeoutmaxsec;
      }
      ### SET ARGUMENT LIST
      ### this sends single comma-delimited string
      if( $GRIBFILE_MODEL eq 'GFSA' && defined $GRIB_LEFT_LON && defined $GRIB_RIGHT_LON && defined $GRIB_TOP_LAT && defined $GRIB_BOTTOM_LAT ) {
        $args = join ',', (
         "curl ${PROXY}",
         $filename,
         $GRIB_LEFT_LON,
         $GRIB_RIGHT_LON,
         $GRIB_TOP_LAT,
         $GRIB_BOTTOM_LAT,
         $ifile,
         $GRIBFTPSTDOUT,
         $GRIBFTPSTDERR,
         $GRIBDIR,
         $childprintoutfilename
        );
        $gribgetcommand = "ftp2u_subregion.pl";
      }
      elsif( $GRIBFILE_MODEL eq 'AVN' && defined $GRIB_LEFT_LON && defined $GRIB_RIGHT_LON && defined $GRIB_TOP_LAT && defined $GRIB_BOTTOM_LAT ) {
        $args = join ',', (
         "curl",
         $filename,
         $GRIB_LEFT_LON,
         $GRIB_RIGHT_LON,
         $GRIB_TOP_LAT,
         $GRIB_BOTTOM_LAT,
         $ifile,
         $GRIBFTPSTDOUT,
         $GRIBFTPSTDERR,
         $GRIBDIR
        );
        $gribgetcommand = "ftpgetdat_ftp2u.pl";
      }
      else {
        ### STANDARD (NON-TRUNCATED) GRIB FILE DOWNLOAD
        $args = join ',', (
                  $JOBARG,
                  $GRIBFILE_MODEL,
                  $ifile,
                  $rundayprt,
                  $gribftpsite,
                  "${gribftpdirectory0}/${filenamedirectory}",
                  $filename,
                  $GRIBFTPSTDOUT,
                  $GRIBFTPSTDERR,
                  $RUNDIR,
                  $GRIBDIR,
                  $cycle_waitsec,
                  $gribgetftptimeoutsec,
                  $mingribfilesize,
                  $childprintoutfilename
         );
        ### CREATE BACKGROUND FTP JOB
        $gribgetcommand = "gribftpget.pl";
      }
      if ($LPRINT>1) { $time = `date +%H:%M:%S` ; jchomp($time) ; print $PRINTFH "${ifile}: FTP REQUEST $gribgetcommand at $time\n"; }
      my $childftpproc = Proc::Background->new( $gribgetcommand, $args );
      if ( $childftpproc->alive ) {
        push @childftplist, $ifile;
        $childftpobject{$ifile} = $childftpproc;
        $childftppid{$ifile} = $childftpproc->pid ;
        print $PRINTFH "${ifile}: call child gribftpget routine: $gribgetftptimeoutsec $filename $gribftpsite ${gribftpdirectory0}/${filenamedirectory}\n";
      }
      else {
        print $PRINTFH ("*** FTP CHILD CREATION FAILED for $ifile - skip this file \n");
        goto NEWGRIBTEST; 
      } 
    }
    else {
      print $PRINTFH ("${ifile}: TEST/RERUN MODE run with *NO*GETGRIB* DOWNLOAD\n");
    }
    NEWGRIBTEST: 
    @oldchildftplist =  @childftplist;
    @childftplist = ();
    ### expect child gribftpget processes started later to have later initialization times, so do them first
    for ( $ilist=$#oldchildftplist; $ilist>=0; $ilist-- ) {
      $ifile = $oldchildftplist[$ilist];
      $childftpproc = $childftpobject{$ifile};
      $childftppid = $childftppid{$ifile};
      ### SET VALUES CONSTANT FOR FILE (FOR ALL POINTS)
      ($ifilegreptest = $ifile ) =~ s/\+/\\\+/g;
      $filevalidday = $filevaliddays{$ifile};
      $filefcsttime = $filefcsttimes{$ifile};
      $filevalidtime = $filevalidtimes{$ifile};
      $fileanaltime = $fileanaltimes{$ifile};
      my $filevalidtimeplus = $filevalidtimepluses{$ifile};
      $fileextendedvalidtime = $fileextendedvalidtimes{$ifile};
      $filename = $filename{$ifile};
      $filenamedirectory = $filenamedirectory{$ifile};
      my $fullfilename = "${GRIBDIR}/${filename}"; 
      $time = `date +%H:%M:%S` ;  jchomp($time);
      ### START OF SKIP TEST OF FTP PROCEESSES IF TEST MODE
      if ( $LGETGRIB > 1 ) {
        ### don't process fcst time if shorter term one already done for this valid time
        ### putting kill here leads to delays in killing (vice putting immediately after successful run status change)
        ###    but is more convenient since loop exists here and can conveniently remove the $ifile from @childftplist
        if ( $filefcsttimes{$ifile} > $latestfcsttime[$fileextendedvalidtimes{$ifile}] && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' ) {
          if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER NEWGRIBTEST $ifile - previous $filevalidtimes{$ifile}Z validation time (extended=${fileextendedvalidtimes{$ifile}}) had shorter fcst time = $latestfcsttime[$fileextendedvalidtime]\n" );}
            ### setting this status will caused file to be ignored later
            $filestatus{$ifile} = $status_skipped; 
            $oldtimescount++;
            ### kill entire pstree  - killing child will _not_ kill gribftpget or curl processes it creates (at least not when job run with nohup)
            my $killout = &kill_pstree( $childftppid );
            if ($LPRINT>1) {print $PRINTFH ("                       killed entire ps tree ftping $filename => $killout \n" );}
            next;
         }
         if ( $childftpproc->alive ) {
           ### keep same order in childftplist
           unshift @childftplist, $ifile;
           next;
         }
         $childtest = $childftpproc->wait ;
         $child_exit_value  = $childtest >> 8 ;      #=int($?/256)  
         $child_signal_num  = $childtest & 127 ;     #=($?-256*exit_value#)
         ### also calculate total download speed, including any partial downloads
         my ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = localtime( $childftpproc->end_time );
         $endhhmmss = sprintf "%02d:%02d:%02d", $hour,$min,$sec ;
         &print_download_speed ( 'FULL_Download', $ftptime0{$ifile}, $endhhmmss );
         ### TREAT GRIBFTPGET ERROR CASES
         ### treat case of job killed by a signal by skipping that file
         if ( $child_signal_num != 0 ) {
           $filestatus{$ifile} = $status_skipped; 
           my $killout = &kill_pstree( $childftppid );
           if ($LPRINT>1) {print $PRINTFH ("** SKIPPING $ifile at $time  - CHILD gribftpget RETURNED NON-ZERO CURL SIGNAL = $child_signal_num SO KILL PS TREE & SKIP PROCESSING \n" );}
           goto STRANGE_CYCLE_END;
         }
         ### treat any other non-zero exit code by skipping that file
         elsif ( $child_exit_value != 0 ) {
           $filestatus{$ifile} = $status_skipped; 
           if ($LPRINT>1) {print $PRINTFH ("** SKIPPING $ifile at $time  - CHILD gribftpget RETURNED UNRECOVERABLE CURL EXIT VALUE = $child_exit_value SO SKIP PROCESSING \n" );}
           goto STRANGE_CYCLE_END;
         }
      } ### END OF SKIP TEST OF FTP PROCEESSES IF TEST MODE

      ### IF REACH HERE, MUST HAVE BEEN A SUCCESSFUL GRIB FTP GET
      STARTNEWGRIB: 
      $foundfilecount = $foundfilecount +1;
      ### CALCULATION INITIALIZATION  
      $calctime0 = `date +%H:%M:%S` ; jchomp($calctime0);
      ### PRINT HEADER FOR START OF NEW FILE CALCULATION
      printf $PRINTFH ("   NEW_GRIB_FILE_RECEIVED : %s  %02d(%02d/%02d)  %7s => %7s %2dZ  %s %s\n",$calctime0,$foundfilecount,$successfultimescount,$dofilecount,$ifile,$filevaliddays{$ifile},$filevalidtimes{$ifile},$filenamedirectory,$filename);
      ### INITIALIZE ERROR FLAGS 
      ######### DO grib_prep FOR EACH GRIB FILE INDIVIDUALLY TO ALLOW THREADED TREATMENT (so threads won't step on each other)
      ######### SO MUST SET SI PARAMS PRIOR TO CALL TO grib_prep
      ### SET ENVIRONMENTAL VARIABLES NEEDED BY WRFSI (except for $ENV{MOAD_DATAROOT} which depends on $regionkey)
      ### set universal paths
      ### OTHER ENV VARIABLES NEEDED FOR CRON RUN 

      ### from emprical tests, NetCDF executables (ncdump,ncgen) must be at /usr/local/netcdf/bin
      ###    use of NETCDF environ. variable OR UTIL/NETCDF path addition does not find ncdump/ncgen !
      $ENV{LANG} = 'en_US';                       # LANG MAY BE SUPERFLUOUS
      if ($LGETGRIB>0) {
        ### CALL EXTERNAL WRFSI SCRIPT TO PREP THIS GRIB FILE FOR LATER WRF INITIALIZATION PROCESSING    
        ### must use yyymmddhh associated with this grib file !
        ### need criteria for determining when tomorrow's julian date needed 
        ### DAY/HR SELECTION - this depends upon validation time of file
        if ( $filevaliddays{$ifile} eq 'curr.' ) { 
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4},${jmo2},${jda2},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4m1},${jmo2m1},${jda2m1},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+1.' ) {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p1},${jmo2p1},${jda2p1},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4},${jmo2},${jda2},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+2.' ) {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p2},${jmo2p2},${jda2p2},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p1},${jmo2p1},${jda2p1},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+3.' ) {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p3},${jmo2p3},${jda2p3},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p2},${jmo2p2},${jda2p2},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+4.' ) {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p4},${jmo2p4},${jda2p4},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p3},${jmo2p3},${jda2p3},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+5.' ) {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p5},${jmo2p5},${jda2p5},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p4},${jmo2p4},${jda2p4},${filevalidtime};
        }
        elsif ( $filevaliddays{$ifile} eq 'curr+6.' ) {
                $grib_yyyymmddhh = sprintf "%4d%02d%02d%02d",${jyr4p6},${jmo2p6},${jda2p6},${filevalidtime};
                $yesterday_grib_yyyymmddhh = sprintf "%4d-%02d-%02d_%02d",${jyr4p5},${jmo2p5},${jda2p5},${filevalidtime};
        }
        else {
          print $PRINTFH "$program ERROR EXIT - grib_yyyymmddhh bad filevaliddays =  $ifile $filevaliddays{$ifile} "; exit 1;
        }

        ########## START OF LOOP OVER REGIONS !!! ##########
        $kpid = 0;
        @childrunmodellist = ();
        $nstartedchildren = 0;
        REGION: foreach $regionkey (@REGION_DOLIST) {
          ### use $regionname when not a hash key, such as a directory name, to allow different searching
          $regionname = $regionkey;
          ( $regionname_lc = $regionname ) =~ tr/A-Z/a-z/;
          ###### NOT USED BUT LEAVE FOR REFERENCE 
          ### SET PRINTED TIME FOR THIS FILE AND GRID
          $localtimeprt = $filevalidtime + $LOCALTIME_ADJ{$regionkey};
          jchomp( $localtimeid = `date +%Z` ); 
          $localtimeid = substr( $localtimeid, 1,2 );
          if( $localtimeid eq 'DT' || $localtimeid eq 'dt' ) {
            $localtimeprt = $localtimeprt +1; 
          }
          if( $localtimeprt < 0 ) {
            $localtimeprt = $localtimeprt + 24; 
          }
          $localtimeid = substr( $LOCALTIME_ID{$regionkey}, 0,1 ) . $localtimeid;
          $localtimeid =~ tr/A-Z/a-z/;
          my $timeprt = $filevalidtimes{$ifile} . 'Z(' . $localtimeprt . $localtimeid . ')'; 

          ###### TEST IF NEEDED FILES NOW RECEIVED FOR ANY GRID - IF SO, RUN MODEL FOR IT
          ### test all possible run times (for simplicity), then change array of received file flags and test for all received
          $iifile = -1;
          $maxfcsttimes = ( $#{$blipmapfilereceivedflag{$regionkey}} + 1 ) / $GRIBFILES_PER_FORECAST_PERIOD{$regionkey} ; 
          for ( $iifcsttimes=1; $iifcsttimes<=$maxfcsttimes; $iifcsttimes++ ) {
            $nreceived = 0;
            for ( $ii=1; $ii<=$GRIBFILES_PER_FORECAST_PERIOD{$regionkey}; $ii++ ) {
              $iifile++;
              $fileid = $GRIBFILE_DOLIST{$regionkey}[$iifile];
              ### add this file to list of those received
              if( $fileid eq $ifile ) { 
                $blipmapfilereceivedflag{$regionkey}[$iifile] = 1 ;
              }
              ### count total received
              if( $blipmapfilereceivedflag{$regionkey}[$iifile] == 1 ) {
                $nreceived++;
              }
            }
            if ($LPRINT>1) {
              $time = `date +%H:%M:%S` ;
              jchomp($time) ;
              print $PRINTFH  "   Check for needed $regionkey files of rungroup $iifcsttimes found ${nreceived}/${GRIBFILES_PER_FORECAST_PERIOD{$regionkey}} received at $time \n";
            }
            ### go to model processing when required grib files obtained
            if ( $nreceived == $GRIBFILES_PER_FORECAST_PERIOD{$regionkey} ) {
              ### reset blipmapfilereceivedflag so these files not processed again
              for ( $jjfile=$iifile; $jjfile>=($iifile-$GRIBFILES_PER_FORECAST_PERIOD{$regionkey}+1); $jjfile-- ) {
                $blipmapfilereceivedflag{$regionkey}[$jjfile] = -1; 
              }
              ### empty list of already processed output files
              @{$finishedoutputhour{$regionkey}} = ( "" );        
              ### go to processing section
              goto ALL_GRIBFILES_AVAILABLE ;
            }
          }
          ### AT PRESENT REQUIRE *ALL* REQUESTED GRIB FILES TO BE RECEIVED TO RUN MODEL
          $nreceived = 0;
          next REGION;

          ### START OF SECTION PROCESSED IF ALL NEEDED GRIB FILES OBTAINED FOR A FORECAST RUN

          ALL_GRIBFILES_AVAILABLE:
          `rm -f GRIBFILE* > /dev/null 2>&1` ; # Remove leftovers before linking new ones

          if($GRIBFILE_MODEL eq 'ETA') {
            `link_grib.csh GRIB/nam*`;
          }
          else {
            `link_grib.csh GRIB/gfs*` ;
          }
          # No check on this is possible, so count GRIBFILES???
          $nGRIBFILES = `ls GRIBFILE.??? | wc -l` ;
          chomp($nGRIBFILES);
          $neededGRIBFILES = $#{$GRIBFILE_DOLIST{$regionkey}} + 1; 
          if( $nGRIBFILES ne $neededGRIBFILES ) {
            die "WRONG NUMBER OF GRIBFILEs - $nGRIBFILES available; should be $neededGRIBFILES \n" ;
          }

          ### SET VARIABLES NEEDED BY PLOT PROCESSING PRIOR TO CREATING CHILD PROCESSES
          ### this section had been placed after child creation - assumes variables same for all regions
          ### DETERMINE VALID DAY & ANAL TIME & FCST PERIOD OF GRIB FILE USED FOR RASP INITIALIZATION
          ### kludgey method uses position of a file in  GRIBFILE_DOLIST so requires %gribfile_dolist ordering to increase in each group
          for( $iifile=0; $iifile<=$#{$GRIBFILE_DOLIST{$regionkey}}; $iifile++ ) {
            if( $ifile eq $GRIBFILE_DOLIST{$regionkey}[$iifile] ) {
              $groupnumber = int( $iifile/$GRIBFILES_PER_FORECAST_PERIOD{$regionkey} +1);
              $startindex = $GRIBFILES_PER_FORECAST_PERIOD{$regionkey}* ($groupnumber -1);
              last;
            }
          }
          $startifile = $GRIBFILE_DOLIST{$regionkey}[$startindex];
          $startvalidday =  $filevaliddays{$startifile} ;
          ### FIND FORECAST PERIOD AND ANAL TIME OF INITIALIZATION GRIB FILE
          $gribanaltime = $fileanaltimes{$startifile} ;
          $gribfcstperiod = $filefcsttimes{$startifile} ;
          $hhinit = $gribanaltime + $gribfcstperiod - 24*int( ($gribanaltime+$gribfcstperiod)/24 ) ;
          ### DETERMINE NUMBER OF DOMAINS for non-window & window runs
          jchomp( $MAXDOMAIN{$regionkey}[0] = `grep -i 'max_dom' namelist.wps.template` );
          $MAXDOMAIN{$regionkey}[0] =~ s/^.*= *([0-9]).*$/$1/ ; 
          if ( $LRUN_WINDOW{$regionkey} > 0 ) {	# NOT YET!!!
            jchomp( $MAXDOMAIN{$regionkey}[1] = `grep -i 'max_dom' $WRFBASEDIR/WRFV2/RASP/${regionkey}-WINDOW/namelist.template` );
            $MAXDOMAIN{$regionkey}[1] =~ s/^.*= *([0-9]).*$/$1/ ; 
            $MAXDOMAIN{$regionkey}[2] = $MAXDOMAIN{$regionkey}[1] ;
          }
          $nstartedchildren++;
          if ($LPRINT>1) { print $PRINTFH  "   ALL needed $regionkey rungroup $groupnumber files received so initiate run\n"; }

          ### START OF THREADEDREGIONRUN IF FOR CHILD CREATION
          ### allow debug tests of threaded case plots which skip model init+run to not create child processes
          if ( $LMODELINIT == 0 && $LMODELRUN == 0 ) {
            print $PRINTFH "   ** LMODELINIT=LMODELRUN=0, so *SKIP* ENTIRE MODEL SEQUENCE FOR $regionkey \n"; 
          }
          ### FOR THREADED REGIONRUN, CREATE CHILD PROCESS FOR EACH REGION
          elsif ( $LTHREADEDREGIONRUN == 1 && ! defined( $kpid = fork() ) ) {
            print $PRINTFH "THREAD OS ERROR EXIT IN PROCESS $$ RUNNING $program $JOBARG for $regionkey - cannot fork error = $!";
            exit 1;
          }
          elsif ( $LTHREADEDREGIONRUN == 0 || $kpid == 0 ) {
            $gridcalcstarttime = `date +%H:%M` ; jchomp($gridcalcstarttime);
            if( $LTHREADEDREGIONRUN == 1 ) {
              ### FOR THREADED REGIONRUN, THIS IS CHILD PROCESS since fork returned 0
              ### IF CHILD, SET NEW PROGRAM NAME TO DISPLAY IN FORK'S ps
              $0 = "rasp-${JOBARG}child${regionkey}";
              print $PRINTFH "   >>> $regionkey THREADED CHILD RUNMODEL STARTED under $RUNPID for $regionkey at $gridcalcstarttime \n";
            }
            else {
              print $PRINTFH "   >>> $regionkey NON-THREADED RUNMODEL STARTED for $regionkey at $gridcalcstarttime \n";
            }
            ### SET TIMEOUT FOR ENTIRE MODEL INIT/RUN SECTION (THREAD)
            if( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i') {
              local $SIG{ALRM} = sub {
                  $time=`date +%H:%M:%S`;
                  jchomp($time);
                  print $PRINTFH "*** $regionname MODEL RUN/INIT *TIMED*OUT* at $time\n";
                  &final_processing;
              };
              alarm ( $gridcalctimeoutsec );
            }
            for( $IWINDOW=$iwindowstart{$regionkey}; $IWINDOW<= $iwindowend{$regionkey}; $IWINDOW++ ) {
              ### SET NAME OF CURRENT CASE HERE
              ###  $LRUN_WINDOW=1 used for REGIONXYZ-WINDOW RUN (assumes needed wrfout files in REGIONXYZ directory)
              if ( $IWINDOW == 0 ) {
                ### include stage2-only case
                $moad = $regionname;
              }
              else {
                $moad = $regionname . "-WINDOW";
              }
              if ($LPRINT>1) {
                $time = `date +%H:%M:%S` ;
                jchomp($time);
                print $PRINTFH "   START $regionname MODEL RUN LOOP $IWINDOW FOR $moad at $time\n";
              }

              ### INITIALIZATIONS
              #GM - No image loop yet            %imageloopfilelist = ();
              ### SET INITIALIZATION TIME FOR ALL DOMAINS  - do here so available outside region thread      
              ###     MEANS THAT START/END MUST BE SAME FOR ALL REGIONS !
              ### DAY/HR SELECTION - this depends upon start/end time of run
              ### WEAKNESS: GRIB GETS TREATED LARGELY INDEPENDENTLY YET ACTUALLY DISTINCT GROUPS
              ### so put kludgey way of determining day of valid time of first file
              ### LATER: REPLACE $DOMAIN1_STARTHH,$DOMAIN1_ENDHH with $DOMAIN1_START_DELTAMINS,$DOMAIN1_END_DELTAMINS
              ###        AND MAKE ALL "DELTAMINS" PARAMS RELATIVE TO START/END *GRIB* FILE TIMES FOR CONSISTENCY
              ### second case treats window run with start on same day as stage1
              ### (note that assumes that run will be for less than 24hrs)
              if( $IWINDOW==0 || $DOMAIN1_STARTHH{$regionname}[0] < $DOMAIN1_STARTHH{$regionname}[1] ) {
                if( $startvalidday eq 'curr.' ) {
                  $startyyyy4dom[1] = $jyr4;
                  $startmm4dom[1] = $jmo2;
                  $startdd4dom[1] = $jda2;
                }
                elsif( $startvalidday eq 'curr+1.' ) {
                  $startyyyy4dom[1] = $jyr4p1;
                  $startmm4dom[1] = $jmo2p1;
                  $startdd4dom[1] = $jda2p1;
                }
                elsif( $startvalidday eq 'curr+2.' ) {
                  $startyyyy4dom[1] = $jyr4p2;
                  $startmm4dom[1] = $jmo2p2;
                  $startdd4dom[1] = $jda2p2;
                }
                elsif( $startvalidday eq 'curr+3.' ) {
                  $startyyyy4dom[1] = $jyr4p3;
                  $startmm4dom[1] = $jmo2p3;
                  $startdd4dom[1] = $jda2p3;
                }
                elsif( $startvalidday eq 'curr+4.' ) {
                  $startyyyy4dom[1] = $jyr4p4;
                  $startmm4dom[1] = $jmo2p4;
                  $startdd4dom[1] = $jda2p4;
                }
                elsif( $startvalidday eq 'curr+5.' ) {
                  $startyyyy4dom[1] = $jyr4p5;
                  $startmm4dom[1] = $jmo2p5;
                  $startdd4dom[1] = $jda2p5;
                }
                elsif( $startvalidday eq 'curr+6.' ) {
                  $startyyyy4dom[1] = $jyr4p6;
                  $startmm4dom[1] = $jmo2p6;
                  $startdd4dom[1] = $jda2p6;
                }
                else {
                  print $PRINTFH "*** ERROR EXIT - start day not valid: $IWINDOW $startvalidday ";
                  exit 1;
                }
              }
              ### treat window run with start on day after stage1
              else {
                if( $startvalidday eq 'curr.' ) {
                  $startyyyy4dom[1] = $jyr4p1;
                  $startmm4dom[1] = $jmo2p1;
                  $startdd4dom[1] = $jda2p1;
                }
                elsif( $startvalidday eq 'curr+1.' ) {
                  $startyyyy4dom[1] = $jyr4p2;
                  $startmm4dom[1] = $jmo2p2;
                  $startdd4dom[1] = $jda2p2;
                }
                elsif( $startvalidday eq 'curr+2.' ) {
                  $startyyyy4dom[1] = $jyr4p3;
                  $startmm4dom[1] = $jmo2p3;
                  $startdd4dom[1] = $jda2p3;
                }
                elsif( $startvalidday eq 'curr+3.' ) {
                  $startyyyy4dom[1] = $jyr4p4;
                  $startmm4dom[1] = $jmo2p4;
                  $startdd4dom[1] = $jda2p4;
                }
                elsif( $startvalidday eq 'curr+4.' ) {
                  $startyyyy4dom[1] = $jyr4p5;
                  $startmm4dom[1] = $jmo2p5;
                  $startdd4dom[1] = $jda2p5;
                }
                elsif( $startvalidday eq 'curr+5.' ) {
                  $startyyyy4dom[1] = $jyr4p6;
                  $startmm4dom[1] = $jmo2p6;
                  $startdd4dom[1] = $jda2p6;
                }
                elsif( $startvalidday eq 'curr+6.' ) {
                  $startyyyy4dom[1] = $jyr4p7;
                  $startmm4dom[1] = $jmo2p7;
                  $startdd4dom[1] = $jda2p7;
                }
                else {
                  print $PRINTFH "*** ERROR EXIT - window start day not valid: $IWINDOW $startvalidday ";
                  exit 1;
                }
              }
              $starthh4dom[1] = $DOMAIN1_STARTHH{$regionname}[$IWINDOW];

              ### ALLOW DIFFERENT STARTS FOR DIFFERENT DOMAINS
              for ( $idomain=2 ; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW] ; $idomain++ ) {
                my $startdeltamins ;
                eval "\$startdeltamins = \$DOMAIN${idomain}_START_DELTAMINS{\$regionname}[\$IWINDOW]" ; 
                ( $startyyyy4dom[$idomain],$startmm4dom[$idomain],$startdd4dom[$idomain],$starthh4dom[$idomain], $min2 ) = &GMT_plus_mins( $startyyyy4dom[$idomain-1],$startmm4dom[$idomain-1],$startdd4dom[$idomain-1],$starthh4dom[$idomain-1], 0, $startdeltamins ) ; 
              }
              ### DAY/HR SELECTION - this depends upon start/end time of run
              ( $endyyyy4dom[1],$endmm4dom[1],$enddd4dom[1],$endhh4dom[1], $min2 ) = &GMT_plus_mins( $startyyyy4dom[1],$startmm4dom[1],$startdd4dom[1],$starthh4dom[1], 0, (60*$FORECAST_PERIODHRS{$regionname}[$IWINDOW]) ); 

              ### Adjust Start & End date/times in namelist.wps
              `cp -f namelist.wps previous.namelist.wps 2>/dev/null`;
              if ($LPRINT>2) { print $PRINTFH "      Old $moad namelist.wps file pre-pended with \"previous.\" \n"; }

              open(NAMELIST, "<", "namelist.wps.template") or 
               die "Can't open namelist.wps.template - Run aborted" ;
              @namelistlines = <NAMELIST>;
              close(NAMELIST);
              open(NEWNAMELIST, ">", "namelist.wps");
              $wps_startdate = $startyyyy4dom[1]."-".$startmm4dom[1]."-".$startdd4dom[1]."_".$starthh4dom[1].":".$min2.":00" ;
              $wps_enddate   = $endyyyy4dom[1]  ."-".$endmm4dom[1]  ."-".$enddd4dom[1]  ."_".$endhh4dom[1]  .":".$min2.":00" ;
              for($iline=0; $iline<=$#namelistlines; $iline++){
                $line = $namelistlines[$iline];
                if($line =~ m/start_date/i ) { $namelistlines[$iline] = sprintf(" start_date = '%s', '%s',\n", $wps_startdate, $wps_startdate); }
                if($line =~ m/end_date/i   ) { $namelistlines[$iline] = sprintf(" end_date   = '%s', '%s',\n", $wps_enddate,   $wps_enddate) ; }
                # Update opt_metgrid_tbl_path - Required to be in $BASEDIR (which must be set!)
                if($line =~ m/opt_metgrid_tbl_path/i   ) {
                  $BaseDir = $ENV{"BASEDIR"};
                  $namelistlines[$iline] = sprintf(" opt_metgrid_tbl_path   = '%s/%s'\n", $BaseDir, $regionname) ;
                }
              }
              print NEWNAMELIST @namelistlines;
              close(NEWNAMELIST);

              `rm -f UNGRIB* > /dev/null 2>&1` ;
              `ungrib.exe > LOG/ungrib.out 2>&1` ;
              $ungribRes = `grep -c 'Successful completion of ' LOG/ungrib.out` ;
              chomp($ungribRes) ;
              if( $ungribRes eq 1){ print $PRINTFH "    Successful completion of ungrib\n" ; }
              else{
                print $PRINTFH "***  Ungrib failed: See ungrib.log and LOG/ungrib.out\n" ;   
                die "***  Ungrib failed: See ungrib.log and LOG/ungrib.out\n" ;   
              }

              # Run metgrid.exe Do we want to save old metgrid files?
              `rm -f met_em* > /dev/null 2>&1`;
              `metgrid.exe > LOG/metgrid.out 2>&1`;
              $metgridRes = `grep -c 'Successful completion of ' LOG/metgrid.out`;
              chomp($metgridRes);
              if( $metgridRes eq 1){ print $PRINTFH "    Successful completion of metgrid\n" ; }
              else {
                print $PRINTFH "***  Metgrid failed: See metgrid.log and LOG/metgrid.out\n" ;   
                die "***  Metgrid failed: See metgrid.log and LOG/metgrid.out\n" ;   
              }

              ### Adjust Start & End date/times in namelist.input
              `cp -f namelist.input previous.namelist.input 2>/dev/null`;
              if ($LPRINT>2) { print $PRINTFH "      Old $moad namelist.input file pre-pended with \"previous.\" \n"; }
              $run_days         = "run_days           = 0,";	# Make sure = 0, so that only start_* & end_* are used
              $run_hours        = "run_hours          = 0,";
              $run_minutes      = "run_minutes        = 0,";
              $run_seconds      = "run_seconds        = 0,";
              $start_year       = "start_year         = "   . $startyyyy4dom[1] . ",";
              $start_month      = "start_month        = "   . $startmm4dom[1]   . ",";
              $start_day        = "start_day          = "   . $startdd4dom[1]   . ",";
              $start_hour       = "start_hour         = "   . $starthh4dom[1]   . ",";
              $start_minute     = "start_minute       = "   . $min2             . ",";
              $start_second     = "start_second       = 00,"                         ;
              $end_year         = "end_year           = "   . $endyyyy4dom[1]   . ",";
              $end_month        = "end_month          = "   . $endmm4dom[1]     . ",";
              $end_day          = "end_day            = "   . $enddd4dom[1]     . ",";
              $end_hour         = "end_hour           = "   . $endhh4dom[1]     . ",";
              $end_minute       = "end_minute         = "   . $min2             . ",";
              $end_second       = "end_second         = 00,"                         ;

              # Determine num_metgrid_levels from a met_em.d01 file
              my $filename = `ls met_em.d01*.nc | tail -1`;
              chomp $filename;
	      #$n_metgrid_levels = `ncdump -h $filename | grep -i 'BOTTOM-TOP_GRID_DIMENSION *=' | sed -r 's/.* = (\w*).*/num_metgrid_levels = \1,/'`;
              $n_metgrid_levels = "command above not working, please set manually";
              print $PRINTFH "      $n_metgrid_levels";
            
              for ( $idomain=2 ; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW] ; $idomain++ ) {
                my $enddeltamins ;
                eval "\$enddeltamins = \$DOMAIN${idomain}_END_DELTAMINS{\$regionname}[\$IWINDOW]" ; 
                ( $endyyyy4dom[$idomain],$endmm4dom[$idomain],$enddd4dom[$idomain],$endhh4dom[$idomain], $min2 ) = &GMT_plus_mins( $startyyyy4dom[$idomain],$startmm4dom[$idomain],$startdd4dom[$idomain],$starthh4dom[$idomain], 0, (60*$FORECAST_PERIODHRS{$regionname}[$IWINDOW]+$enddeltamins) ); 
                $start_year   .= $startyyyy4dom[$idomain] . ",";
                $start_month  .= $startmm4dom[$idomain]   . ",";
                $start_day    .= $startdd4dom[$idomain]   . ",";
                $start_hour   .= $starthh4dom[$idomain]   . ",";
                $start_minute .= $min2                    . ",";
                $start_second .= "00,"                         ;
                $end_year     .= $endyyyy4dom[$idomain]   . ",";
                $end_month    .= $endmm4dom[$idomain]     . ",";
                $end_day      .= $enddd4dom[$idomain]     . ",";
                $end_hour     .= $endhh4dom[$idomain]     . ",";
                $end_minute   .= $min2                    . ",";
                $end_second   .= "00,"                         ;
              }
              open(OLDNAMELIST, "<", "namelist.input.template") or
               die "Missing namelist.input.template - Run aborted" ;
              @namelistlines = <OLDNAMELIST>;
              close(OLDNAMELIST);
              open(NEWNAMELIST, ">", "namelist.input");
              for($iline=0; $iline<=$#namelistlines; $iline++){
                $line = $namelistlines[$iline];
                if($line =~ m/run_days/i)           {$namelistlines[$iline] = sprintf(" %s\n", $run_days    ); }
                if($line =~ m/run_hours/i)          {$namelistlines[$iline] = sprintf(" %s\n", $run_hours   ); }
                if($line =~ m/run_minutes/i)        {$namelistlines[$iline] = sprintf(" %s\n", $run_minutes ); }
                if($line =~ m/run_seconds/i)        {$namelistlines[$iline] = sprintf(" %s\n", $run_seconds ); }
                if($line =~ m/start_year/i)         {$namelistlines[$iline] = sprintf(" %s\n", $start_year  ); }
                if($line =~ m/start_month/i)        {$namelistlines[$iline] = sprintf(" %s\n", $start_month ); }
                if($line =~ m/start_day/i)          {$namelistlines[$iline] = sprintf(" %s\n", $start_day   ); }
                if($line =~ m/start_hour/i)         {$namelistlines[$iline] = sprintf(" %s\n", $start_hour  ); }
                if($line =~ m/start_minute/i)       {$namelistlines[$iline] = sprintf(" %s\n", $start_minute); }
                if($line =~ m/start_second/i)       {$namelistlines[$iline] = sprintf(" %s\n", $start_second); }
                if($line =~ m/end_year/i)           {$namelistlines[$iline] = sprintf(" %s\n", $end_year    ); }
                if($line =~ m/end_month/i)          {$namelistlines[$iline] = sprintf(" %s\n", $end_month   ); }
                if($line =~ m/end_day/i)            {$namelistlines[$iline] = sprintf(" %s\n", $end_day     ); }
                if($line =~ m/end_hour/i)           {$namelistlines[$iline] = sprintf(" %s\n", $end_hour    ); }
                if($line =~ m/end_minute/i)         {$namelistlines[$iline] = sprintf(" %s\n", $end_minute  ); }
                if($line =~ m/end_second/i)         {$namelistlines[$iline] = sprintf(" %s\n", $end_second  ); }
		#if($line =~ m/num_metgrid_levels/i) {$namelistlines[$iline] = sprintf(" %s\n", $n_metgrid_levels); }
                ### Update TIME_STEP in namelist.template if $DOMAIN1_TIMESTEP is specified in parameters file, 
                ### note $regionname global variable used in parameters file
                if ( defined $DOMAIN1_TIMESTEP{$regionname}[$IWINDOW] ) {
                  if ( $line =~  m/ TIME_STEP  *=/i ) {
                    $namelistlines[$iline] = sprintf " time_step = %d,\n", $DOMAIN1_TIMESTEP{$regionname}[$IWINDOW] ;
                  }
                }
              }
              print NEWNAMELIST @namelistlines;
              close(NEWNAMELIST);

              # Grab max_dom from namelist.input: allows plotting of d1 & d2 wrfout files
              $max_dom = `grep -i max_dom namelist.input` ;
              if( $max_dom =~ m/\s*\w+\s*=\s*(\d)/){
                $max_dom = $1;
                print $PRINTFH "      Max_dom = $max_dom\n" ;
              }
              else {
                print $PRINTFH "***** Cannot find max_dom - Assuming 2\n";
                $max_dom = 2;
              }

              ### PRINT START/END INFO
              if ($LPRINT>1) { 
                for ($idomain=1; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW]; $idomain++ ) {
                  printf $PRINTFH "      $moad DOMAIN $idomain START-END = %s-%s-%s:%sZ - %s-%s-%s:%sZ \n",
		            $startyyyy4dom[$idomain],$startmm4dom[$idomain],$startdd4dom[$idomain],$starthh4dom[$idomain],
			        $endyyyy4dom[$idomain],$endmm4dom[$idomain],$enddd4dom[$idomain],$endhh4dom[$idomain] ; 
                }
              }

              # Save previous real.out & run real.exe
              `if [ -f LOG/real.out ]; then mv LOG/real.out LOG/previous.real.out; fi` ;
              if ($LPRINT>1) { print $PRINTFH "      Previous LOG/real.out* files pre-pended with \"previous.\" \n"; }
              `real.exe > LOG/real.out 2>&1` ;
              $realRes = `tail -1 LOG/real.out | grep -c 'SUCCESS COMPLETE REAL_EM INIT'`;
              chomp($realRes);
              if( $realRes eq 1){ print $PRINTFH "    Successful completion of real.exe\n" ; }
              else{
                print $PRINTFH "***  real.exe failed: See real.log and LOG/real.out\n" ;   
                die "***  real.exe failed: See real.log and LOG/real.out\n" ;   
              }

              if ( $LMODELRUN>1 && -f "LOG/wrf.out"  ) {
                if ($LPRINT>2) { print $PRINTFH "      Previous wrf.out file pre-pended with \"previous.\" \n"; }
                `mv -f wrf.out previous.wrf.out 2>/dev/null`;
              }

              #
              # Sort out old wrfout files
              #
              if($LSAVE > 1 && defined $LSAVE_DAYS ) {
                # Remove wrfout files older than $LSAVE_DAYS days in current dir 
                # Note that if LSAVE_DAYS == 0, _nothing_ is saved (not even "previous")
                if ($LPRINT>2) { print $PRINTFH "      Deleting wrfout files older than $LSAVE_DAYS days\n"; }
                $Now=`date +%s`;	# secs since epoch - not jday; must handle year-change
                chomp($Now);
                $Then = $Now - $LSAVE_DAYS * 24*60*60 + 12*60*60;  # extra 12 hrs allows for different run times
                @FileList = `ls wrfout* 2> /dev/null`;
                for my $F (@FileList) {
                  chomp($F);
                  @fil_data = stat $F; # fil_data[9] == mod time (sec since epoch)
                  if($fil_data[9] < $Then){
                    `rm $F`;
                    # if($LPRINT>2) {print $PRINTFH "        rm'd $F\n"; }
                  }
                }
              }
              else { # OLD SCHEME
                ### RENAME OLD WRF OUTPUT FILE PRIOR TO THREAD, SO NOT FOUND AT FIRST THREADED PLOT
                ### KEEP ONLY PREVIOUS DAY WRF EXEC OUTPUT FILES
                ### for threaded plot output, must remove output files from previous jobs
                ### only remove previous files if there are existing non-previous output files
                ### include stage2-only case - must also do for $LRUN_WINDOW=1 since then moad=$regionname-WINODW
                @filelist = `ls -1 wrfout* 2>/dev/null`;
                if ( $LMODELRUN>1 && $#filelist > -1 ) {
                  foreach $filename (@filelist) {
                    jchomp($filename);
                    `mv -f $filename previous.${filename} 2>/dev/null`;
                  }
                  if ($LPRINT>2) { print $PRINTFH "      Previous wrfout files pre-pended with \"previous.\" (older previous files deleted)\n"; }
                }
              }

              ### SAVE DESIRED WRF NON-WINDOW INIT FILES (namelist.input,wrfbdy_d01,wrfinput_d0*) even though run not known successful, since difficult to do later
              if( $LSAVE > 0 && $IWINDOW == 0 ) {
                `rm -f  $savesubdir{$regionname}/namelist.input.gz ; gzip namelist.input -c >| $savesubdir{$regionname}/namelist.input.gz`;
              }
              if( $LSAVE > 2 && $IWINDOW == 0 ) {
                `rm -f  $savesubdir{$regionname}/wrfbdy_d01.gz ; gzip wrfbdy_d01 -c >| $savesubdir{$regionname}/wrfbdy_d01.gz`;
                for ( $idomain=1; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW]; $idomain++ ) {   
                  ### domain init file  non-existent when domain initialized internally via interpolation
                  if( -f "wrfinput_d0${idomain}" ) {
                    `rm -f $savesubdir{$regionname}/wrfinput_d0${idomain}.gz ; gzip wrfinput_d0${idomain} -c >| $savesubdir{$regionname}/wrfinput_d0${idomain}.gz`;
                  }
                }
                ## make read-only to prevent accidental over-write
                #PAULS - split into two so as to avoid "arg list too long" error
                `chmod -f 444 $savesubdir{$regionname}/[a-r]*`;
                `chmod -f 444 $savesubdir{$regionname}/[s-z]*`;

                if ($LPRINT>1) {
                  $time = `date +%H:%M:%S` ;
                  print $PRINTFH "      $moad wrf init files SAVED to $savesubdir{$regionname} at $time";
                } 
              }       
            }

            ### DO MODEL RUN LMODELRUN 
            if ($LMODELRUN>1) {
              if ($LPRINT>1) {
                $time = `date +%H:%M:%S` ; jchomp($time) ; print $PRINTFH "   $moad MODEL RUN BEGINS at $time \n";
              }
              ### RUN MODEL - send stdout containing iteration prints to file
              ### create namelist used for actual run
              ### uses latest $intervalsecons which is for wrfout interval time
#             &template_to_namelist( $moad, $intervalseconds, 0 );
              ### cannot make a single command (to create only one ps) since then namelist cant be read
#             `cd $WRFBASEDIR/WRFV2/RASP/$moad/ ; cp namelist.input wrf.namelist`;
              ### add ${JOBARG}:${regionkey} as argument so ps can differentiate jobs, but not used by executable
              ### must send wrf.exe stderr somewhere as otherwise 'drjack.info -- rsl_nproc_all 1, rsl_myproc 0' is written to this program's stderr !?
              $wrfexe_errout = `wrf.exe "${JOBARG}:${regionkey}" >| wrf.out 2>&1`;

              ### Test for run errors
              ### note: "exceeded cfl" error can produce a NaN which kills execution so badly that these tests not reached:
              #         with script ending with "just-finished child runmodel" processing
              $lrunerr = $?;
              $lastoserr = $!;
              ### must test for errors in log file since fatals still return code of 0
              chomp( $successtest = `tail -1 wrf.out | grep -c -i 'SUCCESS COMPLETE'` ) ;
              if( $lrunerr != 0 || ! defined $successtest || $successtest eq '' ||  $successtest != 1 ) {
                if ( $wrfexe_errout !~ m|^\s*$| ) {
                  print $PRINTFH "*** $moad ERROR EXIT : WRF.EXE => error found in STDERR = $wrfexe_errout \n";
                  exit 1;
                }
                elsif ( ! defined $successtest || $successtest eq '' || $successtest != 1 ) {
                  &write_err( "*** $moad ERROR: WRF.EXE EXIT ERROR: successtest= ${successtest} !=1 => error reported in logfile wrf.out");
                }
                elsif( $lrunerr != 0 ) { 
                  &write_err( "*** $moad ERROR: WRF.EXE EXIT ERROR: non-zero ReturnCode = ${lrunerr} - lastOSerr=${lastoserr} \n");
                }
                ### if batch mode, send email error notice to admininstrator
                if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'WRF_EXECUTION'}) {
                  $mailout='';
                  $subject = "$program wrf.exe ERROR rc=${lrunerr} successtest=${successtest} for $moad - $rundayprt #${groupnumber}";
                  jchomp( $mailout = `echo "STDERR= $wrfexe_errout" | mail -s "${subject}" "$ADMIN_EMAIL_ADDRESS" 2>&1` );
                  if ($LPRINT>1) { print $PRINTFH "*** ERROR NOTICE EMAILED - wrf.exe error \n"; }
                }
                $gridcalcendtime = `date +%H:%M` ; jchomp($gridcalcendtime);
                ### WRITE THREAD TIME SUMMARY FILE
                printf { $SUMMARYFH{$regionkey} } "%d: %s - %s = RUN ERROR ", $groupnumber,$gridcalcstarttime,$gridcalcendtime;
                print $PRINTFH "***>>> $regionkey wrf.exe ERROR EXIT for $regionkey at $gridcalcendtime under $RUNPID \n";
                exit 1;
              }
              else {
                if ($LPRINT>2) {
                  print $PRINTFH "     Exited $moad wrf.exe with no detected error\n";
                }
                ### DO PLOTTING/FTPING
                if(  $LTHREADEDREGIONRUN == 0 ) {
                  &output_model_results_hhmm ( @{$PLOT_HHMMLIST{$regionname}[0]}) ;
                }
              }
              if ($LPRINT>1) {
                $time = `date +%H:%M:%S` ; jchomp($time); print $PRINTFH "   END $regionname MODEL RUN LOOP $IWINDOW FOR $moad at $time\n";
              }
            }
            else {
              if ($LPRINT>1) { print $PRINTFH "   ** LMODELRUN=0, so *SKIP* $regionname MODEL RUN LOOP $IWINDOW FOR $moad WITH ${starthh4dom[1]}Z INITIALIZATION *** \n"; }
            }
            ####### SAVE ??? ####### might want to save 21z output file/plots
            ### NOTE THAT GRIB FILES OVER-WRITTEN EACH DAY SO NEED TO BE SAVED IF WANT TO KEEP
            ### NOTE THAT WRF OUTPUT FILES REMOVED ABOVE SO NEED TO BE SAVED IF WANT TO KEEP
            ### NOTE THAT IMAGE FILES OVER-WRITTEN EACH DAY SO NEED TO BE SAVED IF WANT TO KEEP
          }
          $gridcalcendtime = `date +%H:%M` ; jchomp($gridcalcendtime);
          ### WRITE TIME SUMMARY FILE
          $gridcalcrunhrs = &hhmm2hour($gridcalcendtime) - &hhmm2hour($gridcalcstarttime) ;
          if( $gridcalcrunhrs < 0 ) {
            $gridcalcrunhrs += 24. ;
          }
          printf { $SUMMARYFH{$regionkey} } "%d: %s - %s = %4.2f hr  ", $groupnumber,$gridcalcstarttime,$gridcalcendtime,$gridcalcrunhrs ;
          ### cancel timeout for entire model init/run section (thread)
          alarm ( 0 );
          ### FOR THREADED REGIONRUN, THIS IS CHILD PROCESS SO EXIT
          if( $LTHREADEDREGIONRUN == 1 ) {
            print $PRINTFH "   >>> $regionkey THREADED CHILD RUNMODEL ENDED for $regionkey at $gridcalcendtime under $RUNPID \n";
            ### EXIT THREAD
            exit 0;
          }
          else {
            print $PRINTFH "   >>> $regionkey NON-THREADED RUNMODEL ENDED at $gridcalcendtime \n";
          }
        } ### END OF THREADEDREGIONRUN IF FOR CHILD CREATION

        ### FOR THREADED REGIONRUN, THIS IS PARENT PROCESS 
        if( $LTHREADEDREGIONRUN == 1 ) {
          ### CREATE ARRAY TO TRACK STARTED CHILDREN (not used if not threaded)
          push @childrunmodellist, $kpid ;
          print $PRINTFH "   >>> $regionkey CHILD RUNMODEL $kpid SPUN OFF by $RUNPID for $program $JOBARG \n";
        } ### END OF SECTION PROCESSED IF ALL NEEDED GRIB FILES OBTAINED FOR A FORECAST RUN
      } ########## END OF LOOP OVER GRIDS !!! ##########

      ### FOR THREADED REGIONRUN, CHECK WHETHER ALL CHILD PROCESSES FOR EACH REGION HAVE ENDED
      ### ALSO  LOOK FOR COMPLETED OUTPUT FILES AND PROCESS THEM
      if ( $LTHREADEDREGIONRUN == 1 && $nstartedchildren > 0 ) {
        ### initialization for child test
        $nrunningchildren = $nstartedchildren ;
        $nfinished = 0;
        $ifinishedloop = 0;
        for ( $ichild=0; $ichild<=$#childrunmodellist; $ichild++ ) {
          $child_exitvalue_list[$ichild] = -999;
          $child_signum_list[$ichild] = -999;
        }
        $time = `date +%H:%M:%S` ; jchomp($time);
        printf $PRINTFH "   >>> LOOK FOR RUNNING RUNMODEL CHILDREN with #children = %d & %d and sleepsec= %d sec at %s \n",$nstartedchildren,(1+$#childrunmodellist),$finishloopsleepsec,$time;
        ### require a child to be still running to stay in loop
        ### (since a child might end for mysterious reasons and not be caught by normal processing)
        ### two ways to exit loop - normally second one used
        while ( $nrunningchildren > 0 && $nfinished < $nstartedchildren ) {
          $time = `date +%H:%M:%S` ; jchomp($time);
          $ifinishedloop++;
          ### TEST CHILD STATUS 
          ### if child NOT ended, $childtest=0 $childstatus=-1
          ### if child IS  ended, $childtest=$kpid $childstatus=see_below('exit 0'=>0,'exit 1'=>256)=>$child_signal_num=0,$child_exit_value=rc 
          ### SLEEP AT EACH ITER
          sleep $finishloopsleepsec;
          ### LOOP OVER STARTED CHILD PROCESSES
          $nrunningchildren = 0;
          for ( $ichild=0; $ichild<=$#childrunmodellist; $ichild++ ) {
            $childrunmodel = $childrunmodellist[$ichild];
            ### LOOK FOR JUST-FINISHED CHILDREN FROM THOSE CHILD PIDS STILL ACTIVE 
            if( $childrunmodel > 0 ) {
              $nrunningchildren++;
              ### *** $childtest = 0 while child still running, pid# on first waitpid call after finish, then -1 ***
              $childtest = waitpid ( $childrunmodel, &WNOHANG ) ; 
              ### if just finished, set pid array value to -1 to indicate job finished and add to finished count
              if( $childtest > 0 ) {
                $childrunmodellist[$ichild] = -1;
                $nfinished++;
                ### determine child exist status
                $child_exit_value  = $? >> 8 ;
                $child_signal_num  = $? & 127 ;
                $child_exitvalue_list[$ichild] = $child_exit_value ;
                $child_signum_list[$ichild] = $child_signal_num ;
                ### PRINT FINISHED JOB INFO
                $time = `date +%H:%M:%S` ; jchomp($time);
                print $PRINTFH "   > $ichild JUST-FINISHED CHILD RUNMODEL PID= $childrunmodel = $childtest  RCs= $child_exit_value & $child_signal_num at $time \n";
              }
            }
          }
          ### LOOK FOR AND PROCESS NEWLY CREATED OUTPUT FILES
          foreach $regionkey (@REGION_DOLIST) {
            $regionname = $regionkey;
            ### SET NAME OF CURRENT CASE HERE
            ( $regionname_lc = $regionname ) =~ tr/A-Z/a-z/; 
            $moad = ${regionname};
            ### generate list of available wrfout files (add -window files for window runs)
            @outputfilelist = ();
            for( $IWINDOW=$iwindowstart{$regionkey}; $IWINDOW<= $iwindowend{$regionkey}; $IWINDOW++ ) {
              ### include stage2-only case
              if ( $LRUN_WINDOW{$regionkey} > 0 && $IWINDOW == 1 ) {
                $moad = $regionname . "-WINDOW" ;
              }
              ### look for newly created output files (exclude links)
              ### must have removed output files from previous jobs for this to work!
              ### PLOT DOMAIN FOR WHICH PLOT SIZE IS NOT BLANK
              ### set non-window/window array index
              @findfilelist = ();
              for ( $idomain=1; $idomain<=$MAXDOMAIN{$regionname}[$IWINDOW]; $idomain++ ) {
                if( defined $PLOT_IMAGE_SIZE{$regionname}[$IWINDOW][$idomain-1] && $PLOT_IMAGE_SIZE{$regionname}[$IWINDOW][$idomain-1] !~ '^ *$' ) {
                  push @findfilelist, `find "$WRFBASEDIR/WRFV2/RASP/$moad" -name "wrfout_d0${idomain}*" \! -type l -maxdepth 1 -follow -print 2>/dev/null` ;
                }
              }
              ### ONLY ADD FILES SELECTED TO BE PLOTTTED
              for ( $iifile=0; $iifile<=$#findfilelist; $iifile++ ) {
                jchomp( $findfilelist[$iifile] );
                ( $historyhhmm = $findfilelist[$iifile] ) =~ s|.*/wrfout_d.*_([0-9][0-9]:[0-9][0-9]):.*|$1|;
                $historyhhmm =~ s|:||;
                if( grep ( m/$historyhhmm/, @{$PLOT_HHMMLIST{$regionname}[$IWINDOW]} ) > 0 ) { 
                  ### do not need to test whether link due to use of ! -type l in find command
                  push @outputfilelist, $findfilelist[$iifile] ; 
                }
              }
              ### DAY/HR SELECTION - moved call inside iwindow loop - - this depends upon start/end time of run
              foreach $wrffilename (@outputfilelist) {
                jchomp($wrffilename);
                ### multiple days have "+" in directory name so must allow for it
                ( $wrffilenametest = $wrffilename ) =~ s|\+|\\+|g ;
                if( grep ( m/^${wrffilenametest}$/, @{$finishedoutputhour{$regionkey}} ) == 0 ) { 
                  push @{$finishedoutputhour{$regionkey}}, $wrffilename ;
                  ### do output for this file
                  &output_wrffile_results ( $wrffilename );
                }
              }
            }
          }     
        }
        $time = `date +%H:%M:%S` ; jchomp($time);
        printf $PRINTFH "   > END CHILD RUNMODEL PROCESSING WITH %d/%d CHILDREN ENDED - AFTER %d ITERS OF %d sec at $time \n", $nfinished,(1+$#childrunmodellist),$ifinishedloop,$finishloopsleepsec ;
      }
      SUCCESS_CYCLE_END:
      ### THE ABOVE LABEL USED PRIMARILY FOR TEST RUNS, TO AVOID CALC IN PERL DEBUG MODE BY JUMPING HERE
      ### DO SUCCESSFUL PROCESSING SUMMARY
      $time = `date +%H:%M:%S` ; jchomp($time);
      $successfultimescount = $successfultimescount + 1;
      $timehhmm = `date +%H:%M` ; jchomp($timehhmm);
      $filestatus{$ifile} = $status_processed; 
      ### following saves info needed for skipping of older valid time cases - now done only for _successful_ times!
      $latestfcsttime[$fileextendedvalidtime] = $filefcsttime; 
      ### DO SUCCESSFUL CYCLE PRINT
      if ($LPRINT>1) {printf $PRINTFH ("   GRIB_FILE_PROCESSING_COMPLETE : %s \n", $time );}

      STRANGE_CYCLE_END:
      ### SENT HERE AFTER *UNEXPECTED* FILE PROCESSING OCCURS, FOR CYCLE-ENDING TESTS (INSTEAD OF DIRECTLY STARTING NEW CYCLE)
      ### IMMEDIATELY PRIOR TO HERE SHOULD CONSIDER (1) $filestatus{$ifile} for next attempt  (2) sleep  SINCE WILL IMMEDIATELY RE-CYCLE
      ### remember this filename during next cycle
      $lastfilename = $filename;
      ### to only create 1 blipmap: if($foundfilecount==1) &final_processing;
      ### TEST IF SWITCHING TIME SHUTDOWN NEEDED - similar test also done just after gribget
      if( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' ) {
        $switchingtestjda2z = `date -u +%d` ; jchomp($switchingtestjda2z);
        $switchingtesthhmmz = `date -u +%H:%M` ; jchomp($switchingtesthhmmz);
        $switchingtesttimez = &hhmm2hour( $switchingtesthhmmz );
        ##_for_next_day_switchingtime:
        $switchingtimetestz = $switchingtimehrz{$GRIBFILE_MODEL} - ($minftpmin{$GRIBFILE_MODEL}+$mincalcmin{$GRIBFILE_MODEL})/60. ;
        if ( $switchingtesttimez > $switchingtimetestz && $switchingtestjda2z != $jda2 ){
          ##_for_same_day_switchingtime: if ( $switchingtesttime > $switchingtimetest || $switchingtestjda2 == $jda2 )
          print $PRINTFH ("LOOP-END CYCLE EXIT: SWITCHING TIME Z $switchingtesttimez '>' $switchingtimetestz AND DAY $switchingtestjda2z '!=' $jda2 \n");
          last CYCLE;
        }
      }
      ### EXIT IF ALL FILES PROCESSED
      $oktotal = $successfultimescount + $oldtimescount + $nextskipcount ;
      if( $oktotal >= $dofilecount ) {
        ###  file processing done
        print $PRINTFH ("LOOP-END CYCLE EXIT: OKtimescount = DOfilecount = $dofilecount \n");    
        last CYCLE;
      }
      ### FOR RUN THAT DID NOT REQUEST ANY GRIB DOWNLOAD, EXIT AFTER ONE FILESET (= $GRIBFILES_PER_FORECAST_PERIOD files) PROCESSED
      ### since no new files are to be downloaded, 
      if( $LGETGRIB==0 && $nstartedchildren > 0 ) {
        print $PRINTFH ("LOOP-END CYCLE EXIT: $successfultimescount files processed when LGETGRIB=0 \n");    
        last CYCLE;
      }
      ### EXIT IF GRIB FILE INPUT CASE
      if( $LGETGRIB == -1 ) {
        print $PRINTFH ("LOOP-END CYCLE EXIT: LGETGRIB=-1 SPECIFIED GRIB FILE CASE \n");    
        last CYCLE;
      }    
    }
  }  ### END CYCLE LOOP OVER TIME

  if ($LMODELRUN>0) {
    foreach $regionkey (@REGION_DOLIST) {
      #####  JOB END IMAGE TEST - check for last image expected, if missing send email
      ### if batch mode, send email error notice to admininstrator
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'JOBEND_IMAGE'} ) {
        ### undecided as to what criteria to use to identify "run failure"
        ###    decided to test for expected final output plot images as test of entire process
        ###    but wish it could be less complex
        ### use final parameter for test image
        $testparam = ${$PARAMETER_DOLIST{$regionkey}}[$#{$PARAMETER_DOLIST{$regionkey}}] ;
        ### use final run (stage-1 or stage-2) for test image
        if ( $LRUN_WINDOW{$regionkey} == 0 ) { 
          $teststage = 0 ;
#         $testdir = "${OUTDIR}/${regionkey}" ;
          $testdir = "${OUTDIR}" ;
        }
        else { 
          $teststage = 1 ;
          $testdir = "${OUTDIR}/${regionkey}-WINDOW" ;
        }
        ### use final output time for test image
        $testgmt = ${$PLOT_HHMMLIST{$regionkey}[$teststage]}[$#{$PLOT_HHMMLIST{$regionkey}[$teststage]}] ;
        $testlst = $testgmt + $LOCALTIME_ADJ{$regionkey} * 100 ;
        if( $testlst < 0 ) {
          $testlst += 2400 ;
        }
        elsif( $testlst >= 2400 ) {
          $testlst -= 2400 ;
        }
        $testlst = sprintf "%04d", $testlst ;
        ### mimic $localsoarday calc since $localsoarday may not be available here if error exit
        if( defined $ENV{CURR_ONLY} && $ENV{CURR_ONLY} eq "1" ){ $testday = 'curr.'; }
        else{
          if(    $JOBARG =~ m|\+1| )  { $testday = 'curr+1.'; }
          elsif( $JOBARG =~ m|\+2| )  { $testday = 'curr+2.'; }
          elsif( $JOBARG =~ m|\+3| )  { $testday = 'curr+3.'; }
          elsif( $JOBARG =~ m|\+4| )  { $testday = 'curr+4.'; }
          elsif( $JOBARG =~ m|\+5| )  { $testday = 'curr+5.'; }
          elsif( $JOBARG =~ m|\+6| )  { $testday = 'curr+6.'; }
          else                        { $testday = 'curr.';   }
        }
        ### use output directory so not influenced by LSEND,LSAVE flags
        if( grep (m/sounding/, $testparam) > 0 ){
          $testfile = sprintf "${testdir}/${testparam}.${testday}${testlst}lst.d%d.png", $max_dom ;
        }
        else{
          $testfile = sprintf "${testdir}/${testparam}.${testday}${testlst}lst.d%d.body.png", $max_dom ;
        }
           
        if ($LPRINT>1) { print $PRINTFH "JOB END - CHECK LAST $regionkey IMAGE = $testfile \n"; }
        if ( -f $testfile ) {
          ### existing file should be less than 18 hours old!
          # Problems with %X (last access): chomp( $fileepochsec = `stat --format "%X" $testfile` ) ; 
          chomp( $fileepochsec = `stat --format "%Y" $testfile` ) ; 
          chomp( $currentepochsec = `date +%s` ); 
          $agehr = ( $currentepochsec - $fileepochsec ) / 3600. ;    
          if ( $agehr > 18. ) {
            `echo -e " EXPECTED FINAL IMAGE NOT FOUND \n Latest final image file: \n   $testfile \n   agehr= $agehr > 18" | mail -s "$program RASP ERROR - JOB END IMAGE CHECK for $regionkey - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
            if ($LPRINT>1) { print $PRINTFH "*** ERROR NOTICE EMAILED - JOB END IMAGE CHECK - OLD final image file: $testfile - agehr= $agehr > 18 \n"; }
          }
        }
        else {
          `echo -e " EXPECTED FINAL IMAGE NOT FOUND \n NON-EXISTENT final image file: \n   $testfile" | mail -s "$program RASP ERROR - JOB END IMAGE CHECK for $regionkey - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
          if ($LPRINT>1) { print $PRINTFH "*** ERROR NOTICE EMAILED - JOB END IMAGE CHECK - NON-EXISTENT final image file: $testfile \n"; }
        }
      }
    }  
    ### CALL FINAL PROCESSING ROUTINE
    if ($LPRINT>1) {
      print $PRINTFH "Doing BLIP - call final blip processing\n";
    }
    &final_processing;
  }
  else {
    print $PRINTFH "LMODELRUN=0 => Skip final processing\n";
  }
  exit;
###########  END OF MAIN PROGRAM  ############



#########################################################################
##################   START OF SUBROUTINE DEFINITIONS   ##################
#########################################################################
sub template_to_namelist
{  
  my $inputmoad = $_[0];
  my $intervalseconds = $_[1];
  my $numdoms = $_[2];
  if ($LPRINT>3) {print $PRINTFH "         using template_to_namelist with @_\n";}
  ### CREATE RUN NAMELIST FROM TEMPLATE
  ### keep a copy of the previous namelists input
  ###  RUN_HOURS should be 0 so ignored, else it (not END_HOUR ) controls model end !
  ###  get error 'Exiting subroutine via last at ./rasp.pl' at next line if don't use quotes !?
  if ( -f "${wrfnamelistfile}.last" ) { `mv -f "${wrfnamelistfile}.last" "${wrfnamelistfile}.lastlast" 2>/dev/null`; }
  open(OLDNAMELISTINPUT,"<$WRFBASEDIR/WRFV2/RASP/$inputmoad/namelist.template") or die "Missing namelist.input file for $regionkey - run aborted" ;
  open(NEWNAMELISTINPUT,">${wrfnamelistfile}") ;
  @namelistlines = <OLDNAMELISTINPUT>;
  close(OLDNAMELISTINPUT);
  for ($iline=0; $iline<=$#namelistlines; $iline++ ) {
    $line = $namelistlines[$iline];
    if ( $line =~  m/START_YEAR/i )
      { $namelistlines[$iline] = sprintf "  START_YEAR = " . "%4d, " x $#startyyyy4dom . "\n", @startyyyy4dom[1 .. $#startyyyy4dom] ; }
    if ( $line =~  m/START_MONTH/i )
      { $namelistlines[$iline] = sprintf "  START_MONTH = " . "%02d, " x $#startmm4dom . "\n", @startmm4dom[1 .. $#startmm4dom] ; }
    if ( $line =~  m/START_DAY/i )
      { $namelistlines[$iline] = sprintf "  START_DAY = " . "%02d, " x $#startdd4dom . "\n", @startdd4dom[1 .. $#startdd4dom] ; }
    if ( $line =~  m/START_HOUR/i )
      { $namelistlines[$iline] = sprintf "  START_HOUR = " . "%02d," x $#starthh4dom . "\n", @starthh4dom[1 .. $#starthh4dom] ; }
    if ( $line =~  m/END_YEAR/i )
      { $namelistlines[$iline] = sprintf "  END_YEAR = " . "%4d, " x $#endyyyy4dom . "\n", @endyyyy4dom[1 .. $#endyyyy4dom] ; }
    if ( $line =~  m/END_MONTH/i )
      { $namelistlines[$iline] = sprintf "  END_MONTH = " . "%02d, " x $#endmm4dom . "\n", @endmm4dom[1 .. $#endmm4dom] ; }
    if ( $line =~  m/END_DAY/i )
      { $namelistlines[$iline] = sprintf "  END_DAY = " . "%02d, " x $#enddd4dom . "\n", @enddd4dom[1 .. $#enddd4dom] ; }
    if ( $line =~  m/END_HOUR/i )
      { $namelistlines[$iline] = sprintf "  END_HOUR = " . "%02d, " x $#endhh4dom . "\n", @endhh4dom[1 .. $#endhh4dom] ; }
    if ( $line =~  m/MAX_DOM/i && $numdoms > 0 )
      { $namelistlines[$iline] = sprintf "  MAX_DOM = %d,\n", $numdoms ; }
    if ( $line =~  m/NUM_METGRID_LEVELS/i )
      { $namelistlines[$iline] = sprintf "  NUM_METGRID_LEVELS = %2d, \n",$num_metgrid_levels{$GRIBFILE_MODEL} ; }
    if ( defined $intervalseconds ) {
      if ( $line =~  m/INTERVAL_SECONDS/i )
        { $namelistlines[$iline] = sprintf "  INTERVAL_SECONDS = %d,\n", $intervalseconds ; }
    } 
    ### IF $DOMAIN1_TIMESTEP IN PARAMETERS FILE, OVERWRITE namelist.template TIME_STEP
    ### note $regionname global variable used in parameters file
    if ( defined $DOMAIN1_TIMESTEP{$regionname}[$IWINDOW] ) {
      if ( $line =~  m/ TIME_STEP  *=/i )
        { $namelistlines[$iline] = sprintf "  TIME_STEP = %d,\n", $DOMAIN1_TIMESTEP{$regionname}[$IWINDOW] ; }
    }
  }
  print NEWNAMELISTINPUT @namelistlines ;
  close(NEWNAMELISTINPUT);
  ### keep a copy of the previous namelists input
  `cp -f $wrfnamelistfile "${wrfnamelistfile}.last"`;
}
#########################################################################
#########################################################################
sub template_to_fake1namelist
{  
  ### require start=end same as domain1 - should be true for normal and not matter for windowed run and allows arbitraty start for latter
  my $inputmoad = $_[0];
  my $intervalseconds = $_[1];
  if ($LPRINT>3) {print $PRINTFH "         using template_to_fakenamelist with @_\n";}
  ### CREATE RUN NAMELIST TO RUN *DOMAIN2* real.exe FROM TEMPLATE
  ### uses external $kdomain which is never 1
  open(OLDNAMELISTINPUT,"<$WRFBASEDIR/WRFV2/RASP/$inputmoad/namelist.template") or die "Missing namelist.input file for $regionkey - run aborted" ;
  open(NEWNAMELISTINPUT,">${wrfnamelistfile}") ;
  @namelistlines = <OLDNAMELISTINPUT>;
  close(OLDNAMELISTINPUT);
  for ($iline=0; $iline<=$#namelistlines; $iline++ ) {
    ### FOR THIS CASE END TIME MUST EQUAL START TIME
    $line = $namelistlines[$iline];
    if ( $line =~  m/START_YEAR/i )
      { $namelistlines[$iline] = sprintf "  START_YEAR = %4d,\n",$startyyyy4dom[$kdomain] ; }
    if ( $line =~  m/START_MONTH/i )
      { $namelistlines[$iline] = sprintf "  START_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
    if ( $line =~  m/START_DAY/i )
      { $namelistlines[$iline] = sprintf "  START_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
    if ( $line =~  m/START_HOUR/i )
      { $namelistlines[$iline] = sprintf "  START_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    if ( $line =~  m/END_YEAR/i )
      { $namelistlines[$iline] = sprintf "  END_YEAR = %4d,,\n",$startyyyy4dom[$kdomain] ; }
    if ( $line =~  m/END_MONTH/i )
      { $namelistlines[$iline] = sprintf "  END_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
    if ( $line =~  m/END_DAY/i )
      { $namelistlines[$iline] = sprintf "  END_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
    if ( $line =~  m/END_HOUR/i )
      { $namelistlines[$iline] = sprintf "  END_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    ### SPECIFY ONLY A SINGLE DOMAIN 
    if ( $line =~  m/MAX_DOM/i )
      { $namelistlines[$iline] = sprintf "  MAX_DOM = 1,\n" ; }
    if ( $line =~  m/NUM_METGRID_LEVELS/i )
      { $namelistlines[$iline] = sprintf "  NUM_METGRID_LEVELS = %2d, \n",$num_metgrid_levels{$GRIBFILE_MODEL} ; }
    if ( defined $intervalseconds ) {
      if ( $line =~  m/INTERVAL_SECONDS/i )
        { $namelistlines[$iline] = sprintf "  INTERVAL_SECONDS = %d,\n", $intervalseconds ; }
    }
    ### SELECT DOMAIN VALUES SPECIFIC TO THIS DOMAIN
    if ( $line =~m/^ *e_we *=/i || $line =~m/^ *e_sn *=/i || $line =~m/^ *e_vert *=/i || $line =~  m/^ *d[xy] *=/i ) { 
      for ( $ii=1; $ii<=($kdomain-1); $ii++ ) { 
        $namelistlines[$iline] =~ s/=[^,]*,/ =/ ;
      }
    }
  }
  print NEWNAMELISTINPUT @namelistlines ;
  close(NEWNAMELISTINPUT);
}


#########################################################################
sub template_to_ndownnamelist
{  
  ###### ALA template_to_fake1namelist EXCEPT
  ###### 2 domains instead of 1
  ###### removes column _after_ first col for i_parent_start,j_parent_start
  ###### dont require start=end same as domain1
  my $inputmoad = $_[0];
  my $intervalseconds = $_[1];
  if ($LPRINT>3) {print $PRINTFH "         using template_to_ndownnamelist with @_\n";}
  ### CREATE RUN NAMELIST TO RUN *DOMAIN2* real.exe FROM TEMPLATE
  ### uses external $kdomain which is never 1
  open(OLDNAMELISTINPUT,"<$WRFBASEDIR/WRFV2/RASP/$inputmoad/namelist.template") or die "Missing namelist.input file for $regionkey - run aborted" ;
  open(NEWNAMELISTINPUT,">${wrfnamelistfile}") ;
  @namelistlines = <OLDNAMELISTINPUT>;
  close(OLDNAMELISTINPUT);
  for ($iline=0; $iline<=$#namelistlines; $iline++ ) {
    ### FOR THIS CASE END TIME MUST EQUAL START TIME
    $line = $namelistlines[$iline];
    if ( $line =~  m/START_YEAR/i )
      { $namelistlines[$iline] = sprintf "  START_YEAR = %4d,\n",$startyyyy4dom[$kdomain] ; }
    if ( $line =~  m/START_MONTH/i )
      { $namelistlines[$iline] = sprintf "  START_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
    if ( $line =~  m/START_DAY/i )
      { $namelistlines[$iline] = sprintf "  START_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
    if ( $line =~  m/START_HOUR/i )
      { $namelistlines[$iline] = sprintf "  START_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    if ( $line =~  m/END_YEAR/i )
      { $namelistlines[$iline] = sprintf "  END_YEAR = %4d,,\n",$startyyyy4dom[$kdomain] ; }
    if ( $line =~  m/END_MONTH/i )
      { $namelistlines[$iline] = sprintf "  END_MONTH = %02d,\n",$startmm4dom[$kdomain] ; }
    if ( $line =~  m/END_DAY/i )
      { $namelistlines[$iline] = sprintf "  END_DAY = %02d,\n",$startdd4dom[$kdomain] ; }
    if ( $line =~  m/END_HOUR/i )
      { $namelistlines[$iline] = sprintf "  END_HOUR = %02d,\n",$starthh4dom[$kdomain] ; }
    ### SPECIFY ONLY A SINGLE DOMAIN 
    if ( $line =~  m/MAX_DOM/i )
      { $namelistlines[$iline] = sprintf "  MAX_DOM = 1,\n" ; }
    if ( $line =~  m/NUM_METGRID_LEVELS/i )
       { $namelistlines[$iline] = sprintf "  NUM_METGRID_LEVELS = %2d, \n",$num_metgrid_levels{$GRIBFILE_MODEL} ; }
    if ( defined $intervalseconds ) {
      if ( $line =~  m/INTERVAL_SECONDS/i )
        { $namelistlines[$iline] = sprintf "  INTERVAL_SECONDS = %d,\n", $intervalseconds ; }
    }
    if( $IWINDOW == 1 ) {
      if ( $line =~  m/MAX_DOM/i )
        { $namelistlines[$iline] = "  MAX_DOM = 2, \n"; }
      if ( $line =~  m/i_parent_start/i  || $line =~  m/j_parent_start/i )
        { $namelistlines[$iline] =~ s/(_parent_start\s*=\s*[0-9]+\s*,)\s*[0-9]+\s*,/$1/ ; }
      if ( $line =~  m/parent_grid_ratio/i )
        { $namelistlines[$iline] =~ s/(parent_grid_ratio\s*=\s*[0-9]+\s*,)\s*[0-9]+\s*,/$1/ ; }
    }
    ### SELECT DOMAIN VALUES SPECIFIC TO THIS DOMAIN
    if ( $line =~m/^ *e_we *=/i || $line =~m/^ *e_sn *=/i || $line =~m/^ *e_vert *=/i || $line =~  m/^ *d[xy] *=/i ) { 
      for ( $ii=1; $ii<=($kdomain-1); $ii++ ) { 
        $namelistlines[$iline] =~ s/=[^,]*,/ =/ ;
      }
    }
  }
  print NEWNAMELISTINPUT @namelistlines ;
  close(NEWNAMELISTINPUT);
}


#########################################################################
#########################################################################
### ROUTINE TO DO WRF PLOTS, DO CP TO WEB DIR, FTPING & SAVE
sub output_model_results_hhmm ()
{
  our %ncl_procs;
  my $domainid;
  my $kdomain;
  my $dom;

  # Allow plotting of wrfout_d0[12 ...] according to max_dom in namelist.input file

  # Maximumum number of ncl processes that can run at once
  # Should be limited for large domains with many times, or system may swap (slooow!)
  # If this is zero, N(processes) is unlimited
  # Define in rasp.run.parameters.REGIONXYZ
  if( !defined($MAX_NCL_PROCS) ){ $MAX_NCL_PROCS = 0; }

  if ($LPRINT>1) {
    $time = `date +%H:%M:%S` ; jchomp($time);
    print $PRINTFH "   $regionname model plot start at $time\n";
    if( $MAX_NCL_PROCS ){ print $PRINTFH "     Plotting with a maximum of $MAX_NCL_PROCS copies of ncl\n";}
  }
  my @historyhhmmlist = @_;
  my $nprocs ;
  my $wrf_dom = sprintf "wrfout_d0%d*", $max_dom ;
  @wrflist = `ls -t -1 $wrf_dom`;	# NB: The latest wrfout file is first in the list
  HHMM: for( my $t = 0; $t <= $#historyhhmmlist; $t++) {
    $historyhh = substr  $historyhhmmlist[$t], 0, 2 ;
    $historymm = substr  $historyhhmmlist[$t], 2, 2 ;
    $nprocs = scalar(keys(%ncl_procs));

    ### Find the wrfout file for this hhmm (should be, but ...)
    $nameregex =  sprintf "wrfout_d0%d_2[0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]_%02d:%02d:00",$max_dom,${historyhh},${historymm};

    @wrffilename = grep /$nameregex/, @wrflist;
    if(!defined ($wrffilename[0]) || $wrffilename[0] eq ""){
      # Missing wrfout file :-(
      my $msg = "     ERROR - Missing wrfout file for ${historyhh}:${historymm}\n" ;
      print STDERR $msg;
      if ($LPRINT>1) { print $PRINTFH $msg; }
        next HHMM;
    }
	else{
      chomp($wrffilename[0]);
    }

    if( ! $MAX_NCL_PROCS || $nprocs < $MAX_NCL_PROCS ){
      ($domainid, $kdomain) = &output_wrffile_results ( $wrffilename[0] );
      next HHMM;
    }
    else{   # Need to wait for an ncl to finish as number of running ncl's is limited 
      foreach $hhmm (@historyhhmmlist){
        if( $ncl_procs{$hhmm} ){
          if( $ncl_procs{$hhmm}->alive) {
            &chk_not_too_long($ncl_procs{$hhmm});
          }
          else {
            if( $LPRINT > 1){
              $ncl_time = $ncl_procs{$hhmm}->end_time - $ncl_procs{$hhmm}->start_time ;
              print $PRINTFH "     NCL for $hhmm finished after  $ncl_time secs\n" ;
            }
            $ncl_procs{$hhmm}->wait; # Should be instant
            delete $ncl_procs{$hhmm} ;
            ($domainid, $kdomain) = &output_wrffile_results ( @wrffilename );
            next HHMM;
          }
        }
      }
      sleep(10);  # Tunable parameter!!
      $t--;
    }
  }

  # Wait for all ncls to finish
  while( scalar(keys(%ncl_procs)) > 0 ){
    foreach $historyhhmm (@historyhhmmlist) {
      if( exists $ncl_procs{$historyhhmm}){
        if( ! $ncl_procs{$historyhhmm}->alive){ # Finished
          if( $LPRINT > 1){
            $ncl_time = $ncl_procs{$historyhhmm}->end_time - $ncl_procs{$historyhhmm}->start_time ;
            print $PRINTFH "     NCL for $historyhhmm finished after  $ncl_time secs\n" ;
          }
          delete $ncl_procs{$historyhhmm} ;
        }
        else{
          &chk_not_too_long($ncl_procs{$historyhhmm});
        }
      }
    }
    sleep(10);
  }

  # Now check if they were successful
  foreach $historyhhmm (@historyhhmmlist) {
    my $logfile = "$RUNDIR/LOG/ncl.out.0$kdomain.$historyhhmm" ;
    my $lastline = `tail -15 $logfile` ;
    if( grep /fatal/, $lastline || ! grep /NORMAL END/, $lastline ){    # Fail!
      my $errlogfile = $logfile . "-ERROR" ;
      `cp $logfile $errlogfile` ;
      $msg1 = "    NCL for $historyhhmm FAILED: See $errlogfile";
      if( $LPRINT > 1){ print $PRINTFH $msg1 . "\n" ;}
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) ) {
        `echo $msg1 | mail -s "NCL FAILURE for $moad - $historyhhmm" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
      # We can rerun, but it will need to be wait()'d for
      # my $wrffile =  `grep wrfout $logfile | head -1 | cut -d ' ' -f 3`;
      # chomp($wrffile);
      # if ( -s "$wrffile" ) {
      #   ($domainid, $kdomain) = &output_wrffile_results ( $wrffile );
      # }
    }
  }

  # Need to run ncl for pfd_tot and/or avgstars
  our ($avg_flag, $pfd_flag);
  if($pfd_flag){
    # Other ENV_NCL_... will be left over :-)
    $ENV{'ENV_NCL_PARAMS'} = "pfd_tot";
    my $idx = $historyhhmm ;
    my $logfile = "$RUNDIR/LOG/ncl.out.0${kdomain}.pfd" ;
    $time = `date +%H:%M:%S`;
    print $PRINTFH "     Plotting parameter \"pfd_tot\" at $time \n";

    `cd $NCLDIR ; ncl -n -p < wrf2gm.ncl > $logfile 2>&1` ;
  }

  # When the NCL procs have successfully finished, Copy files to website, etc
  if( $LSEND == 0 ) {
    print $PRINTFH "LSEND == $LSEND; Not sending files to Website\n" ;
    return ;
  }
  if($LSEND < 0){
    print $PRINTFH "LSEND == $LSEND; FTP NOT IMPLEMENTED (Yet?)\n" ;
    return;
  }
  if( $LSEND == 1){
    print $PRINTFH "LSEND == $LSEND; test.files NOT IMPLEMENTED (Yet?)\n" ;
    return;
  }
  if( $LSEND == 3){
    print $PRINTFH "LSEND == $LSEND; first-of-day processing(?) NOT IMPLEMENTED\n" ;
    return;
  }
  if( $LSEND > 3){
    print $PRINTFH "LSEND == $LSEND; Unknown LSEND value\n" ;
    return;
  }

  # LSEND must be 2 - image & data files to website
  my $timestamp = `ls -tr wrfout_d0* | tail -1` ;
  jchomp ($timestamp) ;

  $time = `date +%H:%M:%S`;
  print $PRINTFH "   COPYING files newer than $timestamp to $HTMLBASEDIR/${regionname}/FCST at $time" ;

  # Image files must be newer than the timestamp file
  my @imagelist = `find $imagedir -name \\*.png -cnewer $timestamp` ;
  chomp(@imagelist);

  ####### Do the files all at once with a single "cp" #######
  #  `cp @imagelist $HTMLBASEDIR/${regionname}/FCST` ;
  ########################################

  my @bgProcs = ();

  ####### Do the files as lots of parallel background "cp one_file dest_dir" procs ####
  #  for $f (@imagelist) {
  #    # my $cmd = "cp -pf $f $HTMLBASEDIR/${regionname}/FCST" ;
  #    my $cmd = "cp $f $HTMLBASEDIR/${regionname}/FCST" ;
  #    my $childproc = Proc::Background->new("$cmd");
  #} #Is this sensible - put to balance {}
  #######

  ####### Do the files as exactly 8 simultaneous cp commands
  my $nfiles = $#imagelist;
  my $filespercopy = int $nfiles / 7; # int() truncates towards zero
  for( my $i = 0; $i<$nfiles; $i += $filespercopy ){
    my $end = $i + $filespercopy - 1;
    if( $end >= $nfiles){ $end = $nfiles - 1; }
    @arr = @imagelist[$i .. $end];
    my $cmd = "cp @arr $HTMLBASEDIR/${regionname}/FCST" ;
    my $childproc = Proc::Background->new("$cmd");

    if( !defined $childproc ){   # Process creation failed!!
      print STDERR "FAILED to start: $cmd\n" ;
      if ($LPRINT>1) {
        print $PRINTFH "FAILED to start: $cmd\n" ;
      }
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) ) {
        `echo "FAILED to start: $cmd\n" | mail -s "$program LAUNCH FAILURE for $moad - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
        }
    }
    push @bgProcs, $childproc ;
  }
  # Ensure all procs are waited for.
  for( my $x = $#bgProcs - 1; $x >= 0; $x--){
    if($bgProcs[$x]->alive){
      $bgProcs[$x]->wait ;
    }
  }
  $#bgProcs = 0;

  $time = `date +%H:%M:%S`;
  print $PRINTFH "     POSTED $moad ${domainid}${kdomain} image plots for $localday $localmon $localyyyy at $time" ;

  # Data files must be newer than the timestamp file
  my @datalist = `find $imagedir -name \\*.data -cnewer $timestamp` ;
  chomp(@datalist);

  ###### Copy datafiles all at once ###########
  # `cp @datalist $HTMLBASEDIR/${regionname}/FCST` ;
  ###########################################

  ###### Do the files one at a time, as lots of processes ######
  # for $f (@datalist) {
  #   # my $cmd = "cp -pf $f $HTMLBASEDIR/${regionname}/FCST" ;
  #   my $cmd = "cp $f $HTMLBASEDIR/${regionname}/FCST" ;
  #   } #Is this sensible - put to balance {}

  ###### Copy the data files as exactly 8 simulataneous cp commands
  $nfiles = $#datalist;
  $filespercopy = int $nfiles / 7; # see above
  for( my $i = 0; $i < $nfiles; $i += $filespercopy ){
    my $end = $i + $filespercopy - 1;
    if( $end >= $nfiles){ $end = $nfiles - 1; }
    @arr = @datalist[$i .. $end];
    my $cmd = "cp @arr $HTMLBASEDIR/${regionname}/FCST" ;
  
    my $childproc = Proc::Background->new("$cmd");

    if( !defined $childproc ){   # Process creation failed!!
      print STDERR "FAILED to start: $cmd\n" ;
      if ($LPRINT>1) {
        print $PRINTFH "FAILED to start: $cmd\n" ;
      }
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) ) {
        `echo "FAILED to start: $cmd\n" | mail -s "$program LAUNCH FAILURE for $moad - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
    }
    push @bgProcs, $childproc ;
  }
    
  # Ensure all procs are waited for.
  for( my $x = $#bgProcs - 1; $x >= 0; $x--){
    if($bgProcs[$x]->alive){
      $bgProcs[$x]->wait ;
    }
  }
  $#bgProcs = 0;


  ### WARNING: WINDOW NOT TESTED - NOR IMPLEMENTED PROPERLY
  #
  ### $domainid d/w is posted&saved id used in $regionname directory (vice $moad) for normal/windowed domain
  if( $moad =~ m|-WINDOW|i && $LRUN_WINDOW{$regionkey} > 0 )
    { $domainid = 'w' ; }
  else
    { $domainid = 'd' ; }

  # Print Progress Message
  if ($LPRINT>1) {
    $time = `date +%H:%M:%S`;
    print $PRINTFH "     POSTED $moad ${domainid}${kdomain} image & data files for $localday $localmon $localyyyy at $time" ;
  }

  # Send Valid Day Info files - so validation day associated with time file can be determined via web if needed
  $hrinfopostname = sprintf "valid.%s%02d%02dlst.${domainid}${kdomain}.txt", $postday,$localhh,$localmin ;
  if( $LSEND == 1 ) {
    $hrinfopostname = "test.${hrinfopostname}";
  }
  # `echo "$julianyyyymmddprt{$localsoarday}" >| $HTMLBASEDIR/${regionname}/FCST/${hrinfopostname}`;
  my $str = sprintf("%4d-%02d-%02d", $localyyyy, $localmm, $localday);
  `echo "${str}" >| $HTMLBASEDIR/${regionname}/FCST/${hrinfopostname}`;

  $latestinfopostname = sprintf "valid.%s${domainid}${kdomain}.txt", $postday ;
  if( $LSEND == 1 ) {
    $latestinfopostname = "test.${latestinfopostname}";
  }
  # `echo "${localyyyy}-${localmm}-${localday} ${localhh}${localmin}" >| $HTMLBASEDIR/${regionname}/FCST/${latestinfopostname}`;
  `echo "${str} ${localhh}${localmin}" >| $HTMLBASEDIR/${regionname}/FCST/${latestinfopostname}`;

  `sync`;

  ############################
  # Archive files as specified
  if($LSAVE == 0)                                                         { print $PRINTFH "LSAVE == 0 - No Archiving\n";                  return; }
  if( ! defined $PLOT_IMAGE_SIZE{$regionkey}[${IWINDOW}-1][${kdomain}-1]) { print $PRINTFH "PLOT_IMAGE_SIZE not defined - No Archiving\n"; return; }
  if( $PLOT_IMAGE_SIZE{$regionkey}[${IWINDOW}][${kdomain}-1] eq '' )      { print $PRINTFH "PLOT_IMAGE_SIZE is null - No Archiving\n";     return; }
   
  $time = `date +%H:%M:%S`;
  print $PRINTFH "   ARCHIVING $moad ${domainid}${kdomain} files for $localday $localmon $localyyyy at $time" ;

  # Convert SAVE_PLOT_HHMMLIST from zulu to local times
  # Assume DST does not change in the middle of the run, so it is the same for all files!
  my @Date_Time = split /_/, $timestamp ;
  my $zdate = $Date_Time[$#Date_Time - 1];
  my $ztime = $Date_Time[$#Date_Time];
  my @date_time = (' ', $zdate, $ztime);
  
  my @archivetimeslocal = ();
  for $t (@{$SAVE_PLOT_HHMMLIST{$regionkey}[$IWINDOW-1]}) {
    my $hr = substr $t, 0, 2 ;
    my $mn = substr $t, 2, 2 ;
    my $tt = ($hr + $LOCALTIME_ADJ{$regionkey}) * 3600 + $mn * 60 ;
    if( $tt >= (24*3600) ){ $tt -= (24*3600); }
    if( $tt < 0)          { $tt += (24*3600); }
    my $ttt = sprintf("%02d%02d", $tt / 3600, ($tt % 3600) / 60) ;
    push @archivetimeslocal, $ttt ;
    # print $PRINTFH "ZULU: $t  -- LOCAL: $ttt\n" ;
  }
  
  # Build list of image files to be archived
  my @archivefilelist = ();
  I: for $i (@imagelist) {
      for $t (@archivetimeslocal){
        if( (grep /($t)lst/, $i) > 0 ) {
          push @archivefilelist, $i ;
          next I;
        }
      }
  }
  #### Diagnostic: Print File List
  # print $PRINTFH "LSAVE == $LSAVE; Files to archive:\n" ;
  # for $f (@archivefilelist) {
  #   print $PRINTFH "$f\n" ;
  # }

  $time = `date +%H:%M:%S` ;
  print $PRINTFH "     ARCHIVING $moad ${domainid}${kdomain} plot images for $date_time[1] to $savesubdir{$regionname} at $time";
  #
  ####### Do the files as exactly 8 simultaneous cp commands
  $nfiles = $#archivefilelist;
  $filespercopy = int $nfiles / 7; # int() truncates towards zero
  for( my $i = 0; $i<$nfiles; $i += $filespercopy ){
    my $end = $i + $filespercopy - 1;
    if( $end >= $nfiles){ $end = $nfiles - 1; }
    @arr = @archivefilelist[$i .. $end];
    my $cmd = "cp @arr $savesubdir{$regionname}" ;
    my $childproc = Proc::Background->new("$cmd");

    if( !defined $childproc ){   # Process creation failed!!
      print STDERR "FAILED to start: $cmd\n" ;
      if ($LPRINT>1) {
        print $PRINTFH "FAILED to start: $cmd\n" ;
      }
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) ) {
        `echo "FAILED to start: $cmd\n" | mail -s "$program LAUNCH FAILURE for $moad - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
    }
    push @bgProcs, $childproc ;

  }
  # Ensure all procs are waited for.
  for( my $x = $#bgProcs - 1; $x >= 0; $x--){
     if($bgProcs[$x]->alive){
       $bgProcs[$x]->wait ;
     }
  }
  $#bgProcs = 0;

  $time = `date +%H:%M:%S` ;
  print $PRINTFH "     ARCHIVING $moad ${domainid}${kdomain} data files for $date_time[1] to $savesubdir{$regionname} at $time";

  # Build list of datafiles to be archived
  my @datafilelist = ();
  D: for $d (@datalist) {
      for $t (@archivetimeslocal){
        if( (grep /($t)lst/, $d) > 0 ) {
          push @datafilelist, $d ;
          next D;
        }
     }
  }
  #### Diagnostic: Print File List
  # print STDERR "LSAVE == $LSAVE; Data Files to archive:\n" ;
  # for $f (@datafilelist) {
  #   my $ftail = `basename $f`;
  #   chomp($ftail);
  #   my $cmd = "zip -q ${savesubdir{$regionname}}/$ftail.zip $f";
  #   print $PRINTFH "$cmd\n" ;
  # }

  # Archived DataFiles are zipped
  for $f (@datafilelist) {
    my $ftail = `basename $f`;
    chomp($ftail);
    my $cmd = "zip -q ${savesubdir{$regionname}}/$ftail.zip $f";
    my $childproc = Proc::Background->new("$cmd");

    if( !defined $childproc ){   # Process creation failed!!
      print STDERR "FAILED to start: $cmd\n" ;
      if ($LPRINT>1) {
        print $PRINTFH "FAILED to start: $cmd\n" ;
      }
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) ) {
        `echo "FAILED to start: $cmd\n" 
                | mail -s "$program LAUNCH FAILURE for $moad - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
    }
    push @bgProcs, $childproc ;

    # Potential fork() bomb! Limit procs to 200
    # Max # processes limited to 1024 in /etc/security/limits.d/90-nproc.conf
    if( $#bgProcs > 200 ){
      for( my $x = $#bgProcs - 1; $x >= 0; $x--){
        if($bgProcs[$x]->alive){
          $bgProcs[$x]->wait ;
        }
      }
      $#bgProcs = 0;
    }
  }

  ## Wait until all cp / zip Background Procs have finished.
  ## Assume they _will_ finish - No timeout trap!!
  for( my $x = $#bgProcs - 1; $x >= 0; $x--){
    if($bgProcs[$x]->alive){
      if($bgProcs[$x]->alive){
        $bgProcs[$x]->wait ;
      }
    }
  }
  $#bgProcs = 0;

  $time = `date +%H:%M:%S` ;
  print $PRINTFH "     Image and zipped datafiles for $moad ${domainid}${kdomain} $date_time[1] archived to $savesubdir{$regionname} at $time\n";
  `sync`;

  return ;
}  ## END output_model_results_hhmm ()

# Check ncl proc has not exceeded ncltimeoutsec
sub chk_not_too_long()
{
  my $proc = $_[0];
  $timenow = time();
  if( $timenow - $proc->start_time > $ncltimeoutsec){  # It's run too long
    $rc = $ncl_procs{$historyhhmm}->die ; # Kill it; Note that proc may have finished after test above; rc still == 1
    if($rc > 0){
      $msg1 = "    NCL for $historyhhmm exceeded timeout of $ncltimeoutsec secs\n" ;
      $msg2 = "    Examine $RUNDIR/LOG/ncl.out.0${kdomain}.$historyhhmm\n" ;
      if($LPRINT > 1){ print $PRINTFH $msg1 . $msg2 ; }
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'NCL_TIMEOUT'} ) {
        chomp $msg2;
        `echo $msg2 | mail -s "NCL TIMEOUT for $moad - $historyhhmm" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
    }
    else {
      # Failed to kill proc! This is terminal!!
      $msg3 = "Failed to kill NCL after TIMEOUT for $moad - $historyhhmm" ;
      print STDERR $msg3 ;
      if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' )  ) {
        `echo $msg3 | mail -s "Failed to kill NCL after TIMEOUT for $moad - $historyhhmm" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
      }
      die $msg3 ;
    }
  }
}

my %ncl_procs;  # Empty Associative Array; Must be a Global
our $pfd_flag = 0;
our $avg_flag = 0;

sub output_wrffile_results (@)
### CREATE WRF PLOTS FOR WRF FILES , DO FTPING + SAVE FOR SINGLE OUTPUT TIME
### *NB* DEPENDS ON EXTERNAL $IWINDOW,$regionkey,$regionname
{
  ### note that input can be array, though generally is just a single filename
  my @wrffilename = @_;
  my ( $moad, $kdomain, $domainid, $historyhhmm );
  our %ncl_procs;

  ## Horrible Kludge to reset IWINDOW - we only have IWINDOW = 0!
  $IWINDOW = 0;

  ### LOOP OVER ALL INPUT WRF FILENAMES
  foreach $wrffilename (@wrffilename) {
    ### EXTRACT $moad
    $moad = $regionkey;
    ### AT PRESENT, PLOT 2 DOMAINS
    ### EXTRACT $kdomain FROM FILENAME
    ### allow inclusion of "previous" in filename so can use routine with those filenames
    ( $kdomain = $wrffilename ) =~ s|.*wrfout_d0([1-9]).*|$1|;
    ### SET DOMAIN NAME 3 FOR WINDOWED CASE
    ### $domainid d/w is posted&saved id used in $regionname directory (vice $moad) for normal/windowed domain
    if( $moad =~ m|-WINDOW|i && $LRUN_WINDOW{$regionkey} > 0 )
      { $domainid = 'w' ; }
    else
      { $domainid = 'd' ; }
    ( $historyhhmm = $wrffilename ) =~ s/.*wrfout_d.*_([0-9][0-9]:[0-9][0-9]):.*/$1/;
    $historyhhmm =~ s|:||;
    ### set date variables for display
    my ( $historyhhmmplus, $fcstperiod ); 
    ### DAY/HR SELECTION - used to set historyhhmmplus
    if ( $historyhhmm >= $PLOT_HHMMLIST{$regionkey}[0][0] ) {
      $historyhhmmplus = $historyhhmm ;
    }
    else {
      $historyhhmmplus = $historyhhmm + 2400 ;
    }
    ### allow forecast period string to be decimal hours but strip off any .0 
    $raspfcstperiod = sprintf "%.1f", substr ( ${historyhhmmplus}, 0, 2 ) +0.01667*substr ( ${historyhhmmplus}, 2, 2 ) - $hhinit ;
    if( $raspfcstperiod < 0 ) { $raspfcstperiod += 24; }
    $fcstperiod = sprintf "%.1f", ($gribfcstperiod + $raspfcstperiod ) ;
    ( $fcstperiodprt = $fcstperiod ) =~ s|.0$|| ;
    $time = `date +%H:%M:%S`; jchomp( $time );
    print $PRINTFH "     Plotting WRF Output File : $wrffilename => $moad  & $kdomain & $domainid & $historyhhmm & $historyhhmmplus & $fcstperiod & $LRUN_WINDOW{$regionkey} at $time \n";
    ### CREATE WEB IMAGES FROM WRF OUTPUT FILE
#   $imagedir = "$OUTDIR/$moad" ;
    $imagedir = "$OUTDIR" ;
    ### ncl-environment variables
    $ENV{'ENV_NCL_INITMODE'}   = $GRIBFILE_MODEL ;
    $ENV{'ENV_NCL_REGIONNAME'} = $regionname ;
    $ENV{'ENV_NCL_FILENAME'}   = $RUNDIR . "/" . $wrffilename ;
    $ENV{'ENV_NCL_OUTDIR'}     = $imagedir ;
     ### use local time for plot print
    ( $filename = $wrffilename ) =~ s|.*/([^/]*)|$1| ;
    ( $head,$filemm,$tail ) = split /-/, $filename ;
    ( $fileyyyy = $head ) =~ s|.*_([0-9][0-9][0-9][0-9]).*|$1| ;
    ( $filedd = $tail ) =~ s|([0-9][0-9])_.*|$1| ;
    ( $filehh = $tail ) =~ s|.*_([0-9][0-9]):.*|$1| ;
    ( $filemin = $tail ) =~ s|.*_[0-9][0-9]:([0-9][0-9]).*|$1| ;
    ( $localyyyy,$localmm,$localdd,$localhh, $localmin ) = &GMT_plus_mins( $fileyyyy, $filemm, $filedd, $filehh, $filemin, (60*$LOCALTIME_ADJ{$regionkey}) );
    ( $localday = $localdd ) =~ s|^0|| ;
    $localmon = $mon{$localmm} ;
    $localdow = $dow[ &dayofweek( $localdd, $localmm, $localyyyy ) ];     # uses Date::DayOfWeek
    ### set "day" used in image filename based on run argument
    if( defined $ENV{CURR_ONLY} && $ENV{CURR_ONLY} eq "1" ){ $localsoarday = 'curr.'; }
    else{
      if(    $JOBARG =~ m|\+1| )  { $localsoarday = 'curr+1.'; }
      elsif( $JOBARG =~ m|\+2| )  { $localsoarday = 'curr+2.'; }
      elsif( $JOBARG =~ m|\+3| )  { $localsoarday = 'curr+3.'; }
      elsif( $JOBARG =~ m|\+4| )  { $localsoarday = 'curr+4.'; }
      elsif( $JOBARG =~ m|\+5| )  { $localsoarday = 'curr+5.'; }
      elsif( $JOBARG =~ m|\+6| )  { $localsoarday = 'curr+6.'; }
      else                        { $localsoarday = 'curr.';   }
    }
    $postday = $localsoarday ;    
    ### determine data creation time (gmt)
    ( my $ztime = &zuluhhmm ) =~ s|:|| ;
    $ENV{'ENV_NCL_ID'} = sprintf "Valid %02d%02d %s ~Z75~(%02d%02dZ)~Z~ %s %s %s %d ~Z75~[%shrFcst@%sz]~Z~",
                                 $localhh,$localmin, $LOCALTIME_ID{$regionkey},
                                 $filehh,$filemin, $localdow, $localday, $localmon, $localyyyy,
                                 $fcstperiodprt,$ztime ;
    ### datafile info - add blank at end as separator
    $ENV{'ENV_NCL_DATIME'} = sprintf "Day= %d %d %d %s ValidLST= %d%02d %s ValidZ= %d%02d Fcst= %s Init= %d ", 
                                 $localyyyy,$localmm,$localdd,$localdow,
                                 $localhh,$localmin,$LOCALTIME_ID{$regionkey},
                                 $filehh,$filemin, $fcstperiod, $gribfcstperiod ; 

    ### Set parameter list sent to wrf2gm.ncl
	# Complication with pfd_tot & avg_stars
	# as these must be run once only, when _all_ data files are available.
	# Thus these params must be removed from list
	# And then run after main run
	
	my @ncl_params = ();
	our ($pfd_flag, $avg_flag);
	foreach my $P (@{$PARAMETER_DOLIST{$regionkey}}) {
      if($P eq "pfd_tot")     { $pfd_flag = 1;}
      elsif($P eq "avgstars") { $avg_flag = 1;}
      else                    { push @ncl_params, $P; }
    }
    $ENV{'ENV_NCL_PARAMS'} = sprintf "%s", ( join ':',@ncl_params );

    $paramiddatastring = '' ;
    for ($iimage=0; $iimage<=$#{$PARAMETER_DOLIST{$regionkey}}; $iimage++ ) {
      $paramiddatastring .= "$PARAMETER_DOLIST{$regionkey}[$iimage] " ;
    }
   `cd $ENV{'ENV_NCL_OUTDIR'} ; rm -f $paramiddatastring 2>/dev/null`;

    # export IMAGESIZE for GM: size set for region-specific {$regionkey}[$IWINDOW=0,1]
    $ENV{'GMIMAGESIZE'} = "1600" ;	# Default Image Size

    $imagesize =  $PLOT_IMAGE_SIZE{$regionkey}[$IWINDOW][${kdomain}-1] ;
	if($imagesize ne "") {
      if( $imagesize =~ m|\*| ) {
        $imagesize =~ s|\*|x| ;
	  }
      ($imagewidth,$imageheight) =  split( /x/, $imagesize );
	  my $W = 0+$imagewidth;
	  my $H = 0+$imageheight;
      if( $W > $H){
        $ENV{'GMIMAGESIZE'} = sprintf "%d", $W ;
      }
      else{
        $ENV{'GMIMAGESIZE'} = sprintf "%d", $H ;
      }
    }

    # Start NCL as a background process
    # Let it run its course; it can finish, or it can get stuck
    # When all processes running, look at each proc in a sleep-loop
    # If proc has finished, remove from array
    # If it has exceeded timelimit, kill it
    # Else let it run.

    my $idx = $historyhhmm ;
    my $logfile = "$RUNDIR/LOG/ncl.out.0${kdomain}.$idx" ;
    my $cmd = "cd $NCLDIR ; ncl -n -p < wrf2gm.ncl > $logfile 2>&1" ;
    my $childproc = Proc::Background->new("$cmd");

    if( !defined $childproc ){   # Process creation failed!!
	  print STDERR "FAILED to start: $cmd\n" ;
	  if( ( $RUNTYPE eq '-M' || $RUNTYPE eq '-m' || $RUNTYPE eq '-i' ) && defined $ADMIN_EMAIL{'NCL_TIMEOUT'} ) {
        `echo "FAILED to start: $cmd\n" | mail -s "$program NCL LAUNCH FAILURE for $moad - $rundayprt" "$ADMIN_EMAIL_ADDRESS" 2>&1`;
	  }
    }
    $ncl_procs{$idx} = $childproc ;

    return ($domainid, $kdomain) ;
  }
}

#########################################################################

sub setup_getgrib_parameters
### SET  MODEL-DEPENDENT LGETGRIB AND SCHEDULING PARAMETERS
{
  if ( $GRIBFILE_MODEL eq 'ETA' )
  {
    ###### SET MODEL-SPECIFIC GRIBGET PARAMETERS
    ### set max ftp time for grib get
    $getgrib_waitsec = 4 * 60 ;                # sleep time, _not_ a timeout time
    ### minimum grib filesize (smaller grib files are ignored)
    $mingribfilesize = 5000000;
    ### time for download of grib file (max so far 120+ mins)
    ### *NB* should match that used for curl in script gribftpget
    $gribgetftptimeoutmaxsec = 15 *60 ;
    ###### SET SCHEDULING GRIBGET PARAMETERS
    ### SET LGETGRIB=2 for scheduled get (1=LStests)
    if( $LGETGRIB>1)
      { $LGETGRIB = 2; }
    ### SET FILE AVAILABLITY SCHEDULE TIMES (Z)
    ### 11 march 2004 NCEP ETA TIMES:
    ### gribavailhrzoffset used to _add_ cushion to actual expected availabilty
    if( ! defined $gribavailhrzoffset )
    {
      $gribavailhrzoffset = $gribavailhrzoffset{ETA}; 
    }
    ### gribavailhrzinc is hr increment per forecast hour
    $gribavailhrzinc = 11 / ( 12 * 60 );
    ### gribavailhrz0 is hour of analysis availability for each init.time
    ### 04jan2005 - essentially same as to ones used for blip awip218 files
    ### NOTE THESE ARE ZULU VICE LOCAL TIME USED IN CRONTAB
    $gribavailhrz0{'00'} = &hhmm2hour( '01:40' );      # checked 20jan2005
    $gribavailhrz0{'06'} = &hhmm2hour( '07:14' );
    $gribavailhrz0{'12'} = &hhmm2hour( '13:40' );
    $gribavailhrz0{'18'} = &hhmm2hour( '19:14' );
  }
  elsif ( $GRIBFILE_MODEL eq 'GFSN' || $GRIBFILE_MODEL eq 'GFSA' || $GRIBFILE_MODEL eq 'AVN' )
  {
    ###### SET MODEL-SPECIFIC GRIBGET PARAMETERS
    ### set max ftp time for grib get
    $getgrib_waitsec = 4 * 60 ;                # sleep time, _not_ a timeout time
    ### minimum grib filesize (smaller grib files are ignored)
    $mingribfilesize = 21000000;
    ### time for download of grib file (max so far 120+ mins)
    ### *NB* should match that used for curl in script gribftpget
    $gribgetftptimeoutmaxsec = 15 *60 ;
    ###### SET SCHEDULING GRIBGET PARAMETERS
    ### SET LGETGRIB=2 for scheduled get (1=LStests)
    if( $LGETGRIB>1)
      { $LGETGRIB = 2; }
    ### SET FILE AVAILABLITY SCHEDULE TIMES (Z)
    ### gribavailhrzoffset used to _add_ cushion to actual expected availabilty
    ### allow $gribavailhrzoffset to be set by reading initialization file (rasp.run.parameters or rasp.site.parameters) for test purposes
    if( ! defined $gribavailhrzoffset )
    {
      $gribavailhrzoffset = $gribavailhrzoffset{$GRIBFILE_MODEL}; 
    }
    ### gribavailhrzinc is hr increment per forecast hour
    $gribavailhrzinc = 10 / ( 24 * 60 );
    ### gribavailhrz0 is hour of analysis availability for each init.time
    ### NOTE THESE ARE ZULU VICE LOCAL TIME USED IN CRONTAB
    $gribavailhrz0{'00'} = &hhmm2hour( '03:26' );      # checked 16aug2005
    $gribavailhrz0{'06'} = &hhmm2hour( '09:26' );
    $gribavailhrz0{'12'} = &hhmm2hour( '15:26' );
    $gribavailhrz0{'18'} = &hhmm2hour( '21:26' );
  }
  elsif ( $GRIBFILE_MODEL eq 'RUCH' )
  {
    ###### SET MODEL-SPECIFIC GRIBGET PARAMETERS
    ### set max ftp time for grib get
    $getgrib_waitsec = 4 * 60 ;                # sleep time, _not_ a timeout time
    ### minimum grib filesize (smaller grib files are ignored)
    $mingribfilesize = 45000000;
    ### time for download of grib file (max so far 120+ mins)
    ### *NB* should match that used for curl in script gribftpget
    $gribgetftptimeoutmaxsec = 15 *60 ;
    ###### SET SCHEDULING GRIBGET PARAMETERS
    ### SET LGETGRIB=2 for scheduled get (1=LStests)
    if( $LGETGRIB>1)
      { $LGETGRIB = 2; }
    ### SET FILE AVAILABLITY SCHEDULE TIMES (Z)
    ### gribavailhrzoffset used to _add_ cushion to actual expected availabilty
    if( ! defined $gribavailhrzoffset )
    {
      $gribavailhrzoffset = $gribavailhrzoffset{RUCH}; 
    }
    ### gribavailhrzinc is hr increment per forecast hour
    $gribavailhrzinc = 12 / ( 12 * 60 );
    ### gribavailhrz0 is hour of analysis availability for each init.time
    ### NOTE THESE ARE ZULU VICE LOCAL TIME USED IN CRONTAB
    ### here zero time actually for appearance of 1sthr - hr0 appears 15mins earlier
    $gribavailhrz0{'00'} = &hhmm2hour( '01:31' );      
    $gribavailhrz0{'03'} = &hhmm2hour( '04:23' );      #est from previous/next values
    $gribavailhrz0{'06'} = &hhmm2hour( '07:16' );
    $gribavailhrz0{'09'} = &hhmm2hour( '10:23' );      #est from previous/next values      
    $gribavailhrz0{'12'} = &hhmm2hour( '13:31' );
    $gribavailhrz0{'15'} = &hhmm2hour( '16:23' );      #est from previous/next values      
    $gribavailhrz0{'18'} = &hhmm2hour( '19:16' );
    $gribavailhrz0{'21'} = &hhmm2hour( '22:23' );      #est from previous/next values      
  }
}
#####################################################################################################
#####################################################################################################
sub setup_ftp_parameters ()
### SET  FTP PARAMETERS
{
  #####################  START OF ETA FTP PARAMETER SETUP  ####################
  if ( $GRIBFILE_MODEL eq 'ETA' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    # $gribftpsite1 = 'ftpprd.ncep.noaa.gov';
    $gribftpsite1 = 'https://nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'ETA';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/nam/prod";
    ### at present only need single directory for eta since no "minus" times used
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
    #### IF PREVIOUS ("negative") DAY NEEDED, USE $gribftpdirectory[2]
  }
  elsif ( $GRIBFILE_MODEL eq 'GFSN' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    # $gribftpsite1 = 'ftpprd.ncep.noaa.gov';
    $gribftpsite1 = 'https://nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'GFS';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/gfs/prod";
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
    #### IF PREVIOUS ("negative") DAY NEEDED, USE $gribftpdirectory[2]
  }
  elsif ( $GRIBFILE_MODEL eq 'GFSA' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    # $gribftpsite1 = 'ftpprd.ncep.noaa.gov';
    $gribftpsite1 = 'https://nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'GFSA';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/gfs/prod";
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
  }
  elsif ( $GRIBFILE_MODEL eq 'AVN' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    #$gribftpsite1 = 'ftpprd.ncep.noaa.gov';
    $gribftpsite1 = 'https://nomads.ncep.noaa.gov';
    $gribftpsiteid1 = 'AVN';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "pub/data/nccf/com/gfs/prod";
    ### at present only need single directory for eta since no "minus" times used
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
    #### IF PREVIOUS ("negative") DAY NEEDED, USE $gribftpdirectory[2]
  }
  elsif ( $GRIBFILE_MODEL eq 'RUCH' )
  {
    ### $gribftpsite1,2 sets grib ftp site ($gribftpsite2=''=>no2ndSite)
    ### if change gribftpsite(s) also need changes below and in gribftpget
    ### *NB* FILENAMES MUST BE SAME AT ALTERNATE SITE $gribftpsite2
    $gribftpsite1 = 'gsdftp.fsl.noaa.gov';
    $gribftpsiteid1 = 'FSL';
    $gribftpsite2 = '';
    $gribftpsiteid2 = '';
    $gribftpdirectory0 = "13kmruc/maps_fcst20";
    ### at present only need single directory for eta since no "minus" times used
    #### NEVER NEED PREVIOUS ("negative") DAY SINCE ALL IN ONE DIRECTORY
    ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so now set $gribftpdirectory[1] in routine do_getgrib_selection
    ### even though FSL DIRECTORY STRUCTURE *DOESNT* DEPEND ON INITIALIZATION TIME, UNLIKE NWS 
    $gribftpdirectory[1] = "";
    $gribftpdirectory[2] = "";
    $gribftpdirectory[3] = "";
  }
  #####################  END OF FTP PARAMETER SETUP  ####################
}
#####################################################################################################
#####################################################################################################
sub do_aging ()
### "AGE" LATEST MAPS TO PREVIOUS DAY AND REMOVE FIRST,LAST MAPS
{
  ### AGE DEGRIB DIRS 
  $ivalidday = -1;
  foreach $dummyvalidday (@validdaylist)
  {
    ### need upper case for directory name 
    ### !!! need to isolate validday to avoid upper-case affecting @validdaylist !!!  PERL BUG !!!
    $validday = $dummyvalidday;
    $validday =~ tr/a-z/A-Z/;
    ### get previous valid day
    $ivalidday++;
    if( $ivalidday == 0 ) 
      {
         $newvalidday = "PREVIOUS.";
      }
    else
      { ( $newvalidday = $validdaylist[$ivalidday-1] ) =~ tr/a-z/A-Z/ ; }
    ### loop over valid.times 
    foreach $validtime (@blipmapvalidtimelist)
    {  
      ### move directory
      if ( -d "${DEGRIBBASEDIR}/${validday}${validtime}Z" )
      {
        `rm -fr ${DEGRIBBASEDIR}/${newvalidday}${validtime}Z ; mv ${DEGRIBBASEDIR}/${validday}${validtime}Z ${DEGRIBBASEDIR}/${newvalidday}${validtime}Z`;
print STDOUT "AGING DEGRIB SUBDIR ${validday}${validtime}Z TO ${newvalidday}${validtime}Z \n";
      }
    }
  }
  ### do this for all possible days
  my $dummy = 0;
  for ( $i=0; $i<=$#validdaylist; $i++ )
  {
    ### create "not available" PNG/TXT containing date though don't expect all to be needed
    if ( ${validdaylist[$i]} ne '' )
      {
      ### previousday blipspot for eta not used, but put in to keep parallelism with blipmap 
      jchomp( $availableout = `$UTILDIR/no_blipspot_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}} ; cd $OUTDIR ; mv -f no_blipspot_available.txt no_blipspot_available.${validdaylist[$i]}txt 2>/dev/null` );
      jchomp( $availableout = `$UTILDIR/no_blipmap_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}} ; cd $OUTDIR ; mv -f no_blipmap_available.png no_blipmap_available.${validdaylist[$i]}png 2>/dev/null` );
      }
     else
      {
      jchomp( $availableout = `$UTILDIR/no_blipspot_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}}` );
      jchomp( $availableout = `$UTILDIR/no_blipmap_available.pl $OUTDIR ${validdow{$validdaylist[$i]}} ${validdateprt{$validdaylist[$i]}}` );
      }
    ### create PNG containing month/day/dow
    jchomp( my $getdowpng = `cd $OUTDIR ; $UTILDIR/plt_chars.pl $validdow{${validdaylist[$i]}} ; mv -f plt_chars.png dow.${validdaylist[$i]}${dow_localid}.png  2>/dev/null` );
    jchomp( my $getmonpng = `cd $OUTDIR ; $UTILDIR/plt_chars.pl $validmon{${validdaylist[$i]}} ; mv -f plt_chars.png mon.${validdaylist[$i]}${mon_localid}.png  2>/dev/null` );
    jchomp( my $getda1png = `cd $OUTDIR ; $UTILDIR/plt_chars.pl $validda1{${validdaylist[$i]}} ; mv -f plt_chars.png day.${validdaylist[$i]}${day_localid}.png  2>/dev/null` );
  }
  foreach $regionkey (@REGION_DOLIST)
  {
    if( ! defined( $firstofday{$regionkey} ) )
    {
      $firstofday{$regionkey} = 1;
      ### must loop over all validation times, with ftp for each
      ### use timeout limit as once hung here
      `rm -f $OUTDIR/${regionkey}/blipmap.cp2previousday.out`;
      $ltimelimiterr = &timelimitexec ( $previousdayftptimeoutsec, "\$previousdayout = `cd $OUTDIR ; $UTILDIR/blipmap.cp2previousday $GRIBFILE_MODEL/$regionkey @validdaylist @{$blipmapvalidtimes{$regionkey}} >  ${regionkey}/blipmap.cp2previousday.out 2>&1`;" );
      if ( $ltimelimiterr ne '' )
      {
        &write_err( "*WARNING* $regionkey BLIPMAP PREVIOUS DAY TIMEOUT
          MIGHT HAVE HUNG FTP JOB - see printout ps list" );
        jchomp( $ftppslist = `ps -f -u $USERNAME | grep "ftp -n -i drjack.info" | grep -v 'grep'` ); 
        print $PRINTFH "          ftp2previousday FTP previousdayout= $previousdayout & PS LIST for job $$ = \n $ftppslist \n";
      }
      if ( $previousdayout ne "" ) 
      {
        &write_err( " *** ERROR: $program BLIPMAP PREVIOUS DAY FTP for $regionkey
        previousdayout= $previousdayout" );
      } 
      if ($LPRINT>1) {print $PRINTFH ("CLEARED BLIPMAPs, created previous day files for $regionkey\n");}
    }
  }    
}
#####################################################################################################
#####################################################################################################
sub do_getgrib_selection ()
### GET GRIB ALA LGETGRIB
{
  ### set initial gribftpsite to avoid error if lgetgrib=0
  $gribftpsite = '';
  $gribftpsiteid = $GRIBFILE_MODEL . '-noftp';
  ### START OF IF FOR LGETGRIB>1
  if( $LGETGRIB > 1 )
  {
    ### START OF LGETGRIB=2 FILE DETERMINATION SECTION (using scheduled times)
    if( $LGETGRIB == 2 )
    {
      ### AT PRESENT ONLY USE FIRST FTP STIE FOR SCHEDULED ACCESS
      $gribftpsite = $gribftpsite1;
      $gribftpsiteid = $gribftpsiteid1;
      ### can't know gribfilesize at this point
      $remotegribfilesize = '';
      ### SET PRESENT HOUR TO MATCH TO AVAILABILTY HOUR
      $zhhmm = `date -u +%H:%M` ; jchomp $zhhmm;
      $zhour = &hhmm2hour( $zhhmm );
      ### allow model to run into following zulu day
      $zjday = `date -u +%j` ; jchomp($zjday);
      if ( $zjday > $julianday )
      { $zhour = $zhour + 24 };
      if ( $filename ne '' ) {$lastcyclesleep = 0; }
      else                   {$lastcyclesleep = 1; }
      $filename = '';
      $last_available_grib = '';
      $lalldone = 1;
      ### START OF LOOP OVER POSSIBLE ATTEMPTS
### SCHEDULED GRIBGET FILESTATUS MEANINGS
      for ( $iattempt=1; $iattempt<=$max_schedgrib_attempts; $iattempt++ )
      {
        $ifiledolistindex = -1; 
        FILESEARCH: foreach $file (@filenamedolist)
        {
           ### FILE is grib filename
           ### IFILE is file index string (eg 21Z+6) in filedolist
           $ifiledolistindex = $ifiledolistindex + 1; 
           $ifile = $filedolist[$ifiledolistindex];
           ### if this filestatus too high for this attempt loop, skip it
           if ( $filestatus{$ifile} <= $max_schedgrib_attempts )
             { $lalldone = 0 ; }
           if ( $filestatus{$ifile} > ($iattempt-1) )
             { next FILESEARCH; }
           ### START OF NEW SKIP OF OLDER VALID TIME CASE
           ### don't process fcst time if shorter term one already done for this valid time
           ### dont skip for test mode since normal ordering then gives mostly skips!
           ### changed to fileextendedvalidtime for eta
           if ( $filefcsttimes{$ifile} > $latestfcsttime[$fileextendedvalidtimes{$ifile}] && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
           {
             if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER FILESEARCH $ifile - previous $filevalidtimes{$ifile}Z validation time (extended=${fileextendedvalidtimes{$ifile}}) had shorter fcst time = $latestfcsttime[$fileextendedvalidtime]\n" );}
             ### setting this status will caused file to be ignored later
             $filestatus{$ifile} = $status_skipped; 
             $oldtimescount++;
             next FILESEARCH;
           }
           ### END OF NEW SKIP OF OLDER VALID TIME CASE
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
           ### DON'T PROCESS IF PREVIOUSLY STARTED FTP FOR SAME VALID TIME HAS SHORTER FCST TIME
           ### (this allows a restart at "non-normal" times without creating unneccessary ftps of longer forecast period files)
           if ( defined $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} && $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} < $filefcsttimes{$ifile} && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
           {
             if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER START FILESEARCH $ifile - previously started $filevaliddays{$ifile} $filevalidtimes{$ifile}Z validation time had shorter fcst time = $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}}\n" );}
             ### setting this status will caused file to be ignored later
             $filestatus{$ifile} = $status_skipped; 
             $oldtimescount++;
             next FILESEARCH;
           }
           ### if reach this point, there must be more files needing processing
           $lalldone = 0;
           ### IF HR>AVAIL SET STATUS
           if ( $iattempt==1 && $gribavailhrz{$ifile} < $zhour )
           {
             $filestatus{$ifile} = 0; 
             ### append to file for later examination of "first available" times
             $gribavailhhmm = &hour2hhmm( $gribavailhrz{$ifile} ) ;
            `echo "--- $rundayprt $cycletime - GETGRIB first scheduled for ${gribavailhhmm}Z" >> ${GRIBFILE_MODELDIR}/LOG/gribftpget.notavailable.${ifile}`;
           }
           ### IF THIS FILE AVAILABLE, EXIT LOOP WITH FILENAME
           if ( $filestatus{$ifile} == ($iattempt-1) )
           {
             if ( $LPRINT>1 && $lastcyclesleep == 0 ) {printf $PRINTFH ("SCHEDULED GETGRIB: %d trialfile = %7s (%d) => %s %s\n",$iattempt,$ifile,$filestatus{$ifile},$gribftpdirectory[$filenamedirectoryno{$ifile}],$file);}
             $filename = $file;
             ### PARTIAL SPECIFICATION OF MODEL GRIB FILENAME HERE
             ### **NB** NWS DIRECTORY STRUCTURE DEPENDS ON INITIALIZATION TIME so must set $gribftpdirectory[1] in routine do_getgrib_selection
             ### DAY/HR SELECTION - this depends upon analysis (initialization) time of file
             ###  ASSUMES THAT WILL NEVER ASK FOR FILE WITH INIT(ANAL) TIME BEYOND CURRENT JULIAN DAY !
             ###  if not, add test based on day of init(anal) time
             if ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
             {     
               $gribftpdirectory[1] = sprintf 'MT.nam_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4,$jmo2,$jda2);
               $gribftpdirectory[2] = sprintf 'MT.nam_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4m1,$jmo2m1,$jda2m1);
               $gribftpdirectory[3] = sprintf 'MT.nam_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4p1,$jmo2p1,$jda2p1);
             }
             elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' )
             {
               $gribftpdirectory[1] = sprintf 'MT.gfs_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4,$jmo2,$jda2);
               $gribftpdirectory[2] = sprintf 'MT.gfs_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4m1,$jmo2m1,$jda2m1);
               $gribftpdirectory[3] = sprintf 'MT.gfs_CY.%02d/RD.%04d%02d%02d/PT.grid_DF.gr1',($fileanaltimes{$ifile},$jyr4p1,$jmo2p1,$jda2p1);
             }
             elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' )
             {
               print $PRINTFH "ERROR EXIT: Limited Area GFSA grib file available only on NCEP server\n"; 
               exit 1;
             }
             elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' )
             {
               print $PRINTFH "ERROR EXIT: truncated AVN grib file available only on NCEP server\n"; 
               exit 1;
             }
             elsif ( $gribftpsite eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'RUCH' )
             {
               $gribftpdirectory[1] = "";
               $gribftpdirectory[2] = "";
               $gribftpdirectory[3] = "";
             }
             elsif ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' )
             {     
               $gribftpdirectory[1] = sprintf 'nam.%04d%02d%02d',$jyr4,$jmo2,$jda2;
               $gribftpdirectory[2] = sprintf 'nam.%04d%02d%02d',$jyr4m1,$jmo2m1,$jda2m1;
               $gribftpdirectory[3] = sprintf 'nam.%04d%02d%02d',$jyr4p1,$jmo2p1,$jda2p1;
             }
             elsif ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' || $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' ||  $gribftpsite eq 'http://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' )
             {
               $gribftpdirectory[1] = sprintf 'gfs.%04d%02d%02d/%02d',$jyr4,$jmo2,$jda2,$fileanaltimes{$ifile};
               $gribftpdirectory[0] = sprintf 'gfs.%04d%02d%02d/%02d',$jyr4m1,$jmo2m1,$jda2m1,$fileanaltimes{$ifile};
               $gribftpdirectory[2] = sprintf 'gfs.%04d%02d%02d/%02d',$jyr4p1,$jmo2p1,$jda2p1,$fileanaltimes{$ifile};
             }
             $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
             $filename{$ifile} = $file;
             $filenamedirectory{$ifile} = $gribftpdirectory[$filenamedirectoryno{$ifile}];
             ### increment filestatus so indicates number of attempts
             $filestatus{$ifile}++ ;
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
             $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} = $filefcsttimes{$ifile} ;
             $last_available_grib = $file;
             goto GETTHISGRIBFILE;
           }
        }  
      } 
      ### END OF LOOP OVER POSSIBLE ATTEMPTS
    }
    ### END OF LGETGRIB=2 FILE DETERMINATION SECTION
    ### START OF LGETGRIB=1 FILE DETERMINATION SECTION (using ls files)
    elsif( $LGETGRIB == 3 )
    {
       ### CREATE FTP LS LIST
       ### use subroutine to ftp ls list - with timeout enabled to recover from hung ftp
       ### FIRST TRY FIRST FTP STIE
       $gribftpsite = $gribftpsite1;
       $gribftpsiteid = $gribftpsiteid1;
       `rm -f $LSOUTFILE1`;
       `rm -f $LSOUTFILE2`;
       `rm -f $LSOUTFILEERR`;
   ### RHES3.0 PERL 5.8.0 timeout failure here seems to produce additional LFs thereafter (due to eval's in routine?)
        $ltimelimiterr = &timelimitexec ( $lsgetftptimeoutsec, '&gribftpls( $gribftpsite, $gribftpdirectory0, $gribftpdirectory[1], $gribftpdirectory[2] );' );
       ### errout messages: "Connection timed out" "Unknown Host"
       ### stdout messages: "Not connected"
       ### below combines parts of above 3 messages
       jchomp( $lconnecterr = `grep -c '[oUuNn][nno][ kt][tn ][ioc][mwo][enn][d n][ Hhe][ooc][ust][tte]' $LSOUTFILEERR` );
       ### test that lsoutfile1 was produced
       $lsoutfilesize = -s $LSOUTFILE1 ;
       if ( ! defined $lsoutfilesize ) { $lsoutfilesize = -1; }
       ### treat ftp failure condition
       if ( $ltimelimiterr ne '' || $lconnecterr > 0 || $lsoutfilesize <= 0 )
       {
         print $PRINTFH "FTP1 LS FAILURE:  $ltimelimiterr $lconnecterr $lsoutfilesize to $gribftpsite1\n";
         jchomp( $ftppslist = `ps -f -u $USERNAME | grep "ftp -i -n $gribftpsite" | grep -v 'grep'` ); 
         if ( $ftppslist ne '' )
         {
           print $PRINTFH "                  PS LIST= \n $ftppslist \n";
           jchomp( $runningps=`echo "$ftppslist" | sort -n | sed -n 1p` );
           $runningpid = substr( $runningps, 8,6 );
           jchomp( my $killout=`(kill -9 $runningpid 2>&1) 2>&1` );
           print $PRINTFH "     Job $$ killed $runningps $killout\n";
         }
         if ( $gribftpsite2 ne '' )
         {
           if ($LPRINT>1) { print $PRINTFH ("TRY FTP#2 to $gribftpsite2\n"); }
           `rm -f $LSOUTFILE1`;
           `rm -f $LSOUTFILE2`;
           `rm -f $LSOUTFILEERR`;
           $gribftpsite = $gribftpsite2;
           $gribftpsiteid = $gribftpsiteid2;
           $ltimelimiterr = &timelimitexec ( $lsgetftptimeoutsec, '&gribftpls($gribftpsite, $gribftpdirectory0, $gribftpdirectory[1], $gribftpdirectory[2]);' );
           jchomp( $lconnecterr = `grep -c '[oUuNn][nno][ kt][tn ][ioc][mwo][enn][d n][ Hhe][ooc][ust][tte]' $LSOUTFILEERR` );
           ### test that lsoutfile1 was produced
           $lsoutfilesize = -s $LSOUTFILE1 ;
           if ( ! defined $lsoutfilesize ) { $lsoutfilesize = -1; }
           ### treat ftp failure condition
           if ( $lconnecterr > 0 || $ltimelimiterr ne '' || $lsoutfilesize <= 0 )
           {
             print $PRINTFH "FTP#2 LS FAILURE:  $ltimelimiterr $lconnecterr $lsoutfilesize to $gribftpsite1\n";
             jchomp( $ftppslist = `ps -f -u $USERNAME | grep "ftp -i -n $gribftpsite" | grep -v 'grep'` ); 
             if ( $ftppslist ne '' )
             {
               print $PRINTFH "                  PS LIST= \n $ftppslist \n";
               jchomp( $runningps=`echo "$ftppslist" | sort -n | sed -n 1p` );
               $runningpid = substr( $runningps, 8,6 );
               jchomp( my $killout=`(kill -9 $runningpid 2>&1) 2>&1` );
               print $PRINTFH "     Job $$ killed $runningps $killout\n";
             }
             print $PRINTFH "MUST START NEW CYCLE due to ftp failures - SLEEP $cycle_waitsec sec\n";
             ### sleep to prevent immediate re-cycle 
             sleep $cycle_waitsec;
             $totsleepsec += $cycle_waitsec;
             goto STRANGE_CYCLE_END;
           }
         }
         else
         {      
            ### sleep to prevent immediate re-cycle 
             print $PRINTFH "START NEW CYCLE AFTER SLEEP $cycle_waitsec sec\n";
             sleep $cycle_waitsec;
             $totsleepsec += $cycle_waitsec;
             goto STRANGE_CYCLE_END;
         }
         `echo "$startdate $cycletime  $gribftpsite LS_FTP1_FAILURE $lconnecterr $ltimelimiterr $lsoutfilesize" >> $RUNDIR/LOG/ftp1.log`;
           print $PRINTFH "MUST START NEW CYCLE due to ftp failure \n";
       }
       else
       {
         `echo "$startdate $cycletime  $gribftpsite LS_FTP1_OK" >> "$RUNDIR/LOG/ftp1.log"`;
       }
       if (! defined( $lsoutstdout ) )
       {
          ### sleep to prevent immediate re-cycle 
          print $PRINTFH "MISSING LSOUTSTDOUT - CONTINUE AFTER SLEEP OF $cycle_waitsec sec\n";
          sleep $cycle_waitsec;
          $totsleepsec += $cycle_waitsec;
          goto STRANGE_CYCLE_END;
       }
       ### GET LS OUTPUT
       jchomp( $lsout1 = `cat $LSOUTFILE1` );
       @lslist1 = split( /\n/, $lsout1 );
       if( $gribftpdirectory[2] ne '' && -s $LSOUTFILE2 )
         {
         jchomp( $lsout2 = `cat $LSOUTFILE2` );
         @lslist2 = split( /\n/, $lsout2 );
         }
       ### search for an available unprocessed filename
       $ifiledolistindex = -1; 
       if ( $filename ne '' ) {$lastcyclesleep = 0; }
       else                   {$lastcyclesleep = 1; }
       FILESEARCH: foreach $file (@filenamedolist)
       {
          ### FILE is grib filename
          ### IFILE is file index string (eg 21Z+6) in filedolist
          $ifiledolistindex = $ifiledolistindex + 1; 
          $ifile = $filedolist[$ifiledolistindex];
          if ( $filestatus{$ifile} < 1 )
          {
            ### START OF NEW SKIP OF OLDER VALID TIME CASE
            ### don't process fcst time if shorter term one already done for this valid time
            ### dont skip for test mode since normal ordering then gives mostly skips!
            ### changed to fileextendedvalidtime for eta
            if ( $filefcsttimes{$ifile} > $latestfcsttime[$fileextendedvalidtimes{$ifile}] && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
            {
              if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER $file - previous $filevalidtimes{$ifile}Z validation time (extended=${fileextendedvalidtimes{$ifile}}) had shorter fcst time = $latestfcsttime[$fileextendedvalidtime]\n" );}
              ### set successfultimeend id
              $oldtimescount++;
              ### setting this status will caused file to be ignored later
              $filestatus{$ifile} = $status_skipped; 
              next FILESEARCH;
            }
            ### END OF NEW SKIP OF OLDER VALID TIME CASE
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
           ### DON'T PROCESS IF PREVIOUSLY STARTED FTP FOR SAME VALID TIME HAS SHORTER FCST TIME
           ### (this allows a restart at "non-normal" times without creating unneccessary ftps of longer forecast period files)
           if ( defined $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} && $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} < $filefcsttimes{$ifile} && $RUNTYPE ne " " && $RUNTYPE ne '-t' && $RUNTYPE ne '-T' )
           {
             if ($LPRINT>1) {print $PRINTFH ("SKIP OLDER START FILESEARCH $ifile - previously started $filevaliddays{$ifile} $filevalidtimes{$ifile}Z validation time had shorter fcst time = $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}}\n" );}
             ### setting this status will caused file to be ignored later
             $filestatus{$ifile} = $status_skipped; 
             $oldtimescount++;
             next FILESEARCH;
           }
            ### if reach this point, there must be more files needing processing
            $lalldone = 0;
            if ( $LPRINT>1 && $lastcyclesleep == 0 ) {printf $PRINTFH ("FTP-LS GETGRIB: trial file = %7s (%d) => %s %s\n",$ifile,$filestatus{$ifile},$gribftpdirectory[$filenamedirectoryno{$ifile}],$file);}
            ### choose correct directory
            if ( $ifile =~ /^ *-/ ||  $gribftpdirectory[2] eq '' )
              { @lslist = @lslist1; }
            else
              { @lslist = @lslist2; }
            for ( $ii=0; $ii <= $#lslist; $ii++ )
            {
              ### added filesize test to avoid getting truncated files
              if ( $lslist[$ii] =~ m/$file/  )
              {
                if( $gribftpsite eq 'gsdftp.fsl.noaa.gov' || $gribftpsite eq 'eftp.fsl.noaa.gov' )
                  { $remotegribfilesize = (split(/  */,$lslist[$ii],6))[4]; }
                elsif( $gribftpsite eq 'https://nomads.ncep.noaa.gov' )
                  {
                    $remotegribfilesize = (split(/  */,$lslist[$ii],6))[4];
                  }
                elsif( $gribftpsite eq 'narf.fsl.noaa.gov' )
                  { $remotegribfilesize = (split(/  */,$lslist[$ii],6))[3]; }
                else
                  { print $PRINTFH "BAD gribftpsite= $gribftpsite \n"; exit 1; }
                if ( defined $remotegribfilesize )  
                {
                  if ( $remotegribfilesize >= $mingribfilesize )  
                  {
                    ### not-yet-proceessed file found
                    $filename = $file ;
                    $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
                    $filestatus{$ifile} = 1 ;
                    $filename{$ifile} = $file;
                    $filenamedirectory{$ifile} = $gribftpdirectory[$filenamedirectoryno{$ifile}];
### TO ALLOW MID-DAY RESTART WITH FTP-PARALLEL
                    $lateststartfcsttime{$filevaliddays{$ifile}}{$filevalidtimes{$ifile}} = $filefcsttimes{$ifile} ;
                    last FILESEARCH; 
                  }
                  else
                  {
                  if ( $LPRINT>1 && $lastcyclesleep == 0 ) {print $PRINTFH ("      ( grib file too small: $remotegribfilesize < $mingribfilesize )\n");}
                  }
                }
                else
                {
                  $remotegribfilesize = '';
                }
              }
            }
          }      
          $filename = '';
       }  
    }
    ### END OF LGETGRIB=3 FILE DETERMINATION SECTION 
    GETTHISGRIBFILE:
    ### TREAT NO FILENAME CASES => processing done or no available file
    if ( $lalldone == 1 )
    {
      ###  file processing done
      print $PRINTFH ("PRE-CALC CYCLE EXIT: FILE SELECTION FINDS ALL FILES PROCESSED\n");    
      &final_processing;
    }
    elsif ( $filename eq '' )
    { 
      ###  SLEEP then continue cycle loop
      print $PRINTFH "   PAUSE CYCLE LOOP FOR $cycle_waitsec sec\n";
      sleep $cycle_waitsec;
      $totsleepsec += $cycle_waitsec;
      goto NEWGRIBTEST;
    }
  ### END OF IF FOR LGETGRIB>1
  }
  ### TREAT GRIB FILE INPUT CASE
  elsif ( $LGETGRIB == -1 )
  {
    ### TREAT GRIB FILE INPUT CASE
    $filename = $specifiedfilename ;
    ### extract ifile from grib file name
    ### for NWS ETA filename
    if ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m|fh.(00[0-9][0-9])_tl.press_gr.awip3d$| )
    {
      ### set initialization time since not apparent from filename
      if    ( $1==18 || $1==21 || $1==42 || $1==45 || $1==66 || $1==69 )
        { $ifile = "0Z+${1}"; }
      elsif ( $1==12 || $1==15 || $1==36 || $1==39 || $1==60 || $1==63 )
        { $ifile = "6Z+${1}"; }
      elsif ( $1==6  || $1==9  || $1==30 || $1==33 || $1==54 || $1==57 )
        { $ifile = "12Z+${1}"; }
      elsif ( $1==24 || $1==27 || $1==48 || $1==51 || $1==72 || $1==75 )
        { $ifile = "18Z+${1}" }
      else
        { $ifile = "99Z+${1}"; }
    }
    ### for NWS GFS filename
    elsif ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m|fh.(00[0-9][0-9])_tl.press_gr.onedeg$| )
    {
      ### set initialization time since not apparent from filename
      if    ( $1==18 || $1==21 || $1==42 || $1==45 || $1==66 || $1==69 )
        { $ifile = "0Z+${1}"; }
      elsif ( $1==12 || $1==15 || $1==36 || $1==39 || $1==60 || $1==63 )
        { $ifile = "6Z+${1}"; }
      elsif ( $1==6  || $1==9  || $1==30 || $1==33 || $1==54 || $1==57 )
        { $ifile = "12Z+${1}"; }
      elsif ( $1==24 || $1==27 || $1==48 || $1==51 || $1==72 || $1==75 )
        { $ifile = "18Z+${1}" }
      else
        { $ifile = "99Z+${1}"; }
    }
   ### for FSL filename
    elsif ( $gribftpsite eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'RUCH' && $filename =~ m|^0....([0-9][0-9])....([0-9][0-9])\.grib$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m|^nam\.t([0-9][0-9])z\.awip3d([0-9][0-9])\.tm00.grib2$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' && $filename =~ m|^gfs\.t([0-9][0-9])z\.pgrb2f([0-9][0-9])$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' && $filename =~ m|^gfs\.t([0-9][0-9])z\.pgrbf([0-9][0-9])$| )
    {
      $ifile = "${1}Z+${2}";
    }
   ### for NCEP filename
    elsif ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m|^gfs\.t([0-9][0-9])z\.pgrbf([0-9][0-9])$| )
    {
      $ifile = "${1}Z+${2}";
    }
    else
    {
      print $PRINTFH (" LGETGRIB=-1 CYCLE EXIT: ifile not extracted \n");    
      &final_processing;
    }
    $ifile =~ s/^0([0-9])/$1/;
    $ifile =~ s/\+0/+/;
    ### test for valid ifile
    ($ifilegreptest = $ifile ) =~ s/\+/\\\+/g;
    if(  grep ( m/^${ifilegreptest}$/, @filedolist ) == 0 )
      {
      print $PRINTFH (" LGETGRIB=-1 CYCLE EXIT: invalid ifile = $ifile \n");    
      &final_processing;
      }
    ### test for file existence
    if( ! -f "${GRIBDIR}/${filename}" )
      {
      print $PRINTFH (" LGETGRIB=-1 CYCLE EXIT: specified grib file $filename NOT FOUND\n");    
      &final_processing;
      }
    $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
    print $PRINTFH ("*EXISTING*GRIB*FILE* run with *NO*GETGRIB*\n");
    push @childftplist, $ifile;
    $filename{$ifile} = $filename;
    $filenamedirectory{$ifile} = '*EXISTING*GRIB*';
  }
  else
  {
    ### TREAT CASE WITHOUT GET-GRIB
    $filename = $filenamedolist[$icycle-1];
    $ifile = $filedolist[$icycle-1]; 
    if( ! defined($ifile) )
      {
      print $PRINTFH (" LGETGRIB=0 CYCLE EXIT: undefined ifile \n");    
      &final_processing;
      }
    $filenamedirectory = $gribftpdirectory[$filenamedirectoryno{$ifile}];
    ### i dont understand logic behind following and interferes with xi test runs so hvae commented this out
    print $PRINTFH ("*TEST*MODE* run with *NO*GETGRIB*\n");
    push @childftplist, $ifile;
    $filename{$ifile} = $filename;
    $filenamedirectory{$ifile} = '*NO*GETGRIB*';
  }
}
#################################################################################################
#################################################################################################
sub signal_endcycle()
####### INTERRUPT (Ctrl-C) WILL END CYCLE AND SKIP TO END PROCESSING #######
### MAKE SURE TO SEND "kill -2" TO PERL SCRIPT NOT TO SHELL ! 
{ 
  print "CYCLE TERMINATED by SIGNAL 2 (Ctrl-C)\n";
  if ($LPRINT>1) { print $PRINTFH "CYCLE TERMINATED by SIGNAL 2 (Ctrl-C)\n";}
  &final_processing;
}
#########################################################################
#########################################################################
sub final_processing ()
### FINALPROCESSING put into subroutine so can use with interrput signal
{
  print $PRINTFH "FINALPROCESSING-TESTING finalprocessing0 $LSAVE \n";
  ### CLOSE THREAD TIME SUMMARY FILES
  foreach $regionkey (@REGION_DOLIST)
  {    
    if ( defined $SUMMARYFH{$regionkey} )
    {
      close  ( $SUMMARYFH{$regionkey} ) ;
    }    
  }
  ### KILL ANY EXISTING CHILD MODEL RUN PROCESSES
  foreach $childrunmodelpid (@childrunmodellist)
  {
    ### value of -1 indicates that child already exited
    if(  $childrunmodelpid > 0 )
    {
      my $killout = &kill_pstree( $childrunmodelpid );
      if ($LPRINT>1) { print $PRINTFH ("FINAL PROCESSING KILL OF CHILD RUNMODEL PS TREE: $childrunmodelpid => $killout \n"); }
    }
  }
  foreach $ifile (@childftplist)
  {
    $childftppid = $childftppid{$ifile};
    my $killout = &kill_pstree( $childftppid );
    if ($LPRINT>1) { print $PRINTFH ("FINAL PROCESSING KILL OF CHILD gribftpget PS TREE: $childftppid => $killout \n"); }
  }
  ### KILL EXISTING wrf.exe PROCESSES with argument $JOBARG
  jchomp( $wrfexejobpids = `ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID}" | grep "$USERNAME .*wrf.exe ${JOBARG}:" | tr -s ' ' | cut -f2 -d' ' | tr '\n' ' '` );
  if ( $wrfexejobpids !~ m|^\s*$| )
  {
    if ($LPRINT>1) { print $PRINTFH "*** !!! FINAL PROCESSING KILL OF RUNNING wrf.exe $JOBARG PROCESSES: $wrfexejobpids \n"; }
    ### send stderr to stdout as once tried to kill non-existent job
    jchomp( my $killout = `kill -9 $wrfexejobpids 2>&1` );
  }
  if ( $#childrunmodellist > -1 || $#childftplist > -1 ) { sleep 30; }
  ### MAKE DOUBLY SURE THAT ANY LEFT-OVER CURL JOBS ARE KILLED
  ### be sure to eliminate present job !
  jchomp( $previousjobpids = `ps -f -u $USERNAME | grep -v 'grep' | grep -v "$USERNAME  *${PID}" | grep "$USERNAME .* curl .*${JOBARG}" | tr -s ' ' | cut -f2 -d' ' | tr '\n' ' '` );
  if ( $previousjobpids !~ m|^\s*$| )
  {
    if ($LPRINT>1) { print $PRINTFH "*** !!! UNEXPECTED CURL PROCESSES FOUND SO WILL BE KILLED !!!  PID= $previousjobpids \n"; }
    ### send stderr to stdout as once tried to kill non-existent job
    jchomp( my $killout = `kill -9 $previousjobpids 2>&1` );
  }
  $time = `date +%H:%M:%S` ; jchomp($time);
  #####  PRINT UNANALYZED TIMES
  if ( $lalldone==0 && $LPRINT>1 )
  {
    print $PRINTFH ("UN-PROCESSED TIMES AT FINAL PROCESSING:\n");
    $ifiledolistindex = -1; 
    foreach $file (@filenamedolist)
    {
      ### ifile is file index number in filedolist
      $ifiledolistindex = $ifiledolistindex + 1; 
      $ifile = $filedolist[$ifiledolistindex];
      if ( $filestatus{$ifile} < $status_problem )
      {
        print $PRINTFH ("    $ifile \n");
      }      
    }      
    print $PRINTFH ("PROCESSED BUT UNSUCCESFUL TIMES AT FINAL PROCESSING:\n");
    $ifiledolistindex = -1; 
    foreach $file (@filenamedolist)
    {
      ### ifile is file index number in filedolist
      $ifiledolistindex = $ifiledolistindex + 1; 
      $ifile = $filedolist[$ifiledolistindex];
      if ( $filestatus{$ifile} >= $status_problem && $filestatus{$ifile} < $status_skipped )
      {
        print $PRINTFH ("    $ifile \n");
      }      
    }      
  }      
  ### GET SCRIPT END TIME
  # $endtime = `date +%H:%M` ; jchomp($endtime);
  $endtime = `date +%F_%R:%S` ; jchomp($endtime);
  $elapsed_runhrs = sprintf("%4.1f",$elapsed_runhrs);
  if ($LPRINT>1) {print $PRINTFH "$endtime : END $program for $JOBARG & ${RUNTYPE} on $rundayprt : process $$ (runhr=${elapsed_runhrs}/${cycle_max_runhrs} cycle=${icycle}/${cycle_max} files=${foundfilecount}/${dofilecount})\n";}
  exit;
}
#########################################################################
#########################################################################
sub gribftpls ()
### subroutine gribftpls - gets ls info from server
### $FTPDIRECTORY2 is optional
{
  my ($FTPSITE,$FTPDIRECTORY0,$FTPDIRECTORY1,$FTPDIRECTORY2) = @_;
  ### SET LSFTPMETHOD
  ### curl uses timeout to prevent unkilled ftp processes, can also be verbose
  ###      (and might later use other features, such as filename-only-list, macros, etc)
  my $LSFTPMETHOD = 'CURL';
  my ( $ID );
  if ( $FTPSITE eq 'https://nomads.ncep.noaa.gov' )
  {
    $ID = "anonymous $ADMIN_EMAIL_ADDRESS";
  }
  elsif ( $FTPSITE eq 'https://nomads.ncep.noaa.gov' )
  {
    $ID = "anonymous $ADMIN_EMAIL_ADDRESS";
  }
  elsif ( $FTPSITE eq 'gsdftp.fsl.noaa.gov' )
  {
    $ID = 'ftp glendening@drjack.net';
  }
  else
  { print $PRINTFH "*** ERROR EXIT in gribftpls: UNKNOWN SITE= $FTPSITE\n"; exit 1; }
  ### USE DIFFERENT CODE FOR DIFFERENT NO OF ARGUMENTS
  ### ASSUME FIRST FOR RUC AND 2ND FOR ETA
  if( $FTPDIRECTORY2 eq '' ) 
  {
  ### LS OF SINGLE DIRECTORIES TREATED HERE
    if( $LSFTPMETHOD eq 'FTP' )
    {
      jchomp( $lsoutstdout = `( 
      echo "user $ID";
    echo "debug";
      echo "ascii";
      echo "cd $FTPDIRECTORY0";
      echo "ls $FTPDIRECTORY1 $LSOUTFILE1";
      echo "bye";
      ) | ftp -i -n $FTPSITE  2> $LSOUTFILEERR` ); 
      ### NB ### NEED DIFFERENT FILESIZE STATEMENTS FOR narf VS spur !!! !!!
    }
    elsif( $LSFTPMETHOD eq 'CURL' )
    {
      $ID =~ s/ /:/; 
      jchomp( $lsoutstdout = `curl -v -s --user $ID --max-time $lsgetftptimeoutsec --disable-epsv -o $LSOUTFILE1 "ftp://${FTPSITE}/${FTPDIRECTORY0}/${FTPDIRECTORY1}/" 2>$LSOUTFILEERR`);
    }
  }
  else
  {
  ### LS OF TWO DIRECTORIES TREATED HERE
    if( $LSFTPMETHOD eq 'FTP' )
    {
      jchomp( $lsoutstdout = `( 
      echo "user $ID";
    echo "debug";
      echo "ascii";
      echo "cd $FTPDIRECTORY0";
      ### ASSUME THIS IS FOR ETA - ls on filename to eliminate unwanted files
      echo "ls $FTPDIRECTORY1 $LSOUTFILE1";
      echo "ls $FTPDIRECTORY2 $LSOUTFILE2";
      echo "bye";
      ) | ftp -i -n $FTPSITE  2> $LSOUTFILEERR` ); 
    }
    elsif( $LSFTPMETHOD eq 'CURL' )
    {
      $ID =~ s/ /:/; 
      ### connect only once, listing 2 directorys to 2 different files - so must rename them afterward
      jchomp( $lsoutstdout = `curl -v -s --user $ID --max-time $lsgetftptimeoutsec --disable-epsv -o "$GRIBFILE_MODELDIR/LOG/gribftpls.#1.list" "ftp://${FTPSITE}/${FTPDIRECTORY0}/{${FTPDIRECTORY1},${FTPDIRECTORY2}}/" 2>$LSOUTFILEERR`);
      `mv -f $GRIBFILE_MODELDIR/LOG/gribftpls.${FTPDIRECTORY1}.list $LSOUTFILE1 2>/dev/null ; mv -f $GRIBFILE_MODELDIR/LOG/gribftpls.${FTPDIRECTORY2}.list $LSOUTFILE2 2>/dev/null`
    }
  }
}
#########################################################################
#########################################################################
sub write_err ()
### write line to printout and also to stderr if printout is to file
{
  my $line = shift @_;
  print $PRINTFH ("$line \n");
  if ( $PRINTFH eq 'FILEPRINT' )
  { print STDERR ("$line \n"); }
}
#########################################################################
#########################################################################
sub strip_leading_zero ()
### subroutine strip_leading_zero
{
  my $string = shift @_;
  my $value;
  if ( substr( $string, 0,1 ) == 0 )
    { $value = substr( $string, 1); }
  else
    { $value = $string; }
  return $value;
}
#########################################################################
#########################################################################
sub repeating_printf ()  
### prints arrays with $nrepeats values per line using printf
### such that partial lines dont give "uninitialized value" message
###    more perl shit !!!
### $formatarg = format repeated to output entire array
### $nrepeats = no. of values printed per line
### @a = array to be printed
### $FH = filehandle
{
  ### initialization
  my ( $FH,$formatarg,$nrepeats, @a ) = @_;
  my ( $nvalues,$index,$index1,$index2,$i );
  $nvalues = $#a + 1;
  $index1 = 0;
  $format = '';
  ### first do setup
  if ( $nvalues < $nrepeats )
    ### treat case of less than $nrepeats array values 
    {
    $index2 = $#a;
    }
  else
    ### create format for normal "full" line
    { 
      for ($i=1; $i <= $nrepeats; $i++)
      {
        $format = "$format$formatarg";
      }
      $index2 = $nrepeats - 1;
    }
  ### now do printing
  while ( defined($a[$index1]) )
  {
    if ( $index2 < $#a )
    {
      ### print most lines here with $nrepeats values per line
      printf $FH "$format\n", @a[ $index1 .. $index2 ];
      $index2 = $index2 + $nrepeats;
    }
    else
   {
      ### print any final "partial" line here (and final "full" line if exact)
      $format = '';
      for ($index=$index1; $index <= $#a; $index++)
      {
        $format = "$format$formatarg";
      }
      printf $FH "$format\n", @a[ $index1 .. $#a ];
   }
    $index1 = $index1 + $nrepeats;
  }
}
#########################################################################
#########################################################################
sub hmstimediff ()
### TIMEDIFF compute difference between times ($starttime,$endtime)
### where $start,$end have format "hh:mm:ss" or "hh:mm"
### output difference given in choice of hrs/mins/secs
{
  my ( $starttime, $endtime ) = @_;
  ($hr1,$min1,$sec1) = split( /:/,$starttime );
  ($hr2,$min2,$sec2) = split( /:/,$endtime );
  ### allow hh:mm also
  if ( ! defined $sec1 ) { $sec1 = 0 ; }
  if ( ! defined $sec2 ) { $sec2 = 0 ; }
  $secs = int( 3600 * ( $hr2 - $hr1 ) + 60 * ( $min2 - $min1 ) + ( $sec2 - $sec1 ) );
  if ( $secs < 0 ) { $secs = $secs + 24*3600; }
  $mins = sprintf( "%5.1f",($secs/60) );
  $hrs = sprintf( "%5.1f",($secs/3600) );
  return $hrs,$mins,$secs;
}
#########################################################################
#########################################################################
### inverse sine
### inverse cosine
#########################################################################
#########################################################################
sub timelimitexec ()
### PUT TIME LIMIT ON SERIES OF COMMANDS
### RHES3.0 PERL 5.8.0 - extra lfs appear to result from one of these eval's when FTP1 message triggered
{   
  my ( $timelimitsec, $commands ) = @_;
  $SIG{'ALRM'} = sub { die 'timeout' };
    alarm($timelimitsec);      # set timeout prior to operations
    ### do "timeout enabled" operations here
    eval $commands ;
    $evalerrorinner = $@;
    alarm(0);                   # clear alarm when operations finished
  if ($evalerrorinner)              # check syntax error message from command eval 
  {
     if ($evalerrorinner =~ /timeout/)
     {
       ### process timed out so take appropriate action here
       return $evalerrorinner;
     }
     else
     {
      ### non-timeout errors like $commands syntax error reach here
      alarm(0);                 # clear the still-pending alarm
      print $PRINTFH "$program: timelimitexec eval inner ERROR EXIT = $evalerrorinner for $commands\n";    # to propagate unexpected error
      die "$program: timelimitexec eval inner ERROR = $evalerrorinner for $commands";    # to propagate unexpected error
    } 
  } 
  ### non-error return
  return '';
} 
########################################################################
########################################################################
sub print_download_speed ()
### PRINT FTP DOWNLOAD TIME AND SPEED
### ** NOW DIFFERS FROM ROUTINE IN gribftpget.pl (argument includes times) ***
{
  my ( $arg, $ftptime0, $time) = @_;
  $arg = sprintf "%s",$arg;
  my ( $remotegribfilesize,$localgribfilesize);
  ### now gets $localgribfilesize, $remotegribfilesize internally
  if ( -s "${GRIBFTPSTDERR}.${ifile}" )
  { 
    $remotegribfilesize = `grep 'Getting file with size:' "${GRIBFTPSTDERR}.${ifile}" | cut -d':' -f2`; jchomp($remotegribfilesize);
  }
  else
  {
    $remotegribfilesize = -1;
  }
  jchomp( $remotegribfilesize );
  if ( -s "${GRIBDIR}/${filename}" )
  { 
    ($dum,$dum,$dum,$dum,$dum,$dum,$dum,$localgribfilesize,$dum,$dum,$dum,$dum,$dum) = stat "$GRIBDIR/$filename";
  }
  else
  {
    $localgribfilesize = -1;
  }
  ### find download time
  my ($dummy,$ftpmins,$ftpsecs) = &hmstimediff( $ftptime0, $time );
  if ( $ftpsecs <= 0 )
  {
    print $PRINTFH "GRIB DOWNLOAD ERROR - 0 second download for GRIB ${arg} ${filenamedirectory}/${filename} at $ftptime0 PT\n";
    return -1;
  }    
  ### ADD server,port info from curl output
  $serverinfo = `grep 'Connecting to ' "${GRIBFTPSTDERR}.${ifile}" | cut -d' ' -f4,7` ; jchomp($serverinfo);
  $serverinfo =~ s/\.ncep\.noaa\.gov//;
  $serverinfo =~ s/\.nws\.noaa\.gov//;
  my $kbytespersec = sprintf( "%3.0f", (0.001*$localgribfilesize/$ftpsecs) );
  print $PRINTFH "GRIB ${arg} $ftptime0 - $time PT = ${ftpmins} min for ${filenamedirectory}/${filename}[${remotegribfilesize}] & ${localgribfilesize} b = $kbytespersec Kb/s  @ $serverinfo\n";
  ### log download speed:
  `echo "$rundayprt $ftptime0 - $time PT : $JOBARG $arg ${filenamedirectory}/${filename}=${remotegribfilesize}b = ${localgribfilesize}b / ${ftpmins}min = $kbytespersec Kb/s  @ $serverinfo" >> "$RUNDIR/LOG/grib_download_speed.log"`;
  ### LOG GRIB DOWNLOAD END
  $localgribfilesize = sprintf "%9s",$localgribfilesize;
  ### use file for two fields to match fields written by log_grib_download_size
  ( $hhmm = $time ) =~ s/:..$//;
  `echo "$arg  $rundayprt $hhmm $hhmm ${filename} ${localgribfilesize} = ${ftpmins} min  $kbytespersec Kb/s  @ $serverinfo" >> "LOG/download.log"`;
}
########################################################################
########################################################################
sub zulu2local ()
### CONVERT LOCAL TIME TO ZULU (if input includes : then output is colon-version)
{
  my $ztime = $_[0];
  ### SUBTRACT LOCAL - ZULU TIME TO GET HOUR DIFFERENCE
  my ( $time,$hourz,$tail, $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) ;
  ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = localtime(time);
  ( $sec,$min,$hourz,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = gmtime(time);
  $zuluhrdiff = $hour - $hourz ;
  ### DETERMINE IF HOUR OR HH:MM<:SS>
  if ( $ztime !~ m|:| )
  {
     $time = $ztime + $zuluhrdiff;
     if   ( $time > 24.0 ) { $time -= 24.0 ; }
     elsif ( $time < 0.0 ) { $time += 24.0 ; }
  }
  else
  {
     ( $hourz,$tail ) = split /:/,$ztime,2 ;
     $hourz =~ s/^0//;
     $hour = $hourz + $zuluhrdiff;
     if   ( $hour > 23 ) { $hour -= 24 ; }
     elsif ( $hour < 0 ) { $hour += 24 ; }
     $time = sprintf "%02d:%s", $hour,$tail;
  } 
  return $time;
} 
#########################################################################
#########################################################################
sub local2zulu ()
### CONVERT ZULU TIME TO LOCAL (if input includes : then output is colon-version)
{
  my $time = $_[0];
  ### SUBTRACT LOCAL - ZULU TIME TO GET HOUR DIFFERENCE
  my ( $timez,$hourz,,$tail, $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) ;
  ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = localtime(time);
  ( $sec,$min,$hourz,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = gmtime(time);
  $zuluhrdiff = $hour - $hourz ;
  ### DETERMINE IF HOUR OR HH:MM<:SS>
  if ( $time !~ m|:| )
  {
     $ztime = $time - $zuluhrdiff;
     if   ( $ztime > 24.0 ) { $ztime -= 24.0 ; }
     elsif ( $ztime < 0.0 ) { $ztime += 24.0 ; }
  }
  else
  {
     ( $hour,$tail ) = split /:/,$time,2 ;
     $hour =~ s/^0//;
     $hourz = $hour - $zuluhrdiff;
     if   ( $hourz > 23 ) { $hourz -= 24 ; }
     elsif ( $hourz < 0 ) { $hourz += 24 ; }
     $timez = sprintf "%02d:%s", $hourz,$tail;
  } 
  return $timez;
} 
#########################################################################
#########################################################################
sub hhmm2hour ()
### CONVERT INPUT hh:mm INTO DECIMAL HOUR
{
  my ($hh,$mm) = split ( /:/, $_[0] );
  my $decimalhour = $hh + $mm/60. ;
  return $decimalhour;
} 
#########################################################################
#########################################################################
sub hour2hhmm ()
### CONVERT INPUT DECIMAL hour INTO hh:mm
{
  ### to get integer mins, do for time + 30-sec
  my $hour = $_[0] +0.00833 ; 
  my $hh = int( $hour ); 
  my $mm = int(  ( $hour - $hh ) * 60 );
  my $hhmm = sprintf "%02d:%02d",$hh,$mm;
  return $hhmm;
} 
#########################################################################
#########################################################################
sub print_memory
### PRINT MEMORY INFO FOR TESTS
{
  jchomp( $statm = `cat /proc/$$/statm` ); 
  print $PRINTFH "STATM: @_ = $statm\n";
}
#########################################################################
#########################################################################
sub latest_ls_file_info ()
### FIND LATEST FILE IN ls -l OUTPUT LISTING
{
  my @data = @_;
  ### ignores year, returns last "latest" file in list if there are several
  my %pmon = ( 'Jan','0', 'Feb','1', 'Mar','2', 'Apr','3', 'May','4', 'Jun','5',
               'Jul','6', 'Aug','7', 'Sep','8', 'Oct','9', 'Nov','10', 'Dec','11' );
  my ( $latesttimestamp, $hr, $min, $timestamp, $fileinfo );
  $latesttimestamp = 0;
  my $yy = 100;
  my $ilatest = -1;
  for ( $i=0; $i<=$#data; $i++ )
  {
    ### skip over "total" line
    if ( $data[$i] =~ m/^ *total / ) { next; }
    my ($perm,$node,$uid,$pid,$size,$qmon,$day,$hhmm,$filename) = split ( /\s+/, $data[$i] );
    ($hr,$min) = split ( /:/, $hhmm );
    $timestamp = mktime( 0,$min,$hr,$day,$pmon{$qmon},$yy,0,0,0 );
    ### choice of "<=" will give last "latest" file in list
    ### (appropriate for ncep data listings when time is part of name)
    ### and only consider grib files of interest !
    if ( $latesttimestamp <= $timestamp && (
           ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m/\.press_gr\./ ) 
        || ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' && $filename =~ m/\.pgrbf\./ ) 
        || ( $gribftpsite eq 'tgftp.nws.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m/\.pgrbf\./ ) 
        || ( $gribftpsite eq 'gsdftp.fsl.noaa.gov' && $GRIBFILE_MODEL eq 'FSL' && $filename =~ m/\.grib$/ ) 
        || ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'ETA' && $filename =~ m/\.awip3dd/ ) 
        || ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSN' && $filename =~ m/\.pgrb2f/ ) 
        || ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'GFSA' && $filename =~ m/\.pgrbf/ ) 
        || ( $gribftpsite eq 'https://nomads.ncep.noaa.gov' && $GRIBFILE_MODEL eq 'AVN' && $filename =~ m/\.pgrbf/ ) 
       ) )
      {
        $ilatest = $i;
        $latesttimestamp = $timestamp;
      }
  }
  ### RETURN FILENAME + INFO
  if ( $ilatest > -1 )
    { ($dum,$dum,$dum,$dum,$dum,$fileinfo) = split(/\s+/,$data[$ilatest],6); }
  else
    { $fileinfo = "No 3d grib files found"; }
  jchomp( $fileinfo );
  return $fileinfo;
}
###########################################################################################
###########################################################################################
###########################################################################################
###########################################################################################
sub dayofweek
### Returns the NUMERICAL (0-6, 0=sunday) Day of the Week for any date between 1500 and 2699.
### >>> Month should be in the range 1..12 <<<  Year=yyyy (2 digit gives same result except for century)
### (extracted from Date::DayofWeek)
{
    my ($day, $month, $year) = @_;
  $day = &strip_leading_zero( $day );
  $month = &strip_leading_zero( $month );
    my $doomsday = &Doomsday( $year );
    my @base = ( 0, 0, 7, 4, 9, 6, 11, 8, 5, 10, 7, 12 );
    @base[0,1] = leapyear($year) ? (32,29) : (31,28);
    my $on = $day - $base[$month - 1];
    $on = $on % 7;
    return ($doomsday + $on) % 7;
}
sub Doomsday
### Doomsday is a concept invented by John Horton Conway to make it easier to
### figure out what day of the week particular events occur in a given year.
### Returns the day of the week (in the range 0..6) of doomsday in the particular
### year given. If no year is specified, the current year is assumed.
### (extracted from Date::Doomsday)
{
    my $year = shift;
    $year = ( localtime(time) )[5] unless $year;
    my $century = $year - ( $year % 100 );
    my $base = ( 3, 2, 0, 5 )[ ( ($century - 1500)/100 )%4 ];
    my $twelves = int ( ( $year - $century )/12);
    my $rem = ( $year - $century ) % 12;
    my $fours = int ($rem/4);
    my $doomsday = $base + ($twelves + $rem + $fours)%7;
    return $doomsday % 7;
}
sub leapyear
###  returns 1 or 0 if a year is leap or not  (4digit year - 2 digit gives same result except for century)
### (extracted from Date::Leapyear)
{
    my $year = $_[0];
    return 1 if (( $year % 400 ) == 0 ); # 400's are leap
    return 0 if (( $year % 100 ) == 0 ); # Other centuries are not
    return 1 if (( $year % 4 ) == 0 ); # All other 4's are leap
    return 0; # Everything else is not
}
###########################################################################################
###########################################################################################
sub kill_pstree()
### TO KILL JOB AND ALL ITS CHILDREN      
{
  ### from richard hanschu, @kills=(`pstree -p $previousjobpid` =~ /\(([0-9]+)/g); for ($i=1; $i<=@kills; ++$i){`/bin/kill -9 $kills[$i-1]`; }
  my $jobpid = $_[0];
  ### exit if no argument
  if( ! defined $jobpid ) { return -1; }
  my @kills = (`pstree -p $jobpid` =~ /\(([0-9]+)/g);
  my $killlist = join ' ',(@kills);
  ### send stderr to stdout as once tried to kill non-existent job
  jchomp( my $killout = `kill -9 $killlist 2>&1` );
  return $killout;
}
###########################################################################################
###########################################################################################
sub GMT_plus_mins ()
### CALC DAY/TIME AFTER ADDING $DELmins MINUTES TO INPUT DAY/TIME VALUES
### INPUT/OUTPUT YEAR=4digit MONTH=01-12 DAY=01-31
### MUST ALLOW FOR PERL ZERO INDEXING AND YEAR-1900
{
  use Time::Local;
  my ( $year1,$month1,$day1,$hr1,$min1, $DELmins ) = @_;
  my ( $csec, $year2,$month2,$day2,$hr2,$min2,$sec2, $wday,$jday,$isdst );
  $csec = timegm( 0,$min1,$hr1,$day1,($month1-1),($year1-1900) );
  $csec += 60*$DELmins ;
  ( $sec2,$min2,$hr2,$day2,$month2,$year2, $wday,$jday,$isdst ) = gmtime( $csec );;
  $min2 = sprintf "%02d", $min2 ;
  $hr2 = sprintf "%02d", $hr2 ;
  $day2 = sprintf "%02d", $day2 ;
  $month2 = sprintf "%02d", ($month2+1) ;
  $year2 += 1900 ;
  return $year2,$month2,$day2,$hr2,$min2;
}
###########################################################################################
###########################################################################################
sub system_child_timeout ()
### run system command $command (with args) - kill it+children after $timeout secs, tests every $waitsec secs
### return 0 if no timeout, 1 if timeout+kill
{
  my ( $command, $timeoutsec, $waitsec ) = @_ ;
  my $childproc = Proc::Background->new( "$command" );
  my $elapsedsec = 0;
  my $rc = 0;
  my $childpid = $childproc->pid ;
  while ( $childproc->alive ) {
    if( $elapsedsec > $timeoutsec ) {
      my $killout = &kill_pstree( $childpid );
      $rc = 1;
      last ;
    }
    sleep $waitsec ;
    $elapsedsec += $waitsec ;
  }   
  return $rc ;
}
###########################################################################################
###########################################################################################
sub zuluhhmm()
### RETURN GMT TIME HH:MM STRING
{
  my ( $sec,$min,$hour,$day,$ipmon,$yearminus1900,$ipdow,$jday,$ldst ) = gmtime(time);
  my $hhmm = sprintf "%02d:%02d",$hour,$min ;
  return $hhmm ;
}
###########################################################################################
###########################################################################################
sub fileage_delete ()
{
  ### DETERMINE MODIFICATION AGE OF FILES IN CURRENT DIRECTORY
  my ($dirname,$critagesec) = @_ ;
  ### DETERMINE CURRENT EPOCH SECS
  my $currentcsecs = time() ;
  ### READ FILES
  opendir DIR, $dirname ;
  my @filelist = readdir DIR ;
  closedir DIR ;
  ### LOOP OVER FILES
  my ( $ifile, $filename, $agesecs );
  for ($ifile=0; $ifile<=$#filelist; $ifile++)
  {
    $filename = $dirname . '/' . $filelist[$ifile] ;
    ### DETERMINE AGE IN SECS
    ### treat only regular files
    if( ! -f $filename ) { next; }
    ### get local file time (in epoch secs) using perl "stat"
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat $filename ;
    ### use_modification_age:
    $agesecs = $currentcsecs - $mtime ;
    ### use_access_age:   $agesecs = $currentcsecs - $atime ;
    ### ADDITIONAL TREATMENT OF FILES
    ### delete older files
    if( $agesecs > $critagesec )
    {
      `rm -f $filename 2>/dev/null` ;
    }
  }
}
###########################################################################################
###########################################################################################
### FIND NEAREST INTEGER
sub nint { int($_[0] + ($_[0] >=0 ? 0.5 : -0.5)); }
#########################################################################
###################   END OF SUBROUTINE DEFINITIONS   ###################
#########################################################################
