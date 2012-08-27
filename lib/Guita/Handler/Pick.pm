package Guita::Handler::Pick;
use strict;
use warnings;

use Guita::Config;
use Guita::Git;
use Guita::Mapper::DBI::User;
use Guita::Mapper::DBI::Pick;
use Guita::Mapper::Git;
use Guita::Model::User::Guest;
use Guita::Utils qw(is_valid_filename now);
use Guita::Pager;

use Path::Class;
use Try::Tiny;
use List::MoreUtils qw(each_array);
use URI::Escape;

sub default {
    my ($class, $c) = @_;
    $c->redirect('/picks');
}

sub create {
    my ($class, $c) = @_;
    if ($c->req->method eq 'POST') {
        my $filename = $c->req->string_param('name') || 'gitfile1';
        $c->throw(code => 400, message => 'Bad Parameter') unless is_valid_filename($filename);

        my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new->with($c->dbh('guita'));

        my $uuid = $pick_dbi_mapper->create_pick({
            user_id     => $c->user->uuid,
            description => ($c->req->string_param('description') || ''),
        });
        my $work_tree = dir(config->param('repository_base'))->subdir($uuid);
        $work_tree->mkpath;
        Guita::Git->run(init => $work_tree->stringify);

        my $git_mapper = Guita::Mapper::Git->new->with(Guita::Git->new(work_tree => $work_tree->stringify));
        $git_mapper->config(qw(receive.denyCurrentBranch ignore));

        # textareaの内容をファイルに書きだして
        my $file = $work_tree->file($filename);
        my $fh = $file->openw;
        my $code = scalar($c->req->string_param('code'));
        $code =~ s/\r\n/\n/g;
        print $fh $code;
        close $fh;

        # add して
        $git_mapper->add($file->stringify);

        # commit
        $git_mapper->commit('edited in guita web form', {author => $c->user});

        $c->redirect("/$uuid");
    }
    $c->html('create.html', {
        user => $c->user,
    });
}

sub edit {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;
    my $work_tree = dir(config->param('repository_base'))->subdir($c->id);
    my $git_mapper = Guita::Mapper::Git->new->with(
        Guita::Git->new(work_tree => $work_tree->stringify)
    );

    # HEADを変更するが、同時に変更が起こった場合不整合が起こる
    my $tree = $git_mapper->tree_with_children('HEAD');
    my $user_dbi_mapper = Guita::Mapper::DBI::User->new->with($c->dbh('guita'));
    my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new->with($c->dbh('guita'));
    my $pick = $pick_dbi_mapper->pick($c->id);
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    my $author = $user_dbi_mapper->user_from_uuid( $pick->user_id ) || Guita::Model::User::Guest->new;

    if ($c->req->method eq 'GET') {

        my $files = [ map { +{
            name => $_->{name}, 
            blob => $git_mapper->blob_with_contents($_->{obj}->objectish),
        } } @{ $tree->blobs_list } ];

        $c->html('edit.html', {
            user => $c->user,
            id    => $c->id,
            sha   => $c->sha,
            pick  => $pick,
            files => $files,
        });
    }
    elsif ($c->req->method eq 'POST') {
        # XXX modified を更新するのにdescriptionの変更がなくてもupdateする
        $pick->description($c->req->string_param('description') || '');
        $pick->modified(now());
        $pick_dbi_mapper->update_pick($pick);

        # TODO 変更対象のファイルをロックする
        # TODO ファイルがなくなったら削除する
        my @names = $c->req->string_param('name');
        my @codes = $c->req->string_param('code');

        my $name_generator = each_array(@names, @codes);

        $git_mapper->git->run(qw(reset --hard)); # 不要?
        while (my ($name, $code) = $name_generator->()) {
            # textareaの内容をファイルに書きだして
            my $filename = $name || 'gitfile1';
            $c->throw(code => 400, message => 'Bad Parameter') unless is_valid_filename($filename);

            my $file = $work_tree->file($filename);
            my $fh = $file->openw;
            $code =~ s/\r\n/\n/g;
            print $fh $code;
            close $fh;

            # add して
            $git_mapper->add($file->stringify);
        }
        # 最後にcommit
        $git_mapper->commit('edited in guita web form', {author => $c->user});

        $c->redirect(sprintf("/%s", $c->id));
    }
}

sub delete {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    if ($c->req->method eq 'POST') {
        my $user_dbi_mapper = Guita::Mapper::DBI::User->new->with($c->dbh('guita'));
        my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new->with($c->dbh('guita'));
        my $pick = $pick_dbi_mapper->pick($c->id);
        $c->throw(code => 404, message => 'Not Found') unless $pick;

        my $author = $user_dbi_mapper->user_from_uuid( $pick->user_id ) || Guita::Model::User::Guest->new;
        $c->throw(code => 403, message => 'Forbidden') if $author->is_guest || $c->user->uuid ne $author->uuid;

        $pick_dbi_mapper->delete_pick($pick);
    }

    $c->redirect('/picks');
}

