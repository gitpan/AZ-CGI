##============================================================================##
##                                                                            ##
##   Sub-class for parsing multipart/form-data headers                        ##
##                                                                            ##
##============================================================================##

package AZ::CGI::Mhead;

use AZ::Splitter;
use AZ::CGI::Util;

##
##   Constructor
##   Usage: AZ::CGI::Mhead->new([REFERENCE])
##

sub new
{
    my $class = shift;
    my $self  = bless({},$class);
       $self->add_line(@_) if @_;
    return $self;
}

##
##   Parsing and storing pairs from string line
##   Usage: OBJECT->add_line(REFERENCE)
##

sub add_line
{
    my($self,$ref) = @_;
    my($grp,$key,$val,$stream,@seps);

    @seps = (";",",");
    $stream = AZ::Splitter->new($ref);

    # Reading and storing main pair
    # Main pair should exists and be not empty
    return unless
        $stream->read_to(\$grp,":",-1,s_WEND);
      _trim_for($grp);
    return unless length($grp)
        and $stream->read_to(\$val,\@seps);
      _trim_for($val);
    return unless length($val);
      $grp = lc($grp);
      $self->{$grp}[0] = $val;

    # Reading other pairs
    # For security check, cycle have maximum 4 iterations
    for (1..4)
    {
      last unless
          $stream->read_to(\$key,"=",-1,s_WEND);
        _trim_for($key);
        ($key eq "filename")? $stream->read_some(\$val)
          :$stream->read_to(\$val,\@seps);
      next unless length($key);
        _trim_for($val);
        _cut_quotes_for($val);
        $self->{$grp}[1]{$key} = $val;
    }
}

##
##   Get one element
##   Usage: VALUE = OBJECT->value_get(GROUP[,KEY])
##

sub value_get
{
    my($self,$grp,$key) = @_;
      $grp = lc($grp);
    return q() unless exists($self->{$grp});
    return $self->{$grp}[0] if @_ < 3;
    return $self->{$grp}[1]{$key} if exists($self->{$grp}[1]{$key});
    return q();
}

##
##   Check for element exists
##   Usage: BOOL = OBJECT->value_is(GROUP[,KEY])
##

sub value_is
{
    my($self,$grp,$key) = @_;
      $grp = lc($grp);
    return 0 unless exists($self->{$grp});
    return 1 if @_ < 3;
    return 1 if exists($self->{$grp}[1]{$key});
    return 0;
}

##
##   Clear all stored data
##   Usage: OBJECT->clear()
##

sub clear { %{$_[0]} = () }

1;
