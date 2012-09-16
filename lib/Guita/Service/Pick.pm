package Guita::Service::Pick;
use strict;
use warnings;

use Guita::Config;
use Guita::Git;
use Guita::Mapper::DBI::Pick;
use Guita::Mapper::DBI::User;

use Path::Class;
use Try::Tiny;

use Class::Accessor::Lite (
    new => 1,
);

sub collect_files_for {
    my ($self, $pick, $sha) = @_;

    my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new;

    my $git_mapper = Guita::Mapper::Git->new_with_work_tree(
        dir(config->param('repository_base'))->subdir($pick->uuid),
    );
    return unless $git_mapper;

    my $files = [];
    try {
        $git_mapper->traverse_tree( $sha, sub {
            my ($obj, $path) = @_;
            push @$files, +{ # Fileオブジェクトにする
                name => $path,
                blob => $git_mapper->blob_with_contents($obj->objectish),
            };
        });
    }
    catch {
        warn $_;
    };
    return unless @$files; # 例外返す

    return $files;
}

sub expande_pick {
    my ($self, $pick, $sha) = @_;
    return unless $pick;

    my $author = Guita::Mapper::DBI::User->new->user_from_uuid( $pick->user_id ) 
        || Guita::Model::User::Guest->new;

    # work_treeの存在チェック?
    my $git_mapper = Guita::Mapper::Git->new_with_work_tree(
        dir(config->param('repository_base'))->subdir($pick->uuid)->stringify,
    );
    my $logs = $git_mapper->logs(10, 'HEAD');
    $sha ||= $logs->[0]->objectish;

    $pick->author($author);
    $pick->logs($logs);
    $pick->files($self->collect_files_for($pick, $sha));

    return $pick;
}

sub retrieve_file_content {
    my ($self, $pick, $sha, $path) = @_;
    return unless $pick;

    my $git_mapper = Guita::Mapper::Git->new_with_work_tree(
        dir(config->param('repository_base'))->subdir($pick->uuid)->stringify,
    );

    my $object = $git_mapper->object_for_path($path);
    return $git_mapper->cat_file($object->objectish);
}

sub create {
    my ($self, $user, $filename, $content, $description) = @_;
    # asert

    my $pick_dbi_mapper = Guita::Mapper::DBI::Pick->new;

    my $id = $pick_dbi_mapper->create_pick({
        user_id     => $user->uuid,
        description => $description,
    });
    my $work_tree = dir(config->param('repository_base'))->subdir($id)->stringify;
    my $git_mapper = Guita::Mapper::Git->init($work_tree);
    $git_mapper->config(qw(receive.denyCurrentBranch ignore));

    # まともなエラー処理

    # textareaの内容をファイルに書きだして
    my $file = dir($work_tree)->file($filename);
    my $fh = $file->openw;
    $content = $content . ''; # copy
    $content =~ s/\r\n/\n/g;
    print $fh $content;
    close $fh;

    # add して
    $git_mapper->add($file->stringify);

    # commit
    $git_mapper->commit('edited in guita web form', {author => $user});

    return $id;
}

sub edit {
}

sub delete {
}

1;
