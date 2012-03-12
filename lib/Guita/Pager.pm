package Guita::Pager;
use strict;
use warnings;

use Class::Accessor::Lite (
    new => 1,
    ro => [qw(per_page count)]
);

sub page {
    my ($self, $page) = @_;
    if ($page) {
        $self->{page} = $page;
    }
    return $self->{page} || 1;
}

sub limit {
    my ($self) = @_;
    $self->per_page;
}

sub offset {
    my ($self) = @_;
    $self->per_page * ($self->page - 1);
}

sub has_next  {
    my ($self) = @_;
    $self->per_page * $self->page < $self->count;
}

sub has_prev {
    my ($self) = @_;
    $self->page > 1;
}

1;
