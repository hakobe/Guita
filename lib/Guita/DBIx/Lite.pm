package Guita::DBIx::Lite;
use prelude;
use parent qw(DBIx::Lite);
use Class::Load qw(load_class);

sub dsn { GuitaConf('dsn_guita') }

sub connect {
    my $class = shift;
    return $class->SUPER::connect(
        $class->dsn, undef, undef, {
            mysql_enable_utf8 => 1,
            Callbacks => { connected => \&_connect_cb },
            RootClass => 'DBIx::Sunny',
        }
    );
}

sub _connect_cb {
    my $dbh = shift;
    return;
}

sub schema {
    my $self = shift;
    return state $schema = do {
        my $schema = $self->SUPER::schema(@_);

        load_class 'Guita::Model::User';
        $schema->table('user')->class('Guita::Model::User')->autopk('id');

        load_class 'Guita::Model::Pick';
        $schema->table('pick')->class('Guita::Model::Pick')->autopk('id');

        $schema;
    };
}

sub now {
    my $self = shift;
    return DateTime->now(
        formatter => 'DateTime::Format::MySQL',
    );
}

1;
