#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Object::Botox' );
}

diag( "Testing Object::Botox $Object::Botox::VERSION, Perl $], $^X" );
