package AZ::CGI;

use 5.005;
use strict;
use Fcntl;
use autouse Carp => qw(croak);

use AZ::Splitter q(0.60);

use AZ::CGI::Util;
use AZ::CGI::Mhead;
use AZ::CGI::FILE_i;

our $VERSION = q(0.72);

##============================================================================##
##                                                                            ##
##   Public methods                                                           ##
##                                                                            ##
##============================================================================##

##
##   Constructor.
##   Initializing new class object with default parameters
##

sub new
{
    croak("Usage: OBJECT = AZ::CGI->new()") unless(@_ == 1);
    my $class = shift;
    my $self  = {
        COOKIE     => {},
        FILE       => {},
        GET        => {},
        POST       => {},
        flag       => {},
        set_COOKIE => { cutNull => 1, incEmpty => 0, maxLoops => 128 },
        set_GET    => { cutNull => 1, incEmpty => 0, maxLoops => 128 },
        set_MULTI  => {
                        cutNull    => 1,
                        incEmpty   => 0,
                        maxFiles   => 16,
                        maxKeySize => 128,
                        maxLoops   => 256,
                        maxSize    => 16_777_216,
                        maxValSize => 262_144
                      },
        set_POST   => {
                        cutNull    => 1,
                        incEmpty   => 0,
                        maxKeySize => 128,
                        maxLoops   => 256,
                        maxSize    => 2_097_152,
                        maxValSize => 262_144
                      },
        temp       => []
    };
    return bless($self,$class);
}

##
##   Destructor.
##

sub DESTROY
{
    my $self = shift;

    # Deleting all exists files
    # from temporary files array
    for (@{$self->{temp}})
    {
      next unless -f and not unlink;
        $^W and warn("Can't unlink temporary file $_: $!");
    }

    # Deleting our old undeleted files
    if (not int(rand(50)))
    {
        my($tDir,$tFile,$dh,$file);
        require File::Spec;
          $tDir = File::Spec->tmpdir();
        return unless(opendir($dh,$tDir));
        for(;;)
        {
          last unless
              defined($file=readdir($dh));
            $tFile = File::Spec->catfile($tDir,$file);
            unlink($tFile) if(
              -f $tFile and int(-M $tFile) and not index($file,"AZ_CGI"));
        }
        closedir($dh);
    }
}

##
##   CGI interface wrappers
##

sub GET {
    croak("Usage: VALUE = OBJECT->GET(KEY[,NUMBER])") unless(@_ == 2 or @_ == 3);
    return _iElement(GET => @_);
}

sub GET_is {
    croak("Usage: BOOL = OBJECT->GET_is(KEY[,NUMBER])") unless(@_ == 2 or @_ == 3);
    return _iExists(GET => @_);
}

sub GET_size {
    croak("Usage: SIZE = OBJECT->GET_size(KEY)") unless(@_ == 2);
    return _iSize(GET => @_);
}

sub GET_keys {
    croak("Usage: KEYS = OBJECT->GET_keys()") unless(@_ == 1);
    return _iKeys(GET => @_);
}

sub COOKIE {
    croak("Usage: VALUE = OBJECT->COOKIE(KEY)") unless(@_ == 2);
    return _iElement(COOKIE => @_);
}

sub COOKIE_is {
    croak("Usage: BOOL = OBJECT->COOKIE_is(KEY)") unless(@_ == 2);
    return _iExists(COOKIE => @_);
}

sub COOKIE_keys {
    croak("Usage: KEYS = OBJECT->COOKIE_size()") unless(@_ == 1);
    return _iKeys(COOKIE => @_);
}

sub POST {
    croak("Usage: VALUE = OBJECT->POST(KEY[,NUMBER])") unless(@_ == 2 or @_ == 3);
    return _iElement(POST => @_);
}

sub POST_is {
    croak("Usage: BOOL = OBJECT->POST_is(KEY[,NUMBER])") unless(@_ == 2 or @_ == 3);
    return _iExists(POST => @_);
}

sub POST_size {
    croak("Usage: SIZE = OBJECT->POST_size(KEY)") unless(@_ == 2);
    return _iSize(POST => @_);
}

sub POST_keys {
    croak("Usage: KEYS = OBJECT->POST_keys()") unless(@_ == 1);
    return _iKeys(POST => @_);
}

sub FILE {
    croak("Usage: VALUE = OBJECT->FILE(KEY[,NUMBER])->...") unless(@_ == 2 or @_ == 3);
    return _iFile(@_);
}

sub FILE_is {
    croak("Usage: BOOL = OBJECT->FILE_is(KEY[,NUMBER])") unless(@_ == 2 or @_ == 3);
    return _iExists(FILE => @_);
}

sub FILE_size {
    croak("Usage: SIZE = OBJECT->FILE_size(KEY)") unless(@_ == 2);
    return _iSize(FILE => @_);
}

