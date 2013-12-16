#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

memcached_stats.pl

=head1 SYNOPSIS

memcached_stats.pl memcached.example.com 11211 cmd_get

=head1 DESCRIPTION

memcached の stats, stats settings を取得する

=cut

use constant {
    TIMEOUT                => 5,
    DEFAULT_MEMCACHED_PORT => 11211,
};

my ($host, $port, @keys) = @ARGV;
exit if not $host or not @keys;

my %stats = get_memcached_stats($host, $port);
print join ' ', (map {defined $_ ? $_ : ''} @stats{@keys});
exit;

sub get_memcached_stats {
    my ($host, $port) = @_;
    return if not $host;

    $port = DEFAULT_MEMCACHED_PORT if not defined $port;

    my $memcached_stats;
    eval {
        my $command = sprintf(
            q/echo -ne 'stats settings\r\nstats\r\nquit' | nc -w %d %s %s/,
            TIMEOUT, $host, $port,
        );
        $memcached_stats = qx/$command/;
    };
    if ($@) {
        warn $@;
        return;
    }

    my %stats;
    for my $line (split /\r?\n/, $memcached_stats) {
        $stats{$1} = $2 if $line =~ m/\ASTAT\s(.+?)\s(.+?)\z/;
    }
    eval {
        if (defined $stats{get_hits} and defined $stats{get_misses}) {
            $stats{hit_rate} = sprintf('%.4f', 100 * $stats{get_hits} / ($stats{get_hits} + $stats{get_misses}));
        }
        if (defined $stats{bytes} and defined $stats{limit_maxbytes}) {
            $stats{byte_rate} = sprintf('%.4f', 100 * $stats{bytes} / $stats{limit_maxbytes});
        }
        if (defined $stats{curr_connections} and defined $stats{maxconns}) {
            $stats{conn_rate} = sprintf('%.4f', 100 * $stats{curr_connections} / $stats{maxconns});
        }
    };

    return wantarray ? %stats : \%stats;
}
