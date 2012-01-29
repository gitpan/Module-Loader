#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Module::Loader' ) || print "Bail out!\n";
}

diag( "Testing Module::Loader $Module::Loader::VERSION, Perl $], $^X" );
