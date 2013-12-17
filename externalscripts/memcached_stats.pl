#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

memcached_stats.pl

=head1 SYNOPSIS

memcached_stats.pl example.com:11211 30 cmd_get cmd_set

=head1 DESCRIPTION

memcached の stats, stats settings の値を取得する

=cut

use Fcntl;

use constant {
    DEFAULT_MEMCACHED_PORT => 11211,
    DEFAULT_CACHE_SEC      => 0,                           # 取得結果をキャッシュする時間(秒)
    REQUEST_TIMEOUT        => 5,                           # 取得時のタイムアウト
    CACHE_DIR              => '/tmp',                      # キャッシュファイルの保存先ディレクトリ
    CACHE_FILE_NAME_FORMAT => 'memcached_stats_%s:%s.txt', # キャッシュファイル名のフォーマット
};

main(@ARGV) if not caller(0);

sub main {
    my ($address, $cache_sec, @keys) = @_;
    return if not $address or not @keys;

    my %stats = get_memcached_stats($address, $cache_sec);
    print join ' ', (map {defined $_ ? $_ : ''} @stats{@keys});
    return;
}

sub get_memcached_stats {
    my ($address, $cache_sec) = @_;
    return if not $address;

    my ($host, $port) = split /:/, $address;
    $port      ||= DEFAULT_MEMCACHED_PORT;
    $cache_sec ||= DEFAULT_CACHE_SEC;

    my $memcached_stats;
    my $cache_file = sprintf '%s/'.CACHE_FILE_NAME_FORMAT, CACHE_DIR, $host, $port;
    if ($cache_sec and -e $cache_file) {
        my $mtime = (stat $cache_file)[9];
        if ($cache_sec >= time - $mtime) {
            sysopen(my $fh, $cache_file, O_RDONLY) or die $!;
            $memcached_stats = do {local $/; <$fh>};
            close $fh;
        }
    }
    if (not $memcached_stats) {
        my $command = sprintf(
            q/echo -ne 'stats settings\r\nstats\r\nquit' | nc -w %d %s %s/,
            REQUEST_TIMEOUT, $host, $port,
        );
        $memcached_stats = qx/$command/;
        if ($memcached_stats and $cache_sec) {
            sysopen(my $fh, $cache_file, O_WRONLY|O_CREAT|O_TRUNC) or die $!;
            print $fh $memcached_stats;
            close $fh;
        }
    }

    my %stats;
    for my $line (split /\r?\n/, $memcached_stats) {
        $stats{$1} = $2 if $line =~ m/\ASTAT\s(.+?)\s(.+?)\z/;
    }
    eval {
        # キャッシュヒット率
        if (defined $stats{get_hits} and defined $stats{get_misses}) {
            $stats{hit_rate} = sprintf('%.4f', 100 * $stats{get_hits} / ($stats{get_hits} + $stats{get_misses}));
        }
        # キャッシュ使用率
        if (defined $stats{bytes} and defined $stats{limit_maxbytes}) {
            $stats{byte_rate} = sprintf('%.4f', 100 * $stats{bytes} / $stats{limit_maxbytes});
        }
        # 接続率
        if (defined $stats{curr_connections} and defined $stats{maxconns}) {
            $stats{conn_rate} = sprintf('%.4f', 100 * $stats{curr_connections} / $stats{maxconns});
        }
    };

    return wantarray ? %stats : \%stats;
}
