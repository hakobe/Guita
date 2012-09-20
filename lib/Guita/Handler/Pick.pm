package Guita::Handler::Pick;
use prelude;

use Guita::Git;
use Guita::Model::User::Guest;
use Guita::Service::Pick;
use Guita::Service::PickList;
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
    $c->throw(code => 405, message => 'Method not Allowed')
        if $c->req->method !~ m/^GET|POST$/xms;

    if ($c->req->method eq 'GET') {
        $c->html('create.html', {
            user => $c->user,
        });
    }
    elsif ($c->req->method eq 'POST') {
        my $filename = $c->req->string_param('name') || 'guitafile';
        $c->throw(code => 400, message => 'Bad Parameter') unless is_valid_filename($filename);

        my $pick_service = Guita::Service::Pick->new( dbh => $c->dbh('guita') );
        my $pick = $pick_service->create(
            $c->user,
            $filename,
            $c->req->string_param('code') || '',
            $c->req->string_param('description') || '',
        );

        $c->redirect("/".$pick->id);
    }
}

sub edit {
    my ($class, $c) = @_;
    $c->throw(code => 405, message => 'Method not Allowed')
        if $c->req->method !~ m/^GET|POST$/xms;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $pick = $c->dbixl->table('pick')->search({ id => $c->id })->single;
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    my $pick_service = Guita::Service::Pick->new;
    $pick_service->fill_from_git($pick, $c->sha);
    $pick_service->fill_user($pick);

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

        $pick_service->edit(
            $pick,
            \@codes,
            $c->req->string_param('description') || '',
        );

        $c->redirect(sprintf("/%s", $pick->id));
    }
}

sub fork {
    my ($class, $c) = @_;
    $c->throw(code => 405, message => 'Method not Allowed')
        if $c->req->method !~ m/^POST$/xms;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $base_pick = $c->dbixl->table('pick')->search({ id => $c->id })->single;
    $c->throw(code => 404, message => 'Not Found') unless $base_pick;

    my $pick_service = Guita::Service::Pick->new;
    $pick_service->fill_user($base_pick);

    if ($c->req->method eq 'POST') {
        my $pick = $pick_service->fork(
            $base_pick,
            $c->user,
        );

        $c->redirect(sprintf("/%s", $pick->id));
    }
}

sub delete {
    my ($class, $c) = @_;
    $c->throw(code => 405, message => 'Method not Allowed')
        if $c->req->method !~ m/^POST$/xms;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    if ($c->req->method eq 'POST') {
        my $pick_service = Guita::Service::Pick->new;

        my $pick = $c->dbixl->table('pick')->search({ id => $c->id })->single;
        $c->throw(code => 404, message => 'Not Found') unless $pick;

        $pick_service->fill_user($pick);
        $c->throw(code => 403, message => 'Forbidden') if $pick->author->is_guest || $c->user->id ne $pick->author->id;

        $pick->delete;
        $c->redirect('/picks');
    }
}

# pick を表示
sub pick {
    my ($class, $c) = @_;
    $c->throw(code => 405, message => 'Method not Allowed')
        if $c->req->method !~ m/^GET$/xms;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $pick = $c->dbixl->table('pick')->search({ id => $c->id})->single;
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    my $pick_service = Guita::Service::Pick->new;
    $pick_service->fill_user($pick);
    $pick_service->fill_from_git($pick, $c->sha);

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
    $c->throw(code => 405, message => 'Method not Allowed')
        if $c->req->method !~ m/^GET$/xms;

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
    $c->throw(code => 405, message => 'Method not Allowed')
        if $c->req->method !~ m/^GET$/xms;

    my $page = $c->req->number_param('page');
    my $pager = Guita::Pager->new({
        count    => $c->dbixl->table('pick')->select->count,
        per_page => 10,
        page     => ($page && $page =~ m/^\d+$/xms) ? $page : 1,
    });

    my $picks = Guita::Service::PickList->new->list({
        limit  => $pager->limit,
        offset => $pager->offset,
    });

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
