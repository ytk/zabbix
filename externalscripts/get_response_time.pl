#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

get_response_time.pl

=head1 SYNOPSIS

get_response_time.pl url

=head1 DESCRIPTION

レスポンスタイムを取得する

=cut

my ($url) = @ARGV;

my $command = sprintf(
    q|curl -kL -w '%%{time_total}' -o /dev/null %s 2>/dev/null|,
    $url,
);
print qx/$command/;
exit;
