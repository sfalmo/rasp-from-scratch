#!/usr/bin/perl

use JSON;

$dir = $ARGV[0];

print "Starting title2json.pl for directory $dir\n";

@files = glob("$dir/*.data");

foreach my $file (@files) {
    $str = `awk 'FNR==2' ${file}`;
    if ($file =~ m/(.*?)\.data/) {
        $filenameBase = $1;

        if ($str =~ m/(.*?) Valid (.*?) ~Z75~\((.*)\)~Z~ (.*?) ~Z75~\[(.*\@\d{4}z?)\]~Z~/) {
            $parameter = $1;
            $validLocal = $2;
            $validZulu = $3;
            $validDate = $4;
            $fcstTime = $5;

            my %array = (parameter => $parameter, validLocal => $validLocal, validZulu => $validZulu, validDate => $validDate, fcstTime => $fcstTime);
            open(FILE, '>', "${filenameBase}.title.json") or die $!;
            print FILE encode_json \%array;
            close(FILE);
        }
    }
}
