package Guita::Views;

use utf8;
use strict;
use warnings;

use Exporter::Lite;
our @EXPORT = qw(html redirect render);

use Guita::Config;

use Text::Xslate qw(mark_raw);
use Encode;
use Data::Dumper;
use HTML::Trim;
use DateTime;

my $XSLATE = Text::Xslate->new(
    syntax => 'TTerse',
    module => [
        'Text::Xslate::Bridge::TT2Like'
    ],
    path   => [
        config->root->subdir('templates')
    ],
    cache_dir => '/tmp/guitacache',
    cache     => 1,
    function  => {
        trim => sub {
            my ($text, $n) = @_;
            HTML::Trim::vtrim($text || '', $n, "…");
        },
        uri_for => sub {
            my ( $path, $args ) = @_;
            my $uri = Text::Xslate->current_vars->{base}->clone;
            $path =~ s|^/||;
            $uri->path( $uri->path . $path );
            $uri->query_form(@$args) if $args;
            $uri;
        },
        short_sha1 => sub {
            my $sha1 = shift;
            return unless $sha1;
            substr $sha1, 0, 11;
        },
        datetime_epoch => sub {
            my $epoch = shift;
            DateTime->from_epoch(epoch => $epoch).q();
        },
        strip => sub {
            my ($text, $length) = @_;
            $length ||= 140;

            return $text if length($text) <= ($length - 3);

            my $result = substr $text, 0, $length;
            "$result\n...";
        },
        dump => sub {
            local $Data::Dumper::Varname = '';
            local $Data::Dumper::Sortkeys = 1;
            Dumper(shift);
        }
    },
);

sub render {
    my ($self, $name, $vars) = @_;
    $vars ||= {};
    $vars->{r} = $self;
    $vars->{base} = $self->req->base;

    my $content = $XSLATE->render($name, $vars);
}

sub html {
    my ($self, $name, $vars) = @_;
    my $content = $self->render($name, $vars);

    $self->res->content_type('text/html; charset=utf-8');
    $self->res->content(encode_utf8 $content);
}

sub redirect {
    my ($self, $location) = @_;
    $self->res->code(302);
    $self->res->header('Location' => $location);
}

1;
