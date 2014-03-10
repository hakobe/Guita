package Guita::Model::User;
use strict;
use warnings;

use Guita::Utils qw(now);

use DateTime;
use DateTime::Format::MySQL;
use JSON::XS;

use Class::Accessor::Lite (
    new => 1,
);

sub is_guest { 0 }

sub id {
    my ($self) = @_;

    return $self->get('id');
}

sub sk_expires {
    my ($self) = @_;
    DateTime::Format::MySQL->parse_datetime($self->{sk_expires})
                           ->set_time_zone('local');
}

sub is_expired {
    my ($self) = @_;
    now >= $self->sk_expires;
}

sub struct {
    my ($self) = @_;
    decode_json($self->get('struct'));
}

sub email {
    my ($self) = @_;
    $self->struct->{api}->{user}->{email};
}

sub avatar_url {
    my ($self) = @_;
    $self->struct->{api}->{user}->{avatar_url};
}

1;
