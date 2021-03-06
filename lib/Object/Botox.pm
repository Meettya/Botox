package Object::Botox;

use 5.008;
use strict;
use warnings;

our $VERSION = '1.06';
$VERSION = eval $VERSION;

=head1 NAME

Botox - simple implementation of Modern Object Constructor with accessor, prototyping and default-settings of inheritanced values.

=head1 VERSION

B<$VERSION 1.06>

=head1 SYNOPSIS

Botox предназначен для создания объектов с прототипируемыми управляемыми по доступности свойствами: write-protected или public И возможности установки этим свойствам дефолтных значений (как в прототипе, так и при создании объекта). Построение цепочки наследования производится на основе ::mro, методы и свойства переопределяются в потомке.

  package Parent;
  use Botox; # yes, we are got constructor
  
  # default properties for ANY object of `Parent` class:
  # prop1_ro ISA 'write-protected' && prop2 ISA 'public'
  # and seting default value for each other
  
  # strictly named constant PROTOTYPE !
  use constant PROTOTYPE => { 'prop1_ro' => 1 , 'prop2' => 'abcde' }; 

=head1 DESCRIPTION

Botox - простой абстрактный конструктор, дающий возможность создавать объекты по прототипу и управлять их свойствами: write-protected или public. Кроме того он позволяет проставить свойствам значения по умолчанию (как в прототипе, так и при создании объекта).

Класс создается так:
   
	package Parent;

	use Botox;
        
    # strictly named constant PROTOTYPE !
	use constant PROTOTYPE => {
                'prop1_ro' => 1 ,
                'prop2' => 'abcde'
                };
	
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
	# change default value for prop1
	my $foo = new Parent( { prop1 => 888888 } );
		
	1;

Собственно, это весь код для создания экземпляра.

	use Data::Dumper;
	print Dumper($foo);
	
Даст нам 

	$VAR1 = bless( {
			'Parent::prop1' => 888888,
			'Parent::prop2' => 'abcde'
			 }, 'Parent' );


Свойства, описаные в конструкторе класса, могут наследоваться и иметь права доступа.

Право доступа указывается в имени свойства конструкцией bar + '_ro' или '_rw'(default).
Право на доступ по чтению-записи является правилом по умолчанию, таким образом  его указание не обязательно.
Напротив, ограничение прав "ro - только чтение" требует явного указания этого факта.
Далее для возможности работы с данным свойством НА ЗАПИСЬ из экземпляра объекта следует создать в классе акцессор, например:

	eval{ $foo->prop1(-23) };
	print $@."\n";
	
Даст нам что-то вроде:

	Can`t change RO properties |prop1| to |-23| in object Parent from Child at ./test_more.t line 84

Для работы с данным свойством в родительском классе у нас был создан аксессор, который и следует использовать:

	$foo->set_prop1(-23);

Создавая производный класс от родительского

	package Child;	
	use base 'Parent';

	use constant PROTOTYPE => {
                'prop1' => 48,
			    'prop5' => 55 , 
			    'prop8_ro' => 'tetete'
			    };
	1;

В наследство мы получим ВСЕ методы Parent (что ожидаемо) и ВСЕ дефолтные свойства Parent (что неожиданно), и это правильная вещь.
Дефолтные значения И свойства доступа прототипа могут переопределяться в потомке, перезаписывая данные. 

	package GrandChild;

	use Data::Dumper;
	my $baz = new Child();
	
	print Dumper($baz);
	
	eval{$baz->prop8(-23)};
	print $@."\n";
	
	eval{$baz->prop1(1_000)};
	print '$baz->prop1 = '.$baz->prop1()."\n";

Даст нам вот такой вывод:

	$VAR1 = bless( {
                 'Child::prop5' => 55,
                 'Child::prop2' => 'abcde',
                 'Child::prop1' => 48,
                 'Child::prop8' => 'tetete'
               }, 'Child' );

	Can`t change RO properties |prop8| to |-23| in object Child from GrandChild at ./test_more.t line 84
	$baz->prop1 = 1000

То есть мы смогли получить новый класс Child на базе Parent со свойствами обоих классов, причем настройки верхнего уровня переопределяют родительские (включая права доступа).

Кроме того, возможна дефолтная инициализация свойств объекта:

	package GrandChild;

	use Data::Dumper;
	my $baz = new Child(prop1 => 99); # OR ({prop1 => 99}) as you wish
	
	print Dumper($baz);

Даст нам вот такой вывод:

	$VAR1 = bless( {
                 'Child::prop5' => 55,
                 'Child::prop2' => 'abcde',
                 'Child::prop1' => 99,
                 'Child::prop8' => 'tetete'
               }, 'Child' );

При создании объекта возможно задавать значения как rw так и ro свойств(что логично).
Попытка задать значение несуществующего свойства даст ошибку.

При успешном присвоении значения результатом операции является сам объект, т.е. можно создавать цепочки присвоений, типа
    $baz->prop1(88)->prop2('loreum ipsum');
Вероятно это может пригодится.

=cut

use constant 1.01;
use MRO::Compat qw( get_linear_isa ); # mro::* interface compatibility for Perls < 5.9.5
use autouse 'Carp' => qw( croak carp );

my ( $create_accessor, $prototyping, $setup, $pre_set );

my %properties_cache; # inside-out styled chache

