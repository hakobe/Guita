package Guita::Model::Git::Object::Blob;
use strict;
use warnings;
use parent qw(Guita::Model::Git::Object::Base);

use Class::Accessor::Lite (
    ro => [qw(content)],
);

sub is_blob { 1 }

1;
