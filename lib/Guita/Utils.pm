package Guita::Utils;
use strict;
use warnings;

use Exporter::Lite;
use DateTime;
use DateTime::Format::MySQL;

our @EXPORT_OK = qw(now is_valid_filename);

sub now () {
    DateTime->now(time_zone => 'local')
            ->set_formatter( DateTime::Format::MySQL->new );
}

sub is_valid_filename {
    my ($filename) = @_;
    $filename =~ m/^(?!\.)[a-zA-Z0-9\._-]+/xms;
}


1;
