package Guita::Git;
use prelude;

use parent qw(Git::Repository); # やめたい感じがする
use Git::Repository 'Log';

use Guita::Model::Git::Diff;
use Guita::Model::Git::Object::Blob;
use Guita::Model::Git::Object::Tree;

use List::Util qw(reduce);
use Path::Class;
use Encode;

sub new_with_git_dir {
    my ($class, $git_dir) = @_;

    $class->new(git_dir => $git_dir);
}

sub new_with_work_tree {
    my ($class, $work_tree) = @_;

    $class->new(work_tree => $work_tree);
}

sub init {
    my ($class, $work_tree) = @_;
    # エラー処理まともにする
    dir($work_tree)->mkpath unless -e $work_tree;
    $class->run(init => $work_tree);

    $class->new_with_work_tree($work_tree);
}

sub clone {
    my ($class, $url, $work_tree) = @_;
    # エラー処理まともにする
    dir($work_tree)->mkpath unless -e $work_tree;
    $class->run(clone => $url, $work_tree);

    $class->new_with_work_tree($work_tree);
}

sub add {
    my ($self, $filepath) = @_;

    $self->run(add => $filepath);
}

sub commit {
    my ($self, $comment, $args) = @_;

    my @params = ('-m', $comment);
    if ($args && $args->{author}) {
        push @params, (
            sprintf(q[--author='%s <hoge%s>'], $args->{author}->name, $args->{author}->email),
        );
    }

    $self->run(commit => @params);
}

sub tree {
    my ($self, $objectish) = @_;

    Guita::Model::Git::Object::Tree->new({
        objectish => $objectish,
    });
}

sub tree_with_children {
    my ($self, $objectish) = @_;

    my $tree = $self->tree($objectish);

    my $ls_tree = $self->ls_tree($objectish);

    $tree->{trees} = {};
    for my $key (keys %{ $ls_tree->{tree} }) {
        my $obj = Guita::Model::Git::Object::Tree->new({
            objectish => $ls_tree->{tree}->{$key}->{sha},
            mode      => $ls_tree->{tree}->{$key}->{mode},
        });
        $tree->{trees}->{$key} = $obj;
    }

    $tree->{blobs} = {};
    for my $key (keys %{ $ls_tree->{blob} }) {
        my $obj = Guita::Model::Git::Object::Blob->new({
            objectish => $ls_tree->{blob}->{$key}->{sha},
            mode      => $ls_tree->{blob}->{$key}->{mode},
        });
        $tree->{blobs}->{$key} = $obj;
    }

    $tree;
}

