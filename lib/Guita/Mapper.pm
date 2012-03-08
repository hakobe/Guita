package Guita::Mapper;
use strict;
use warnings;

use Class::Accessor::Lite (
    new => 1,
);

sub with {
    my ($self, $storage) = @_;
    $self->{storage} = $storage;
    $self;
}

sub storage {
    my ($self) = @_;
    $self->{storage};
}

1;
__END__
