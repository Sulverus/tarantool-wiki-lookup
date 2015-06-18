#!/usr/bin/perl -w
#
use strict;
use warnings;

my ($limit, $passed, $in_file) = (
  -1,
  0,
  "dumps/wiki_ru_2015-05-19_out.json" );
open PS, "cat $in_file | cut -d\":\" -f2 | cut -d, -f3 | " or
  die "Can't open $in_file: $?";
while (<PS>) {
  last if $passed == $limit;
  chomp $_;
  print '{"method":"wiki.lookup", "params":[', $_, '], "id":0}', "\n";
  ++$passed;
}
