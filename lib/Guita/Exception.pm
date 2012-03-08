package Guita::Exception;

use utf8;
use strict;
use warnings;

sub throw {
    my ($class, %opts) = @_;
    my $self = $class->new(%opts);
    die $self;
}

sub new {
    my ($class, %opts) = @_;
    bless \%opts, $class;
}


1;

