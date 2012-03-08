package Guita::Git;
use strict;
use warnings;

use parent qw(Git::Repository);
use Git::Repository 'Log';

# XXX 
# Git::Repository::Log の振る舞いを修正
# Model::Git::Object::Commit とかを用紙すべき
package Git::Repository::Log;
no warnings 'redefine';
use Encode;

sub parent { $_[0]{parent}; }
sub message { decode_utf8 ($_[0]{message}); }
sub objectish { $_[0]{commit}; }

1;
__END__