sub object_for_path {
    my ($self, $objectish, $path) = @_;

    my $tree = $self->tree_with_children($objectish);

    reduce { 
        return unless $a->is_tree;

        my $child = $a->children->{$b};
        $child->is_tree ? $self->tree_with_children($child->objectish) : $child;
    } $tree, (grep { $_ } split(/\//, $path));
}

# XXX 適切な配置ではない
sub traverse_tree {
    my ($self, $objectish, $callback, $path) = @_;
    return unless $callback;
    $path ||= '';

    my $tree = $self->tree_with_children($objectish);

    for my $blob_with_name (@{ $tree->blobs_list }) {
        $callback->(
            $blob_with_name->{obj},
            $path ? join('/', $path, $blob_with_name->{name}) : $blob_with_name->{name},
        );
    }
    for my $tree_with_name (@{ $tree->trees_list }) {
        $self->traverse_tree(
            $tree_with_name->{obj}->objectish,
            $callback,
            $path ? join('/', $path, $tree_with_name->{name}) : $tree_with_name->{name},
        );
    }
}

sub blob {
    my ($self, $objectish) = @_;

    Guita::Model::Git::Object::Blob->new({
        objectish => $objectish,
    });
}

sub blob_with_contents {
    my ($self, $objectish, $args) = @_;
    my $blob = $self->blob($objectish, $args);

    $blob->{contents} = decode_utf8($self->cat_file($objectish));
    $blob;
}

sub logs {
    my ($self, $size, $objectish, $path) = @_;

    [$self->log("-$size", $objectish, '--', $path)];
}

sub commit_of {
    my ($self, $objectish) = @_;

    $self->log("-1", $objectish, '--')->next;
}

sub diff {
    my ($self, $from, $to) = @_;

    Guita::Model::Git::Diff->new({
        from  => $from,
        to    => $to,
        diff_files => $self->diff_files($from, $to),
        diff_stats => $self->diff_stats($from, $to),
    });
}

sub diff_full {
    my ($self, $from, $to) = @_;
    $self->run('diff', '-p', $from, $to);
}

sub diff_stats {
    my ($self, $from, $to) = @_;
    my @lines = $self->run('diff', '--numstat', $from, $to);

    my $result = {
        total => {
            ins => 0,
            del => 0,
            lines => 0,
            files => 0,
        },
        files => {},
    };
    for my $line (@lines) {
        my ($ins, $del, $filename) = split /\t/, $line;
        $result->{total}->{ins}   += $ins;
        $result->{total}->{del}   += $del;
        $result->{total}->{lines} += $ins + $del;
        $result->{total}->{files} += 1;
        $result->{files}->{$filename} = {
            ins => $ins,
            del => $del,
        };
    }
    $result;
}

sub diff_files {
    my ($self, $from, $to) = @_;
    my $results = {};
    my $current_file = "";

    for my $line ( $self->diff_full($from, $to) ) {
        if ($line =~ m/diff --git a\/(.*?) b\/(.*?)/ms) {
            $current_file = $1;
            $results->{$current_file} = {
                patch => $line,
                path  => $current_file,
                mod   => '',
                src   => '',
                dst   => '',
                type  => 'modified',
            };
        }
        else {
            if ($line =~ m/index (.......)\.\.(.......)( ......)*/ms) {
                $results->{$current_file}->{src} = $1;
                $results->{$current_file}->{dst} = $2;
                $results->{$current_file}->{mode} = $3;
                $results->{$current_file}->{mode} =~ s/\s+//g;
            }
            if ($line =~ m/(.*?) file mode (......)/ms ) {
                $results->{$current_file}->{type} = $1;
                $results->{$current_file}->{mode} = $2;
            }
            if ($line =~ m/^Binary files /ms) {
                $results->{$current_file}->{binary} = 1;
            }
            $results->{$current_file}->{patch} .= "\n$line";
        }
    }
    $results;
}

sub rev_parse {
    my ($self, $objectish) = @_;

    scalar $self->run('rev-parse', $objectish);
}

sub branches {
    my ($self) = @_;

    [ (map { $_ =~ s/\s+//g; $_ } grep { $_ !~ m/ -> / } $self->run('branch', '-r')) ];
}

sub cat_file {
    my ($self, $objectish) = @_;
    decode_utf8(scalar $self->run('cat-file', '-p', $objectish));
}

sub cat_file_commit {
    my ($self, $objectish) = @_;
    scalar $self->run('cat-file', 'commit', $objectish);
}

sub ls_tree {
    my ($self, $tree_ish) = @_;
    $tree_ish ||= 'HEAD';

    my $results = {
        tree => {},
        blob => {},
    };
    my @lines = $self->run('ls-tree', $tree_ish);
    for my $line (@lines) {
        my ($info, $filename) = split /\t/, $line;
        my ($mode, $type, $sha) = split /\s+/, $info;

        $results->{$type}->{$filename} = { mode => $mode, sha => $sha };
    }
    return $results;
}

sub config {
    my $self = shift;
    $self->run('config', @_);
}

# XXX 
# Git::Repository::Log の振る舞いを修正
# Model::Git::Object::Commit とかを用紙すべき
package Git::Repository::Log;
no warnings 'redefine';
use Encode;

sub parent { $_[0]{parent}; }
sub message { decode_utf8 ($_[0]{message}); }
sub objectish { $_[0]{commit}; }

1;
__END__
