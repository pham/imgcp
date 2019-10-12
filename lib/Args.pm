package Args;

=head1 NAME

Args - parses a list of arguments and determine configuration

=head1 SYNOPSYS

    use Args;
    my %conf = Args::validate(@ARGV);
    print ($conf{-filename} || "Cannot find configuration '-filename'"), "\n";

    ### Dumps out all valid configurations
    foreach (sort keys %conf) {
        printf "key=[%s] val=[%s]\n", $_, $conf{$_};
    }

=head1 DESCRIPTION

Given a list of arguments, this module will determine a pair of parameters
of the form: C<-config> and C<value>. For example, if you have a list of
arguments taken from command-line:

    ./program -param1 file1 -param2 file2 -param3 -param4

This module will return a hash:

    %hash = (
        '-param1' => 'file1',
        '-param2' => 'file2'
    );

=cut

use strict;

=head2 Public Methods

=head3 validate (I<@array>)

Takes in a I<list> and return a hash of valid configurations

=cut

sub validate {
    my %self = ();
    for (my $i=0; $i<scalar @_; $i+=2) {
        if ($_[$i] =~ /^-/) {
            $self{$_[$i]} = $_[$i+1]
        }
    }
    return %self;
}

=head3 add (I<$class>,I<@array>)

Similar to C<validate> except does not return a value, rather takes in
an class as the initial argument and populates its values.

=cut

sub add {
    my $self = shift;
    for (my $i=0; $i<scalar @_; $i+=2) {
        next unless $_[$i];
        if ($_[$i] =~ /^-/) {
            $self->{$_[$i]} = $_[$i+1]
        }
    }
}

1;

__END__

=head1 HISTORY

20050420 - Created

20050422 - Added C<add> subroutine.

=head1 AUTHOR

This module by Paul Pham <paul@aquaron.com>.

=cut
