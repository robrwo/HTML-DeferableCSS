use Test::Most;

use HTML::DeferableCSS;

subtest "inline" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            test => 'foo',
        },
    );

    isa_ok $css, 'HTML::DeferableCSS';

    is $css->link_html('test'),
        '<link rel="stylesheet" href="/foo.css">',
        "link_html";

    my $cdata = $css->css_files->{test}->[0]->slurp_raw;

    is $css->inline_html('test'), "<style>$cdata</style>", "inline";

    is $css->link_or_inline_html('test'), $css->inline_html('test'), "link_or_inline";

};

subtest "inline (small inline_max)" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            test => 'foo',
        },
        inline_max => 5,
    );

    isa_ok $css, 'HTML::DeferableCSS';

    is $css->link_html('test'),
        '<link rel="stylesheet" href="/foo.css">',
        "link_html";

    my $cdata = $css->css_files->{test}->[0]->slurp_raw;

    is $css->inline_html('test'), "<style>$cdata</style>", "inline";

    is $css->link_or_inline_html('test'), $css->link_html('test'), "link_or_inline";

};

subtest "inline url" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            test => 'http://example.com',
        },
    );

    isa_ok $css, 'HTML::DeferableCSS';

    throws_ok {
        $css->inline_html('test');
    } qr/'test' refers to a URI/, "inline_html of a URL dies";

    is $css->link_or_inline_html('test'), $css->link_html('test'), "link_or_inline";

};

subtest "inline (0-byte file)" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            test => '0.css',
        },
    );

    isa_ok $css, 'HTML::DeferableCSS';

    is $css->link_html('test'),
        '<link rel="stylesheet" href="/0.css">',
        "link_html";

    warning_like {
        is $css->inline_html('test'), "", "inline";
    } qr/empty file/, 'warning';

    is $css->link_or_inline_html('test'), "", "link_or_inline";

};

done_testing;
