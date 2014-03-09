package Guita::Service::Pick;
use prelude;
use parent qw(Guita::Service);

sub find_user_by_name {
    my ($class, $name) = @_;

    return $class->dbixl->table('user')->search({
        name => $name,
    })->single
}

1;
