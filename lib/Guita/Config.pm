package Guita::Config;

use utf8;
use strict;
use warnings;

use Config::ENV 'GUITA_ENV', export => 'config';
use Path::Class;

sub root {
    my ($self) = @_;
    $self->param('root');
}

common +{
    root => file(__FILE__)->parent->parent->parent->absolute,
};

config default => {
    repository_base => file(__FILE__)->parent->parent->parent->subdir('repos')->absolute,
    dsn_guita       => 'dbi:mysql:dbname=guita;host=localhost',
};

1;
