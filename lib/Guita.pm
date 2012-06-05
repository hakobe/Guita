package Guita;

use strict;
use warnings;

use Guita::Base; # route
use parent qw(Guita::Base);

our @EXPORT = qw(config);

use Guita::Pick;

route "/"                => "Guita::Pick default";
route "/picks"           => "Guita::Pick picks";
route "/picks/-/create"  => "Guita::Pick create";
route "/mine"            => "Guita::Pick mine";

route "/auth"          => "Guita::Auth";
route "/auth/callback" => "Guita::Auth callback";
route "/auth/logout"   => "Guita::Auth logout";

route "/{id:[0-9]+}"                => "Guita::Pick pick";
route "/{id:[0-9]+}/:sha"           => "Guita::Pick pick";
route "/{id:[0-9]+}/:sha/-/edit"    => "Guita::Pick edit";
route "/{id:[0-9]+}/:sha/-/delete"  => "Guita::Pick delete";
route "/{id:[0-9]+}/:sha/:filename" => "Guita::Pick raw";

route "/api/pick/{id:[0-9]+}/-/star_count"  => "Guita::Pick star_count";

route "/:username"       => "Guita::Pick picks";

1;
__END__
