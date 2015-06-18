#!/usr/bin/perl -w

use strict;
use warnings;

my ($pos, $offset, $id_max, $last, $batch_size) = (
  0, 0, 5679809, 0, 1000000 );
$offset = $batch_size;

`mkdir -p dumps`;

while (1) {
  if ($offset > $id_max) {
    $offset = $id_max;
    $last = 1;
  }
  my $cmd = "./wiki_cat_conv.pl --start_id=$pos --end_id=$offset > dumps/ru_wiki.$pos-$offset.json";
  my $result = `$cmd`;
  print "$cmd, $result; $!\n";
  last if $last;
  $pos += $batch_size + 1;
  $offset = $pos + $batch_size;
}
