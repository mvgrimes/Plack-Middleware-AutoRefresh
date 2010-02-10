use Module::Build;

my $build = Module::Build->new(
    module_name   => 'Plack::Middleware::AutoRefresh',
    license       => 'perl',
    create_readme => 1,
    requires      => {
        'perl'                      => '5.008',
        'Plack'                     => 0,
        'AnyEvent'                  => 0,
        'AnyEvent::Filesys::Notify' => 0,
        'File::Slurp'               => 0,
        'File::Basename'            => 0,
        'File::ShareDir'            => 0,
        'JSON::Any'                 => 0,
        'Carp'                      => 0,
        'Readonly'                  => 0,
    },
    build_requires     => {},
    configure_requires => { 'Module::Build' => '0.36', },
    share_dir          => 'share',

    meta_merge => {
        resources => {
            bugtracker =>
              'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Plack-Middleware-AutoRefresh',
            repository =>
              'http://github.com/mvgrimes/Plack-Middleware-AutoRefresh'
        }
    },
);

$build->create_build_script;

