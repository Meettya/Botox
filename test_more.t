#!/opt/local/bin/perl -w

use strict;

use Test::More tests => 15; 

use_ok( 'Botox', qw(new) );
can_ok('Botox', qw(new) );

{	package Parent;

	use Botox qw(new);
		
	our $object_prototype = { 'prop1_ro' => 1 , 'prop2' => 'abcde' };
	
	sub show_prop1{ # It`s poinlessly - indeed property IS A accessor itself
		my ( $self ) = @_;
		return $self->prop1;
	}
	
	sub set_prop1{ # It`s NEEDED for RO property
		my ( $self, $value ) = @_;
		$self->prop1($value);
	}
	
	sub parent_sub{ # It`s class method itself
		my $self = shift;
		return $self->prop1;
	}
	1;
}
   
{	package Child;
	
	use Data::Dumper;
	
	use base 'Parent';
	
	our $object_prototype = {  %$Parent::object_prototype,
					'prop1_ro' => 44, 'prop5' => 55 , 'prop8_ro' => 'tetete' };
	
	my $make_test = sub {	
		my ( $self, $i ) = @_ ;		
		main::ok($self->prop1 == 1 && $self->prop2 eq 'abcde', "Init test pass");
		main::ok($self->show_prop1 == 1, "Read accessor test pass");
		main::ok(! eval{ $self->prop1(4*$i) } && $@ && $self->prop1 == 1 , 
				"Read-only property test pass");
		main::ok($self->set_prop1(5*$i) && $self->prop1 == 5*$i,
				"Write accessor method test pass");
		main::ok($self->prop2 ne 'wxyz'.$i && $self->prop2('wxyz'.$i) 
				&& $self->prop2 eq 'wxyz'.$i, "Read-write property test pass");
		main::ok($self->parent_sub == $self->prop1, "Class method test pass");
	};
	
	my $persistent_test = sub{
		my $self = shift;		
		main::ok($self->prop1 == 5 && $self->prop2 eq 'wxyz1', 
					"Persistent data test pass");	
	};
		
	my $foo = new Parent;
	print "\nFirst object test:\n";
	&$make_test($foo,1);

	my $bar = new Parent;	
	print "\nSecond object test:\n";
	&$make_test($bar,2);
	print "\nPersistent data test:\n";
	&$persistent_test($foo);

	print Dumper($foo);

	1;
}

{ package GrandChild;


	use Data::Dumper;
	my $baz = new Child;
	
	print Dumper($baz);

	print $baz->show_prop1,"\n";

}
