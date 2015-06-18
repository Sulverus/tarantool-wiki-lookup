#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use DBI;
use JSON;
use Data::Dumper;
use Getopt::Long;
use Encode qw(encode_utf8);

my $stat = {
  pages_passed => 0
};

my $params = {
  database => "wiki",
  host => "127.0.0.1",
  user => "root",
  password => "",

  start_id => 0,
  end_id => 10,

  dump_limit => 10,

  rpc_id => 0
};

sub fetch_value {

  my ($q, $v) = (@_, undef);

  my $db = DBI->connect(
      "dbi:mysql:database=$params->{database};host=$params->{host}",
      $params->{user},
      $params->{password},
      { RaiseError => 1, PrintError => 1 } );

  $v = $db->selectrow_array($q);

  $db->disconnect();

  return $v;
}

sub go {

  sub start_fetch {
    my ($db, $q, $st) = (@_, undef);
    $st = $db->prepare($q);
    $st->execute();
    return $st;
  }

  sub do_write {
    my ($fh, $pages) = @_;
    $params->{rpc_id} = 0 if $params->{rpc_id} > 2000000;
    print '{"method":"load",',
                 '"id":', $params->{rpc_id} . ',',
                 '"params": ', JSON->new->utf8(0)->encode($pages),
                 '}',
                 "\n"
           or die "Can't write: $!";
    ++$params->{rpc_id};
  }

  my $db = DBI->connect(
      "dbi:mysql:database=$params->{database};host=$params->{host}",
      $params->{user},
      $params->{password},
      { RaiseError => 1, PrintError => 1 } );

  my $page_st = start_fetch($db,
    "SELECT page_id, page_namespace, page_title " .
    "FROM page " .
    "WHERE page_id BETWEEN $params->{start_id} AND $params->{end_id}");

  my ($pageslen, $pages) = (0, []);
  while (my $page = $page_st->fetchrow_hashref()) {

    next if not exists $page->{page_title}
        or not defined $page->{page_title}
        or $page->{page_title} eq '';

    my ($id, $title, $space) = (
        $page->{page_id} + 0,
        $page->{page_title},
        $page->{page_namespace} + 0 || 0 );

    my $cl_to_arr = [];
    my $cat_st = start_fetch($db,
        "SELECT cl_from, cl_to ".
        "FROM categorylinks ".
        "WHERE cl_from = $id" );
    while (my $cat = $cat_st->fetchrow_hashref()) {
      next if not defined $cat->{cl_from} or $cat->{cl_from} eq "";
      my ($cl_from, $cl_to) = ($cat->{cl_from}, $cat->{cl_to});
      push @$cl_to_arr, $cl_to;
    }

    if ($pageslen >= $params->{dump_limit}) {
      do_write(undef, $pages);
      ($pageslen, $pages) = (0, []);
    }

    push @$pages, [ $id * 1, $space * 1, $title, $cl_to_arr ];
    ++$pageslen;
    ++$stat->{pages_passed};
  }

  do_write(undef, $pages) if length $pageslen;

  $db->disconnect();

  local $Data::Dumper::Terse = 1;
  warn "** Stat ", Dumper($stat), "\n";
}

###
# Entry
my $show_id_max = 0;
GetOptions(
  "database=s" => \$params->{database},
  "host=s" => \$params->{host},
  "user=s" => \$params->{user},
  "password=s" => \$params->{password},
  "start_id=i" => \$params->{start_id},
  "end_id=i" => \$params->{end_id},
  "dump_limit=i" => \$params->{dump_limit},
  "id_max" => \$show_id_max,
  "help|?" => sub {
    print "Usage: $0 --OPTIONS ...\n",
          "\tAllowed options: \n",
          "\t\tdatabase - Database name, default wiki\n",
          "\t\thost - Database host, default 127.0.0.1\n",
          "\t\tuser - Database user, default root\n",
          "\t\tpassword - Database user password, default empty\n",
          "\t\tstart_id - Wiki.page.page_id start, default 0\n",
          "\t\tend_id - Wiki.page.page_id stop, default 10\n",
          "\t\tdump_limit - {.., params: [ << limit of elements ] }, default 10\n",
          "\t\tid_max - show Wiki.page.page_id max and exit",
          "\t\thelp - print this and exit\n",
          "\n";
    exit 0;
  }
);

if ($show_id_max) {
  print fetch_value(
    "SELECT page_id " .
    "FROM page " .
    "ORDER BY page_id DESC LIMIT 0,1" ),
    "\n";
  exit 0;
}

go();
