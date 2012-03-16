#!/usr/bin/env perl

use strict;
use warnings;
use Devel::KYTProf;

use lib glob 'modules/*/lib';
use lib 'lib';
use Plack::Runner;

my $runner = Plack::Runner->new;
$runner->parse_options(
    '--port', 3005,
    '--Reload', join(',', glob('modules/*/lib'), 'lib'),
    '--app', 'script/app.psgi',
    @ARGV,
);

$runner->run;