my $err_text =  [
	qq(Can`t change RO property |%s| to |%s| in object %s from %s),
	qq(Haven`t property |%s|, can't set to |%s| in object %s from %s),
	qq(Name |%s| reserved as property, but subroutine named |%s| in class %s was founded, new\(\) method from %s aborted),
	qq(Odd number of elements in list),
	qq(Only list or anonymous hash are alowed in new\(\) method in object %s)
		];


=head2 Methods

=over

=item new (public)

new() - создает объект (на основе хеша) по прототипу и инициализирует его

=cut

sub new{
    my $invocant = shift;
    my $self = bless( {}, ref $invocant || $invocant ); # Object or class name 
	exists $properties_cache{ ref $self } ? $pre_set->( $self ) : $prototyping->( $self );
	$setup->( $self, @_ ) if @_;
	return $self;
}

=back

=begin comment import(protected)
    
Parameters: 
    @_ - calling args
Returns: 
    void
Explain:
    - имплантирует в вызывающий метод конструктор new (не думаю, что нужны переименования)

=end comment

=cut

sub import{
    no strict 'refs';
    *{+caller.'::new'} = \&new;
    
}

=begin comment pre_set (private)
	инициирует объект прото-свойствами, если в кеше уже был объект этого класса
Parameters: 
	$self - сам объект
Returns: 
	void
Explain:
	берем список свойств из кеша и делаем инициацию значениями.
	акцессоры у нас УЖЕ есть, нет никакого смысла повторно мутить всю бодягу

=end comment

=cut 


$pre_set = sub{

	my $self = shift;		
	while ( my ($key, $value) = each %{$properties_cache{ ref $self }} ){		
		$self->$key($value);
	};

};


=begin comment prototyping (private)
	конструирует объект по доступным прото-свойствам, объявленным в нем самом или в родителях
Parameters: 
	$self - сам объект
Returns: 
	void
Explain:
	проходимся по дереву объектов, ничиная с самого объекта и
	строим по описанию прототипа все, прибавляя ко всему свойства

=end comment

=cut 


$prototyping = sub{
	
	my $self = shift;
	my $class_list = mro::get_linear_isa( ref $self );	
	# it`s for exist properies ( we are allow redefine, keeping highest )
	my %seen_prop;

	foreach my $class ( @$class_list ){
            
		# next if haven`t prototype
		next unless ( $constant::declared{$class."::PROTOTYPE"} );
 
		my $proto = $class->PROTOTYPE();
		next unless ( ref $proto eq 'HASH' );

		# or if we are having prototype - use it !		
		for ( reverse keys %$proto ) { # anyway we are need some order, isn`t it?
			
			my ( $field, $ro ) = /^(.+)_(r[ow])$/ ? ( $1, $2 ) : $_ ;
			next if ( exists $seen_prop{$field} );
			$seen_prop{$field} = $proto->{$_}; # for caching
			
			$create_accessor->( $self, $field, defined $ro && $ro eq 'ro' );
			$self->$field( $proto->{$_} );
			
			# need check property are REALY setted, or user defined same named subroutine, I think
			unless ( exists $self->{ (ref $self).'::'.$field} ){
				croak sprintf $err_text->[2], $field, $field, ref $self, caller(1);
			}
			
		}
	}
	
	$properties_cache{ ref $self } = \%seen_prop; # for caching
};


=begin comment create_accessor (private)
	создает акцессоры для объекта
Parameters: 
	$class	- класс объекта
	$field	- имя свойста
	$ro	- тип свойства : [ 1|undef ]
Returns: 
	void

=end comment

=cut

$create_accessor = sub{
	my $class = ref shift;
	my ( $field, $ro ) = @_ ;
	
	my $slot = "$class\::$field"; # inject sub to invocant package space
	no strict 'refs';             # So symbolic ref to typeglob works.
	return if ( *$slot{CODE} );   # don`t redefine ours closures
	
	*$slot = sub {      		  # or create closures
			my $self = shift;
			return $self->{$slot} unless ( @_ );
			if ( $ro && !( caller eq ref $self || caller eq __PACKAGE__ ) ){
				croak sprintf $err_text->[0], $field, shift, ref $self, caller;
			}
			$self->{$slot} = shift;
			return $self;	      # yap! for chaining
		};

};

=begin comment setup (private)
	устанавливает свойста объекта при его создании
Parameters: 
	$self - сам объект
	@_ - свойства для установки:
		(prop1=>aaa,prop2=>bbb) AND ({prop1=>aaa,prop2=>bbb}) ARE allowed
Returns: 
	void

=end comment

=cut

$setup = sub{
	my $self = shift;
	my %prop;
	
	if ( ref $_[0] eq 'HASH' ){
	    %prop = %{$_[0]};
	}
	elsif ( ! ref $_[0] ) {
	    unless ( $#_ % 2 ) {
		# so, if list are odd whe are have many troubless,
		# but for support some way as perl 'Odd number at anonimous hash'
		carp sprintf $err_text->[3], caller(1);
		push @_, undef;
	    }
	    %prop = @_ ;
	}
	else {
	    croak sprintf $err_text->[4], ref $self, caller(1);
	}

	while ( my ($key, $value) = each %prop ){
	    # if realy haven`t property in PROTOTYPE
	    unless ( exists ${$properties_cache{ ref $self }}{$key} ) {
		    croak sprintf $err_text->[1], $key, $value, ref $self, caller(1);
	    }
	    $self->$key( $value );
	}

};

1;


__END__


=head1 EXPORT

method |new|

=head1 SEE ALSO

Moose, Mouse, Class::Accessor, Class::XSAccessor

=head1 INSTALLATION

To install this module type the following:

   perl Build.PL
   ./Build
   ./Build test
   ./Build install

=head1 AUTOR	

Meettya <L<meettya@cpan.org>>

=head1 BUGS

Вероятно даже в таком объеме кода могут быть баги. Пожалуйста, сообщайте мне об их наличии по указаному e-mail или любым иным способом.

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
