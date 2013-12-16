#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

measure_response_time.pl

=head1 SYNOPSIS

measure_response_time.pl http://www.example.com/
measure_response_time.pl http://www.example.com/ | awk '{print $1}'

=head1 DESCRIPTION

指定URLのレスポンスタイム(とステータスコード)を取得する

=cut

my ($target_url) = @ARGV;

my $command = sprintf(
    q|curl -kL %s -w '%%{time_total} %%{http_code}' -o /dev/null 2> /dev/null|,
    $target_url,
);

print qx/$command/;
exit;
