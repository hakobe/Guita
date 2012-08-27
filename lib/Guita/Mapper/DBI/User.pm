package Guita::Mapper::DBI::User;
use strict;
use warnings;

use parent qw(Guita::Mapper::DBI);

sub create_user {
    my ($self, $args) = @_;
    my $uuid = $self->uuid_short;
    my ($sql, $bind) = SQL::NamedPlaceholder::bind_named(
        q[
            INSERT INTO user
            SET
                uuid       = :uuid,
                github_id  = :github_id,
                name       = :name,
                sk         = :sk,
                sk_expires = :sk_expires,
                struct     = :struct
        ],
        {
            uuid       => $uuid,
            github_id  => $args->{github_id},
            name       => $args->{name},
            sk         => $args->{sk},
            sk_expires => now->add( days => 14 ),
            struct     => encode_json($args->{struct}),
        },
    );
    $self->dbh->prepare_cached($sql)->execute(@$bind);

    $uuid;
}

sub update_user {
    my ($self, $user) = @_;

    my ($sql, $bind) = SQL::NamedPlaceholder::bind_named(
        q[
            UPDATE user
            SET
                name       = :name,
                sk         = :sk,
                sk_expires = :sk_expires,
                struct     = :struct
            WHERE
                uuid       = :uuid
        ],
        {
            name       => $user->name,
            uuid       => $user->uuid,
            sk         => $user->sk,
            sk_expires => now->add( days => 14 ),
            struct     => encode_json($user->struct),
        },
    );
    $self->dbh->prepare_cached($sql)->execute(@$bind);
};

sub user_from_github_id {
    my ($self, $github_id) = @_;

    $self->single(
        db => 'guita',
        class => 'Guita::Model::User',
        sql => 'SELECT * FROM user WHERE github_id = :github_id',
        bind => { github_id => $github_id },
    );
}

sub user_from_sk {
    my ($self, $sk) = @_;

    $self->single(
        db => 'guita',
        class => 'Guita::Model::User',
        sql => 'SELECT * FROM user WHERE sk = :sk',
        bind => { sk => $sk },
    );
}

sub user_from_uuid {
    my ($self, $uuid) = @_;

    $self->single(
        db => 'guita',
        class => 'Guita::Model::User',
        sql => 'SELECT * FROM user WHERE uuid = :uuid',
        bind => { uuid => $uuid },
    );
}

sub user_from_name {
    my ($self, $name) = @_;

    $self->single(
        db => 'guita',
        class => 'Guita::Model::User',
        sql => 'SELECT * FROM user WHERE name = :name',
        bind => { name => $name },
    );
}

1;
