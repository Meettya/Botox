#!/usr/bin/perl -w

{{{package Botox;

use strict;

our $VERSION = 0.4.1;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(new prepare set_multi AUTOLOAD);
our %EXPORT_TAGS = ( all => [qw(new prepare set_multi AUTOLOAD)]);

use autouse 'Carp' => qw(carp croak);

sub new {
    my $invocant = shift;
    my $self = bless({}, ref $invocant || $invocant);
    $self->prepare(@_) if @_;
    return $self;
}

sub prepare {
	my $class = ref shift;
	foreach (@_) {
		my ($field,$ro) = /^(.+)_(r[ow])$/?($1,$2):($_,'');
		my $slot = "$class\::$field"; #inject sub to invocant package space
		no strict "refs";          # So symbolic ref to typeglob works.
		*$slot = sub {
			my $self = shift;
			if (@_) {
				if(('ro' eq $ro) && !(((caller)[0] && ref $self eq (caller)[0]) || ((caller 1)[0] && ref $self eq (caller 1)[0]))){
					carp "Can`t change RO properties \"$field\" in object ".ref $self;}
				else {$self->{$slot} = shift;}
			}
			return $self->{$slot};
		};
	}
}


sub set_multi  {
	my $self = shift;
	my %var = @_;	
	no strict "refs";
	foreach (keys %var) {
		$self->$_($var{$_})	
	}
}


sub AUTOLOAD {
my $self = shift;
croak "$self not object" unless ref $self;

my $name = our $AUTOLOAD;
return if $name =~ /::DESTROY$/;
($name) = $name =~ /::(.+)$/;
carp "Haven`t properties \"$name\" in object ".ref $self;
}

1;
}}}

__END__

=encoding utf-8

=pod

=head1 NAME

Botox - simple perl OO beauty-shot.

=head1 SYNOPSIS

Botox предназначен для упрощения конструирования классов и объектов.

  use Botox qw(new prepare set_multi AUTOLOAD);
  my $object = new Parent(qw(name adress_rw surname_ro));


=head1 DESCRIPTION

Botox - очень простой модуль-подсластитель по мотивам Moose, но не использующий слишком сильной магии.
Здесь есть лишь пара легких трюков, которым можно запросто научится за полчасика.

Класс создается так:
	
 {{{package Parent;	
   use Botox qw(new prepare set_multi AUTOLOAD); # now you KNOW how mach is it cost.
   my $object = new Parent(qw(name adress_rw surname_ro));
   1;
 }}}

Экземпляр объекта создается так:
	
 {{{package Child;
   my $foo = new Parent;
   $foo->set_multi(name=>'Dolly',adress=>'Scotland, Newerland');
 }}}

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
