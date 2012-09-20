package Guita::Service::PickList;
use prelude;
use parent qw(Guita::Service);

use Guita::Pager;
use Guita::Service::Pick;
use Guita::Model::User::Guest;
use Path::Class;
use List::MoreUtils qw(uniq);

sub list {
    my ($self, $args) = @_;

    my $pick_service = Guita::Service::Pick->new;

    # Model::List::Pick を返すようにする
    my @picks =
        map {
            my $pick = $_;
            my $work_tree = dir(GuitaConf('repository_base'))->subdir($pick->id . '.git');

            my $git = Guita::Git->new_with_git_dir( $work_tree->stringify );
            my $tree = $git->tree_with_children('HEAD');

            my $blob_with_name = $tree->blobs_list->[0];
            $blob_with_name ? +{
                pick   => $pick,
                blob   => $git->blob_with_content($blob_with_name->{obj}->objectish),
            } : ()
        }
        grep {
            my $pick = $_;
            my $work_tree = dir(GuitaConf('repository_base'))->subdir($pick->id . '.git');
            -e $work_tree->stringify;
        }
        $self->dbixl->table('pick')
            ->limit($args->{limit})
            ->offset($args->{offset})
            ->order_by('-created')
            ->all;

    my @user_ids = uniq map { $_->{pick}->user_id } grep { $_->{pick}->user_id != 0 } @picks;
    my %user_id_to_user = 
        map { $_->id => $_ }
        $self->dbixl->table('user')
            ->search({ id => {-in => \@user_ids} })
            ->limit(scalar(@user_ids))
            ->all;
    $user_id_to_user{0} = Guita::Model::User::Guest->new;
    $_->{pick}->author( $user_id_to_user{ $_->{pick}->user_id } ) for @picks;

    return [ @picks ];
}


1;
