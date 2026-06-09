#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

my ($sid, $trait, $headlines, $extracols, $ncols, $marker_output, $trait_output);

GetOptions("sid=s"=>\$sid,
	"trait=s"=>\$trait,
	"headlines=s"=>\$headlines,
	"extracols=s"=>\$extracols,
	"ncols=s"=>\$ncols,
	"marker_output=s"=>\$marker_output,
	"trait_output=s"=>\$trait_output);

open (MYFILE2, $trait) or die "Can't open '$trait': $!";
open (MYFILE1, $sid) or die "Can't open '$sid': $!";
open (MYOUT, ">>$trait_output");
my @array;

if ($headlines > 0) {
	system("head -n $headlines $trait > $trait_output");
}

while(<MYFILE1>) {
        my @line = split("\t",$_);
        for (my $c=0; $c<$ncols; $c++) {
               $array[$c] = $line[$c];
        }
        last;
}

#my $cutv = "cut -f1-$extracols";
my $cutv = "awk '{print \$1";
my @a = (2..$extracols);
for(@a){
        $cutv .= ",\$$_";
}

while(my $line = <MYFILE2>) {
        chomp $line;
        my ($k, $v) = split("\t", $line);
        my @match = grep{$array[$_] eq $k } 0..$#array;
        if (@match){
              print MYOUT "$line\n";
              my $tmp = $match[0] + 1;
              $cutv .= ",\$$tmp";
        }
}

close(MYFILE1);
close(MYFILE2);
close(MYOUT);

$cutv .= "}' OFS='\t' $sid > $marker_output";
#print STDERR "$cutv\n";
system($cutv);

open(MYTRAIT, $trait_output);
open(MYOUT, ">mlmm_$trait_output");
my $firstLine = <MYTRAIT>;
chomp $firstLine;
my @traits = split/\s+/,$firstLine;
my $numTraits = @traits;

print MYOUT "phenotype_id,phenotype_name,ecotype_id,value,replicate_id\n";
while(<MYTRAIT>) {
	my @line = split/\s+/,$_;
	for (my $c=1; $c<$numTraits; $c++) {
		print MYOUT "$c,$traits[$c],$line[0],$line[$c],$c\n";
	}
}
close(MYOUT);
close(MYTRAIT);

