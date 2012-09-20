package Guita::Service::Pick;
use prelude;
use parent qw(Guita::Service);

use Guita::Git;
use Guita::Gitolite;
use Path::Class;

sub collect_files_for {
    my ($self, $pick, $sha) = @_;

    my $git = Guita::Git->new_with_git_dir(
        dir(GuitaConf('repository_base'))->subdir($pick->id . '.git'),
    );
    return unless $git;

    my $files = [];
    try {
        $git->traverse_tree( $sha, sub {
            my ($obj, $path) = @_;
            push @$files, +{ # Fileオブジェクトにする
                name => $path,
                blob => $git->blob_with_contents($obj->objectish),
            };
        });
    }
    catch {
        warn $_;
    };
    return unless @$files; # 例外返す

    return $files;
}

sub fill_from_git {
    my ($self, $pick, $sha) = @_;
    return unless $pick;

    my $author = $self->dbixl->table('user')->search({ id => $pick->user_id })->single
        || Guita::Model::User::Guest->new;

    # work_treeの存在チェック?
    my $git = Guita::Git->new_with_git_dir(
        dir(GuitaConf('repository_base'))->subdir($pick->id . '.git'),
    );
    my $logs = $git->logs(10, 'HEAD');
    $sha ||= $logs->[0]->objectish;

    $pick->author($author);
    $pick->logs($logs);
    $pick->files($self->collect_files_for($pick, $sha));

    return $pick;
}

sub fill_user {
    my ($self, $pick) = @_;
    return unless $pick;

    my $author = $self->dbixl->table('user')->search({ id => $pick->user_id })->single
        || Guita::Model::User::Guest->new;

    $pick->author($author);

    return $pick;
}

sub file_content_at {
    my ($self, $pick, $sha, $path) = @_;
    return unless $pick;

    my $git = Guita::Git->new_with_git_dir(
        dir(GuitaConf('repository_base'))->subdir($pick->id . '.git')->stringify,
    );

    my $object = $git->object_for_path($sha, $path);
    return $git->cat_file($object->objectish);
}

sub create {
    my ($self, $user, $filename, $content, $description) = @_;
    # asert

    my $pick = $self->dbixl->table('pick')->insert({
        user_id     => $user->id,
        description => $description,
    });

    my $gitolite = Guita::Gitolite->new;
    $gitolite->add_repository($user, $pick->id, [$user]);

    my $work_tree = dir(GuitaConf('working_base'))->subdir($pick->id)->stringify;
    my $git = Guita::Git->clone('yohei@gitolite:' . $pick->id, $work_tree);

    # textareaの内容をファイルに書きだして
    my $file = dir($work_tree)->file($filename);
    my $fh = $file->openw;
    $content = $content . ''; # copy
    $content =~ s/\r\n/\n/g;
    print $fh $content;
    close $fh;

    # add して
    $git->add($file->stringify);

    # commit
    $git->commit('edited in guita web form', {author => $user});
    $git->run(qw( push -f origin master));

    return $pick;
}

sub edit {
    my ($self, $pick, $codes, $description) = @_;
    # TODO 変更対象のファイルをロックする
    # TODO ファイルがなくなったら削除する

    my $work_tree = dir(GuitaConf('working_base'))->subdir($pick->id);
    my $git = Guita::Git->new_with_work_tree($work_tree->stringify);

    # XXX modified を更新するのにdescriptionの変更がなくてもupdateする
    $pick->update({
        description => $description,
        modified    => $self->dbixl->now(),
    });

    $git->run(qw(reset --hard)); # 不要?

    for my $code (@$codes) {
        my $file = $work_tree->file($code->{path});
        next unless -e $file;

        my $fh = $file->openw;
        $code =~ s/\r\n/\n/g;
        print $fh $code->{content};
        close $fh;

        # add して
        $git->add($file->stringify);
    }

    $git->commit('edited in guita web form', {author => $pick->author});
    $git->run(qw( push -f origin master));

    return $pick;
}

sub fork {
    my ($self, $base_pick, $user) = @_;

    my $pick = $self->dbixl->table('pick')->insert({
        user_id        => $user->id,
        description    => $base_pick->description,
        parent_pick_id => $base_pick->id,
    });

    my $gitolite = Guita::Gitolite->new;
    $gitolite->add_repository($user, $pick->id, [$user]);

    my $base_git = Guita::Git->new_with_git_dir($base_pick->repository_path);
    $base_git->run(qw( push --all), 'yohei@gitolite:'.$pick->id);

    return $pick;
}

1;
