package HTML::DeferableCSS;

# ABSTRACT: Simplify management of stylesheets in your HTML

use v5.10;
use Moo 1.006000;

use Carp;
use Devel::StrictMode;
use File::ShareDir 1.112 qw/ dist_file /;
use MooX::TypeTiny;
use List::Util 1.45 qw/ first uniqstr /;
use Path::Tiny;
use Types::Path::Tiny qw/ Dir File Path /;
use Types::Common::Numeric qw/ PositiveOrZeroInt /;
use Types::Common::String qw/ NonEmptySimpleStr SimpleStr /;
use Types::Standard qw/ Bool CodeRef HashRef Maybe Tuple /;

# RECOMMEND PREREQ: Type::Tiny::XS

use namespace::autoclean;

our $VERSION = 'v0.3.1';

=head1 SYNOPSIS

  use HTML::DeferableCSS;

  my $css = HTML::DeferableCSS->new(
      css_root      => '/var/www/css',
      url_base_path => '/css',
      inline_max    => 512,
      aliases => {
        reset => 1,
        jqui  => 'jquery-ui',
        site  => 'style',
      },
      cdn => {
        jqui  => '//cdn.example.com/jquery-ui.min.css',
      },
  );

  $css->check or die "Something is wrong";

  ...

  print $css->deferred_link_html( qw[ jqui site ] );


=head1 DESCRIPTION

This is an experimental module for generating HTML-snippets for
deferable stylesheets.

This allows the stylesheets to be loaded asynchronously, allowing the
page to be rendered faster.

Ideally, this would be a simple matter of changing stylesheet links
to something like

  <link rel="preload" as="stylesheet" href="....">

but this is not well supported by all web browsers. So a web page
needs some L<JavaScript|https://github.com/filamentgroup/loadCSS>
to handle this, as well as a C<noscript> block as a fallback.

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

use deferred-loading stylesheets, which requires embedding JavaScript
code as a workaround for web browsers that do not support these
natively.

=back

=cut

=attr aliases

This is a required hash reference of names and their relative
filenames to L</css_root>.

It is recommended that the F<.css> and F<.min.css> suffixes be
omitted.

