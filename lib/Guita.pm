package Guita;

use strict;
use warnings;

use Guita::Base; # route
use parent qw(Guita::Base);

our @EXPORT = qw(config);

use Guita::Pick;

route "/"              => "Guita::Pick default";
route "/picks"         => "Guita::Pick picks";
route "/picks/create"  => "Guita::Pick create";
route "/mine"          => "Guita::Pick mine";

route "/auth"          => "Guita::Auth";
route "/auth/callback" => "Guita::Auth callback";
route "/auth/logout"   => "Guita::Auth logout";

route "/:id"                => "Guita::Pick pick";
route "/:id/:sha"           => "Guita::Pick pick";
route "/:id/:sha/-/edit"    => "Guita::Pick edit";
route "/:id/:sha/-/delete"  => "Guita::Pick delete";
route "/:id/:sha/:filename" => "Guita::Pick raw";


1;
__END__
