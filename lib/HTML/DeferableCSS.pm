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

has cdn_links => (
    is        => 'ro',
    isa       => HashRef [NonEmptySimpleStr],
    predicate => 1,
);

has use_cdn_links => (
    is      => 'lazy',
    isa     => Bool,
    builder => 'has_cdn_links',
);

has inline_max => (
    is      => 'ro',
    isa     => PositiveOrZeroInt,
    default => 1024,
);

sub href {
    my ($self, $name, $file) = @_;
    croak "missing name" unless defined $name;
    $file //= $self->css_files->{$name};
    croak "invalid name '$name'" unless defined $file;
    my $href = $self->url_base_path . $file->[1]->stringify;
    if ($self->use_cdn_links && $self->has_cdn_links) {
        return $self->cdn_links->{$name} // $href;
    }
    return $href;
}

sub link_html {
    my ( $self, $name, $file ) = @_;
    return sprintf( '<link rel="stylesheet" href="%s">',
        $self->href( $name, $file ) );
}

sub inline_html {
    my ( $self, $name, $file ) = @_;
    croak "missing name" unless defined $name;
    $file //= $self->css_files->{$name};
    croak "invalid name '$name'" unless defined $file;
    return "<style>" . $file->[0]->slurp_raw . "</style>";
}

sub link_or_inline_html {
    my ($self, $name ) = @_;
    croak "missing name" unless defined $name;
    my $file = $self->css_files->{$name};
    croak "invalid name '$name'" unless defined $file;
    if ($file->[2] <= $self->inline_max) {
        return $self->inline_html($name, $file);
    }
    else {
        return $self->link_html($name, $file);
    }
}

=head1 KNOWN ISSUES

=head2 XHTML Support

This module is written for HTML5.

It does not support XHTML self-closing elements or embedding styles
and scripts in CDATA sections.

=cut

1;

=head1 append:AUTHOR

F<reset.css> comes from L<http://meyerweb.com/eric/tools/css/reset/>.

=cut