sub FILE_keys {
    croak("Usage: KEYS = OBJECT->FILE_keys()") unless(@_ == 1);
    return _iKeys(FILE => @_);
}

##
##   Settings interface wrappers
##

sub set_GET    { _set(GET    => @_) }
sub set_COOKIE { _set(COOKIE => @_) }
sub set_POST   { _set(POST   => @_) }
sub set_MULTI  { _set(MULTI  => @_) }

##
##   Utilites
##

sub env
{
    croak("Usage: VALUE = OBJECT->env(KEY)") unless(@_ == 2);
    my(undef,$key) = @_;
    return q() unless exists($ENV{$key}) and defined($ENV{$key});
    return $ENV{$key};
}

sub uri_decode
{
    croak("Usage: DECODED = OBJECT->uri_decode(URI)") unless(@_ == 2);
    my(undef,$uri) = @_;
      _uri_decode_for($uri);
    return $uri;
}

sub uri_encode
{
    croak("Usage: ENCODED = OBJECT->uri_encode(URI)") unless(@_ == 2);
    my(undef,$uri) = @_;
      _uri_encode_for($uri);
    return $uri;
}

##============================================================================##
##                                                                            ##
##   Private interface methods                                                ##
##                                                                            ##
##============================================================================##

##
##   CGI interface methods
##

sub _iElement
{
    my($T,$self,$key,$num) = (@_,0);
      $self->_init($T) unless $self->{flag}{$T};
    return $self->{$T}{$key}[$num] if exists($self->{$T}{$key}[$num]);
    return q();
}

sub _iFile
{
    my($T,$self,$key,$num) = (q(FILE),@_,0);
    my @new;
      $self->_init($T) unless $self->{flag}{$T};
      push(@new,$self->{$T}{$key}[$num]) if exists($self->{$T}{$key}[$num]);
    return bless(\@new,q(AZ::CGI::FILE_i));
}

sub _iExists
{
    my($T,$self,$key,$num) = (@_,0);
      $self->_init($T) unless $self->{flag}{$T};
    return 1 if exists($self->{$T}{$key}[$num]);
    return 0;
}

sub _iSize
{
    my($T,$self,$key) = @_;
      $self->_init($T) unless $self->{flag}{$T};
    return scalar(@{$self->{$T}{$key}}) if exists($self->{$T}{$key});
    return 0;
}

sub _iKeys
{
    my($T,$self) = @_;
      $self->_init($T) unless $self->{flag}{$T};
    return keys(%{$self->{$T}});
}

sub _init
{
    my $self = shift;
    for(@_)
    {
        $self->_init_g(), $self->{flag}{$_}++, next if /GET/;
        $self->_init_c(), $self->{flag}{$_}++, next if /COOKIE/;
        $self->_init_p();
        $self->{flag}{POST}++;
        $self->{flag}{FILE}++;
    }
}

##
##   Settings interface method
##

