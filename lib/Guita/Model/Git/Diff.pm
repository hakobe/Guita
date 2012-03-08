package Guita::Model::Git::Diff;
use strict;
use warnings;

use Class::Accessor::Lite (
    new => 1,
    ro  => [qw(
        from to
        files
        stats
    )],
);

sub files_as_list {
    my ($self) = @_;
    my $results = [];

    [ map { $self->files->{$_} } sort { $a cmp $b } keys %{ $self->files } ];
}

1;
