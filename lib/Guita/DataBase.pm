package Guita::DataBase;
use prelude;

use DBIx::Lite;

use Guita::DBIx::Lite;

use Class::Accessor::Lite::Lazy (
    new => 1,
);

my $INSTANCE;
sub instance {
    my ($class) = @_;
    $INSTANCE ||= $class->new;
}

my $MAYBE_CONNECTED;
sub dbixl {
    my ($self) = @_;
    my $dbixl = Guita::DBIx::Lite->new;
    $MAYBE_CONNECTED = 1;
    $dbixl->connect;
}

sub DESTROY {
    my ($self) = @_;

    if ($MAYBE_CONNECTED) {
        try {
            my $connector = $self->dbixl->{connector};
            $connector->disconnect if $connector;
        }
        catch {
            warn "error while disconnecting : $_";
        };
    }
}

1;
