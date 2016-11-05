package Catalog;
use strict;
use Args;
use File::Path;
use File::Copy;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	$self->_init(@_);
	return $self;
}

sub _init {
	my $self = shift;
	%$self = Args::validate(@_);
}

sub do {
	my $self = shift;

	my $funcf = sub { 
		my ($src,$f) = (@_);
		my $ctime = (stat "$src/$f")[9];
		my ($dd,$mm,$yy) = (localtime ($ctime))[3,4,5];
		my $dest = sprintf "%s/%04d%02d%02d", 
			$self->{-preserve} ? $src : $self->{-target},
			$yy+1900, $mm+1, $dd;

		mkpath ($dest,0,0755) unless -d $dest;
		copy ("$src/$f", "$dest/$f");
	};

	$self->_read_dirs($self->{-source},$funcf);
}

sub _read_dirs {
	my $self = shift;
	my ($dir,$funcf) = (@_);

	if (opendir DIR, $dir) {
		my @objs = grep !/^\./ && !/^\d{8}/, readdir(DIR);
		closedir DIR;

		my $x = 0;
		my $max = scalar @objs;

		foreach my $obj (@objs) {
			if (-d "$dir/$obj") {
				&_read_dirs("$dir/$obj", $funcf);
			} else {
				&$funcf($dir,$obj);
				$$self->{-progress} = ++$x/$max*100;
			}
		}
	}
}

1;
