use strict;
use Module::Build;
Module::Build->new(
    module_name => 'Net::DAAP::Server',
    license     => 'perl',
    requires    => {
        'perl' => 5.006,
        'Net::DAAP::DMAP::Pack' => 0,
        'HTTP::Request' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    create_makefile_pl => 'traditional',
   )->create_build_script;
