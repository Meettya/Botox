use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Object::Botox',
    AUTHOR              => 'Meettya <meettya@gmail.com>',
    VERSION_FROM        => 'lib/Object/Botox.pm',
    ABSTRACT		 => 'Advanced Object constructor',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Object-Botox-*' },
);
