package Botox;

use strict;
use warnings;

our $VERSION = 0.9.5;

use Exporter 'import';
our @EXPORT_OK = qw(new);

my ( $prepare, $prototyping );
my $err_text = qq(Can`t change RO properties |%s| to |%s| in object %s from %s at %s line %d\n);

sub new{
    my $invocant = shift;
    my $self = bless( {}, ref $invocant || $invocant ); # Object or class name  
	&$prototyping( $self );
	return $self;
}

$prototyping = sub{
	my $self = shift;
	my $isa = (ref $self )."\::ISA";
	# we are known what is it for
	no strict 'refs';  
	# YES, just push object class to grandparents list AND get ALL prior object _proptotype one by one 
	my $class_list = [ @$isa ,( ref $self ) ];

	foreach my $class (@$class_list){
	
		my $proto = $class."\::object_prototype";

		# exit if havent prototype
		return unless ( ${$proto} && ref ${$proto} eq 'HASH' );
		# or if we are having prototype - use it !		
		for ( reverse keys %${$proto} ) { # YES! reverse for keep RO properties
			&$prepare( $self, $_ );
			my $field = /^(.+)_r[ow]$/ ?  $1 : $_ ;
			$self->$field( ${$proto}->{$_} )
		}	
	}
};

$prepare = sub{
	my $class = ref shift;
	my $row_field = shift;

	my ( $field, $ro ) = $row_field =~ /^(.+)_(r[ow])$/ ? ( $1, $2 ) : $row_field;
	my $slot = "$class\::$field"; 	# inject sub to invocant package space
	no strict 'refs';          		# So symbolic ref to typeglob works.
	return if ( *$slot{CODE} );		# don`t redefine ours closures
	
	*$slot = sub {					# or create closures
		my $self = shift;		
		return $self->{$slot} unless ( @_ );						
		if ( defined $ro && $ro eq 'ro' &&
						!( caller eq ref $self || caller eq __PACKAGE__ ) ){
			die sprintf $err_text, $field, shift, ref $self, caller;
		}
		else {
			return $self->{$slot} = shift;
		}
	};	

};

1;


__END__

=encoding utf-8

=pod

=head1 NAME

Botox - simple implementation of Abstract Factory with prototyping and declared accessibilities for properties: write-protected or public AND default fill it. 

=head1 VERSION

B<$VERSION 0.9.5>

=head1 SYNOPSIS

Botox предназначен для создания объектов с прототипируемыми управляемыми по доступности свойствами: write-protected или public И возможности установки этим свойствам дефолтных значений.

  package Parent;
  use Botox qw(new); # yes, we are got constructor
  
  # default properties for ANY object of `Parent` class:
  # prop1_ro ISA 'write-protected' && prop2 ISA 'public'
  # and seting default value for each other
  our $object_prototype = { 'prop1_ro' => 1 , 'prop2' => 'abcde' }; 


=head1 DESCRIPTION

Botox - простой абстрактный конструктор, дающий возможность создавать объекты по прототипу и управлять их свойствами: write-protected или public. Кроме того он позволяет проставить свойствам значения по умолчанию.

Класс создается так:
   
	package Parent;

	use Botox qw(new);
	our $object_prototype = { 'prop1_ro' => 1 , 'prop2' => 'abcde' };
	
	sub show_prop1{ # It`s poinlessly - indeed property IS A accessor itself
		my ( $self ) = @_;
		return $self->prop1;
	}
	
	sub set_prop1{ # It`s NEEDED for RO aka protected on write property
		my ( $self, $value ) = @_;
		$self->prop1($value);
	}
	
	sub parent_sub{ # It`s class method itself
		my $self = shift;
		return $self->prop1;
	}
	1;


Экземпляр объекта создается так:

	package Child;
	
	my $foo = new Parent;
		
	1;

Собственно, это весь код для создания экземпляра.

	use Data::Dumper;
	print Dumper($foo);
	
Даст нам 

	$VAR1 = bless( {
			'Parent::prop1' => 1,
			'Parent::prop2' => 'abcde'
			 }, 'Parent' );


Свойства, описаные в конструкторе класса, могут наследоваться и иметь права доступа.

Право доступа указывается в имени свойства конструкцией bar + '_ro' или '_rw'(default).
Право на доступ по чтению-записи является правилом по умолчанию, таким образом  его указание не обязательно.
Напротив, ограничение прав "ro - только чтение" требует явного указания этого факта.
Далее для возможности работы с данным свойством НА ЗАПИСЬ из экземпляра объекта следует создать в классе акцессор, например:

	eval{$foo->prop1(-23)};
	print $@."\n";
	
Даст нам что-то вроде:

	Can`t change RO properties |prop1| to |-23| in object Parent from Child at ./test_more.t line 84

Для работы с данным свойством в родительском классе у нас был создан аксессор, который и следует использовать:

	$foo->set_prop1(-23);

Создавая производный класс от родительского

	package Child;	
	use base 'Parent';

	our $object_prototype = {'prop1' => 48, 'prop5' => 55 , 
		'prop8_ro' => 'tetete' };
	1;

В наследство мы получим ВСЕ методы Parent (что ожидаемо) и ВСЕ дефолтные свойства Parent (что неожиданно), и это правильная вещь.
Вероятнее всего методы родителя будут ожидать наличия знакомых им свойств, поэтому они сохраняют свойства атрибута прав доступа (RO\RW), однако позволяют переписать сами значения.

	package GrandChild;

	use Data::Dumper;
	my $baz = new Child;
	
	print Dumper($baz);
	
	eval{$baz->prop1(-23)};
	print $@."\n";

Даст нам вот такой вывод:

	$VAR1 = bless( {
                 'Child::prop5' => 55,
                 'Child::prop2' => 'abcde',
                 'Child::prop1' => 48,
                 'Child::prop8' => 'tetete'
               }, 'Child' );

	Can`t change RO properties |prop1| to |-23| in object Child from GrandChild at ./test_more.t line 84

То есть мы смогли получить новый класс Child на базе Parent со свойствами обоих классов, причем в свойствах преобладают настройки прав свойств родителя и значения свойств ребенка.

=head1 AUTOR	

Meettya <L<meettya@gmail.com>>

=head1 BUGS

Вероятно даже в таком объеме кода могут быть баги. Пожалуйста, сообщайте мне об их наличии по указаному e-mail или любым иным способом.

=head1 SEE ALSO

Moose, Mouse

=head1 COPYRIGHT

B<Moscow>, fall 2009.

=head1 LICENSE

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of the
  License, or (at your option) any later version.  You may also can
  redistribute it and/or modify it under the terms of the Perl
  Artistic License.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

=cut

