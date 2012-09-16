package Guita::Exception;

use utf8;
use strict;
use warnings;

# いろんなExceptionをここで管理するようにする
#use Exceptin::Class qw(
#    Guita::Exception::InvalidParameter
#);

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

