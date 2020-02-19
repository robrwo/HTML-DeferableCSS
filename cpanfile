requires "Devel::StrictMode" => "0";
requires "File::ShareDir" => "1.112";
requires "List::Util" => "1.45";
requires "Moo" => "0";
requires "MooX::TypeTiny" => "0";
requires "Path::Tiny" => "0";
requires "Types::Common::Numeric" => "0";
requires "Types::Common::String" => "0";
requires "Types::Path::Tiny" => "0";
requires "Types::Standard" => "0";
requires "Types::URI" => "0";
requires "URI" => "0";
requires "namespace::autoclean" => "0";
requires "perl" => "v5.10.0";
recommends "Type::Tiny::XS" => "0";

on 'test' => sub {
  requires "Cwd" => "0";
  requires "File::Spec" => "0";
  requires "File::Spec::Functions" => "0";
  requires "Module::Metadata" => "0";
  requires "Test::More" => "0";
  requires "Test::Most" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::ShareDir::Install" => "0.06";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CleanNamespaces" => "0.15";
  requires "Test::EOF" => "0";
  requires "Test::Kwalitee" => "1.21";
  requires "Test::MinimumVersion" => "0";
  requires "Test::More" => "0";
  requires "Test::Perl::Critic" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::TrailingSpace" => "0.0203";
};
