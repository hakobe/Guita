package Guita::Model::Pick;
use prelude;

use Encode;
use Path::Class qw(dir);

use Class::Accessor::Lite::Lazy (
    new => 1,
    rw => [
        qw(
        ),
        # expandable by Guita::Service::Pick
        qw(
            author
            logs
            files
        ),
    ],
);

sub description {
    my ($self) = @_;

    decode_utf8($self->get('description'));
}

sub working_path {
    my ($self) = @_;
    return dir(GuitaConf('working_base'))->subdir($self->id)->stringify;
}

sub repository_path {
    my ($self) = @_;
    return dir(GuitaConf('repository_base'))->subdir($self->id . '.git')->stringify;
}

1;
