#!/usr/bin/perl

use JSON;

$dir = $ARGV[0];

print "Starting title2json.pl for directory $dir\n";

@files = glob("$dir/*.data");

sub padZero {
    $str = shift @_;
    if (length($str) == 1 || length($str) == 3) {
	return '0'.$str;
    }
    return $str;
}

foreach my $file (@files) {
    if ($file =~ m/(.*?)\.data/) {
        $filenameBase = $1;
	my ($year, $month, $day, $weekday, $validLocal, $timezone, $validZulu, $fcstTime, $initTime, $fcstZulu, $parameter, $unit, $mult, $min, $max);

        $str = `awk 'FNR==2' ${file}`;
        if ($str =~ m/(.*?) Valid (.*?) ~Z75~\((.*)\)~Z~ (.*?) ~Z75~\[(\d*)hrFcst\@(\d*?)z\]~Z~/) {
	    $fcstZulu = $6;
	}

        $str = `awk 'FNR==4' ${file}`;
        if ($str =~ m/\ADay= (\d*?) (\d*?) (\d*?) (.*?) ValidLST= (\d*?) (.*?) ValidZ= (.*?) Fcst= (.*?) Init= (.*?) Param= (.*?) Unit= (.*?) Mult= (.*?) Min= (.*?) Max= (.*?)$/) {
            $year = $1;
            $month = padZero($2);
            $day = padZero($3);
            $weekday = $4;
            $validLocal = padZero($5);
            $timezone = $6;
            $validZulu = padZero($7);
            $fcstTime = $8;
            $initTime = $9;
            $parameter = $10;
            $unit = $11;
            $mult = $12;
            $min = $13;
            $max = $14;
        }
        my %array = (year => $year, month => $month, day => $day, weekday => $weekday, validLocal => $validLocal, timezone => $timezone, validZulu => $validZulu, fcstTime => $fcstTime, initTime => $initTime, fcstZulu => $fcstZulu, parameter => $parameter, unit => $unit, mult => $mult, min => $min, max => $max);
        open(FILE, '>', "${filenameBase}.title.json") or die $!;
        print FILE encode_json \%array;
        close(FILE);
    }
}
