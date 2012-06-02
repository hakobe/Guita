package Guita::Model::User;
use strict;
use warnings;

use Guita::Utils qw(now);

use DateTime;
use DateTime::Format::MySQL;
use JSON::XS;

use Class::Accessor::Lite (
    new => 1,
    ro => [qw(uuid)],
    rw => [qw(
        uuid
        github_id
        sk
    )],
);

sub is_guest { 0 }

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
    decode_json($self->{struct});
}

sub name {
    my ($self) = @_;
    $self->struct->{api}->{user}->{login};
}

sub avatar_url {
    my ($self) = @_;
    $self->struct->{api}->{user}->{avatar_url};
}

sub ssh_keys {
    my ($self) = @_;
    join "\n", map { $_->{key} } @{ $self->struct->{api}->{user_keys} };
}

1;
