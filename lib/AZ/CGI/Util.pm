##============================================================================##
##                                                                            ##
##   Sub-class with some utilite funstions                                    ##
##                                                                            ##
##============================================================================##

package AZ::CGI::Util;

use strict;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(_trim_for _cut_null_for _cut_quotes_for _to_numeric
                 _gen_rstr _simple_basename _uri_decode_for _uri_encode_for
               );

our(@_clat,$_clat_size,%_chr2hex);

##
##   Random strings generator. (Normal works only with little size)
##   Usage: STRING = _gen_rstr(SIZE)
##

sub _gen_rstr($)
{
    my($size,$str) = @_;
    unless(@_clat)
    {
      @_clat = ("a".."z","A".."Z","0".."9");
      $_clat_size = @_clat - 0.5;
    }
    $str .= $_clat[rand($_clat_size)] for(1..$size);
    return $str;
}

##
##   Convert string to numeric without warnings
##   Usage: NUMBER = _to_numeric(STRING)
##

sub _to_numeric($)
{
    no warnings;
    return $_[0] + 0;
}

##
##   Extracting file name from path. Very simple variant, but here more then enough
##   Usage: BASENAME = _simple_basename(PATH)
##

sub _simple_basename($)
{
    for(@_)
    {
      return /([^\\\/\:]+)$/? $1 : q();
    }
}

##
##   Url-formed strings decoder
##   Usage: _uri_decode_for(STRING1[,STRING2[,...]])
##

sub _uri_decode_for
{
    no warnings;
    for(@_)
    {
      tr/+/ /;
      if ($] > 5.007)
      {
          use bytes;
          s/%u([0-9a-fA-F]{4})/pack("U",hex($1))/eg;
      }
      else
      {
          my($dec);
          s/%u([0-9a-fA-F]{4})
          /
              # Here utf-8 characters can have
              # maximal length 3 bytes (4 hex simbols)
              $dec = hex($1);
              if ($dec < 0x80) { chr($dec) }
              else
              { if ($dec < 0x800)
                {
                  pack("c2",0xc0|($dec>>6),0x80|($dec&0x3f));
                } else {
                  pack("c3",0xe0|($dec>>12),0x80|(($dec>>6)&0x3f),0x80|($dec&0x3f));
                }
              }
          /egx;
      }
      s/%([0-9a-fA-F]{2})/chr(hex($1))/eg;
    }
}

##
##   Url-formed strings encoder
##   Usage: _uri_encode_for(STRING1[,STRING2[,...]])
##

sub _uri_encode_for
{
    unless(%_chr2hex)
    { for(0..255)
    {
      $_chr2hex{chr()} = sprintf("%%%02X",$_);
    }}

    for(@_)
    {
      s/([^A-Za-z0-9\-_.!~*\'() ])/$_chr2hex{$1}/g;
      tr/ /+/;
    }
}

##
##   Remove leading and trailing spaces
##   Usage: _trim_for(STRING1[,STRING2[,...]])
##

sub _trim_for
{
    for(@_)
    {
      s/^\s+//;
      s/\s+$//;
    }
}

##
##   Remove null-code simbols from strings
##   Usage: _cut_null_for(STRING1[,STRING2[,...]])
##

sub _cut_null_for
{
    for(@_)
    {
      tr/\0/ /;
    }
}

##
##   Remove double quotes from strings
##   Usage: _cut_quotes_for(STRING1,STRING2,...)
##

sub _cut_quotes_for
{
    for(@_)
    {
      s/^\"(.*)\"$/$1/s;
    }
}

1;
