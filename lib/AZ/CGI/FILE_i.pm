##============================================================================##
##                                                                            ##
##   FILE interface sub-class                                                 ##
##                                                                            ##
##============================================================================##

package AZ::CGI::FILE_i;

use autouse Carp => qw(croak);

sub name {
    croak("Usage: NAME = OBJECT->FILE(...)->name()") unless(@_ == 1);
    return @{$_[0]}? $_[0][0][0] : q();
}

sub base {
    croak("Usage: BASE = OBJECT->FILE(...)->base()") unless(@_ == 1);
    return @{$_[0]}? $_[0][0][1] : q();
}

sub temp {
    croak("Usage: TEMP = OBJECT->FILE(...)->temp()") unless(@_ == 1);
    return @{$_[0]}? $_[0][0][2] : q();
}

sub mime {
    croak("Usage: MIME = OBJECT->FILE(...)->mime()") unless(@_ == 1);
    return @{$_[0]}? $_[0][0][3] : q();
}

sub size {
    croak("Usage: SIZE = OBJECT->FILE(...)->size()") unless(@_ == 1);
    return @{$_[0]}? $_[0][0][4] : 0;
}

1;
