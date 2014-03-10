package Guita::Handler::Pick;
use prelude;

use Guita::Model::User::Guest;
use Guita::Service::Pick;
use Guita::Service::User;
use Guita::Pager;
use Guita::Utils qw(is_valid_filename now);

use Path::Class;
use List::MoreUtils qw(each_array);
use URI::Escape;

sub default {
    my ($class, $c) = @_;
    $c->redirect('/picks');
}

sub create {
    my ($class, $c) = @_;
    $c->redirect('/auth?auth_location=/picks/-/create') if $c->user->is_guest;

    if ($c->req->method eq 'POST') {
        my $filename = $c->req->string_param('name') || 'guitafile';
        $c->throw(code => 400, message => 'Bad Parameter') unless is_valid_filename($filename);

        my $pick = Guita::Service::Pick->create(
            $c->user,
            $filename,
            $c->req->string_param('code') || '',
            $c->req->string_param('description') || '',
        );

        $c->redirect("/".$pick->id);
    }
    $c->html('create.html', {
        user => $c->user,
    });
}

sub edit {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    # HEADを変更するが、同時に変更が起こった場合不整合が起こる
    my $pick = $c->dbixl->table('pick')->search({ id => $c->id })->single;
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    Guita::Service::Pick->fill_from_git($pick, $c->sha);
    Guita::Service::Pick->fill_users([$pick]);

    $c->throw(code => 403, message => 'Forbidden')
        if $c->user->is_guest || $pick->author->id != $c->user->id;

    if ($c->req->method eq 'GET') {
        $c->html('edit.html', {
            user => $c->user,
            id    => $c->id,
            sha   => $c->sha,
            pick  => $pick,
        });
    }
    elsif ($c->req->method eq 'POST') {
        my @paths = $c->req->string_param('name');
        my @contents = $c->req->string_param('code');

        my $code_generator = each_array(@paths, @contents);
        my @codes;
        while (my ($path, $content) = $code_generator->()) {
            push @codes, { path => $path, content => $content };
        }

        Guita::Service::Pick->edit(
            $pick,
            $c->user,
            \@codes,
            $c->req->string_param('description') || '',
        );

        $c->redirect(sprintf("/%s", $pick->id));
    }
}

sub delete {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    if ($c->req->method eq 'POST') {
        my $pick = $c->dbixl->table('pick')->search({ id => $c->id })->single;
        $c->throw(code => 404, message => 'Not Found') unless $pick;

        Guita::Service::Pick->fill_users([$pick]);
        $c->throw(code => 403, message => 'Forbidden') if $pick->author->is_guest || $c->user->id ne $pick->author->id;

        $pick->delete;
    }

    $c->redirect('/picks');
}

# pick を表示
sub pick {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $pick = $c->dbixl->table('pick')->search({ id => $c->id})->single;
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    Guita::Service::Pick->fill_users([$pick]);
    Guita::Service::Pick->fill_from_git($pick, $c->sha);

    $c->html('pick.html', {
        user            => $c->user,
        id              => $c->id,
        sha             => $c->sha || $pick->logs->[0]->objectish,
        head_sha        => $pick->logs->[0]->objectish,
        pick            => $pick,
        repository_url  => GuitaConf('remote_repository_base') . '/' . $c->id,
    });
}

sub raw {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;
    $c->throw(code => 404, message => 'Not Found') unless $c->sha;
    $c->throw(code => 404, message => 'Not Found') unless $c->filename;

    my $pick = $c->dbixl->table('pick')->search({ id => $c->id })->single;
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    my $content = Guita::Service::Pick->new->file_content_at(
        $pick,
        $c->sha,
        $c->filename,
    );

    $c->text($content);
}

sub picks {
    my ($class, $c) = @_;

    my $page = $c->req->number_param('page');
    my $pager = Guita::Pager->new({
        count    => Guita::Service::Pick->count,
        per_page => 10,
        page     => ($page && $page =~ m/^\d+$/xms) ? $page : 1,
    });

    my $picks = Guita::Service::Pick->list({
        limit  => $pager->limit,
        offset => $pager->offset,
    });
    Guita::Service::Pick->fill_users([ map { $_->{pick}} @$picks ]);


    $c->html('picks.html', {
        user    => $c->user,
        recents => $picks,
        pager   => $pager,
    });
}

sub picks_for_user {
    my ($class, $c) = @_;
    $c->throw(code => 404, message => 'Not Found') unless $c->username;

    my $user = Guita::Service::User->find_user_by_name( $c->username );
    $c->throw(code => 404, message => 'Not Found') unless $user;

    my $page = $c->req->number_param('page');
    my $pager = Guita::Pager->new({
        count    => Guita::Service::Pick->count_for_user($user->id),
        per_page => 10,
        page     => ($page && $page =~ m/^\d+$/xms) ? $page : 1,
    });

    my $picks = Guita::Service::Pick->list_for_user({
        user_id => $user->id,
        limit   => $pager->limit,
        offset  => $pager->offset,
    });
    Guita::Service::Pick->fill_users([ map { $_->{pick}} @$picks ]);


    $c->html('picks.html', {
        user    => $c->user,
        recents => $picks,
        pager   => $pager,
    });
}

sub mine {
    my ($class, $c) = @_;
    $c->user ? $c->redirect('/'.uri_escape($c->user->name)) : $c->redirect('/picks');
}

1;
