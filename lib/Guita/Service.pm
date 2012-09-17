package Guita::Service;
use prelude;

use Guita::DataBase;

use Class::Accessor::Lite (
    new => 1,
);

sub dbixl {
    Guita::DataBase->instance->dbixl;
};

1;
