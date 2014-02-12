package Guita::Service::Pick;
use prelude;
use parent qw(Guita::Service);

use Guita::Git;
use Path::Class;
use Fcntl qw(:flock SEEK_END);

sub collect_files_for {
    my ($self, $pick, $sha) = @_;

    my $git = Guita::Git->new_with_work_tree(
        dir(GuitaConf('repository_base'))->subdir($pick->id),
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
    my $git = Guita::Git->new_with_work_tree(
        dir(GuitaConf('repository_base'))->subdir($pick->id)->stringify,
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

    my $git = Guita::Git->new_with_work_tree(
        dir(GuitaConf('repository_base'))->subdir($pick->id)->stringify,
    );

    my $object = $git->object_for_path($sha, $path);
    return $git->cat_file($object->objectish);
}

sub create {
    my ($self, $user, $filename, $content, $description) = @_;

    my $pick = $self->dbixl->table('pick')->insert({
        user_id     => $user->id,
        description => $description,
    });

    # bare でうまいことしたいなぁ
    my $work_tree = dir(GuitaConf('repository_base'))->subdir($pick->id)->stringify;
    my $git = Guita::Git->init($work_tree);
    $git->config(qw(receive.denyCurrentBranch ignore));

    # まともなエラー処理

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

    return $pick;
}

sub edit {
    my ($self, $pick, $author, $codes, $description) = @_;
    # TODO ファイルがなくなったら削除する

    my $work_tree = dir(GuitaConf('repository_base'))->subdir($pick->id);
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

        $code =~ s/\r\n/\n/g;

        my $fh = $file->openw;
        flock($fh, LOCK_EX) or die "Cannot lock $code->{path}: $!\n";
        seek($fh, 0, SEEK_END) or die "Cannot seek - $!\n"; # ロック中になにか書き込まれてたらいけないので
        print $fh $code->{content};
        flock($fh, LOCK_UN) or die "Cannot unlock $code->{path}: $!\n";
        close $fh;

        # add して
        $git->add($file->stringify);
    }

    $git->commit('edited in guita web form', {author => $author});
}

1;
