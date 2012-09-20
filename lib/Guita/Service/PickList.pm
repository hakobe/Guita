package Guita::Service::PickList;
use prelude;
use parent qw(Guita::Service);

use Guita::Pager;
use Guita::Service::Pick;
use Path::Class;

sub list {
    my ($self, $args) = @_;

    # Model::List::Pick を返すようにする
    my $picks = [
        map {
            my $pick = $_;
            my $work_tree = dir(GuitaConf('repository_base'))->subdir($pick->id . '.git');

            my $git = Guita::Git->new_with_git_dir( $work_tree->stringify );
            my $tree = $git->tree_with_children('HEAD');

            my $blob_with_name = $tree->blobs_list->[0];
            $blob_with_name ? +{
                pick   => $pick,
                name   => $blob_with_name->{name},
                blob   => $git->blob_with_contents($blob_with_name->{obj}->objectish),
            } : ()
        }
        grep {
            my $pick = $_;
            my $work_tree = dir(GuitaConf('repository_base'))->subdir($pick->id . '.git');
            -e $work_tree->stringify;
        }
        $self->dbixl->table('pick')->limit($args->{limit})->offset($args->{offset})->all
    ];

    return $picks;
}


1;
