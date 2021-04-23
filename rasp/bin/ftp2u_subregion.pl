#!/usr/bin/perl

# This script downloads GFS data for a lat/long specified region.
# It makes use of the g2sub scripts from NOAA for their NOMADS high availability
# system. The current URL to get an index of the NOMADS system is:
# https://nomads.ncep.noaa.gov/
#
# Script is based on the ftpgetdat_ftp2u.pl script originally written by
# Paul Hope (Cape Town, South Africa) Jan 2006, updated May 2007.
#
# The author of this script is Mats Henrikson, written in April 2009.
# Adapted for use with grib2 by Paul Scorer November 2014

use strict;
use warnings;
$| = 1; # turns on stdout/err autoflushing

# Base url to use.
# 0.5 deg my $SERVERURL = 'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p50.pl
#
# 0.25 deg
my $SERVERURL  = 'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl';
# 0.25 deg - Secondary Variables
my $SERVERURLB = 'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25b.pl';

# the maximum number of tries to get the file
my $MAX_TRIES = 20;
# the number of seconds to sleep between unsuccessful tries
my $SLEEP_SECONDS = 60;

# the date to try to get this file for
my $curdate = `date -u +%Y%m%d`;
chomp $curdate;

# read the argument list
my (
  $curlexe,
  $targetfile,
  $leftlong,
  $rightlong,
  $toplat,
  $bottomlat,
  $ifile,
  $GRIBFTPSTDOUT,
  $GRIBFTPSTDERR,
  $outdir,
  ### PRINTOUT
  $printoutfilename
) = split ',', $ARGV[0];
#4debug: print "debug: $targetfile: $curlexe,$targetfile,$leftlong,$rightlong,$toplat,$bottomlat,$ifile,$GRIBFTPSTDOUT,$GRIBFTPSTDERR,$outdir,$curdate\n";

# the time of the GFS model run, i.e. one of 00, 06, 12, 18.
$targetfile =~ /t([\d]{2})z/;
my $runTime = $1;

my $sourcefile = $targetfile;
my $url;
my $urlb;

# the actual urls to curl to get the subregioned file
$url = "${SERVERURL}"
          ."?file=$sourcefile"
          ."\&all_lev=on"
          ."\&all_var=on"
          ."\&subregion="
          ."\&leftlon=$leftlong"
          ."\&rightlon=$rightlong"
          ."\&toplat=$toplat"
          ."\&bottomlat=$bottomlat"
          ."\&dir=\%2Fgfs.$curdate/$runTime"
	  ."%2Fatmos";

# And for the additional parameters
my $sourcefileb;
if($sourcefile =~ s/\.pgrb2\./.pgrb2b./ ){
  $sourcefileb = $sourcefile;
}
$urlb = "${SERVERURLB}"
        ."?file=$sourcefileb"
        ."\&all_lev=on"
        ."\&all_var=on"
        ."\&subregion="
        ."\&leftlon=$leftlong"
        ."\&rightlon=$rightlong"
        ."\&toplat=$toplat"
        ."\&bottomlat=$bottomlat"
        ."\&dir=\%2Fgfs.$curdate/$runTime"
	."%2Fatmos";


#4debug:
`echo "$url\n$urlb\n" >> $printoutfilename ` ;

my $STDOUTFILE = "${GRIBFTPSTDOUT}.${ifile}";
my $STDERRFILE = "${GRIBFTPSTDERR}.${ifile}";

# Make sure no leftovers from a previous run
`rm -f $outdir/$targetfile`;
`rm -f ${STDOUTFILE}`;

URL: for my $U ($url, $urlb) {
  my $iter;
  ITER: for ( $iter = 0; $iter < $MAX_TRIES; $iter++) {
    ###PRINTOUT
    my $time = `date +%H:%M:%S`; chomp($time);
  
    my $writeOut = "Downloaded %{size_download} bytes in %{time_total} seconds (%{speed_download} bytes per second).\n";
    `$curlexe --create-dirs --write-out "$writeOut" --output "/tmp/$targetfile" "$U" >> ${STDOUTFILE} 2>| ${STDERRFILE}`;
    
    # quick check that nothing catastrophic has happened
    unless ($? == 0)
    {
      `echo "-> $ifile CHILDFTP $$ $time  >> ftp2u_subregion *WARNING: problem retrieving file, sleeping $SLEEP_SECONDS sec ($iter of $MAX_TRIES) ..." >> $printoutfilename`;
      sleep $SLEEP_SECONDS;
      next ITER;
    }
      
    # Real GRIB files end with "7777" so check for that
    my $gribend = `tail -c 4 /tmp/$targetfile`;
    if ( $gribend eq "7777" ) {   # Success! Create / append to targetfile
      `cat /tmp/$targetfile >> $outdir/$targetfile && rm -f /tmp/$targetfile`;
      next URL;
    }
    else {
      `echo "-> $ifile CHILDFTP $$ $time  >> ftp2u_subregion *WARNING: file does not end in 7777: sleeping $SLEEP_SECONDS sec ($iter of $MAX_TRIES) ..." >> $printoutfilename`;
  
      `rm -f /tmp/$targetfile`;
      sleep $SLEEP_SECONDS;
      next ITER;
    }
  }

  # Make sure we have not reached MAX_TRIES
  if($iter == $MAX_TRIES){
    print STDERR "$targetfile: ERROR: exceeded $MAX_TRIES tries, giving up!\n";
    ##PRINTOUT
    my $time = `date +%H:%M:%S`; chomp($time);
    `echo "-> $ifile CHILDFTP $$ $time  >> ftp2u_subregion ***ERROR: exceeded $MAX_TRIES tries, giving up!" >> $printoutfilename`;
    `rm -f /tmp/$targetfile`;
    exit 1;
  }

}
  
exit 0;
