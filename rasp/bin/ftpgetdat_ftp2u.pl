#!/usr/bin/perl

# This script downloads GFS data for a particular lat/long specified region.
# It makes use of the g2sub scripts from NOAA for their NOMADS high availability
# system. The current URL to get an index of the NOMADS system is:
# https://nomads.ncep.noaa.gov/
#
# This script is based on the ftpgetdat_ftp2u.pl script originally written by
# Paul Hope (Cape Town, South Africa) Jan 2006, updated May 2007.
#
# The author of this script is Mats Henrikson, written in April 2009.

use strict;
use warnings;
$| = 1; # turns on stdout/err autoflushing

# Base url to use.
my $SERVERURL = 'https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_hd.pl';

# cnvgrib path
my $CNVGRIB = 'UTIL/cnvgrib';

# the maximum number of tries to get the file
my $MAX_TRIES = 20;
# the number of seconds to sleep between unsuccessful tries
my $SLEEP_SECONDS = 120;

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

# the filename we are asked for and the name of the file on the server are not the same
# figure out what the server filename will be
my $sourcefile = $targetfile;
$sourcefile =~ s/pgrb2?/mastergrb2/;
#4debug: print "$targetfile: Our target file: $targetfile\n";
#4debug: print "$targetfile: The source file on the server: $sourcefile\n";


# the actual url to curl to get the subregioned file
my $url = "${SERVERURL}"
          ."?file=$sourcefile"
          ."\&all_lev=on"
          ."\&all_var=on"
          ."\&subregion="
          ."\&leftlon=$leftlong"
          ."\&rightlon=$rightlong"
          ."\&toplat=$toplat"
          ."\&bottomlat=$bottomlat"
          ."\&dir=\%2Fgfs.$curdate$runTime\%2Fmaster";
#4debug: print "$targetfile: URL to subregion the file on the server: $url\n";
                
my $STDOUTFILE = "${GRIBFTPSTDOUT}.${ifile}";
my $STDERRFILE = "${GRIBFTPSTDERR}.${ifile}";

MAIN: for (my $iter = 1; $iter <= $MAX_TRIES; $iter++)
{
  ###PRINTOUT
  my $time = `date +%H:%M:%S`; chomp($time);

  # lets just redirect stdout/stderr into file and work with those, makes things
  # easier to debug when there are problems...
  #4debug:     print "$targetfile: Asking for a subregion of file $sourcefile, coords: left=$leftlong,right=$rightlong,top=$toplat,bottom=$bottomlat.\n";
  my $writeOut = "Downloaded %{size_download} bytes in %{time_total} seconds (%{speed_download} bytes per second).";
  `$curlexe --create-dirs --write-out "$writeOut" --output "$outdir/$targetfile.tmp" "$url" >| ${STDOUTFILE} 2>| ${STDERRFILE}`;
  
  # quick check that nothing catastrophic has happened
  unless ($? == 0)
  {
    ##PRINTOUT
    `echo "-> $ifile CHILDFTP $$ $time  >> g2subregion *WARNING: problem retrieving file, sleeping $SLEEP_SECONDS sec ($iter of $MAX_TRIES) ..." >> $printoutfilename`;
    sleep $SLEEP_SECONDS;
    next;
  }
    
  # unfortunately even if the file is not found on the server the server still
  # returns a 200 OK, so we'll check the size of the file, error pages seem to be smaller than 10kb
  unless (-s "$outdir/$targetfile.tmp" > 10240)
  {
    ##PRINTOUT
    `echo "-> $ifile CHILDFTP $$ $time  >> g2subregion *WARNING: file is smaller than 10kb, sleeping $SLEEP_SECONDS sec ($iter of $MAX_TRIES) ..." >> $printoutfilename`;
    sleep $SLEEP_SECONDS;
    next;
  }
  
  # do we need more tests? if so they go here. we could run wgrib2.exe on it
  
  # run cnvgrib on the file to convert it to grib1 (otherwise hinterp fails)
  `$CNVGRIB -g21 -nv $outdir/$targetfile.tmp $outdir/$targetfile >| ${STDOUTFILE} 2>| ${STDERRFILE}`;
  unlink "$outdir/$targetfile.tmp"
    or die "cannot remove $outdir/$targetfile.tmp: $!\n";
  exit 0;
}

# if we arrive down here we've probably passed MAX_TRIES
print STDERR "$targetfile: ERROR: exceeded $MAX_TRIES tries, giving up!\n";
##PRINTOUT
my $time = `date +%H:%M:%S`; chomp($time);
`echo "-> $ifile CHILDFTP $$ $time  >> g2subregion ***ERROR: exceeded $MAX_TRIES tries, giving up!" >> $printoutfilename`;
exit 1;
