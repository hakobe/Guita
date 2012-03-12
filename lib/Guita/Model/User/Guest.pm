package Guita::Model::User::Guest;
use strict;
use warnings;

use parent qw(Guita::Model::User);

use Guita::Utils qw(now);

use DateTime;
use DateTime::Format::MySQL;
use JSON::XS;

sub is_guest { 1 }

sub uuid { 0 }

sub github_id { -1 }

sub sk { '' }

sub sk_expires { now }

sub is_expired { 0 }

sub struct { +{} }

sub name { 'Guest' }

1;
