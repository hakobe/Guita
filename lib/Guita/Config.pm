package Guita::Config;

use utf8;
use strict;
use warnings;
use v5.14;

use Exporter::Lite;
our @EXPORT = qw(config GuitaConf);
use Path::Class;
use TOML qw(from_toml);
use Carp qw(croak);

sub new {
    my ($class) = @_;
    my $config_file = $class->root->file('config.toml');

    my ($config, $error) = from_toml scalar($config_file->slurp);
    if ($error) {
        croak qq|Cannot load config file "@{[ $config_file->stringify ]}" : $error|;
    }

    my $self = bless {
        config => $config,
    }, $class;
    $self;
}

sub GuitaConf {
    config()->param($_[0]);
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
