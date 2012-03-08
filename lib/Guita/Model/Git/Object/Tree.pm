package Guita::Model::Git::Object::Tree;
use strict;
use warnings;
use parent qw(Guita::Model::Git::Object::Base);

use Class::Accessor::Lite(
    ro => [qw( trees blobs )],
);

sub is_tree { 1 }

sub children {
    my ($self) = @_;

    +{
        %{ $self->trees },
        %{ $self->blobs },
    };
}

sub trees_list {
    my ($self) = @_;

    [
        sort {
            $a->{name} cmp $b->{name};
        }
        map {
            my $key = $_;
            my $obj = $self->trees->{$key};
            { name => $key, obj => $obj };
        } keys %{$self->trees}
    ];
}

sub blobs_list {
    my ($self) = @_;

    [
        sort {
            $a->{name} cmp $b->{name};
        }
        map {
            my $key = $_;
            my $obj = $self->blobs->{$key};
            { name => $key, obj => $obj };
        } keys %{$self->blobs}
    ];
}
1;
