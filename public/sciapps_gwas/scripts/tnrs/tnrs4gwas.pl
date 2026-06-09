#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

my ($sid, $trait, $header, $out);

GetOptions("sid=s"=>\$sid,
	"trait=s"=>\$trait,
	"header=s"=>\$header,
	"out=s"=>\$out);

open (MYFILE1, $sid) or die "Can't open '$sid': $!";
open (MYFILE2, $trait) or die "Can't open '$trait': $!";
open (MYOUT, ">>$out");
open (MYO2, ">unmapped.txt");

my %hash;
while(my $line = <MYFILE1>) {
        chomp $line;
        my ($v,$k) = split("\t",$line);
        $k =~ s/\_//g;
        $k = uc($k);
        $hash{$k} = $v;
}

if ($header > 0){
	system("head -n $header $trait > $out");
}

while(my $line = <MYFILE2>) {
        chomp $line;
        my ($k, @v) = split("\t", $line);
        my $kk = $k;
        $k =~ s/[\s\-\_\.]//g;
        $k = uc($k);
        if (exists $hash{$k}){
              print MYOUT "$hash{$k}\t@v\n";
        }
        else {
              print MYO2 "$kk\n";
        }
}

close(MYFILE1);
close(MYFILE2);
close(MYOUT);
close(MYO2);

