package Net::Google::Spreadsheets::Base;
use Moose;
use namespace::clean -except => 'meta';
use Carp;

has service => (
    isa => 'Net::Google::Spreadsheets',
    is => 'ro',
    required => 1,
    lazy => 1,
    default => sub { shift->container->service },
);

my %ns = (
    gd => 'http://schemas.google.com/g/2005',
    gs => 'http://schemas.google.com/spreadsheets/2006',
    gsx => 'http://schemas.google.com/spreadsheets/2006/extended',
    batch => 'http://schemas.google.com/gdata/batch',
);

my $pkg = __PACKAGE__;
while (my ($prefix, $uri) = each %ns) {
    no strict 'refs';
    *{"$pkg\::${prefix}ns"} = sub {XML::Atom::Namespace->new($prefix, $uri)};
}

my %rel2label = (
    edit => 'editurl',
    self => 'selfurl',
);

for (values %rel2label) {
    has $_ => (isa => 'Str', is => 'ro');
}

has accessor => (
    isa => 'Str',
    is => 'ro',
);

has atom => (
    isa => 'XML::Atom::Entry',
    is => 'rw',
    trigger => sub {
        my ($self, $arg) = @_;
        my $id = $self->atom->get($self->ns, 'id');
        croak "can't set different id!" if $self->id && $self->id ne $id;
        $self->_update_atom;
    },
    handles => ['ns', 'elem', 'author'],
);

has id => (
    isa => 'Str',
    is => 'ro',
);

has content => (
    isa => 'Str',
    is => 'ro',
);

has title => (
    isa => 'Str',
    is => 'rw',
    default => 'untitled',
    trigger => sub {$_[0]->update}
);

has etag => (
    isa => 'Str',
    is => 'rw',
);

has container => (
    isa => 'Maybe[Net::Google::Spreadsheets::Base]',
    is => 'ro',
);

__PACKAGE__->meta->make_immutable;

sub _update_atom {
    my ($self) = @_;
    $self->{title} = $self->atom->title;
    $self->{id} = $self->atom->get($self->ns, 'id');
    $self->etag($self->elem->getAttributeNS($self->gdns->{uri}, 'etag'));
    for ($self->atom->link) {
        my $label = $rel2label{$_->rel} or next;
        $self->{$label} = $_->href;
    }
}

sub list_contents {
    my ($self, $class, $cond) = @_;
    $self->content or return;
    my $feed = $self->service->feed($self->content, $cond);
    return map {$class->new(container => $self, atom => $_)} $feed->entries;
}

sub entry {
    my ($self) = @_;
    my $entry = XML::Atom::Entry->new;
    $entry->title($self->title) if $self->title;
    return $entry;
}

sub sync {
    my ($self) = @_;
    my $entry = $self->service->entry($self->selfurl);
    $self->atom($entry);
}

sub update {
    my ($self) = @_;
    $self->etag or return;
    my $atom = $self->service->put(
        {
            self => $self,
            entry => $self->entry,
        }
    );
    $self->container->sync;
    $self->atom($atom);
}

sub delete {
    my $self = shift;
    my $res = $self->service->request(
        {
            uri => $self->editurl,
            method => 'DELETE',
            header => {'If-Match' => $self->etag},
        }
    );
    $self->container->sync if $res->is_success;
    return $res->is_success;
}

1;
__END__

=head1 NAME

Net::Google::Spreadsheets::Base - Base class of Net::Google::Spreadsheets::*.

=head1 SEE ALSO

L<http://code.google.com/intl/en/apis/spreadsheets/docs/2.0/developers_guide_protocol.html>

L<http://code.google.com/intl/en/apis/spreadsheets/docs/2.0/reference.html>

L<Net::Google::AuthSub>

L<Net::Google::Spreadsheets>

=head1 AUTHOR

Nobuo Danjou E<lt>nobuo.danjou@gmail.comE<gt>

=cut

