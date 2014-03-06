package Guita::Service;
use prelude;

use Guita::DataBase;

sub dbixl {
    Guita::DataBase->instance->dbixl;
};

1;
