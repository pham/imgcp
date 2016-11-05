#!perl -w

use POSIX;
use Tk;
use Tk::JPEG;
use Tk::DirTree;
use Tk::ProgressBar;
use Image::Magick;
use File::Path;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Time::Local;

use constant PRODUCT     =>  "mkimage v1.2";
use constant OR_CW       =>  8;
use constant OR_CCW      =>  6;
use constant IM_WIDTH    =>  380;
use constant WIDTH       =>  390;
use constant HEIGHT      =>  200;
use constant QUALITY     =>  88;

use constant FLAG_NORMAL =>  1<<0;
use constant FLAG_CAT    =>  1<<1;
use constant FLAG_ZIP    =>  1<<2;
use constant FLAG_GRAY   =>  1<<3;
use constant FLAG_EQ     =>  1<<4;
use constant FLAG_NORM   =>  1<<5;
use constant FLAG_THUMB  =>  1<<6;
use constant FLAG_IMAGE  =>  1<<7;
use constant FLAG_VIEW   =>  1<<8;
use constant FLAG_UNCAT  =>  1<<9;
use constant FLAG_RETIME =>  1<<10;
use constant FLAG_BYDATE =>  1<<11;
use constant FLAG_PRESRV =>  1<<12;

use constant ICON     => << '.';
R0lGODlhIAAgAIAAAGYAADMAACH5BAAAAAAALAAAAAAgACAAAAJVhI+py+0Po5y0omBjwHT7zwGb
BX7HmDloel4hK4YrvM6k52qNbTP9/gJOfgri4hc0uoKnl/IibMIMz0yV+bhioyVQpdbdqsTTcsdc
JPvCJitbjX4UAAA7
.

use vars qw/$PROGRESS $BUTTON $PFRAME $MW $FLAG $DIR/;

my @COPTS = ('uncat','retime','bydate','presrv');
my @IOPTS = ('image','thumb','gray','norm','eq');
my @POPTS = ('view');
my %CONF = (
	'cat'    => { "d" => 'Categorize Images'           },
	'uncat'  => { "d" => 'Uncategorize'                },
	'retime' => { "d" => 'Restore original time'       },
	'bydate' => { "d" => 'By date only'                },
	'presrv' => { "d" => 'Preserve dir structure'      },
	'parse'  => { "d" => 'Parse Images'                },
	'zip'    => { "d" => 'Pack Images'                 },
	'thumb'  => { "d" => 'Create thumbnails'           },
	'image'  => { "d" => 'Create images'               },
	'gray'   => { "d" => 'Gray thumbnails'             },
	'norm'   => { "d" => 'Normalization'               },
	'eq'     => { "d" => 'Equalization'                },
	'view'   => { "d" => 'View Pictures',     "v" => 1 },
);

select((select(STDOUT), $|=1)[0]);
($FLAG, $DIR) = &process_cmd();

$MW = &_init;
MainLoop;

exit (0);

sub Main {
	$DIR =~ s/\/+$//;
	&_conf2bit();

	if ($FLAG & FLAG_CAT) {
		if ($FLAG & FLAG_UNCAT) {
			print "Uncategorizing images...\n";
			&Uncategorize($DIR);
		} elsif ($FLAG & FLAG_RETIME) {
			print "Restoring original time...\n";
			&Untime($DIR);
		} else {
			print "Categorizing images...\n";
			print &Categorize($DIR);
		}
	} elsif ($FLAG & FLAG_ZIP) {
		print "Packaging images...\n";

		### check to make sure we've got everything
		$FLAG |= FLAG_THUMB;

		print &Package($DIR);
	} elsif ($FLAG & (FLAG_IMAGE|FLAG_THUMB)) {
		if ($FLAG & FLAG_IMAGE) { print "Making images\n" }
		if ($FLAG & FLAG_THUMB) { print "Making thumbnails\n" }
		print &MakeImages($DIR);
	}
	print "Finished\n";
	$BUTTON->configure(-state,'normal');
}

### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
### P A C K A G I N G
### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
sub Package {
	my $dir = shift;

	opendir DIR, "$dir" or return "ERROR: unable to open $dir $!\n";
	my @dirs = grep !/^\./, readdir(DIR);
	closedir DIR;

	my @jpgs = grep /\.jpg$/i, @dirs;
	my @fold = grep -d "$dir/$_", @dirs;

	foreach my $d (@fold) {
		&Package("$dir/$d");
	}

	if ($dir =~ /\/t$/) {
		my $parent = $dir;
		$parent =~ s/\/t$//;
		my $state = _show_photos($parent) if $FLAG & FLAG_VIEW;
		if ($state == 2) {
			printf "+ Skip $parent.zip\n";
			return undef;
		}
	
		my $x = 0;
		foreach my $j (@jpgs) {
   	   		_remove($parent,$j,$#jpgs+1,++$x);
		}

		### making named directory according to the parent's name
		if ($parent =~ /\/web$/) {
			my $old = $parent;
			my @e = split /\//, $parent;
			pop @e;
			my $name = $e[-1];
			$name =~ s/^\d{8}\_//;
			$parent = join '/', @e, $name;
			rename $old, $parent;
		}

		my $zip = Archive::Zip->new();
		my $member = $zip->addTree("$parent", "web");
		if ($zip->writeToFileNamed("$parent.zip") == AZ_OK) {
			printf "+ Written $parent.zip (%d)\n", -s "$parent.zip";
			rmtree("$parent");
		} else {
			printf "- Failed writing $parent.zip ($!)\n";
		}
	}
}

sub _remove {
	my ($dir,$img,$max,$x) = (@_);

	unlink "$dir/t/$img" unless (-s "$dir/$img");

	my $file = "$dir/$img";
	printf " %3d/%-3d |%-25s| Validating: %30s\r", 
		$x, $max, "-"x($x/$max*25), substr("$dir/$img", -30);

	$PROGRESS = $x/$max*100; $PFRAME->update;
	print "\n" if ($x == $max);
}

### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
### P R O C E S S I N G
### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
sub MakeImages {
	my $dir = shift;
	opendir DIR, "$dir" or return "ERROR: unable to open $dir $!\n";
	my @dirs = grep !/^(\.+|t)$/, readdir(DIR);
	closedir DIR;

	my @jpgs = grep /\.jpg$/i, @dirs;
	my @fold = grep -d "$dir/$_", @dirs;

	foreach my $d (@fold) {
		&MakeImages("$dir/$d");
	}

	my $x = 0;
	foreach my $j (@jpgs) {
   		unless (-s "$dir/$j" > 200000 and 
   				$FLAG&FLAG_THUMB and FLAG_IMAGE&~$FLAG) {
   			_resize_image($dir,$j,$#jpgs+1,++$x);
   		}
	}
}

sub _process_all {
	my ($d, $p) = (@_);
	my $c = "?";
	
	my $img = Image::Magick->new;
	$img->Read("$d/$p");

	if ($FLAG & FLAG_IMAGE) {
		$c = _process_image($img,$d,$p);
		$d .= "/web";
	}
	if ($FLAG & FLAG_THUMB) {
		$c = _process_thumb($img,$d,$p);
	}
	undef $img;
	return $c;
}

sub _resize_image {
	my ($dir,$img,$max,$x) = (@_);
	
	my $c = &_process_all($dir, $img);
	printf " %3d/%-3d |%-25s| Resizing: %30s\r", 
		$x, $max, "$c"x($x/$max*25), substr("$dir/$img", -30);

	$PROGRESS = $x/$max*100; $PFRAME->update;
	print "\n" if ($x == $max);
}

sub _auto_rotate {
	my ($img,$d,$p) = (@_);

	my ($orien,$h,$w) = 
		$img->Get('%[EXIF:Orientation]','height','width');

	if ($orien & (OR_CW|OR_CCW) and $w > $h ) {
		$img->Strip;
		$img->Rotate(degrees=>-90)         if $orien == 8;
		$img->Rotate(degrees=>90)          if $orien == 6;
    
		return $img->Write(filename=>"$d/$p");
	}
	return 0;
}

sub _process_image {
	my ($img,$d,$p) = (@_);

	my ($orien,$dt,$h,$w) = 
		$img->Get('%[EXIF:Orientation]','%[EXIF:DateTime]','height','width');

	if ($w <= IM_WIDTH or $h <= IM_WIDTH) {
		return "*";
	}

	mkdir "$d/web", 0755 unless -d "$d/web";

	### save date information to restore
	my @f = reverse split /[:\s\.]/, $dt;
	my $seed = timelocal($f[0],$f[1],$f[2],$f[3],$f[4]-1,$f[5]);

	### has this picture been rotated?
	$orien = 0 if ($orien & (OR_CW|OR_CCW) and $w < $h);
	my $geom = ($w < $h) ? int($w/($h/IM_WIDTH)) : IM_WIDTH;

	$img->Strip;
	
#	$img->UnsharpMask(amount=>40);
	$img->Scale(geometry=>$geom);
	$img->Contrast(1);
	$img->Normalize                    if $FLAG & FLAG_NORM;
	$img->Equalize                     if $FLAG & FLAG_EQ;
	$img->Rotate(degrees=>-90)         if $orien == 8;
	$img->Rotate(degrees=>90)          if $orien == 6;

	my $c = $img->Write(filename=>"$d/web/$p",quality=>QUALITY) ? "." : "-";
	utime $seed, $seed, "$d/web/$p";
	return $c;
}

sub _process_thumb {
	my ($img, $d, $p) = (@_);

	### auto rotate the image
	&_auto_rotate($img, $d, $p);

	my ($h,$w) = $img->Get("height","width");

	return "*" unless ($h == IM_WIDTH or $w == IM_WIDTH);

	mkdir "$d/t", 0755 unless -d "$d/t";

	$img->Resize(geometry=>$w/2 . "x" . $h/2,filter=>'Gaussian',blur=>-2);
	$img->Crop(width=>100,height=>100,x=>10,y=>10);
	$img->Quantize(colorspace=>'gray') if $FLAG & FLAG_GRAY;
	$img->Contrast(1);

	return $img->Write(filename=>"$d/t/$p",quality=>QUALITY) ? 
		"." : ($FLAG & FLAG_IMAGE) ? "=" : "-";
}

### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
### C A T A L O G S
### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
sub Untime {
	my ($dir) = (@_);

	if (opendir DIR, "$dir") {
		my @objs = grep !/^\./, readdir(DIR);
		closedir DIR;

		my $x = 0;
		my $max = scalar @objs;

		foreach my $obj (@objs) {
			if (-d "$dir/$obj") {
				&Untime("$dir/$obj");
			} else {
				_untime("$dir/$obj");
				$PROGRESS = ++$x/$max*100; $PFRAME->update;
			}
		}
	}
}

sub Uncategorize {
	my ($dir) = (@_);

	if (opendir DIR, "$dir") {
		my @objs = grep !/^\./, readdir(DIR);
		closedir DIR;

		my $x = 0;
		my $max = scalar @objs;
		$dir =~ /^(.*)\/[^\/]+$/;
		my $parent = $1;

		foreach my $obj (sort @objs) {
			if (-d "$dir/$obj") {
				&Uncategorize("$dir/$obj");
				rmdir "$dir/$obj";
			} else {
				rename ("$dir/$obj", "$parent/$obj");
				$PROGRESS = ++$x/$max*100; $PFRAME->update;
			}
		}
	}
}

sub Categorize {
	my $dir = shift;

	my $funcf = sub { 
		my ($d,$f,$pt,$subdir) = (@_);
		my $ctime = (stat "$d/$f")[9];
		my ($dd,$mm,$yy) = (localtime ($ctime))[3,4,5];
		my $sdir = sprintf "%s/%04d%02d%02d", 
			($FLAG & FLAG_PRESRV) ? $d : $dir,
			$yy+1900, $mm+1, $dd;

		### check to see if previous time is 3600sec apart
		if (FLAG_BYDATE &~ $FLAG) {
			if (abs($$pt-$ctime) > 3600) { $$subdir++ }
			$$pt = $ctime;
			$sdir .= "_" . $$subdir;
		}

		mkpath ($sdir,0,0755) unless -d $sdir;
		if (-s "$sdir/$f") {
			print "ER: $sdir/$f exists!\r";
		} elsif (!rename ("$d/$f", "$sdir/$f")) {
			print "ER: $d/$f -> $sdir/$f: $!\r";
		}
	};

	my $funcd = sub { $_ = shift; print "ER: $_: $!\r" unless rmdir ($_) };

	&_read_dirs($dir, $funcf, $funcd);
	print "\n";
	return "";
}

sub _read_dirs {
	my ($dir,$funcf,$funcd) = (@_);

	if (opendir DIR, "$dir") {
		my @objs = grep !/^\./ && !/^\d{8}/, readdir(DIR);
		closedir DIR;

		my $pt = my $subdir = my $x = 0;
		my $max = scalar @objs;

		foreach my $obj (@objs) {
			if (-d "$dir/$obj") {
				&_read_dirs("$dir/$obj", $funcf, $funcd);
				&$funcd("$dir/$obj") unless $FLAG & FLAG_PRESRV;
				print "\n";
			} else {
				printf " %3d/%-3d |%-25s| Category: %25s\r", 
					++$x, $max, "-"x($x/$max*25), substr("$dir/$obj", -25);
				&$funcf($dir,$obj,\$pt,\$subdir);

				$PROGRESS = $x/$max*100; $PFRAME->update;
			}
		}
	}
}

sub _untime {
	my $p = shift;

	my $img = Image::Magick->new;
	$img->Read($p);

	my $t = $img->Get('%[EXIF:DateTime]');

	### save date information to restore
	my @f = reverse split /[:\s\.]/, $t;
	my $seed = timelocal($f[0],$f[1],$f[2],$f[3],$f[4]-1,$f[5]);

	undef $img;
	utime $seed, $seed, $p;
}

### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
### C O M M A N D S   P R O C E S S I N G
### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
sub _conf2bit {
	$FLAG = 0;
	foreach (keys %CONF) {
		next unless $CONF{$_}{'v'};
		&_assign_bit("-$_",\$FLAG);
	}
}

sub _assign_bit {
	my ($v,$f) = (@_);
	if    ($v =~ /^-c/)  { $$f |= FLAG_CAT;    $CONF{'cat'}{'v'}    = 1 }
	elsif ($v =~ /^-z/)  { $$f |= FLAG_ZIP;    $CONF{'zip'}{'v'}    = 1 }
	elsif ($v =~ /^-g/)  { $$f |= FLAG_GRAY;   $CONF{'gray'}{'v'}   = 1 }
	elsif ($v =~ /^-n/)  { $$f |= FLAG_NORM;   $CONF{'norm'}{'v'}   = 1 }
	elsif ($v =~ /^-e/)  { $$f |= FLAG_EQ;     $CONF{'eq'}{'v'}     = 1 }
	elsif ($v =~ /^-t/)  { $$f |= FLAG_THUMB;  $CONF{'thumb'}{'v'}  = 1 }
	elsif ($v =~ /^-i/)  { $$f |= FLAG_IMAGE;  $CONF{'image'}{'v'}  = 1 }
	elsif ($v =~ /^-v/)  { $$f |= FLAG_VIEW;   $CONF{'view'}{'v'}   = 1 }
	elsif ($v =~ /^-r/)  { $$f |= FLAG_RETIME; $CONF{'retime'}{'v'} = 1 }
	elsif ($v =~ /^-u/)  { $$f |= FLAG_UNCAT;  $CONF{'uncat'}{'v'}  = 1 }
	elsif ($v =~ /^-b/)  { $$f |= FLAG_BYDATE; $CONF{'bydate'}{'v'} = 1 }
	elsif ($v =~ /^-p/)  { $$f |= FLAG_PRESRV; $CONF{'presrv'}{'v'} = 1 }
}

sub process_cmd() {
	my $f = 0;
	for my $x (0..$#ARGV) {
		next if $ARGV[$x] !~ /^\-/;
		&_assign_bit($ARGV[$x],\$f);
	}

	if (!($f & (FLAG_THUMB|FLAG_IMAGE)) and $f & FLAG_NORMAL) {
		$f |= (FLAG_THUMB|FLAG_IMAGE);
		$CONF{'image'}{'v'} = 1;
		$CONF{'thumb'}{'v'} = 1;
	}

	$CONF{'parse'}{'v'} = 1 if $f & FLAG_NORMAL;

	my @args = grep(!/^\-/, @ARGV);
	return ($f,$args[0]);
}

### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
### Tk    O B J E C T S
### - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - -- - --
sub _init {
	my $mw = new Tk::MainWindow(
		-title => PRODUCT,
		-background => "white",
	);

	$mw->geometry(WIDTH ."x".HEIGHT."+100+100");
	$mw->resizable(0,0);
	$mw->Icon(-image, $mw->Photo(-data => ICON, -format => 'gif'));

	_f_main($mw);

	return $mw;
}

sub _f_main {
	my $parent = shift;

	my ($f,$top,$mid,$bot);

	$f = $parent->Frame(-background,'white');

	$top = $f->Frame(-background,'white')->pack(-ipady,5);
	$mid = $f->Frame(-background,'white')->pack();
	$PFRAME = $f->Frame(-background,'white')->pack(-side,'bottom');

	_f_directory($top);
	_f_options($mid);
	_f_progress($PFRAME);

	$f->pack(-fill,'both',-expand,1);
}

sub _f_options {
	my $parent = shift;
	my ($l,$c,$r,$cat,$parse,$zip);

	my %opts = (-border,1,-relief,'ridge',-background,'#cccccc');
	my %pack = (-padx,5,-side,'left',-anchor,'n');
	$l = $parent->Frame(%opts)->pack(%pack);
	$c = $parent->Frame(%opts)->pack(%pack);
	$r = $parent->Frame(%opts)->pack(%pack);

	my $events = sub {
		my $f_cat   = $CONF{'cat'}{'v'};
		my $f_parse = $CONF{'parse'}{'v'};
		my $f_zip   = $CONF{'zip'}{'v'};

		$cat->configure(-state, $f_parse || $f_zip ? 'disabled':'normal');
		$parse->configure(-state, $f_cat || $f_zip ? 'disabled':'normal');
		$zip->configure(-state, $f_cat || $f_parse ? 'disabled':'normal');

		foreach (@COPTS) {
			$$_->configure(-state, $cat->cget('-state'));
		}

		foreach (@IOPTS) {
			$$_->configure(-state, $parse->cget('-state'));
		}

		foreach (@POPTS) {
			$$_->configure(-state, $zip->cget('-state'));
		}

		$BUTTON->configure(
			-state, ($f_cat||$f_parse||$f_zip)&&$DIR ? 'normal' : 'disabled');
	};

	### three main groups
	$cat = $l->Checkbutton(
		-text     => $CONF{'cat'}{'d'},
		-font     => 'Arial 8 bold',
		-anchor   => 'w',
		-variable => \$CONF{'cat'}{'v'},
		-command  => \&$events,
	)->pack(-anchor,'nw',-fill,'x');

	$parse = $c->Checkbutton(
		-text     => $CONF{'parse'}{'d'},
		-font     => 'Arial 8 bold',
		-anchor   => 'w',
		-variable => \$CONF{'parse'}{'v'},
		-command  => \&$events,
	)->pack(-anchor,'w',-fill,'x');
	$zip = $r->Checkbutton(
		-text     => $CONF{'zip'}{'d'},
		-font     => 'Arial 8 bold',
		-variable => \$CONF{'zip'}{'v'},
		-anchor   => 'w',
		-command  => \&$events,
	)->pack(-anchor,'nw',-fill,'x');

	foreach (@COPTS) {
		$$_ = $l->Checkbutton(
			-text       => $CONF{$_}{'d'},
			-background => '#cccccc',
			-state      => 'disabled',
			-variable   => \$CONF{$_}{'v'},
		)->pack(-anchor => 'w');
	}
	foreach (@IOPTS) {
		$$_ = $c->Checkbutton(
			-text       => $CONF{$_}{'d'},
			-background => '#cccccc',
			-state      => 'disabled',
			-variable   => \$CONF{$_}{'v'},
		)->pack(-anchor => 'w');
	}
	foreach (@POPTS) {
		$$_ = $r->Checkbutton(
			-text       => $CONF{$_}{'d'},
			-background => '#cccccc',
			-state      => 'disabled',
			-variable   => \$CONF{$_}{'v'},
		)->pack(-anchor => 'w');
	}
	&$events;
}

sub _f_directory {
	my $parent = shift;

	my $f = $parent->Frame(-background,'white')->pack();

	$f->Label(
		-background   => 'white',
		-text         => 'Search Drive:',
		-font         => 'Arial 8 bold'
		)->pack(-anchor,'w');

	$f->Entry( 
		-width        => 40,
		-font         => 'Arial 10 bold',
		-borderwidth  => 1,
		-relief       => 'sunken',
		-background   => '#dfdfdf',
		-textvariable => \$DIR,
		)->pack(-side,'left',-padx,5);

	$f->Button( 
		-font         => 'Arial 3 bold',
		-text         => '. . .', 
		-width        => 3,
		-height       => 3,
		-relief       => 'groove',
		-background   => '#dfdfdf',
		-command      => sub { $DIR = &__get_dir($parent); }
		)->pack(-side,'left',-padx,5);

	$BUTTON = $f->Button( 
		-text     => 'PROCESS',
		-command  => sub 
					{
					$BUTTON->configure(-state => 'disabled');
					&Main;
					},
		-font        => 'Arial 8 bold',
		-borderwidth => 1,
		-background  => '#eeeeee',
		-state       => 'disabled',
		)->pack ( -anchor, 'e' );
}

sub __get_dir() {
	my $parent = shift;
	my $ok = 0; # flag: "1" means OK, "-1" means cancelled

	my $t = $parent->Toplevel;
	$t->title("Choose directory:");
	$t->after(1,sub {$t->attributes(-toolwindow,1)});

	my $f = $t->Frame->pack(-fill => "x", -side => "bottom");
	my $curr_dir = $DIR || Cwd::cwd();

	my $d = $t->Scrolled('DirTree',
		-scrollbars        => 'osoe',
		-width             => 35,
		-height            => 20,
		-selectmode        => 'browse',
		-exportselection   => 1,
		-browsecmd         => sub { $curr_dir = shift },
		-command           => sub { $ok = 1 },
	)->pack(-fill => "both", -expand => 1);

	$d->chdir($curr_dir);
	$f->Button(
		-font         => 'Arial 8',
		-text         => 'Cancel',
		-width        => 10,
		-border       => 1,
		-relief       => 'raised',
		-background   => '#ffffff',
		-command => sub { $ok = -1; $curr_dir = "" }
	)->pack(-side => 'left');
	$f->Button(
		-font         => 'Arial 8 bold',
		-text         => 'OK',
		-width        => 10,
		-border       => 1,
		-relief       => 'raised',
		-background   => '#ffffff',
		-command => sub { $ok =  1 })->pack(-side => 'right');

	$f->waitVariable(\$ok);
	$t->destroy();

	return $curr_dir;
}

sub _f_progress () {
	my $parent = shift;

	$parent->ProgressBar(
		-width      => 7,
		-length     => WIDTH,
		-from       => 0,
		-to         => 100,
		-blocks     => 50,
		-gap        => 0,
		-variable   => \$PROGRESS,
		-colors     => [0, '#000000'],
		-background => 'white',
	)->pack();
}

sub _show_photos {
	my $dir = shift;

	opendir DIR, $dir or return 0;
	my @jpgs = map { "$dir/$_" } grep /\.jpg$/i, readdir(DIR);
	closedir DIR;

	my $t = $MW->Toplevel;
	$t->overrideredirect(1);
	$t->geometry("+150+150");
	$t->focus;

	my $f = $t->Frame->pack;
	my ($ok,$x,$img,$note) = (0,0,$f->Photo,$f->Label(-font, 'Arial 8 bold'));

	my $next_pix = sub {
		return ($ok = 1) if ($#jpgs < 0);
		$img->configure( -file => $jpgs[0] ); 
		$note->configure(
			-text => (sprintf "[%3d/%-3d] %30s", 
				$x%($#jpgs+1)+1, $#jpgs+1, substr($jpgs[0],-30))
		);
	};

	&$next_pix;

	my @del = ();
    $t->bind( '<KeyPress>' => sub {
		if    ($Tk::event->K eq "Escape") { $ok = 2 }
		elsif ($Tk::event->K eq "Return") { $ok = 1 }
		elsif ($Tk::event->K eq "Right")  { $x++; push @jpgs, shift @jpgs }
		elsif ($Tk::event->K eq "Left")   { $x--; unshift @jpgs, pop @jpgs }
		elsif ($Tk::event->K eq "Delete") { push @del, shift @jpgs }
		elsif ($Tk::event->k == 221)      { _rotate($jpgs[0], 90) }
		elsif ($Tk::event->k == 219)      { _rotate($jpgs[0], -90) }
		&$next_pix;
	});
	$f->Label(-image, $img)->pack;

	$note->pack(-side => 'left');

	$f->waitVariable(\$ok);
	$t->destroy();

	unlink @del if $ok == 1 and $#del >= 0;

	return $ok;
}

sub _rotate {
	my ($file,$deg) = (@_);

	my $img = new Image::Magick;
	my $s = $img->Read($file);
	unless ($s) {
		$img->Strip;
		$img->Rotate(degrees=>$deg);
		$img->Write(filename=>$file);
	}
#	undef $img;
}

1;
