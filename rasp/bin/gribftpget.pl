#! /usr/bin/perl -w

### ARCHIVE-ADDED gribftpget to get archive file from nomads server (gets entire file, not subdomain)
#
# 11 July 2015 Added fix for end of ftpprd, as per
# http://www.drjack.info/cgi-bin/WEBBBS/rasp-forum_config.pl/read/5991#5991
# Thanks to Alan Crouse

### USED FOR PARALLEL-DOWNLOAD 
###    assumes grib file already removed
### THIS VERSION DOES _FINITE_NO_ OF LOOPS IF TOO SMALL TEST NOT MET (exits earlier for other tests)

  ### *NB* RUNARG used only for display purposes at present
  ### USES RUNDIR (which depends on $RUNARG) TO DISTINGUISH BETWEEN curl CALLS FROM DIFFERENT RUNS
  my $RUNARG;

  ### READ ARGUMENT LIST
  (
    $RUNARG,
    $MODELTYPE,
    $ifile,
    $rundayprt,
    $gribftpsite,
    $FTPDIRECTORY,
    $filename,
    $GRIBFTPSTDOUT,
    $GRIBFTPSTDERR,
    $RUNDIR,
    $GRIBDIR,
#3    $UTILDIR,
    $cycle_waitsec,
    $gribgetftptimeoutsec,
    $mingribfilesize,
    $printoutfilename
  ) = split ',', $ARGV[0];
  #4test: `echo "ARGS= @ARGV" >| tmptmp.gribftpget.args`;
  #4test: `echo "gribgetftptimeoutsec = $gribgetftptimeoutsec" >> tmptmp.gribftpget.args`;
  #4test print "filename = $filename \n";

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

  ######## SET PARAMETERS 
  ### SET MAX NO OF ITERATIONS OF LOOP
  $getgrib_maxwait = 60 ;
  ### SET SLEEP SEC BETWEEN LOOP ITERS
  ### but for some cases $cycle_waitsec used instead (expected to be longer)
  $getgrib_waitsec = 2 *60;
  ### SET PARAMETERS USED IN ERROR EMAIL 
  my $program = "$ENV{PWD}/gribarchiveget.pl";   # used in email message
  my $emailaddress = $ENV{'RASP_ADMIN_EMAIL_ADDRESS'} ;  # used in email address
  #old my $emailaddress = 'admin@drjack.info';          # used in email address


  ### INITIALIZATION
  ### now print to same printout as main routine using passed in filename
  # (untested for std.out. case - tried to use "&1" as filename)
  $logfile = "$printoutfilename";
  #old $logfile = "${GRIBDIR}/gribarchiveget.log.${ifile}";
  #old `mv -f $logfile ${logfile}.last`;
  #old $MODELTYPE = substr($MODELARG,0,3);
  $remotegribfilesize = '';

  ### SET CURL FTP OPTIONS
  $ftpoptions = "--max-time $gribgetftptimeoutsec";
  ### ADD CURL SPEED TEST PARAMETERS FOR ETA
  if ( $MODELTYPE eq 'ETA' )
  { $ftpoptions .= " --speed-time 300 --speed-limit 10000"; }
  #old-alter_ipnumber  if ( $MODELTYPE ne 'ETA' )
  #old-alter_ipnumber  { $ftpoptions .= " --interface eth0:0";  }
  #old-alter_ipnumber  else
  #old-alter_ipnumber  {
  #old-alter_ipnumber    ### spread i8z and 21z downloads over different IPs to avoid "too many connections" failure
  #old-alter_ipnumber    $analtime = substr( $filename, 5, 2 );
  #old-alter_ipnumber    $fcsttime = substr( $filename, 15, 2 );
  #old-alter_ipnumber    $validtime = $analtime + $fcsttime ;
  #old-alter_ipnumber    $validtest = $validtime % 2 ;
  #old-alter_ipnumber    if ( $validtest == 1 )
  #old-alter_ipnumber    {
  #old-alter_ipnumber      $ftpoptions .= " --interface eth0:1 --speed-time 300 --speed-limit 10000";
  #old-alter_ipnumber      #old $ftpoptions .= " --interface eth0:1 --speed-time 900 --speed-limit 10000";
  #old-alter_ipnumber    }
  #old-alter_ipnumber    else
  #old-alter_ipnumber    {
  #old-alter_ipnumber      $ftpoptions .= " --interface eth0:2 --speed-time 300 --speed-limit 10000";
  #old-alter_ipnumber      #old $ftpoptions .= " --interface eth0:2 --speed-time 900 --speed-limit 10000";
  #old-alter_ipnumber      #older $ftpoptions .= " --interface eth0:2 --speed-time 1800 --speed-limit 20000";
  #old-alter_ipnumber    }
  #old-alter_ipnumber  }

  ############################################

    ### CURL RETURN CODES                       RC    $exit_value  $signal_num
    # Received only partial file:              4608       18       0
    # Operation too slow. Less than ...        7168       28       0               CURL="Operation timeout"
    # Connection time-out                        "         "       "
    # You have been denied a connection from this server due to excessive connections      ??14436??         29     0  CURL: "unknown reply"
    # WHEN SERVER DOWN? * socket error: 110     ???       29       0       CURL="unknown reply"
    # No such file or directory                 4864      19       0       CURL="ftp couldnt RETR"   
    # Socket error                              1792       7       0       CURL="failed to connect to host"   
    # Couldnt resolve host                      1536       6       0       CURL="couldnt resolve host"   
    # Connection aborted (1st attempt)         14336      56       0       CURL="failure in receiving network data"   
    # No curl executable                       32512     127       0       
    # Incorrect user/pw                         2560      10       0       
    # Protocol error, eg bad output file write   256       1       0       
    # FTP weird reply                           3072       1       0       CURL="could not parse reply send to USER request"
    # bad download resume                                 36       0       
    #FSL:  maximum number of clients (2) from your host are already connected     2304   9  0  CURL="login access denied"
    #NCEP/NWS:  missing directory   2304   9  0  CURL="login access denied"

    ### SET CURL RETURN CODE CASES : leading * => "fatal" error, i.e. forces error exit (else loop continues)
    $errormsg[1]   = "* PROTOCOL ERROR";        ### eg failed output file write due to bad directory
    $errormsg[6]   = "UNRESOLVED HOST (no connection made)";
    $errormsg[7]   = "CONNECTION FAILURE";
    $errormsg[8]   = "WEIRD REPLY, PARSE ERROR 8";           ###  once due to server being temporarily down 
    $errormsg[9]   = "LOGIN DENIED (NCEP/NWS=>missing_directory FSL=>too_many_connections)";
    $errormsg[10]  = "BAD USER/PW (no connection made)";
    $errormsg[11]  = "PARSE ERROR 11";
    $errormsg[12]  = "PARSE ERROR 12";
    $errormsg[13]  = "PARSE ERROR 13";
    $errormsg[14]  = "PARSE ERROR 14";
    $errormsg[17]  = "COULD NOT SET BINARY MODE";
    $errormsg[18]  = "ONLY PARTIAL FILE RECEIVED";
    $errormsg[19]  = "REMOTE GRIB FILE NOT FOUND $filename";
    $errormsg[22]  = "REMOTE GRIB FILE NOT FOUND $filename";
    $errormsg[23]  = "* BAD LOCAL WRITE (blank filename ?)";
    $errormsg[28]  = "TOO SLOW => TIMEOUT";
    $errormsg[29]  = "SERVER DOWN/UNAVAILABLE";
    $errormsg[36]  = "DOWNLOAD RESUME ERROR";
    $errormsg[56]  = "ABORTED CONNECTION";
    $errormsg[78]  = "FILE DOES NOT EXIST";
    $errormsg[127]  = "* CURL PROGRAM FAILURE";
    $errormsg[247]  = "* ID/PW LOGIN FAILURE";
    $errormsg[256] = "* GRIBARCHIVEGET RC 256";   ### RC=256 error - dont really know what this means but sounds like it should be fatal

  ############################################

  ### LOOP OVER GETGRIB MORE THAN ONCE IF ERROR CONDITION RESULTS FOR FILE EXPECTED TO EXIST
  # should not need this loop with lgetgrib=1 as file should then exist,
  # but keep for other cases or in case connection problems occur
  ### START OF GETGRIB LOOP
  for ( $iwait=1; $iwait <= $getgrib_maxwait; $iwait++ )
  {  
    $time = `date +%H:%M:%S`; jchomp($time);
    $ftptime0 = $time;

    ### probably could use -C option on iter 1 also (when no file exists)  but not tested, so be safe
    if ( $iwait > 1 ) 
      { $ftpoptions = '-C - ' . $ftpoptions ; }

    `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} >> GRIBARCHIVEGET LOOP TOP: $filename" >> $logfile`;

    ### LOG GRIB DOWNLOAD START
    ### use file for two fields to match fields written by log_grib_download_size
    ( $hhmm = $time ) =~ s/:..$//;
#3  `echo "GRIBARCHIVEGET  $rundayprt $hhmm $hhmm ${filename}         0" >> "$RUNDIR/$MODELTYPE/download.log"`;
    `echo "GRIBARCHIVEGET  $rundayprt $hhmm $hhmm ${filename}         0" >> "$RUNDIR/LOG/download.log"`;
    $gribarchivegetreturn = 'precall';           # set here to avoid possible undef value in print

#DUMFTP-TESTING: call dummy ftp program for testing
#DUMFTP-TESTING+ print $PRINTFH "CALL FOR FAKE FTP FOR $ifile = THEN EXIT LOOP \n";
#DUMFTP-TESTING+   $ltimelimiterr = &timelimitexec ( $gribgetftptimeoutsec, "\$gribarchivegetreturn=`$UTILDIR/xgribarchiveget $gribftpsite $GRIBDIR $FTPDIRECTORY $filename ${GRIBFTPSTDOUT}.${ifile} ${GRIBFTPSTDERR}.${ifile} $ftpoptions`" );
#DUMFTP-TESTING+ last;

    #childftp+ 
#NOFTP-TESTING: just sleep instead of doing ftp
#NOFTP-TESTING+ if ( ! -s "${GRIBDIR}/${filename}" )
#NOFTP-YTESTING+ {

#FTP-PARALLEL: plan to use curl which has its own time-limit option, so eliminate timeout wrapper
#old  $ltimelimiterr = &timelimitexec ( $gribgetftptimeoutsec, "\$gribarchivegetreturn=`$UTILDIR/gribarchiveget $gribftpsite $GRIBDIR $FTPDIRECTORY $filename ${GRIBFTPSTDOUT}.${ifile} ${GRIBFTPSTDERR}.${ifile} $ftpoptions`" );

############################################################################
######################  START OF FORMER BASH SCRIPT  #######################
    
      #example $UTILDIR/gribarchiveget $gribftpsite $GRIBDIR $FTPDIRECTORY $filename ${GRIBFTPSTDOUT}.${ifile} ${GRIBFTPSTDERR}.${ifile} $ftpoptions

      ### GET GRIB FILE yymmddzulu & WRITE TO GRIBDIR/file
      ### 7 arguments
      #   gribarchiveget SITE locdlDIR gribfiledirectory gribfilename std.out.filename err.out.filename ftp-options
      #   eg: gribarchiveget SITE /users/glendeni/SOAR/BLIP maps_fcst 0203721000006.grib
      #       "$DIR/tmp.${program}.gribarchiveget.out1" "$DIR/tmp.${program}.gribarchiveget.out2" -C -

      ### with ftp std.out,err to TMPFILE1,TMPFILE2
      ### USED BY blip.pl (made separate so can kill if ftp has problem)

      ### SET LSFTPMETHOD
      ### curl uses timeout to prevent unkilled ftp processes, can also be verbose
      ###      (and might later use other features, such as filename-only-list, macros, etc)
      #old LSFTPMETHOD='FTP'; # ftp method now untested - error codes set up for curl operation - ftp has no time limit constraint
      $LSFTPMETHOD='CURL';

      ### PARSE ARGUMENT
      ### allow optional site to be 1st argument
      if    ( $gribftpsite eq "ftpprd.ncep.noaa.gov" )
      { $ID='anonymous drjack@drjack.info'; }
      elsif ( $gribftpsite eq "tgftp.nws.noaa.gov" )
      { $ID='anonymous drjack@drjack.info'; }
      elsif ( $gribftpsite eq "gsdftp.fsl.noaa.gov" )
      { $ID='ftp apassword'; }
      ### ARCHIVE-ADDED
      elsif ( substr( $gribftpsite, 0, 8 ) eq 'https://' )
      { $ID=''; }
      else
      {
        ### gribarchiveget ERROR: bad site = $gribftpsite"
        exit -9 ;  
        #old once allowed site to be optional and this was default site
        #old ID='ftprap20 ros7coe'
        #old FTPSITE='narf.fsl.noaa.gov'
      }

      $TMPFILE1 = "${GRIBFTPSTDOUT}.${ifile}" ;
      $TMPFILE2 = "${GRIBFTPSTDERR}.${ifile}" ;

      ### REMOVE OLD FILES 
      # below should not be needed with unique filenames, but just in case
      #now depend upon blip program to remove file, so can do re-start of same job rm -f ${GRIBDIR}/${filename}
      # delete files separately so can use Bourne shell
      `rm -f $TMPFILE1`;
      `rm -f $TMPFILE2`;

      ### FTP CASE TREATED HERE
      if ( $LSFTPMETHOD eq "FTP" )
      {
        # instead use "-i" flag to turn off prompt  echo "prompt";
        `( 
          echo "user $ID";
        #4test(nb:verbose_default=on):
        echo "debug";
          echo "binary";
          echo "cd $FTPDIRECTORY";
          ### below ls not needed bur provides check on available files
        #NOT USED (LS SEEMS TO HANG AT NCEP)  echo "ls";
          echo "lcd $GRIBDIR";
          echo "get $filename";
          echo "bye";
      ###NB### ftp argument order used as identifier for killing hung jobs !!!
      ###NB### so do not change unless also change grep associated with kill  !!!
        #new ) | ftp -n -i spur.fsl.noaa.gov > $TMPFILE1 2> $TMPFILE2
        #old ) | ftp -n -i narf.fsl.noaa.gov > $TMPFILE1 2> $TMPFILE2
        ) | ftp -n -i $gribftpsite > $TMPFILE1 2> $TMPFILE2`;
      }
      ### CURL CASE TREATED HERE
      elsif ( $LSFTPMETHOD eq "CURL" )
      {
        #ARCHIVE-ADDED
        if ( substr( $gribftpsite, 0, 8 ) eq 'https://' )
        {
         `curl -v -s -f -o "${GRIBDIR}/${filename}" "${gribftpsite}/${FTPDIRECTORY}/${filename}" > $TMPFILE1 2>$TMPFILE2`;
          #4test: print "curl -v -s -o ${GRIBDIR}/${filename} ${gribftpsite}/${FTPDIRECTORY}/${filename} > $TMPFILE1 2>$TMPFILE2 \n";
        }
        else
        {
          $ID =~ s/ /:/;
          #silent:  `curl -s --user $ID $ftpoptions --disable-epsv -o "${GRIBDIR}/${filename}" "ftp://${gribftpsite}/${FTPDIRECTORY}/${filename}" > $TMPFILE1 2>$TMPFILE2`;
          #verbose:
          `curl -v -s --user $ID $ftpoptions --disable-epsv -o "${GRIBDIR}/${filename}" "ftp://${gribftpsite}/${FTPDIRECTORY}/${filename}" > $TMPFILE1 2>$TMPFILE2`;
        }
      }
      ### should send back most recent command return code

      ### return exit code from last command = ftp
      $gribarchivegetreturn = $? ;

#######################  END OF FORMER BASH SCRIPT  ########################
############################################################################

#NOFTP-TESTING+ }
#NOFTP-TESTING+ sleep 300;

    $time = `date +%H:%M:%S`; jchomp($time);

###TTTESTING `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> *GETGRIB-POST OPTIONS= $ftpoptions ==RETURN=${gribarchivegetreturn}==" >> $logfile`;

    #why was i formerly calling rucfptls after gribarchiveget here ?
    #old $ltimelimiterr = &timelimitexec ( $gribgetftptimeoutsec, "`$UTILDIR/gribarchiveget $gribftpsite $GRIBDIR $filename $GRIBFTPSTDOUT $GRIBFTPSTDERR`; &gribftpls($gribftpsite);" );

    ### ASSUME THAT RETURN CODE IS "wait" TYPE CONFLATION OF 2 NUMBERS
    if ( $gribarchivegetreturn !~ m|^\s*$| )
    {
      $exit_value  = $gribarchivegetreturn >> 8 ;    #=int($?/256)
      $signal_num  = $gribarchivegetreturn & 127 ;   #=($?-256*exit_value#)
    }
    else
    {
      $exit_value = 0;
      $signal_num = 0;
    }

    ### TREAT CASE OF GRIB GET ENDED DUE TO CURL/FTP SIGNAL
    ### for curl,ftp return code = 128+signal
    if ( $signal_num > 0 )
    #old if ( $gribarchivegetreturn !~ m|^\s*$| && $signal_num > 0 )
    {
      `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> ** GRIBARCHIVEGET RC ERROR (?SIGNAL?) EXIT **  RC= $gribarchivegetreturn => $exit_value & $signal_num" >> $logfile`;
      exit $gribarchivegetreturn ;
    }

    ### FOR NON-ZERO RETURN CODE
    if ( $exit_value > 0 )
    {
      if ( defined $errormsg[$exit_value] )
      {

        ### TREAT CASE OF RC => ERROR EXIT FORCED
        if ( substr($errormsg[$exit_value],0,1) eq '*' )
        {
          `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> ** GRIBARCHIVEGET ERROR EXIT *${errormsg[$exit_value]} ** RC= $gribarchivegetreturn => $exit_value & $signal_num" >> $logfile`;
          exit $gribarchivegetreturn ;
        }

        ### TREAT CASE OF RC => SEND WARNING but loop continues
        else
        {
          `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> GRIBARCHIVEGET LOOP WARNING - $errormsg[$exit_value] - CONTINUE AFTER $cycle_waitsec sec" >> $logfile`; 
          sleep $cycle_waitsec;
          next;
        }
      }

      ### TREAT CASE OF GRIB GET ENDED DUE TO UNEXPECTED RC
      else
      {
        if ( defined $emailaddress && $emailaddress !~ m|^ *$| )
        {
          ### send mail to warn of what has occurred
          $subject = "** gribarchiveget.pl UNKNOWN RETURN CODE";
          `echo "From ${program}: $time $MODELTYPE $ifile ${gribarchivegetreturn} => $exit_value & $signal_num
s
  ** SCRIPT gribarchiveget.pl REPORTED A PROBLEM WHEN ATTEMPTING TO DOWNLOAD A $MODELTYPE OUTPUT FILE
     $exit_value = return code from CURL program (non-zero if CURL detects a problem)
     $signal_num = signal from background call to CURL (non-zero if CURL itself fails)
  ** MOST LIKELY THIS IS CAUSED BY AN UNKNOWN CURL RETURN CODE,
  **   IN WHICH CASE A FIX-UP SHOULD BE ADDED to gribarchiveget.pl
  **   TO TREAT THE RETURN CODE AS A FAILURE (stop trying to download this file and skip WRF processing)
  **   OR NON-FAILURE (continue trying to download this file) EVENT
  ** PLEASE REPORT THIS EVENT TO THE RASP FORUM

  CALL ARGUMENTS PROVIDED TO gribarchiveget.pl ARE:
  $RUNARG
  $MODELTYPE
  $ifile
  $rundayprt
  $gribftpsite
  $FTPDIRECTORY
  $filename
" | mail -s "$subject" "$emailaddress"`;
         #bad `echo "From ${program}: $time $MODELTYPE $ifile = $exit_value & $signal_num" | mail -s "$subject" "$emailaddress" < /dev/null`;
        }
        `cp ${TMPFILE2} "${TMPFILE2}.getgrib_unexpectedrc"`;
        #2continue: `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> *NOTICE* GRIBARCHIVEGET UNEXPECTED RC = $gribarchivegetreturn => $exit_value & $signal_num - NO ACTION TAKEN " >> $logfile`;
        #2continue: sleep $cycle_waitsec;
        #2continue: next;
        #2exit:
        `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> **ERROR** GRIBARCHIVEGET UNEXPECTED RC = $gribarchivegetreturn => $exit_value & $signal_num - SCRIPT EXITED " >> $logfile`;  exit $gribarchivegetreturn ;
      }

    }

    ### BELOW ARE NOT RETURN CODE TESTS - USUALLY NOT REACHED SINCE SPECIFIC CURL EXIT CODE TESTED FIRST - BUT JUST IN CASE ...

    ### GO TO NEXT ITER IF NO FILE EXISTS
    # if no file exists, $! will contain message "No such file or directory"
    if ( ! -s "$GRIBDIR/$filename" || `/bin/grep -c 'No such file' ${GRIBFTPSTDOUT}.${ifile}` > 0 )
    { 
      ### save curl file for later examination
      `cp ${TMPFILE2} "${TMPFILE2}.getgribloop_localfilenotfound"`;
      `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> GRIBARCHIVEGET LOOP - LOCAL GRIB FILE NOT FOUND: likely ftp error - return= ${gribarchivegetreturn} => $exit_value & $signal_num - CONTINUE AFTER $cycle_waitsec sec" >> $logfile`; 
      sleep $cycle_waitsec;
      next;
     }

    ### TEST FOR TOO SMALL DOWNLOADED FILE & PRINT DOWNLOAD SPEED
    # calc localgribfilesize from actual file on disk not from a previous ftp ls
    ($dum,$dum,$dum,$dum,$dum,$dum,$dum,$localgribfilesize,$dum,$dum,$dum,$dum,$dum) = stat "$GRIBDIR/$filename";
    #old jchomp( $filels = `ls -l ${GRIBDIR}/$filename` );
    #old ($dummy,$dummy,$dummy,$dummy,$localgribfilesize,$dummy) = split( /  */, $filels, 6 );
    ### treat case of transmission error as indicated by too small a file
    #stderr: added defined test to eliminate UV message
    ### try to get remotegribfilesize from curl output if needed
    if ( $remotegribfilesize eq '' )
    {
      $remotegribfilesize = `grep 'Getting file with size:' ${TMPFILE2} | cut -d':' -f2`; jchomp($remotegribfilesize);
    }
    if ( defined $localgribfilesize )
      {
      if ( $remotegribfilesize ne '' && $localgribfilesize < $remotegribfilesize )
      {
        ### THIS OCCURS WHEN CURL STOPPED DUE TO "operation too slow" 
        ### THIS OCCURS WITH MESSAGE " Received only partial file: "
        ### set successfultimeend id
        #childftp- $successfulendtime{$filevaliddays{$ifile}}{$filefcsttime}{$filevalidtime} = '2SMAL';
        ### SAVE CURL FILE FOR LATER EXAMINATION
        #childftp
       `cp ${TMPFILE2} "${TMPFILE2}.getgrib_gribtoosmall1"`;
        #childftp- `cp ${GRIBFTPSTDERR} ${GRIBFTPSTDERR}.getgrib_gribtoosmall1`;
        ### PRINT FTP DOWNLOAD TIME AND SPEED
        &print_download_speed ( '*TOO*SMALL' );
        ### SET ATTEMPT RE-TRY CHOICE
        `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> GRIBARCHIVEGET LOOP - DOWNLOADED GRIB FILE TOO SMALL: $filename local $localgribfilesize < remote $remotegribfilesize - CONTINUE AFTER  $getgrib_waitsec sec" >> $logfile`; 
        sleep $getgrib_waitsec;
        next; 
        #childftp- exit -3 ;  # 2SMAL exit
      }
      ### TEST FOR SIZE ABOVE SPECIFIED MINIMUM
      if ( $localgribfilesize < $mingribfilesize )
      {
        ### set successfultimeend id
        #childftp- $successfulendtime{$filevaliddays{$ifile}}{$filefcsttime}{$filevalidtime} = 'SMAL2';
        ### SAVE CURL FILE FOR LATER EXAMINATION
        #childftp
        `cp ${TMPFILE2} "${TMPFILE2}.getgrib_toosmall2"`;
        #childftp- `cp $GRIBFTPSTDERR ${GRIBFTPSTDERR}.getgrib_toosmall2`;
        ### PRINT FTP DOWNLOAD TIME AND SPEED
        &print_download_speed ( 'TOO*SMALL*' );
        ### SET ATTEMPT RE-TRY CHOICE
        `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> **DOWNLOADED GRIB FILE SMALLER THAN MINIMUM**: $filename local $localgribfilesize < min $mingribfilesize [remote=${remotegribfilesize}] - *EXIT*" >> $logfile`; 
         exit -4 ;  # MINSIZE exit
      }
    }    
    else
    {
        ### set successfultimeend id
        ### save curl file for later examination
        `cp ${TMPFILE2} "${TMPFILE2}.getgrib_failedstat"`;
        ### print ftp download time and speed
        &print_download_speed ( '*STAT*FAILED*' );
        ### SET ATTEMPT RE-TRY CHOICE
        `echo "-> $ifile CHILDFTP $$ ${iwait}/${getgrib_maxwait} -->> GRIBARCHIVEGET LOOP ** STAT FAILED ** for $filename - CONTINUE AFTER $getgrib_waitsec sec" >> $logfile`; 
        sleep $getgrib_waitsec;
        next;
    }

    #PARALLEL-FTP:  eliminated case of grib get ended due to time limit

    ### IF GET THIS FAR, SHOULD HAVE A COMPLETE SUCCESSFUL FILE TRANSFER
    exit 0 ;

  ### END OF GETGRIB LOOP
  }

  ### TREAT CASE WHERE MAX ITERS REACHED
  ### save curl file for later examination
  `cp $TMPFILE2 "${TMPFILE2}.getgribloop_itersexceeded"`;
  ### no sleep between attempts when wait loop max iters reached
  `echo "-> $ifile CHILDFTP $$ $time ${iwait}/${getgrib_maxwait} -->> GRIBFRPGET END **WARNING** max.iters $getgrib_maxwait reached -  lastRC=${gribarchivegetreturn} !" >> $logfile`;
   exit -2 ;    # 'GLOOP' exit

