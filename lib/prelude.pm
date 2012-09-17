package prelude;

use v5.16;

use utf8;
use strict;
use warnings;

use Guita::Config;

sub import {
    require feature;
    feature->import(':5.16');
    strict->import;
    utf8->import;
    warnings->import;

    my $pkg = caller;
    if ($pkg ne 'Guita::Config') {
        eval qq[
            package $pkg;
            use Guita::Config qw(GuitaConf);
            use Try::Tiny;
        ];
        die $@ if $@;
    }
}

1;
