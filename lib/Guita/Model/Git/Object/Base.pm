package Guita::Model::Git::Object::Base;
use strict;
use warnings;

use Class::Accessor::Lite (
    new => 1,
    ro => [qw(
        contents objectish size type mode name
    )],
);

sub is_tree   { 0 };
sub is_blob   { 0 };
sub is_commit { 0 };

1;
__END__
