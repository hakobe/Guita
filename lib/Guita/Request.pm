package Guita::Request;
use utf8;
use strict;
use warnings;
use parent qw(Plack::Request);
use Hash::MultiValue;
use Encode qw(decode_utf8);

use Scalar::Util qw(weaken);
sub _context {
    my ($self, $c) = @_;
    if ($c) {
        $self->{_context} = $c;
        weaken($self->{_context});
    } else {
        $self->{_context};
    }
}

sub parameters {
    my $self = shift;

    $self->env->{'plack.request.merged'} ||= do {
        my $query = $self->query_parameters;
        my $body  = $self->body_parameters;
        my $path  = $self->path_parameters;
        Hash::MultiValue->new($path->flatten, $query->flatten, $body->flatten);
    };
}

sub parameters_as_string {
    my $self = shift;
    my $hash = Hash::MultiValue->new();
    $self->parameters->each( sub { $hash->add($_[0], decode_utf8($_[1])) } );
    return $hash;
}

sub path_parameters {
    my $self = shift;

    if (@_ > 1) {
        $self->{_path_parameters} = Hash::MultiValue->new(@_);
    }

    $self->{_path_parameters} ||= Hash::MultiValue->new;
}

sub string_param {
    my ($self, $key) = @_;
    my $code = sub {
        my $str = decode_utf8($_[0]);
        defined($str) ? decode_utf8(substr($str, 0, 65536)) : ();
    };
    wantarray
        ? map { $code->($_) } $self->parameters->get_all($key)
        : $code->($self->parameters->get($key));
}

sub number_param {
    my ($self, $key) = @_;
    my $code = sub {
        my $val = shift;
        defined $val or $val = "";
        $val =~ /^[\d.]+$/ ? $val + 0 : ();
    };
    wantarray
        ? map { $code->($_) } $self->parameters->get_all($key)
        : $code->($self->parameters->get($key));
}

#sub datetime_param {
#}

sub boolean_param {
    my ($self, $key) = @_;
    !!$self->parameters->{$key};
}

sub single_splat {
    my ($self) = @_;
    return $self->path_parameters->{splat}->[0];
}

sub is_xmlhttprequest {
    my ($self) = @_;
    my $requested_with = $self->header('X-Requested-With') || '';
    $requested_with eq 'XMLHttpRequest';
}

1;
