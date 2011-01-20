use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Object::Botox',
    license             => 'perl',
    dist_author         => 'Meettya <meettya@gmail.com>',
    dist_version_from   => 'lib/Object/Botox.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Object-Botox-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
