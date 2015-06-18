#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use JSON;
use Data::Dumper;
use LWP::UserAgent;
use Getopt::Long;

my $stat = {
  lines_passed => 0,
  bytes_passed => 0,
  batches_passed => 0,
  decode_json_oks => 0,
  decode_json_errors => 0,
  http_errors => 0
};

my $params = {
  verbose => 0,

  url => "http://0.0.0.0:8081/load",

  batch_len => 1000,
  in_filename => "wiki_ru_2015-05-19_out.json",
  start_from => 0,
  limit => 10000,

  send_buf_max => 16384,
  max_size => 16384*2,
  timeout => 3,
  max_redirect => 1
};

sub do_send($$$)
{
  my ($ua, $req, $buf) = @_;

  $stat->{bytes_passed} += length($buf);
  ++$stat->{batches_passed};

  $req->content($buf);
  my $resp = $ua->request($req);

  warn "load.pl got content: ", $resp->content() if $params->{verbose};

  if ($resp->is_success) {
    my $a = eval { decode_json($resp->content); };
    if ($@) {
      warn "load.pl: ", $@," content: ", $resp->content, "\n";
      ++$stat->{decode_json_errors};
      exit 1;
    } else {
      ++$stat->{decode_json_oks};
    }
    return;
  }

  warn "load.pl http error:", $resp->status_line(), ", ", $resp->content(), "\n";

  ++$stat->{http_errors};
  return;
}

sub start()
{
  open (my $in, $params->{in_filename})
      or die "Failed to open $params->{in_filename}: $!";

  my $ua = LWP::UserAgent->new();
  $ua->max_size($params->{max_size});
  $ua->timeout($params->{timeout});
  $ua->max_redirect($params->{max_redirect});

  my $req = HTTP::Request->new('POST', $params->{url});
  $req->header('Content-Type' => 'application/json');

  if ($params->{start_from} > 0) {
    while (<$in>) {
      --$params->{start_from};
      last if $params->{start_from} <= 0;
    }
  }

  my ($buf, $lines) = ("[", 0);
  while (<$in>) {

    last if $params->{limit} == 0;

    if (length($buf) + length($_) >= $params->{send_buf_max}
      || $lines == $params->{batch_len})
    {
      chop($buf);
      $buf .= "]";
      do_send($ua, $req, $buf);
      $buf = "[";
      $lines = 0;
    }

    $buf .= $_ . ",";
    ++$lines;
    --$params->{limit};
    ++$stat->{lines_passed};
  }

  chop($buf);
  $buf .= "]";
  do_send($ua, $req, $buf) if length($buf) > 0 and !($buf eq "[");

  close $in;

  return;
}

###
# Entry
my $help = 0;

sub set($$) {
  die "Arg '$_[0]' _must_ be positive not 0 number " if $_[1] <= 0;
  $params->{$_[0]} = $_[1];
  return;
}

GetOptions(
  "url=s" => \$params->{url},
  "batch_len=i" => \&set,
  "in_filename=s" => \$params->{in_filename},
  "start_from=i" => \&set,
  "limit=i" => \&set,
  "help|?" => \$help) or die "Error in command line arguments\n";

if ($help) {
  print
      "Usage: load.pl --OPTION ...\n",
      "Options: ", join(", ", keys $params),
      "\n";
  exit 0;
}

start();
print "Stat: ", Dumper($stat);

