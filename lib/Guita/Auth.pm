package Guita::Auth;
use strict;
use warnings;

use Guita::Config;
use Guita::Mapper::DBI;

use URI;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI::Escape qw(uri_escape);
use JSON::XS;
use Digest::SHA1 qw(sha1_hex);

# see http://developer.github.com/v3/oauth/

sub default {
    my ($self, $c) = @_;

    my $uri = URI->new('https://github.com/login/oauth/authorize');
    $uri->query_form(
        client_id    => config->param('github_client_id'),
    );

    $c->redirect($uri->as_string);
}

sub callback {
    my ($self, $c) = @_;

    $c->throw(code => 400, message => 'Bad Request') unless $c->req->param('code');

    my $ua = LWP::UserAgent->new;
    my $token_res = $ua->request(POST(
        'https://github.com/login/oauth/access_token', 
        [
            client_id     => config->param('github_client_id'),
            client_secret => config->param('github_client_secret'),
            code          => scalar($c->req->param('code')),
        ],
    ));

    $c->throw(code => 400, message => 'Bad Request') if $token_res->is_error;

    my ($access_token) = $token_res->content =~ m/access_token=(.*?)(?:&|$)/xms;
    my $user_res = $ua->request(GET(
        'https://api.github.com/user?access_token=' . uri_escape($access_token),
    ));
    $c->throw(code => 400, message => 'Bad Request') if $user_res->is_error;

    my $user_json = decode_json($user_res->content);
    $c->throw(code => 400, message => 'Bad Request') if !($user_json && $user_json->{id});

    my $sk = sha1_hex(
        join('-', 'salt', config->param('session_key_salt'), $user_json->{id}, time())
    );
    my $dbi_mapper = Guita::Mapper::DBI->new->with($c->dbh('guita'));
    my $user = $dbi_mapper->user_from_github_id($user_json->{id});
    if ($user) {
        $user->sk($sk);
        $dbi_mapper->update_user($user);
    }
    else {
        $dbi_mapper->create_user({
            github_id => $user_json->{id},
            sk        => $sk,
            struct    => $user_json,
        });
    }
    $c->res->headers->push_header('Set-Cookie' => "sk=$sk; path=/");

    $c->redirect('/');
}

sub logout {
    my ($self, $c) = @_;
    $c->throw(code => 400, message => 'Bad Request') if $c->user->is_guest;

    my $dbi_mapper = Guita::Mapper::DBI->new->with($c->dbh('guita'));
    $c->user->sk('');
    $dbi_mapper->update_user($c->user);
    $c->res->headers->push_header('Set-Cookie' => "sk=; path=/");

    $c->redirect('/');
}

1;
