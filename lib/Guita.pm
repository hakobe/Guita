package Guita;

use strict;
use warnings;

use Guita::Base; # route
use parent qw(Guita::Base);

our @EXPORT = qw(config);

route "/"                => "Guita::Handler::Pick default";
route "/picks"           => "Guita::Handler::Pick picks";
route "/picks/-/create"  => "Guita::Handler::Pick create";
route "/mine"            => "Guita::Handler::Pick mine";

route "/auth"          => "Guita::Handler::Auth";
route "/auth/callback" => "Guita::Handler::Auth callback";
route "/auth/logout"   => "Guita::Handler::Auth logout";

route "/{id:[0-9]+}"                => "Guita::Handler::Pick pick";
route "/{id:[0-9]+}/:sha"           => "Guita::Handler::Pick pick";
route "/{id:[0-9]+}/:sha/-/edit"    => "Guita::Handler::Pick edit";
route "/{id:[0-9]+}/:sha/-/delete"  => "Guita::Handler::Pick delete";
route "/{id:[0-9]+}/:sha/:filename" => "Guita::Handler::Pick raw";

route "/:username"       => "Guita::Handler::Pick picks";

1;
__END__
