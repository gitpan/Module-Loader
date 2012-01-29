use inc::Module::Install;

name     'Module-Loader';
all_from 'lib/Module/Loader.pm';
author   q{Brad Haywood <brad@geeksware.net>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

