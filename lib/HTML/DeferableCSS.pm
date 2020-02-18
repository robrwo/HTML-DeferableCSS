package HTML::DeferableCSS;

# ABSTRACT: Simplify management of stylesheets in your HTML

use v5.10;
use Moo;

use Carp qw/ croak /;
use Devel::StrictMode;
use File::ShareDir qw/ module_file /;
use MooX::TypeTiny;
use List::Util qw/ first uniqstr /;
use Path::Tiny;
use Types::Path::Tiny qw/ Dir File Path /;
use Types::Common::Numeric qw/ PositiveOrZeroInt /;
use Types::Common::String qw/ NonEmptySimpleStr SimpleStr /;
use Types::Standard qw/ Bool CodeRef HashRef Tuple /;

# RECOMMEND PREREQ: Type::Tiny::XS

use namespace::autoclean;

use constant PATH => 0;
use constant NAME => 1;
use constant SIZE => 2;

=head1 SYNOPSIS

  use HTML::DeferableCSS;

  my $css = HTML::DeferableCSS->new(
      css_root      => '/var/www/css',
      url_base_path => '/css',
      inline_max    => 512,
      aliases => {
        jqui  => 'jquery-ui',
        site  => 'style',
      },
      cdn => {
        jqui  => '//cdn.example.com/jquery-ui.min.css',
      },
  );

  ...

  print $css->deferred_link_html( qw[ jqui site ] );

=head1 DESCRIPTION

This module allows you to simplify the management of stylesheets for a
web application, from development to production by

=over

=item *

declaring all stylesheets used by your web application;

=item *

specifying remote aliases for stylesheets, e.g. from a CDN;

=item *

enable or disable the use of minified stylesheets;

=item *

switch between local copies of stylesheets or CDN versions;

=item *

automatically inline small stylesheets;

=item *

use deferred-loading stylesheets;

=back

=cut

has aliases => (
    is       => 'ro',
    isa      => STRICT ? HashRef [NonEmptySimpleStr] : HashRef,
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
    is  => 'lazy',
    isa => STRICT
             ? HashRef [ Tuple [ Path, Path, PositiveOrZeroInt ] ]
             : HashRef,
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
        # PATH NAME SIZE
        $files{$name} = [ $file, $file->relative($root), $file->stat->size ];
    }

    return \%files;
}

has cdn_links => (
    is        => 'ro',
    isa       => STRICT ? HashRef [NonEmptySimpleStr] : HashRef,
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

has defer_css => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has include_noscript => (
    is      => 'lazy',
    isa     => Bool,
    builder => sub {
        my ($self) = @_;
        return $self->defer_css;
    },
);

has preload_script => (
    is      => 'lazy',
    isa     => File,
    coerce  => 1,
    builder => sub { module_file(__PACKAGE__, 'cssrelpreload.min.js') },
);

has link_template => (
    is      => 'ro',
    isa     => CodeRef,
    builder => sub {
        return sub { sprintf('<link rel="stylesheet" href="%s">', @_) },
    },
);

has preload_template => (
    is      => 'ro',
    isa     => CodeRef,
    builder => sub {
        return sub { sprintf('<link rel="preload" as="style" href="%s" onload="this.onload=null;this.rel=\'stylesheet\'">', @_) },
    },
);

has asset_id => (
    is        => 'ro',
    isa       => NonEmptySimpleStr,
    predicate => 1,
);

sub href {
    my ($self, $name, $file) = @_;
    croak "missing name" unless defined $name;
    $file //= $self->css_files->{$name};
    croak "invalid name '$name'" unless defined $file;
    my $href = $self->url_base_path . $file->[NAME]->stringify;
    $href .= '?' . $self->asset_id if $self->has_asset_id;
    if ($self->use_cdn_links && $self->has_cdn_links) {
        return $self->cdn_links->{$name} // $href;
    }
    return $href;
}

sub link_html {
    my ( $self, $name, $file ) = @_;
    return $self->link_template->( $self->href( $name, $file ) );
}

sub inline_html {
    my ( $self, $name, $file ) = @_;
    croak "missing name" unless defined $name;
    $file //= $self->css_files->{$name};
    croak "invalid name '$name'" unless defined $file;
    return "<style>" . $file->[PATH]->slurp_raw . "</style>";
}

sub link_or_inline_html {
    my ($self, $name ) = @_;
    croak "missing name" unless defined $name;
    my $file = $self->css_files->{$name};
    croak "invalid name '$name'" unless defined $file;
    if ($file->[SIZE] <= $self->inline_max) {
        return $self->inline_html($name, $file);
    }
    else {
        return $self->link_html($name, $file);
    }
}

sub deferred_link_html {
    my ($self, @names) = @_;
    my $buffer = "";
    my @deferred;
    for my $name (uniqstr @names) {
        my $file = $self->css_files->{$name} or croak "invalid name '$name'";
        if ($file->[SIZE] <= $self->inline_max) {
            $buffer .= $self->inline_html($name, $file);
        }
        elsif ($self->defer_css) {
            my $href = $self->href($name, $file);
            push @deferred, $href;
            $buffer .= $self->preload_template->($href);
        }
        else {
            $buffer .= $self->link_html($name, $file);
        }
    }

    if (@deferred) {

        $buffer .= "<noscript>" .
            join("", map { $self->link_template->($_) } @deferred ) .
            "</noscript>" if $self->include_noscript;

        $buffer .= "<script>" .
            $self->preload_script->slurp_raw .
            "</script>";

    }

    return $buffer;
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

F<cssrelpreload.js> comes from L<https://github.com/filamentgroup/loadCSS/>.

=cut
