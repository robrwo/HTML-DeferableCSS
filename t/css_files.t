use Test::Most;

use HTML::DeferableCSS;

subtest "css_files" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            reset => 'reset',
        },
    );

    isa_ok $css, 'HTML::DeferableCSS';

    my $files = $css->css_files;

    cmp_deeply $files, {
        reset => [ obj_isa('Path::Tiny'), obj_isa('Path::Tiny'), 773 ],
    }, "css_files";

    is $files->{reset}->[0]->stringify => "t/etc/css/reset.min.css", "filename";

};

subtest "css_files (prefer_min=0)" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            reset => 'reset',
        },
        prefer_min => 0,
    );

    isa_ok $css, 'HTML::DeferableCSS';

    my $files = $css->css_files;

    cmp_deeply $files, {
        reset => [ obj_isa('Path::Tiny'), obj_isa('Path::Tiny'), 1092 ],
    }, "css_files";

    is $files->{reset}->[0]->stringify => "t/etc/css/reset.css", "filename";

};

subtest "css_files (full name)" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            reset => 'reset.css',
        },
    );

    isa_ok $css, 'HTML::DeferableCSS';

    my $files = $css->css_files;

    cmp_deeply $files, {
        reset => [ obj_isa('Path::Tiny'), obj_isa('Path::Tiny'), 1092 ],
    }, "css_files";

    is $files->{reset}->[0]->stringify => "t/etc/css/reset.css", "filename";

};

subtest "css_files (full name)" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            reset => 'reset.min.css',
        },
    );

    isa_ok $css, 'HTML::DeferableCSS';

    my $files = $css->css_files;

    cmp_deeply $files, {
        reset => [ obj_isa('Path::Tiny'), obj_isa('Path::Tiny'), 773 ],
    }, "css_files";

    is $files->{reset}->[0]->stringify => "t/etc/css/reset.min.css", "filename";

};

subtest "css_files (bad css_root)" => sub {

    # We don't test for the actual error, since that is dependent upon
    # Types::Path::Tiny

    dies_ok {
        my $css = HTML::DeferableCSS->new(
            css_root => 't/etc/cssx',
            aliases  => {
                reset => 'resetx',
            },
        );
    } 'constructor died';

};

subtest "css_files (bad filename)" => sub {

    my $css = HTML::DeferableCSS->new(
        css_root => 't/etc/css',
        aliases  => {
            reset => 'resetx',
        },
    );

    isa_ok $css, 'HTML::DeferableCSS';

    throws_ok {
        $css->css_files
    } qr/alias 'reset' refers to a non-existent file/;

};

done_testing;
