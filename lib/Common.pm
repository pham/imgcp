package Common;

use strict;
use warnings;
use Carp qw/croak confess/;
use Time::Local;
use Exporter qw/import/;

our @EXPORT_OK  = qw/
    ckargv ckargv_filter ckargv_clean extend
    uts2ymd uts2ymdhms ymd2uts utsround
    /;

our %EXPORT_TAGS = (
    all     => \@EXPORT_OK
);

=head1 NAME

C<Aquaron::Common2.pm> - Collection of tools that is used by various packages.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Exportable bits

=head2 Exportable functions

All functions should be exported manually, or you can export all:

 use Common qw/ :all /;

=head2 Functions

=cut

sub __char_to_type {
    return
        $_[0] eq '!' ? 0 :
        $_[0] eq '^' ? 0 :
        $_[0] eq '@' ? [] :
        $_[0] eq '%' ? {} : '';
}

=head3 ckargv (I<{opts}>, I<[list-of-fields]>)

Check for required fields, return undef if all required fields are not met.

 ckargv({ one => 1, three => 3 }, [qw/ one !two three four /]);

Returns undef because C<four> doesn't exist but set C<two> to empty string value.

If validated, returns new data.

=cut

sub ckargv {
    my $opts        = shift;
    my $req         = shift;
    my $def         = shift // {};

    foreach (@$req) {
        if (s/^!([!^@%]?)//) {
            $opts->{$_} ||= $def->{$_} || __char_to_type($1);
        } else {
            confess qq{Missing "$_"} if not defined $opts->{$_};
        }
    }
    return $opts;
}

=head3 ckargv_filter

Similar to C<ckargv> but only return the matched elements.

=cut

sub ckargv_filter {
    my $opts        = shift || {};
    my $req         = shift;
    my $def         = shift // {};
    my $data        = {};

    foreach (@$req) {
        if (s/^!([!^@%]?)//) {
            $data->{$_} ||= $def->{$_} || $opts->{$_} || __char_to_type($1);
        } elsif (not defined $opts->{$_}) {
            confess qq{Missing "$_"};
        } else {
            $data->{$_}    = $opts->{$_};
        }
    }
    return $data;
}

=head3 ckargv_clean

Removes all empty values (use with extend)

=cut

sub ckargv_clean {
    my $opts        = shift // {};

    foreach (keys %$opts) {
        !$opts->{$_} and delete $opts->{$_};
    }
    return $opts;
}


=head3 extend (I<hash_ref1>, I<hash_ref2>)

Combines hashes and return newly formed hash (similar to jQuery $.extend).

=cut

sub extend {
    foreach (@_) {
        ($_ && ref($_) eq 'HASH') // croak q{Requires hash ref};
    }

    my %res     = (%{$_[0]}, %{ckargv_clean($_[1])});
    return \%res;
}


=head3 uts2ymd (I<[time]>)

Returns YYYY-MM-DD for the given C<time>.

=cut

sub uts2ymd {
    my ($y,$m,$d)     = (localtime(shift || time))[5,4,3];

    return sprintf "%04d-%02d-%02d", $y+1900, $m+1, $d;
}

=head3 uts2ymdhms (I<[time]>)

Returns YYYY-MM-DD HH:MM-DD for the given C<time>.

=cut

sub uts2ymdhms {
    my @p             = (localtime(shift || time))[5,4,3,2,1,0];

    return sprintf "%04d-%02d-%02d %02d:%02d:%02d",
        $p[0]+1900, $p[1]+1, $p[2], $p[3], $p[4], $p[5];
}


=head3 ymd2uts (I<YYYY-MM-DD [HH:MM:SS]>)

Returns the C<time> for the given YYYY-MM-DD.

=cut

sub ymd2uts {
    my $date        = shift        // confess q{Missing YYYY-MM-DD string};
    my @d           = split /[\s:-]+/, $date;

    return timelocal(
        $d[5]       || 0,
        $d[4]       || 0,
        $d[3]       || 0,
        $d[2]       || 0,
        $d[1]       ?  $d[1] - 1 : 0,
        $d[0]       || 0
    );
}

=head3 utsround (I<minute|hour|day>, I<[time]>)

Truncate unix timestamp to the current value in C<minute>, C<hour> or C<day>.

=cut

sub utsround {
    my $unit        = shift        // confess q{Missing 'minute', 'hour' or 'day'};
    my $uts         = shift        // time;
    my @p           = split /[\s:-]+/, uts2ymdhms($uts);
    my $nelem       = uc $unit eq 'MINUTE'
                    ? 4 : uc $unit eq 'HOUR'
                    ? 3
                    : 2;

    return ymd2uts(join '-', @p[0..$nelem]);
}

=head1 AUTHOR

Paul Pham

=head1 COPYRIGHT AND LICENSE

(C) Aquaron Corp. All Rights Reserved.

=cut

1;
