package Guita::Handler::Auth;
use prelude;

use URI;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI::Escape qw(uri_escape);
use JSON::XS;
use Digest::SHA1 qw(sha1_hex);
use Path::Class qw(file);
use DateTime;
use DateTime::Format::HTTP;

# see http://developer.github.com/v3/oauth/

sub default {
    my ($self, $c) = @_;

    my $uri = URI->new('https://github.com/login/oauth/authorize');
    $uri->query_form(
        client_id => GuitaConf('github_client_id'),
        scope => 'user,public_repo',
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
            client_id     => GuitaConf('github_client_id'),
            client_secret => GuitaConf('github_client_secret'),
            code          => scalar($c->req->param('code')),
        ],
    ));
    $c->throw(code => 400, message => 'Bad Request: token') if $token_res->is_error;

    my ($access_token) = $token_res->content =~ m/access_token=(.*?)(?:&|$)/xms;

    # user json
    my $user_res = $ua->request(GET(
        'https://api.github.com/user?access_token=' . uri_escape($access_token),
    ));
    $c->throw(code => 400, message => 'Bad Request: user json') if $user_res->is_error;
    my $user_json = decode_json($user_res->content);

    # user keys json
    my $user_keys_res = $ua->request(GET(
        'https://api.github.com/user/keys?access_token=' . uri_escape($access_token),
    ));
    $c->throw(code => 400, message => 'Bad Request: user keys json') if $user_keys_res->is_error;
    my $user_keys_json = decode_json($user_keys_res->content);

    my $sk = sha1_hex(
        join('-', 'salt', GuitaConf('session_key_salt'), $user_json->{id}, time())
    );
    my $user = $c->dbixl->table('user')->search({ github_id => $user_json->{id} })->single;
    if ($user) {
        $user->sk($sk);
        my $struct = $user->struct;
        $struct->{api}->{user}      = $user_json;
        $struct->{api}->{user_keys} = $user_keys_json;

        $user->update({
            name   => $user_json->{login},
            sk     => $sk,
            struct => encode_json( $struct ),
        });
    }
    else {
        $user = $c->dbixl->table('user')->insert({
            github_id => $user_json->{id},
            name      => $user_json->{login},
            sk        => $sk,
            struct    => encode_json({
                api => {
                    user      => $user_json,
                    user_keys => $user_keys_json,
                }
            }),
        });
    }
    my $expires = DateTime::Format::HTTP->format_datetime(
        DateTime->now(time_zone => 'local')->add( days => 7 )
    );
    my $domain = $c->req->uri->host;
    $c->res->headers->header('Set-Cookie' => qq[csk=$sk; path=/; expires=$expires; domain=$domain;]);

    my $gitolite = Guita::Gitolite->new;
    $gitolite->add_user($user);

    $c->redirect('/');
}

sub logout {
    my ($self, $c) = @_;
    $c->throw(code => 400, message => 'Bad Request') if $c->user->is_guest;

    $c->user->update({ sk => '' });

    $c->redirect('/');
}

1;
