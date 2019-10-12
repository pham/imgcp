package ReadDir;

use strict;
use Args;

=head1 NAME

ReadDir - a module to read--recursively--a given directory

=head1 SYNOPSIS

    use ReadDir;
    my $dir = ReadDir('/root');

    ### Get a list of all modules under /root
    my @files = $dir->Get(-type => 'files', -filter => qr/\.pm$/);

    ### get a list of only directory names
    my @dirs = $dir->Get(-type => 'dirs');

=head1 DESCRIPTION

Traverse through a directory and read all directories and files under the
directory. You can return a list of sub-directories or a list of files.

=head2 Public Method

=head3 new (F<dirname>)

Given a valid directory, invocation of this method will return an object
containing one element: C<-dir> of which the value will be the supplied
F<dirname>.

=cut

sub new {
    my $class = shift;
    my $self = { -dir => shift };
    bless $self, $class;
    return $self;
}

=head3 Get ([options])

The main method of this object. Read a given directory and return based on
the supplied request C<files|dirs>, it will return a list of elements. If
a C<-filter> option is specified, it will only return elements that matches
the criteria.

=head2 Options

=over 4

=item -dir => F<dirname>

Starting directory name

=item -type => [dirs|files]

Type of data to return, C<dirs> will return directories
C<files> will return files. Default type is C<files>.

=item -filter => qr/I<regex>/

Optional option to pre-filter the result. Must be a precompiled I<regex>
for this filter to work. By the same token, you could post-filter the
result after the list has been returned.

=back

=cut

sub Get {
    my $self = shift;
    return undef if !$self->{-dir};

    my %args = Args::validate(@_);

    undef my @list;

    if ($args{-type} eq "dirs")
        {
        &_get_dir($self->{-dir},\@list);
        }
    else
        {
        &_get_all($self->{-dir},\@list);
        }

    return grep /$args{-filter}/, @list if ($args{-filter});
    return @list;
}

=head2 Private Methods

=head3 _get_dir (F<directory>,I<@list>)

Recursively call itself to read all the directories and return only dirs.

=cut

sub _get_dir {
    my $dir = shift;
    my $list = shift;

    if (opendir F, $dir) {
        my @files = grep !/^\./ && -d "$dir/$_", readdir (F);
        closedir F;
        foreach my $f (@files) {
            push @$list, "$dir/$f";
            &_get_dir("$dir/$f", $list);
        }
    }
    return undef;
}

=head3 _get_all (F<directory>,I<@list>)

Similar to C<_get_dirs> except returns all the files instead of directories.

=cut

sub _get_all {
    my $dir = shift;
    my $list = shift;

    if (opendir F, $dir) {
        my @files = grep !/^\./, readdir (F);
        closedir F;
        foreach my $f (@files) {
            if (-d "$dir/$f") {
                &_get_all("$dir/$f", $list);
            } else {
                push @$list, "$dir/$f";
            }
        }
    }
    return undef;
}

1;

__END__

=head1 DEPENDENCIES

=for html <a href="{#h.ref#}&amp;_pod=Args">Args</a>

=head1 HISTORY

20050420 - Created

=head1 AUTHOR

This module by Paul Pham <paul@aquaron.com>.

=cut
