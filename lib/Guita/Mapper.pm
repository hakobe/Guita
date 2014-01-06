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

my $DEFAULT_STORAGE;
sub default_storage {
    my ($class, $storage) = @_;
    if ($storage) {
        $DEFAULT_STORAGE = $storage;
    }
    return $DEFAULT_STORAGE;
}

sub storage {
    my ($self) = @_;
    return $self->{storage} || $self->default_storage;
}

1;
__END__
