package Guita::Mapper::DBI::Pick;
use strict;
use warnings;

use parent qw(Guita::Mapper::DBI);

use Guita::Utils qw(now);
use Encode;

sub create_pick {
    my ($self, $args) = @_;

    my $uuid = $self->uuid_short;
    my ($sql, $bind) = SQL::NamedPlaceholder::bind_named(
        q[
            INSERT INTO pick
            SET
                uuid        = :uuid,
                description = :description,
                user_id     = :user_id,
                created     = :created,
                modified    = :modified
        ],
        {
            uuid        => $uuid,
            description => encode_utf8($args->{description}),
            user_id     => $args->{user_id},
            created     => now(),
            modified    => now(),
        },
    );
    $self->dbh->prepare_cached($sql)->execute(@$bind);

    $uuid;
}

sub update_pick {
    my ($self, $pick) = @_;

    my ($sql, $bind) = SQL::NamedPlaceholder::bind_named(
        q[
            UPDATE pick
            SET
                description = :description,
                modified    = :modified
            WHERE
                uuid = :uuid
        ],
        {
            uuid        => $pick->uuid,
            description => encode_utf8($pick->description),
            modified    => $pick->modified,
        },
    );
    $self->dbh->prepare_cached($sql)->execute(@$bind);
}

sub delete_pick {
    my ($self, $pick) = @_;

    my ($sql, $bind) = SQL::NamedPlaceholder::bind_named(
        q[
            DELETE from pick
            WHERE 
                uuid    = :uuid
        ],
        {
            uuid    => $pick->uuid,
        },
    );
    $self->dbh->prepare_cached($sql)->execute(@$bind);
}

sub pick {
    my ($self, $id) = @_;

    $self->single(
        db => 'guita',
        class => 'Guita::Model::Pick',
        sql => 'SELECT * FROM pick WHERE uuid = :uuid',
        bind => { uuid => $id },
    );
}

sub picks {
    my ($self, $args) = @_;
    $self->array(
        db    => 'guita',
        class => 'Guita::Model::Pick',
        sql   => 'SELECT * FROM pick ORDER BY created desc LIMIT :offset,:limit',
        bind => {
            offset => $args->{offset} || 0,
            limit  => $args->{limit}  || 10,
        },
    )
}

sub picks_for_user {
    my ($self, $user, $args) = @_;
    $self->array(
        db    => 'guita',
        class => 'Guita::Model::Pick',
        sql   => 'SELECT * FROM pick WHERE user_id = :user_id ORDER BY created desc LIMIT :offset,:limit',
        bind => {
            user_id => $user->uuid,
            offset  => $args->{offset} || 0,
            limit   => $args->{limit}  || 10,
        },
    )
}

sub picks_count {
    my ($self) = @_;
    $self->single(
        db    => 'guita',
        sql   => 'SELECT count(*) as c FROM pick',
    )->{c};
}

1;