# pick を表示
sub pick {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new->with($c->dbh('guita'));
    my $user_dbi_mapper = Guita::Mapper::DBI::User->new->with($c->dbh('guita'));
    my $pick = $pick_dbi_mapper->pick($c->id);
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    my $author = $user_dbi_mapper->user_from_uuid( $pick->user_id ) || Guita::Model::User::Guest->new;

    my $git_mapper;
    try {
        $git_mapper = Guita::Mapper::Git->new->with(
            Guita::Git->new(
                work_tree => dir(config->param('repository_base'))->subdir($c->id),
            )
        );
    };
    $c->throw(code => 404, message => 'Not Found') unless $git_mapper;

    my $logs = $git_mapper->logs(10, 'HEAD');
    my $sha = $c->sha || $logs->[0]->objectish;

    my $files = [];
    try {
        $git_mapper->traverse_tree( $sha, sub {
            my ($obj, $path) = @_;
            push @$files, +{
                name => $path,
                blob => $git_mapper->blob_with_contents($obj->objectish),
            };
        });
    };
    $c->throw(code => 404, message => 'Not Found') unless @$files;

    $c->html('pick.html', {
        user            => $c->user,
        author          => $author,
        id              => $c->id,
        sha             => $sha,
        head_sha        => $logs->[0]->objectish,
        pick            => $pick,
        files           => $files,
        logs            => $logs,
        repository_url  => config->param('remote_repository_base') . '/' . $c->id,
    });
}

sub raw {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;
    $c->throw(code => 404, message => 'Not Found') unless $c->sha;
    $c->throw(code => 404, message => 'Not Found') unless $c->filename;

    my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new->with($c->dbh('guita'));
    my $pick = $pick_dbi_mapper->pick($c->id);
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    my $git_mapper;
    try {
        my $work_tree = dir(config->param('repository_base'))->subdir($c->id);
        $git_mapper = Guita::Mapper::Git->new->with(
            Guita::Git->new(work_tree => $work_tree->stringify)
        );
    };
    $c->throw(code => 404, message => 'Not Found') unless $git_mapper;

    my $tree;
    try {
        $tree = $git_mapper->tree_with_children($c->sha);
    };
    $c->throw(code => 404, message => 'Not Found') unless $tree;

    $c->throw(code => 404, message => 'Not Found') unless $tree->blobs->{$c->filename};
    my $blob = $git_mapper->blob_with_contents($tree->blobs->{$c->filename}->objectish);

    $c->text($blob->contents);
}

sub star_count {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new->with($c->dbh('guita'));
    my $user_dbi_mapper = Guita::Mapper::DBI::User->new->with($c->dbh('guita'));
    my $pick = $pick_dbi_mapper->pick($c->id);
    $c->throw(code => 404, message => 'Not Found') unless $pick;

    my $author = $pick_dbi_mapper->user_from_uuid( $pick->user_id ) || Guita::Model::User::Guest->new;

    if ($c->req->method eq 'POST') {
        $pick->star_count( $pick->star_count + ($c->req->param('count') || 1) );
        $pick_dbi_mapper->update_pick($pick);
    }
    $c->json({
        star_count => $pick->star_count,
    });
}

sub picks {
    my ($class, $c) = @_;

    my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new->with($c->dbh('guita'));
    my $user_dbi_mapper = Guita::Mapper::DBI::User->new->with($c->dbh('guita'));
    my $pager = Guita::Pager->new({
        count    => $pick_dbi_mapper->picks_count,
        per_page => 10,
        page     => $c->req->number_param('page') || 1,
    });

    my $author = $user_dbi_mapper->user_from_name($c->username) if $c->username;
    my $recents = [ map { 
        my $pick = $_;
        my $work_tree = dir(config->param('repository_base'))->subdir($pick->uuid);
        my $git_mapper = Guita::Mapper::Git->new->with(
            Guita::Git->new(work_tree => $work_tree->stringify)
        );
        my $tree = $git_mapper->tree_with_children('HEAD');

        my $blob_with_name = $tree->blobs_list->[0];
        $blob_with_name ? +{
            pick   => $pick,
            author => ($user_dbi_mapper->user_from_uuid($pick->user_id) || Guita::Model::User::Guest->new),
            name   => $blob_with_name->{name},
            blob   => $git_mapper->blob_with_contents($blob_with_name->{obj}->objectish),
        } : ()
    } @{ 
        $author ? $pick_dbi_mapper->picks_for_user($author, {offset => $pager->offset, limit => $pager->limit})
                : $pick_dbi_mapper->picks({offset => $pager->offset, limit => $pager->limit})
                ;
    } ];

    $c->html('picks.html', {
        user    => $c->user,
        author  => $author,
        recents => $recents,
        pager   => $pager,
    });
}


sub mine {
    my ($class, $c) = @_;
    $c->user ? $c->redirect('/'.uri_escape($c->user->name)) : $c->redirect('/picks');
}

1;
