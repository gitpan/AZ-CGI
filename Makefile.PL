##============================================================================##
##                                                                            ##
##   AZ::CGI Makefile                                                         ##
##                                                                            ##
##============================================================================##

use 5.005;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME           => 'AZ::CGI',
    VERSION_FROM   => 'lib/AZ/CGI.pm',
    ABSTRACT_FROM  => 'lib/AZ/CGI.pod',
    AUTHOR         => 'Andrian Zubko, <ondr@mail.ru>',
    PREREQ_PM      => { AZ::Splitter => q(0.60) }
);
