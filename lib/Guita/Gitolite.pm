package Guita::Gitolite;
use prelude;

use Class::Accessor::Lite::Lazy (
    new => 1,
    ro_lazy => [qw( admin_repos admin_path )],
);

use Guita::Git;
use Path::Class;
use Data::Section::Simple qw(get_data_section);

sub _build_admin_repos {
    my ($self) = @_;

    if (!(-e $self->admin_path)) {
        Guita::Git->clone(
            'yohei@gitolite:gitolite-admin',
            $self->admin_path,
        );
    }
    my $git = Guita::Git->new_with_work_tree($self->admin_path);
    $git->run(qw(fetch));
    $git->run(qw(reset --hard origin/master));

    return $git;
}

sub _build_admin_path {
    my ($self) = @_;
    return dir(GuitaConf('working_base'))->subdir('gitolite-admin')->stringify;
}

sub setup_repository {
}

sub add_user {
    my ($self, $user) = @_;
    my $git = $self->admin_repos;

    my $file = dir($self->admin_path)->subdir('keydir')->file( $user->name . '.pub' );
    my $fh = $file->openw;
    print $fh $user->ssh_key;
    close $fh;

    $git->add($file->stringify);
    $git->commit('add user', {author => $user});
    $git->run(qw( push -f origin master )); # XXX force
}

sub add_repository {
    my ($self, $user, $name, $users) = @_;
    my $git = $self->admin_repos;

    my $file = dir($self->admin_path)->subdir('conf/picks')->file("$name.conf");
    my $fh = $file->openw;
    print $fh sprintf(
        get_data_section('repos.conf'),
        $name,
        '@all',
        #join(' ', map { $_->name } @$users),
    );
    close $fh;

    $git->add($file->stringify);
    $git->commit('add $repos', {author => $user});
    $git->run(qw( push -f origin master )); # XXX force
}

sub reconfgure_repository {
    my ($self) = @_;
}

1;

__DATA__
@@ repos.conf
repo %s
    R       =   @all
    RW+     =   %s