If the name is the same as the filename (without the extension) than
you can simply use C<1>.  (Likewise, an empty string or C<0> disables
the alias:

  my $css = HTML::DeferableCSS->new(
    aliases => {
        reset => 1,
        gone  => 0,       # using "gone" will throw an error
        one   => "1.css", #
    }
    ...
  );

If all names are the same as their filenames, then an array reference
can be used:

  my $css = HTML::DeferableCSS->new(
    aliases => [ qw( foo bar } ],
    ...
  );

Absolute paths cannot be used.

You may specify URLs instead of files, but this is not recommended,
except for cases when the files are not available locally.

=cut

has aliases => (
    is       => 'ro',
    isa      => STRICT ? HashRef [Maybe[SimpleStr]] : HashRef,
    required => 1,
    coerce   => sub {
        return { map { $_ => $_ } @{$_[0]} } if ref $_[0] eq 'ARRAY';
        return $_[0];
    },
);

=attr css_root

This is the required root directory where all stylesheets can be
found.

=cut

has css_root => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

=attr url_base_path

This is the URL prefix for stylesheets.

It can be a full URL prefix.

=cut

has url_base_path => (
    is      => 'ro',
    isa     => SimpleStr,
    default => '/',
);

=attr prefer_min

If true (default), then a file with the F<.min.css> suffix will be
preferred, if it exists in the same directory.

Note that this does not do any minification. You will need separate
tools for that.

=cut

has prefer_min => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

=attr css_files

This is a hash reference used internally to translate L</aliases>
into the actual files or URLs.

If files cannot be found, then it will throw an error. (See
L</check>).

=for Pod::Coverage PATH NAME SIZE

=cut

has css_files => (
    is  => 'lazy',
    isa => STRICT
             ? HashRef [ Tuple [ Maybe[Path], NonEmptySimpleStr, PositiveOrZeroInt ] ]
             : HashRef,
    builder => 1,
    coerce  => 1,
);

use constant PATH => 0;
use constant NAME => 1;
use constant SIZE => 2;

sub _build_css_files {
    my ($self) = @_;

    my $root = $self->css_root;
    my $min  = $self->prefer_min;

    my %files;
    for my $name (keys %{ $self->aliases }) {
        my $base  = $self->aliases->{$name} or next;
        if ($base =~ m{^(\w+:)?//}) {
            $files{$name} = [ undef, $base, 0 ];
        }
        else {
            $base = $name if $base eq '1';
            $base =~ s/(?:\.min)?\.css$//;
            my @bases = $min
                ? ( "${base}.min.css",  "${base}.css", $base )
                : ( "${base}.css",  "${base}.min.css", $base );

            my $file = first { $_->exists } map { path( $root, $_ ) } @bases;
            unless ($file) {
                $self->log->( error => "alias '$name' refers to a non-existent file" );
                next;
            }
            # PATH NAME SIZE
            $files{$name} = [ $file, $file->relative($root)->stringify, $file->stat->size ];
        }
    }

    return \%files;
}

=attr cdn_links

This is a hash reference of L</aliases> to URLs. (Only one URL per
alias is supported.)

When L</use_cdn_links> is true, then these URLs will be used instead
of local versions.

=attr has_cdn_links

This is true when there are L</cdn_links>.

=cut

has cdn_links => (
    is        => 'ro',
    isa       => STRICT ? HashRef [NonEmptySimpleStr] : HashRef,
    predicate => 1,
);

=attr use_cdn_links

When true, this will prefer CDN URLs instead of local files.

=cut

has use_cdn_links => (
    is      => 'lazy',
    isa     => Bool,
    builder => 'has_cdn_links',
);

=attr inline_max

This specifies the maximum size of an file to inline.

Local files under the size will be inlined using the
L</link_or_inline_html> or L</deferred_link_html> methods.

Setting this to 0 disables the use of inline links, unless
L</inline_html> is called explicitly.

=cut

has inline_max => (
    is      => 'ro',
    isa     => PositiveOrZeroInt,
    default => 1024,
);

=attr defer_css

True by default.

This is used by L</deferred_link_html> to determine whether to emit
code for deferred stylesheets.

=cut

has defer_css => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

=attr include_noscript

When true, a C<noscript> element will be included with non-deffered
links.

This defaults to the same value as L</defer_css>.

=cut

has include_noscript => (
    is      => 'lazy',
    isa     => Bool,
    builder => 'defer_css',
);

=attr preload_script

This is the pathname of the F<cssrelpreload.js> file that will be
embedded in the resulting code.

The script comes from L<https://github.com/filamentgroup/loadCSS>.

You do not need to modify this unless you want to use a different
script from the one included with this module.

=cut

has preload_script => (
    is      => 'lazy',
    isa     => File,
    coerce  => 1,
    builder => sub { dist_file( qw/ HTML-DeferableCSS cssrelpreload.min.js / ) },
);

=attr link_template

This is a code reference for a subroutine that returns a stylesheet link.

=cut

has link_template => (
    is      => 'ro',
    isa     => CodeRef,
    builder => sub {
        return sub { sprintf('<link rel="stylesheet" href="%s">', @_) },
    },
);

=attr preload_template

This is a code reference for a subroutine that returns a stylesheet
preload link.

=cut


has preload_template => (
    is      => 'ro',
    isa     => CodeRef,
    builder => sub {
        return sub { sprintf('<link rel="preload" as="style" href="%s" onload="this.onload=null;this.rel=\'stylesheet\'">', @_) },
    },
);

=attr asset_id

This is an optional static asset id to append to local links. It may
refer to a version number or commit-id, for example.

This is useful to ensure that changes to stylesheets are picked up by
web browsers that would otherwise use cached copies of older versions
of files.

=attr has_asset_id

True if there is an L</asset_id>.

=cut

has asset_id => (
    is        => 'ro',
    isa       => NonEmptySimpleStr,
    predicate => 1,
);

=attr log

This is a code reference for logging errors and warnings:

  $css->log->( $level => $message );

By default, this is a wrapper around L<Carp> that dies when the level
is "error", and emits a warning for everything else.

You can override this so that errors are treated as warnings,

  log => sub { warn $_[1] },

or that warnings are fatal,

  log => sub { die $_[1] },

or even integrate this with your own logging system:

  log => sub { $logger->log(@_) },

=cut

has log => (
    is => 'ro',
    isa => CodeRef,
    builder => sub {
        return sub {
            my ($level, $message) = @_;
            croak $message if ($level eq 'error');
            carp $message;
        };
    },
);

=method check

This method instantiates lazy attributes and performs some minimal
checks on the data.  (This should be called instead of L</css_files>.)

It will throw an error or return false (depending on L</log>) if there
is something wrong.

This was added in v0.3.0.

=cut

sub check {
    my ($self) = @_;

    my $files = $self->css_files;

    scalar(keys %$files) or
        return $self->log->( error => "no aliases" );

    return 1;
}

=method href

  my $href = $css->href( $alias );

This returns this URL for an alias.

=cut

sub href {
    my ($self, $name, $file) = @_;
    $file //= $self->_get_file($name) or return;
    if (defined $file->[PATH]) {
        my $href = $self->url_base_path . $file->[NAME];
        $href .= '?' . $self->asset_id if $self->has_asset_id;
        if ($self->use_cdn_links && $self->has_cdn_links) {
            return $self->cdn_links->{$name} // $href;
        }
        return $href;
    }
    else {
        return $file->[NAME];
    }
}

=method link_html

  my $html = $css->link_html( $alias );

This returns the link HTML markup for the stylesheet referred to by
C<$alias>.

=cut

sub link_html {
    my ( $self, $name, $file ) = @_;
    return $self->link_template->( $self->href( $name, $file ) );
}

=method inline_html

  my $html = $css->inline_html( $alias );

This returns an embedded stylesheet referred to by C<$alias>.

=cut

sub inline_html {
    my ( $self, $name, $file ) = @_;
    $file //= $self->_get_file($name) or return;
    if (my $path = $file->[PATH]) {
        if ($file->[SIZE]) {
            return "<style>" . $file->[PATH]->slurp_raw . "</style>";
        }
        $self->log->( warning => "empty file '$path'" );
        return "";
    }
    else {
        $self->log->( error => "'$name' refers to a URI" );
        return;
    }
}

=method link_or_inline_html

  my $html = $css->link_or_inline_html( @aliases );

This returns either the link HTML markup, or the embedded stylesheet,
if the file size is not greater than L</inline_max>.

Note that a stylesheet will be inlined, even if there is are
L</cdn_links>.

=cut

sub link_or_inline_html {
    my ($self, @names ) = @_;
    my $buffer = "";
    foreach my $name (uniqstr @names) {
        my $file = $self->_get_file($name) or next;
        if ( $file->[PATH] && ($file->[SIZE] <= $self->inline_max)) {
            $buffer .= $self->inline_html($name, $file);
        }
        else {
            $buffer .= $self->link_html($name, $file);
        }
    }
    return $buffer;
}

=method deferred_link_html

  my $html = $css->deferred_link_html( @aliases );

This returns the HTML markup for the stylesheets specified by
L</aliases>, as appropriate for each stylesheet.

If the stylesheets are not greater than L</inline_max>, then it will
embed them.  Otherwise it will return the appropriate markup,
depending on L</defer_css>.

=cut

sub deferred_link_html {
    my ($self, @names) = @_;
    my $buffer = "";
    my @deferred;
    for my $name (uniqstr @names) {
        my $file = $self->_get_file($name) or next;
        if ($file->[PATH] && $file->[SIZE] <= $self->inline_max) {
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

sub _get_file {
    my ($self, $name) = @_;
    unless (defined $name) {
        $self->log->( error => "missing name" );
        return;
    }
    if (my $file = $self->css_files->{$name}) {
        return $file;
    }
    else {
        $self->log->( error => "invalid name '$name'" );
        return;
    }

}


=head1 KNOWN ISSUES

=head2 XHTML Support

This module is written for HTML5.

It does not support XHTML self-closing elements or embedding styles
and scripts in CDATA sections.

=head2 Encoding

All files are embedded as raw files.

No URL encoding is done on the HTML links or L</asset_id>.

=head2 It's spelled "Deferrable"

It's also spelled "Deferable".

=cut

1;

=head1 append:BUGS

Please report any bugs in F<cssrelpreload.js> to
L<https://github.com/filamentgroup/loadCSS/issues>.

=head1 append:AUTHOR

This module was developed from work for Science Photo Library
L<https://www.sciencephoto.com>.

F<reset.css> comes from L<http://meyerweb.com/eric/tools/css/reset/>.

F<cssrelpreload.js> comes from L<https://github.com/filamentgroup/loadCSS/>.

=cut
