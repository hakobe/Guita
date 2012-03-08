package Guita::Model::Pick;
use strict;
use warnings;

use DateTime;
use DateTime::Format::MySQL;

use Class::Accessor::Lite (
    new => 1,
    ro  => [qw(
        uuid
        user
        description
    )],
);

sub created {
    my ($self) = @_;
    warn 111;
    DateTime::Format::MySQL->parse_datetime($self->{created});
}

1;
