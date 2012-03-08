package Guita::Pick;
use strict;
use warnings;

use Guita::Config;
use Guita::Git;
use Guita::Mapper::Git;
use Path::Class;
use Try::Tiny;

use SQL::NamedPlaceholder;

sub default {
    my ($class, $c) = @_;
    $c->redirect('/picks/create');
}

# pick をつくる
sub create {
    my ($class, $c) = @_;
    if ($c->req->method eq 'POST') {
        my $uuid = $c->uuid_short('guita');
        my ($sql, $bind) = SQL::NamedPlaceholder::bind_named(
            q[
                INSERT INTO pick
                SET
                    uuid = :uuid,
                    user = :user
            ],
            {
                uuid => $uuid,
                user => 'hakobe',
            },
        );
        $c->dbh('guita')->prepare_cached($sql)->execute(@$bind);

        my $work_tree = config->param('repository_base')->subdir($uuid);
        $work_tree->mkpath;
        Guita::Git->run(init => $work_tree->stringify);

        my $git_mapper = Guita::Mapper::Git->new->with(Guita::Git->new(work_tree => $work_tree->stringify));

        # textareaの内容をファイルに書きだして
        my $file = $work_tree->file($c->req->string_param('name') || 'gitfile1');
        my $fh = $file->openw;
        print $fh scalar($c->req->string_param('code'));
        close $fh;

        # add して
        $git_mapper->add($file->stringify);

        # commit
        $git_mapper->commit('from guita');

        $c->redirect("/$uuid");
    }
    $c->html('create.html');
}

sub edit {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $work_tree = config->param('repository_base')->subdir($c->id);
    my $git_mapper = Guita::Mapper::Git->new->with(
        Guita::Git->new(work_tree => $work_tree->stringify)
    );

    if ($c->sha eq 'HEAD') {
        my $resolved_sha = $git_mapper->rev_parse($c->sha);
        $c->redirect(sprintf("/%s/%s/edit", $c->id, $resolved_sha));
        return;
    }

    if ($c->req->method eq 'GET') {
        my $tree = $git_mapper->tree_with_children('HEAD'); # とはいえHEADしか編集できない

        my $pick = $c->single(
            db => 'guita',
            class => 'Guita::Model::Pick',
            sql => 'SELECT * FROM pick WHERE uuid = :uuid',
            bind => { uuid => $c->id },
        );
        $c->throw(code => 404, message => 'Not Found') unless $pick;

        my $files = [ map { +{
            name => $_->{name}, 
            blob => $git_mapper->blob_with_contents($_->{obj}->objectish),
        } } @{ $tree->blobs_list } ];

        $c->html('edit.html', {
            id    => $c->id,
            sha   => $c->sha,
            pick  => $pick,
            files => $files,
        });
    }
    elsif ($c->req->method eq 'POST') {
        # TODO 変更対象のファイルをロックする

        # textareaの内容をファイルに書きだして
        my $file = $work_tree->file($c->req->string_param('name') || 'gitfile1');
        my $fh = $file->openw;
        print $fh scalar($c->req->string_param('code'));
        close $fh;

        # add して
        $git_mapper->add($file->stringify);

        # commit
        $git_mapper->commit('from pick');

        $c->redirect(sprintf("/%s", $c->id));
    }
}

# pick を表示
sub pick {
    my ($class, $c) = @_;

    $c->throw(code => 404, message => 'Not Found') unless $c->id;

    my $pick = $c->single(
        db => 'guita',
        class => 'Guita::Model::Pick',
        sql => 'SELECT * FROM pick WHERE uuid = :uuid',
        bind => { uuid => $c->id },
    );

    my $work_tree = config->param('repository_base')->subdir($c->id);
    my $git_mapper = Guita::Mapper::Git->new->with(
        Guita::Git->new(work_tree => $work_tree->stringify)
    );
    my $tree;
    try {
        $tree = $git_mapper->tree_with_children($c->sha);
    }
    catch {
        warn $_;
    };
    $c->throw(code => 404, message => 'Not Found') unless $tree;

    my $files = [ map { +{
        name => $_->{name}, 
        blob => $git_mapper->blob_with_contents($_->{obj}->objectish),
    } } @{ $tree->blobs_list } ];

    $c->html('pick.html', {
        id    => $c->id,
        sha   => $c->sha,
        pick  => $pick,
        files => $files,
        logs  => $git_mapper->logs(20, 'HEAD'),
    });
}

sub picks {
    my ($class, $c) = @_;

    my $recents = [ map { 
        my $pick = $_;
        my $work_tree = config->param('repository_base')->subdir($pick->uuid);
        my $git_mapper = Guita::Mapper::Git->new->with(
            Guita::Git->new(work_tree => $work_tree->stringify)
        );
        my $tree = $git_mapper->tree_with_children('HEAD');

        my $blob_with_name = $tree->blobs_list->[0];
        +{
            pick => $pick,
            name => $blob_with_name->{name},
            blob => $git_mapper->blob_with_contents($blob_with_name->{obj}->objectish),
        }
    } @{ $c->array(
        db    => 'guita',
        class => 'Guita::Model::Pick',
        sql   => 'SELECT * FROM pick ORDER BY created desc LIMIT 5',
    ) } ];

    $c->html('picks.html', {
        recents => $recents,
    });
}


sub mine {
    my ($class, $c) = @_;
}

1;