########################################################################
sub print_download_speed ()
### PRINT FTP DOWNLOAD TIME AND SPEED 
### ** NOW DIFFERS FROM ROUTINE USED IN blip.pl (may later change this to agree) ***
# uses known external $ftptime0 - prints argument in string
# now gets $localgribfilesize, $remotegribfilesize internally
{
  my $arg = sprintf "%s",$_[0];
  ### now gets $localgribfilesize, $remotegribfilesize internally
  if ( -s "${GRIBFTPSTDERR}.${ifile}" )
  { 
    $remotegribfilesize = `grep 'Getting file with size:' "${GRIBFTPSTDERR}.${ifile}" | cut -d':' -f2`; jchomp($remotegribfilesize);
  }
  else
  {
    $remotegribfilesize = -1;
  }
  if ( -s "${GRIBDIR}/${filename}" )
  { 
    ($dum,$dum,$dum,$dum,$dum,$dum,$dum,$localgribfilesize,$dum,$dum,$dum,$dum,$dum) = stat "$GRIBDIR/$filename";
  }
  else
  {
    $localgribfilesize = -1;
  }
  $time = `date +%H:%M:%S`; jchomp($time);
  my ($dummy,$ftpmins,$ftpsecs) = &hmstimediff( $ftptime0, $time );
  my $kbytespersec = sprintf( "%3.0f", (0.001*$localgribfilesize/$ftpsecs) );
  ### ADD server,port info from curl output
  #PARALLEL-FTP:
  $serverinfo = `grep 'Connecting to ' ${TMPFILE2} | cut -d' ' -f4,7`; jchomp($serverinfo);
  #SERIAL-FTP: $serverinfo = `grep 'Connecting to ' ${GRIBFTPSTDERR} | cut -d' ' -f4,7`; jchomp($serverinfo);
  $serverinfo =~ s/\.ncep\.noaa\.gov//;
  `echo "-> $ifile PRINT_DOWNLOAD_SPEED -->> GRIB ${arg} $ftptime0 - $time PT = ${ftpmins} min for $FTPDIRECTORY/${filename}[${remotegribfilesize}] & ${localgribfilesize} b = $kbytespersec Kb/s  @ $serverinfo" >> $logfile`;
  #old print $PRINTFH "GRIB ${arg} $ftptime0 to $time PT => ${ftpmins} min for ${filenamedirectory}/${filename} ${localgribfilesize} b => $kbytespersec Kb/s\n";
  #old print $PRINTFH "GRIB ${arg} $ftptime0 to $time PT => ${ftpmins} min for ${localgribfilesize} b => $kbytespersec Kb/s\n";
  #older print $PRINTFH "GRIB download: $ftptime0 to $time PT => ${ftpmins} min for ${localgribfilesize} b => $kbytespersec Kb/s\n";
  ### log download speed:
  `echo "$rundayprt $ftptime0 - $time PT : $MODELTYPE $arg $FTPDIRECTORY/${filename}=${remotegribfilesize}b = ${localgribfilesize}b / ${ftpmins}min = $kbytespersec Kb/s  @ $serverinfo" >> "$RUNDIR/grib_download_speed.log"`;
  #old `echo "$rundayprt $ftptime0 - $time PT : $MODELTYPE $arg ${ftpmins} min for ${localgribfilesize} b => $kbytespersec Kb/s" >> "$RUNDIR/grib_download_speed.log"`;
  ### LOG GRIB DOWNLOAD END
  $localgribfilesize = sprintf "%9s",$localgribfilesize;
  ### use file for two fields to match fields written by log_grib_download_size
  ( $hhmm = $time ) =~ s/:..$//;
#3`echo "$arg  $rundayprt $hhmm $hhmm ${filename} ${localgribfilesize} = ${ftpmins} min  $kbytespersec Kb/s  @ $serverinfo" >> "$RUNDIR/$MODELTYPE/download.log"`;
  `echo "$arg  $rundayprt $hhmm $hhmm ${filename} ${localgribfilesize} = ${ftpmins} min  $kbytespersec Kb/s  @ $serverinfo" >> "$RUNDIR/LOG/download.log"`;
}
# end of print_download_speed
########################################################################
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
  # time difference can not be negative
  if ( $secs < 0 ) { $secs = $secs + 24*3600; }
  $mins = sprintf( "%5.1f",($secs/60) );
  $hrs = sprintf( "%5.1f",($secs/3600) );
  return $hrs,$mins,$secs;
}
# end of hmstimediff
#########################################################################
