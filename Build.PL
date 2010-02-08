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
        'Data::Dump'                => 0,
        'File::Slurp'               => 0,

    },
    build_requires => {},

    # meta_merge => {
    #     resources => {
    #         bugtracker =>
    #           'http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-EditorTools',
    #         repository => 'http://github.com/mvgrimes/app-editortools'
    #     }
    # },
);

$build->create_build_script;

