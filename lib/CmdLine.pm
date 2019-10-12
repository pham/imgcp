package CmdLine;
use strict;

=head1 NAME

CmdLine - Command line parsing

=head1 SYNOPSIS

    use CmdLine;

    my $cl = new CmdLine(@ARGV);
    $cl->Set(-internal => 'Internal Key');

    $cl->Unset(qw/-file -internal/);

    $cl->Dump;

=head1 DESCRIPTION

Parses the command line arguments C<@ARGV> into their respective C<-key>
and C<value> pairs.

=head2 Public Methods

=head3 new (I<@array>)

Create a CmdLine object. With the supplied array, parses through the list
to find elements starting with a I<dash> (C<->) followed by an element B<not>
starting with a I<dash>. These are combined into a key/val pairs stored in
the internal hash.

=cut

sub new {
    my $class           = shift ;
    my $self            = {};

    bless $self, $class;

    $self->_init(@_);

    return $self;
}

=head3 silent (I<@array>)

Same as new except removes the prefix '-' from all keys and does not print
error messages.

=cut

sub silent {
    my $class           = shift ;
    my $self            = {};

    bless $self, $class;
    $self->_silent(@_);

    return $self;
}

=head3 Count

Return the total count of the keys

=cut

sub Count {
    return scalar keys %{ $_[0] };
}

=head3 Set (I<@array>)

Reset the values, or setting new key/value pairs.

=cut

sub Set {
    my $self            = shift ;

    $self->_init(@_);
}

=head3 SetRaw (I<%params>)

Takes a list and turn them into internal key/value pairs.

=cut

sub SetRaw {
    my $self            = shift ;
    my $params          = shift || {};

    foreach (keys %$params) {
        $self->{$_}     = $params->{$_};
    }
}

=head3 Unset (I<@keys>)

Deletes supplied list of keys.

=cut

sub Unset {
    my $self            = shift ;

    map { delete $self->{$_} } @_;
}

=head3 Get (I<key>)

Get a value for given key. Always an empty string for errors.

=cut

sub Get {
    my $self            = $_[0];
    my $key             = $_[1] // return q{};
    return $self->{$key} // return q{};
}

=head3 Dump

Print out all key/value pairs.

=cut

sub Dump {
    my $self            = shift ;
    foreach (sort keys %$self) {
        printf "%20s => %s\n", $_, $self->{$_}
    }
}

=head2 Private Methods

=head3 _init (I<@array>)

Initializes the array of key/value pairs. If a key is not recognized, it will
print "Unrecognized" and not populate that key.

=cut

sub _init {
    my $self            = shift ;

    for (my $x=0; $x<scalar @_; $x++) {
        ### if the next argument starts with a '-' then it's a flag
        if (not defined $_[$x+1] or $_[$x+1] =~ /^-/) {
            if ($_[$x] =~ /^-/) {
                $self->{$_[$x]} = 1;
            } else {
                printf "Unrecognized: \"%s\"\n", $_[$x];
                $x++;
            }
        } elsif ($_[$x] =~ /^-/) {
            $self->{$_[$x]} = $_[$x+1];
            $x++;
        } else {
            printf "Unrecognized: \"%s\"\n", $_[$x];
            $x++;
        }
    }
    return undef;
}

sub _silent {
    my $self            = shift ;

    for (my $x=0; $x<scalar @_; $x++) {
        if (not defined $_[$x+1] or $_[$x+1] =~ /^-/) {
            if ($_[$x] =~ s/^-//) {
                $self->{$_[$x]}         = 1;
            } else {
                $x ++;
            }
        } elsif ($_[$x] =~ s/^-//) {
            $self->{$_[$x]}             = $_[$x+1];
            $x ++;
        } else {
            $x ++;
        }
    }
    return undef;
}

1;

__END__

=head1 HISTORY

20050420 - Created

20050914 - Looking for a defined value, not a '0' in the parameter.

20061011 - add _silent for compatibility with CGI's that removes the '-'
from the keys.

=head1 AUTHOR

This module by Paul Pham <paul@aquaron.com>

=cut
