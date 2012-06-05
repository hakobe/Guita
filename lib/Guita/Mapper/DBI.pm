package Guita::Mapper::DBI;
use strict;
use warnings;

use parent qw(Guita::Mapper);

use Guita::Config;
use Guita::Utils qw(now);

use Class::Load qw(load_class);
use SQL::NamedPlaceholder;
use JSON::XS;
use Encode;

sub dbh {
    my ($self) = @_;
    $self->storage;
}

sub uuid_short {
    my ($self) = @_;
    $self->dbh->selectrow_hashref("SELECT UUID_SHORT() as uuid_short", { Slice => {} })->{uuid_short};
}

sub single {
    my ($self, %args) = @_;
    return $self->array(%args)->[0];
}

sub array {
    my ($self, %opts) = @_;
    load_class $opts{class} if $opts{class};

    my ($sql, $bind) = SQL::NamedPlaceholder::bind_named($opts{sql}, $opts{bind} || {});

    if (config->param('explain')) {
        eval {
            my $explain = $self->dbh($opts{db})->selectrow_hashref("EXPLAIN $sql", { Slice => {} }, @$bind);
            if ($explain->{Extra} =~ m{filesort} && $explain->{rows} > 1) {
                $explain->{sql} = $sql;
                use Data::Dumper;
                warn Dumper $explain ;
            }
        };
    }

    my $res = $self->dbh->selectall_arrayref($sql, { Slice => {} }, @$bind);
    return $opts{class} ? [ map { bless $_, $opts{class} } @$res ] : $res;
}

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
        sql   => 'SELECT * FROM pick ORDER BY modified desc LIMIT :offset,:limit',
        bind => {
            offset => $args->{offset} || 0,
            limit  => $args->{limit}  || 5,
        },
    )
}

sub picks_for_user {
    my ($self, $user, $args) = @_;
    $self->array(
        db    => 'guita',
        class => 'Guita::Model::Pick',
        sql   => 'SELECT * FROM pick WHERE user_id = :user_id ORDER BY modified desc LIMIT :offset,:limit',
        bind => {
            user_id => $user->uuid,
            offset  => $args->{offset} || 0,
            limit   => $args->{limit}  || 5,
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
