package HTML::DeferableCSS;

use v5.10;
use Moo;

use Carp qw/ croak /;
use MooX::TypeTiny;
use List::Util qw/ first /;
use Path::Tiny;
use Types::Path::Tiny qw/ Dir Path /;
use Types::Common::Numeric qw/ PositiveOrZeroInt /;
use Types::Common::String qw/ NonEmptySimpleStr SimpleStr /;
use Types::Standard qw/ Bool HashRef Tuple /;

use namespace::autoclean;

use constant FILE => 0;
use constant SIZE => 1;

has aliases => (
    is       => 'ro',
    isa      => HashRef [NonEmptySimpleStr],
    required => 1,
);

has css_root => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

has url_base_path => (
    is      => 'ro',
    isa     => SimpleStr,
    default => '/',
);

has prefer_min => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has css_files => (
    is      => 'lazy',
    isa     => HashRef [ Tuple [ Path, Path, PositiveOrZeroInt ] ],
    builder => 1,
    coerce  => 1,
);

sub _build_css_files {
    my ($self) = @_;

    my $root = $self->css_root;
    my $min  = !$self->prefer_min;

    my %files;
    for my $name (keys %{ $self->aliases }) {
        my $base  = $self->aliases->{$name};
        my @bases = ( $base );
        unshift @bases, "${base}.css" unless $base =~ /\.css$/;
        unshift @bases, "${base}.min.css" unless $min || $base =~ /\.min\.css$/;
        my $file = first { $_->exists } map { path( $root, $_ ) } @bases;
        unless ($file) {
            croak "alias '$name' refers to a non-existent file";
        }
        $files{$name} = [ $file, $file->relative($root), $file->stat->size ];
    }

    return \%files;
}

1;

=head1 append:AUTHOR

F<reset.css> comes from L<http://meyerweb.com/eric/tools/css/reset/>.

=cut
