package Guita::Model::Pick;
use strict;
use warnings;

use Guita::Utils qw(now);
use DateTime;
use DateTime::Format::MySQL;
use Encode;

use Class::Accessor::Lite (
    new => 1,
    rw => [
        qw(
        ),
        # expandable by Guita::Service::Pick
        qw(
            author
            logs
            files
        ),
    ],
);

sub description {
    my ($self) = @_;

    decode_utf8($self->get('description'));
}

1;
