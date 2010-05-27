package Botox;

use strict;

our $VERSION = 0.9.3;

use Exporter 'import';
our @EXPORT_OK = qw(new);

my ( $prepare, $prototyping, $error_stack );
my $err_text = qq(Can`t change RO properties |%s| to |%s| in object %s from %s at %s line %s\n);

sub new{
    my $invocant = shift;
    my $self = bless( {}, ref $invocant || $invocant ); # Object or class name  
   	&$prototyping( $self );
	return $self;
}

$prototyping = sub{
	my $self = shift;
	my $proto = (ref $self )."\::object_prototype";
	
	no strict 'refs';
	# exit if havent prototype
	return unless ( ${$proto} && ref ${$proto} eq 'HASH' );
	# or if we are having prototype - use it !		
	for ( keys %${$proto} ) {
		&$prepare( $self, $_ );
		my $field = /^(.+)_r[ow]$/ ?  $1 : $_ ;
		$self->$field( ${$proto}->{$_} )
	}
};

$prepare = sub{
	my $class = ref shift;
	foreach ( @_ ) {
		my ( $field, $is_ro ) = /^(.+)_r[ow]$/ ? ( $1, 1 ) : $_;
		my $slot = "$class\::$field"; 	# inject sub to invocant package space
		no strict 'refs';          		# So symbolic ref to typeglob works.

		next if ( *$slot{CODE} );		# don`t redefine ours closures

		*$slot = sub {					# or create closures
			my $self = shift;
			
			return $self->{$slot} unless ( @_ );
							
			if ( $is_ro && !( caller eq ref $self || caller eq __PACKAGE__ ) ){
				die sprintf $err_text, $field, shift, ref $self, caller;
			}
			else {
				return $self->{$slot} = shift;
			}
		};	
	}
};

1;


__END__

=encoding utf-8

=pod

=head1 NAME

Botox - simple implementation of Abstract Factory with prototyping and declared accessibilities for properties: write-protected or public AND default fill it. 

=head1 VERSION

B<$VERSION 0.9.4>

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
   
	{	package Parent;
	
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
	}

Экземпляр объекта создается так:

	{	package Child;
	
		my $foo = new Parent;
		
		1;
	}

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
Далее для возможности работы с данным свойством НА ЗАПИСЬ из экземпляра объекта следует создать в классе акцессор:

   #$foo->surname('sheep'); # wrong! surname is RO properties, create acessor in Parent instead
   # - need in Parent -
    sub set_surname {
    my $self = shift;
    $self->surname(shift) if @_;
    }
   # - then in Child - 
    $foo->set_surname('sheep'); # right! you are create acessor.

В Botox свойства, подобно методам, B<наследуются>. Создавая класс с двумя и более предками следует внимательно отнестись к очередности указания родителей класса. Левый родитель получает приоритет при наличии одинаковых свойств.

Для облегчения инициализации свойств экземпляра в Botox имеется метод set_multi (только для RW-свойств)
	
	$foo->set_multi(name=>'Dolly',adress=>'Scotland, Newerland');

Метод prepare может быть вызван для создания свойств вместо передачи списка методу new

  {{{package Parent;	
    use Botox qw(new prepare set_multi AUTOLOAD);
    my $object = new Parent;
	$object->prepare(qw(name adress_rw surname_ro));
	1;
  }}}

Использование AUTOLOAD объясняется желанием сэкономить нервы, выдавая нефатальное сообщение об отсутствии свойства или метода в классе.
ИМХО! Фатализм и повышеная смертность приложений при малейших ошибках является ошибкой проектирования системы.

=head1 AUTOR	

Meettya <L<meettya@gmail.com>>

=head1 BUGS

Вероятно даже в таком объеме кода могут быть баги. Пожалуйста, сообщайте мне об их наличии по указаному e-mail или любым иным способом.

=head1 SEE ALSO


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