sub _set
{
    unless(@_ > 2 and not @_ % 2) {
      croak("Usage: OBJECT->set_$_[0](-PARAM => VALUE, ...)");
    }
    my($T,$self,%params,$value,$set) = @_;
    local($_);

    # Checking some stuff
    for($T) {
      croak("Too late for changing settings")
        if exists($self->{flag}{/MULTI/? q(POST) : $_});
    }
    $set = $self->{q(set_).$T};

    # Checking/setting new parameter
    while (($_,$value)=each(%params))
    {
        croak("Parameter name should beggining by '-'") unless(s/^-//);
        croak("Parameter '-$_' is not allowed here") unless(exists($set->{$_}));
        $set->{$_} = (
          /incEmpty|cutNull/ or $value >= 0)? $value : 2e9;
    }
}

##============================================================================##
##                                                                            ##
##   Private structures initialization methods                                ##
##                                                                            ##
##============================================================================##

##
##   GET query parser
##   Usage: SELF->_init_g()
##

sub _init_g
{
    my($self,$stream,$part,@seps) = shift;
    my($pos,$key,$val);

    # Preparing object for handle works with query string
    $stream = AZ::Splitter->new(\($self->env("QUERY_STRING")));
    @seps = qw(& ;);

    # Splitting and storing pairs
    for (1..$self->{set_GET}{maxLoops})
    {
      last unless
          $stream->read_to(\$part,\@seps);
        $pos = index($part,"=") + 1;
        $key = $pos? substr($part,0,$pos-1) : $part;
        $val = $pos? substr($part,$pos) : q();
      next unless length($key);
      next unless
          length($val) or $self->{set_GET}{incEmpty};
        _uri_decode_for($key,$val);
        _cut_null_for($key,$val) if $self->{set_GET}{cutNull};
        push(@{$self->{GET}{$key}},$val);
    }
}

##
##   COOKIE string parser
##   Usage: SELF->_init_c()
##

sub _init_c
{
    my($self,$stream,$seps,$part) = shift;
    my($pos,$key,$val,$query);

    # Preparing object for
    # handle works with COOKIE string
    $query  = $self->env("HTTP_COOKIE");
    $query  = $self->env("COOKIE") unless length($query);
    $stream = AZ::Splitter->new(\$query);

    # Splitting and storing pairs
    for (1..$self->{set_COOKIE}{maxLoops})
    {
      last unless
          $stream->read_to(\$part,";");
        $pos = index($part,"=") + 1;
        $key = $pos? substr($part,0,$pos-1) : $part;
        $val = $pos? substr($part,$pos) : q();
        _trim_for($key,$val);
      next unless length($key);
      next unless
          length($val) or $self->{set_COOKIE}{incEmpty};
        _uri_decode_for($key,$val);
        _cut_null_for($key,$val) if $self->{set_COOKIE}{cutNull};
        $self->{COOKIE}{$key} = [$val];
    }
}

##
##   POST query parser (main part)
##   Usage: SELF->_init_p()
##

sub _init_p
{
    my($self,$clen,$ctype,$tm) = shift;

    # Checking some enviroment variables.
    # Reading and parsing 'Content-Type' string
    return unless
        $self->env("REQUEST_METHOD") eq "POST";
      $clen = _to_numeric($self->env("CONTENT_LENGTH"));
    return unless $clen > 0;
      $ctype = AZ::CGI::Mhead->new();
      $ctype->add_line(\("Content-Type: ".$self->env("CONTENT_TYPE")));

    # Checking Content-Length
    # and running subroutine depending by Content-Type
    $tm = $ctype->value_get("Content-Type");
    if ($tm eq "application/x-www-form-urlencoded")
    {
      return unless
          $clen <= $self->{set_POST}{maxSize};
        $self->_init_p_simple($clen);
    }
    elsif ($tm eq "multipart/form-data")
    {
      return unless
          $clen <= $self->{set_MULTI}{maxSize};
        $tm = $ctype->value_get("Content-Type","boundary");
      return unless length($tm);
        $self->_init_p_multipart($clen,$tm);
    }
}

##
##   POST simple query parser
##   Usage: SELF->_init_p_simple(CONTENT_LENGTH)
##

sub _init_p_simple
{
    # Usual POST query, but not usual algorithm,
    # without loading all POST data into memory ;-)
    my($self,$clen) = @_;
    my($stream,$key,$val);

    # Initializing object for
    # handle works with input stream
    binmode STDIN;
      $stream = AZ::Splitter->new(\*STDIN,$clen);

    # Reading, decoding and storing pairs
    for (1..$self->{set_POST}{maxLoops})
    {
      last unless
          $stream->read_to(\$key,"=",$self->{set_POST}{maxKeySize}+1,s_WEND);
        $stream->read_to(\$val,"&",$self->{set_POST}{maxValSize});
      next unless length($key);
      next unless length($val) or $self->{set_POST}{incEmpty};
      next unless
          length($key) <= $self->{set_POST}{maxKeySize};
        _uri_decode_for($key,$val);
        _cut_null_for($key,$val) if $self->{set_POST}{cutNull};
        push(@{$self->{POST}{$key}},$val);
    }
}

##
##   POST multipart query parser
##   Usage: SELF->_init_p_multipart(CONTENT_LENGTH, BOUNDARY)
##

sub _init_p_multipart
{
    # Here too, we working with POST data
    # directly, without full loading into memory
    my($self,$clen,$sep) = @_;
    my($crlf,$nforw,$tm,$name,$loop) = (qq(\r\n),1);
    my($fcount,$header,$stream) = $self->{set_MULTI}{maxFiles};;

    # Initializing objects
    # for handle works with input stream and multipart headers   
    # and little correcting separator
    binmode STDIN;
      $stream = AZ::Splitter->new(\*STDIN,$clen);
      $header = AZ::CGI::Mhead->new();
    $sep = q(--).$sep;

    # Main cycle. Having limit
    # quantity of iterations for security check
    for ($loop = $self->{set_MULTI}{maxLoops}; $loop--> 0;)
    {
        # Rewind position to next found separator,
        # if this was'nt disabled. And let reading header
      last unless not $nforw++ or
          $stream->read_to(undef,$sep,-1,s_WEND);
      last unless $stream->read_some(\$tm,2);
      last unless $tm eq $crlf;
      last unless
          $stream->read_to(\$tm,($crlf x2),8*1024,s_WEND);
        $header->clear();
        $header->add_line(\$_) for split($crlf,$tm,6);

        # Checking header,
        # extracting and checking parameter 'name'
      next unless
          $header->value_get("Content-Disposition") eq "form-data";
        $name = $header->value_get("Content-Disposition","name");
      next unless length($name);
      next unless length($name) <= $self->{set_MULTI}{maxKeySize};
        _cut_null_for($name)
          if $self->{set_MULTI}{cutNull};

        # Let look what we have
        if ($header->value_is("Content-Disposition","filename"))
        { if ($fcount)
        {
            # File transfer
            my($fh,$file,$base,$mime);

            # Correct/check filename, create
            # new temporary file and read all data, before next
            # found separator directly to temporary file
            $tm = $header->value_get("Content-Disposition","filename");
            $base = _simple_basename($tm);
          next unless
              length($base) and ($fh,$file) = $self->_tmp_file();
          last unless $stream->read_to($fh,$crlf.$sep,-1,s_WEND);
            $nforw = 0;
          next unless close($fh) and
              $stream->stat_wsize() == $stream->stat_rsize();
            $mime = $header->value_get("Content-Type");
            _cut_null_for($tm,$base,$mime) if $self->{set_MULTI}{cutNull};
            push(@{$self->{FILE}{$name}},[
              $tm,$base,$file,$mime,$stream->stat_rsize()]);
            $fcount--;
        }}

        elsif ($header->value_get("Content-Type") eq "multipart/mixed")
        { if ($fcount)
        {
            # Many files transfer
            my($mnforw,$msep,$mheader) = 1;
            my($fh,$file,$base,$mime);

            # Extracting, checking
            # and little correcting multipart/mixed separator.
            # Initializing object for handle works with headers
            $msep = $header->value_get("Content-Type","boundary");
          next unless length($msep);
            $mheader = AZ::CGI::Mhead->new();
            $msep = q(--).$msep;

            # Main multipart/mixed cycle
            # Also having limit for quantity of iterations
            for (++$loop; $fcount and $loop--> 0;)
            {
                # Rewind position to next found separator,
                # if this was'nt disabled. And let reading header
              last unless not $mnforw++ or
                  $stream->read_to(undef,$msep,-1,s_WEND);
              last unless $stream->read_some(\$tm,2);
              last unless $tm eq $crlf;
              last unless
                  $stream->read_to(\$tm,($crlf x2),8*1024,s_WEND);
                $mheader->clear();
                $mheader->add_line(\$_) for split($crlf,$tm,6);

                # Checking multipart/mixed header
                $tm = $mheader->value_get("Content-Disposition");
              next unless $tm eq "file" or $tm eq "attachment";
              next unless
                  $mheader->value_is("Content-Disposition","filename");

                # Correct/check filename, create
                # new temporary file and read all data, before next
                # found separator directly to temporary file
                $tm = $mheader->value_get("Content-Disposition","filename");
                $base = _simple_basename($tm);
              next unless
                  length($base) and ($fh,$file) = $self->_tmp_file();
              last unless $stream->read_to($fh,$crlf.$msep,-1,s_WEND);
                $mnforw = 0;
              next unless close($fh) and
                  $stream->stat_wsize() == $stream->stat_rsize();
                $mime = $mheader->value_get("Content-Type");
                _cut_null_for($tm,$base,$mime) if $self->{set_MULTI}{cutNull};
                push(@{$self->{FILE}{$name}},[
                  $tm,$base,$file,$mime,$stream->stat_rsize()]);
                $fcount--;
            }
        }}

        else
        {
            # Simple value.
            # Reading and storing data before next found separator
          last unless $stream->read_to(
              \($tm),$crlf.$sep,$self->{set_MULTI}{maxValSize},s_WEND);
            $nforw = 0;
          next unless
              $stream->stat_rsize() or $self->{set_MULTI}{incEmpty};
            _cut_null_for($tm) if $self->{set_MULTI}{cutNull};
            push(@{$self->{POST}{$name}},$tm);
        }
    }
}

##============================================================================##
##                                                                            ##
##   Private utilites methods                                                 ##
##                                                                            ##
##============================================================================##

##
##   Temporary files generator
##   Usage: (HANDLER, FILENAME) = SELF->_tmp_file()
##

sub _tmp_file
{
    my($self,$fh,$file) = shift;
    require File::Spec;

    # Three attempts to create new
    # temporary file in shared temporary directory
    for (1..3)
    {
      $file = File::Spec->catfile(
          File::Spec->tmpdir(),"AZ_CGI_"._gen_rstr(16).".tmp"
        );
      next unless
          sysopen($fh,$file,O_WRONLY|O_CREAT|O_EXCL|O_BINARY);
        push(@{$self->{temp}},$file);
      return($fh,$file);
    }
    # Well, only stay to generate
    # warning message and returns empty array..
    $^W and warn(
      "Can't create temporary file at directory: ".File::Spec->tmpdir()
    );
    return();
}

1;
