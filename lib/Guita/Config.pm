package Guita::Config;

use utf8;
use strict;
use warnings;
use v5.14;

use Exporter::Lite;
our @EXPORT = qw(config);
use Path::Class;

sub new {
    my ($class) = @_;
    my $config = do $class->root->file('config.pl')->stringify;
    my $self = bless {
        config => $config,
    }, $class;
    $self;
}

sub config {
    state $instance = __PACKAGE__->new;
}

sub param {
    my ($self, $key) = @_;
    $self->{config}->{$key};
}

sub root {
    my ($class) = @_;
    state $root = file(__FILE__)->parent->parent->parent->absolute,
}


1;
