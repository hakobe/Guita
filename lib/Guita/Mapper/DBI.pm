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


1;
