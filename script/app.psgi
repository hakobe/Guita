# vim:ft=perl:
use strict;
use warnings;
use lib 'lib';
use lib glob 'modules/*/lib';

use Path::Class;
use Plack::Builder;
use File::Spec;
use Cache::LRU;

use Guita;
use Guita::Config ();
use Plack::Middleware::Runtime;
use Plack::Middleware::StaticShared;

builder {
    enable "Plack::Middleware::ReverseProxy";
    enable "Plack::Middleware::Static",
    path => qr{^/(images|js|css)/},
    root => Guita::Config->param('root')->subdir('static');

    enable "Plack::Middleware::Runtime";
    enable "Plack::Middleware::StaticShared",
        cache => Cache::LRU->new(size => 10),
        base => './static/',
        binds => [
            {
                prefix       => '/.shared.js',
                content_type => 'text/javascript; charset=utf-8',
            },
            {
                prefix       => '/.shared.css',
                content_type => 'text/css; charset=utf-8',
                filter       => sub {
                    s{\s+}{ }g;
                    $_;
                }
            },
        ],
        ;

    enable "Plack::Middleware::Session";

    sub {
        Guita->new(shift)->run->res->finalize;
    };
};
