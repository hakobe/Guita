use inc::Module::Install;

name    'Guita';
version '0.00';
license 'in-company'; 

requires 'Module::Install';
requires 'Plack';
requires 'Plack::Session';
requires 'Plack::Middleware::StaticShared';
requires 'Plack::Middleware::ReverseProxy';
requires 'Starlet';

requires 'parent';
requires 'DBI';
requires 'DBD::mysql';
requires 'Path::Class';
requires 'File::Spec';
requires 'Class::Accessor::Lite';
requires 'Class::Accessor::Lite::Lazy';
requires 'Encode';
requires 'DateTime';
requires 'DateTime::Format::MySQL';
requires 'JSON::XS';
requires 'Exporter::Lite';
requires 'Class::Load';
requires 'Try::Tiny';
requires 'URI';
requires 'URI::Escape';
requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';
requires 'Scalar::Util';
requires 'SQL::NamedPlaceholder';
requires 'List::Util';
requires 'List::MoreUtils';
requires 'Hash::MultiValue';
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';
requires 'HTTP::Request';
requires 'HTTP::Request::Common';
requires 'Hash::MultiValue';
requires 'HTML::Trim';
requires 'Git::Repository';
requires 'Digest::SHA1';
requires 'Data::Dumper';
requires 'Config::ENV';
requires 'Router::Simple';
requires 'Devel::KYTProf';

requires 'DBIx::Lite';
requires 'DBIx::Sunny';

WriteAll;
