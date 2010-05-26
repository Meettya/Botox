package Botox;

use strict;

our $VERSION = 0.8.4;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( new  );

use autouse 'Carp' => qw( carp croak );

sub new{
    my $invocant = shift;
    my $self = bless( {}, ref $invocant || $invocant ); # Object or class name  
   	Botox::prototyping($self);
	return $self;	
}

sub prototyping {
	my ( $proto, $self ) = ( undef, @_ );
	
	{ # just to create $proto
		no strict 'refs';
		$proto = ${( ref $self )."\::prototype"};
	}
	
	# if we are having prototype - use it !
	if( ref $proto eq 'HASH' ){		
		for ( keys %$proto ) {
			Botox::prepare( $self, $_ );
			my $field = /^(.+)_r[ow]$/ ?  $1 : $_ ;
			$self->$field( $proto->{$_} )
		}
	}
};

sub prepare{
	my $class = ref shift;
	foreach ( @_ ) {
		my ( $field, $is_ro ) = /^(.+)_r[ow]$/ ? ( $1, 1 ): $_;
		my $slot = "$class\::$field"; 	# inject sub to invocant package space
		no strict 'refs';          		# So symbolic ref to typeglob works.

		next if ( *$slot{CODE} );		# don`t redefine ours closures
		
		*$slot = sub {					# or create closures
			my $self = shift;
			return $self->{$slot} unless ( @_ );
			
			if ( $is_ro && ! grep { defined $_ and ref $self eq $_ ||
						__PACKAGE__ eq $_ } ( caller, caller 1 ) ){
				carp "Can`t change RO properties \"$field\" in object ".ref $self;
				return undef;
			}
			else {
				$self->{$slot} = shift;
				return $self->{$slot};
			}
		};
	}
}


sub AUTOLOAD{
	my $self = shift;
	croak "$self not object" unless ref $self;
	
	my $name = our $AUTOLOAD;
	return if $name =~ /::DESTROY$/;
	($name) = $name =~ /::(.+)$/;
		
	carp "Haven`t \"$name\" in object ".ref $self;
	undef;
}

1;


__END__

=encoding utf-8

=pod

=head1 NAME

Botox - simple perl OO beauty-shot.

=head1 VERSION

B<$VERSION 0.8.4>

=head1 SYNOPSIS

Botox предназначен для упрощения конструирования классов и объектов, представляя из себя абстрактную фабрику.

  package Parent;
  use Botox qw(:all); # imported ( new prepare set_multi AUTOLOAD )
  our $prototype = { 'prop1_ro' => 1.5 , 'prop2' => 2_000_000 }; # default properties for ANY object of `Parent` class


=head1 DESCRIPTION

Botox - очень простой модуль-подсластитель по мотивам Moose, но не использующий слишком сильной магии, ну почти не использующий.
Его цель - автоматизация конструирования объектов и упрощение синтаксиса ОО.

Класс создается так:
   
   {package Parent;	
	use Botox qw(:all);
	our $prototype = { 'prop1_ro' => 1.5 , 'prop2' => 2_000_000 };
	
	sub show_prop1{
   		my ( $self ) = @_;
   		return $self->prop1;
	}
	
	sub set_prop1{
		my ( $self, $value ) = @_;
		$self->prop1($value);
	}
	1;
   }

Экземпляр объекта создается так:

   {package Child;
	$\ = "\n";
	my $foo = new Parent;

	#show RO property
	print 'Property ',$foo->prop1;
	print 'From accessor ', $foo->show_prop1;
	print 'Try to update RO';
	print $foo->prop1(4) ? 'success' : 'fail' ;	
	print 'Property after update RO ',$foo->prop1;
	
	# RO via accessor
	print 'Try to update RO via accessor';
	print $foo->set_prop1(5) ? 'success' : 'fail' ;	
	print 'Property after update RO via accessor ',$foo->prop1;
	
	#show RW property
	print 'Property ',$foo->prop2;
	print 'Try to update RW';
	print $foo->prop2(4_000_000) ? 'success' : 'fail' ;	
	print 'Property after update RW ',$foo->prop2;	
	
	1;
	}




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

=cut

