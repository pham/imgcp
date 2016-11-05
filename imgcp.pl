#!perl -w

use strict;
use CmdLine;
use Tk;
use Ptk::BasicWindow;
use ReadDir;
use File::Path;
use File::Copy;

use constant PRODUCT    => 'imgcp v1.3';
use constant FG         => '#EAEAEA';
use constant BG         => '#4F6D7A';
use constant HBG        => '#869CA5';
use constant HELP       => <<EOT;
imgcp -source D: -target C:\/tmp -auto -ex tmp,ext

-source > Dir of where files are
-target > Where to copy files to
-auto   > Start copying immediately
-ex     > List of extensions to exclude
EOT
use vars qw /$STATUS $BW $CL/;
select((select(STDOUT), $|=1)[0]);

$CL     = CmdLine->new(@ARGV);
$BW     = Ptk::BasicWindow->new(
    -fg         => FG,
    -bg         => BG,
    -hbg        => HBG,
    -h          => 120,
    -w          => 450,
    -product    => PRODUCT
);

&main;
$CL->{-runit} and &_cat;

MainLoop;

exit (0);

sub main {
    my $mw      = $BW->{-mw};
    my $top     = $mw->Frame(-bg,BG)->pack(qw/-pady 5 -padx 5 -fill both/);
    my $middle  = $top->Frame(-bg,BG)->pack(qw/-side left -fill y -anchor w/);
    my $bottom  = $mw->Frame(-bg,BG)->pack(qw/-side bottom/);

    $CL->{-source} ||= '';
    $CL->{-target} ||= '';

    if (-d $CL->{-source} && -d $CL->{-target}) {
        $mw->{buttonLabel}  = sprintf qq{Copy from %s}, $CL->{-source};
        $mw->{button}       = $BW->button($middle, {
            text    => \$mw->{buttonLabel},
            cb      => \&_cat,
            font    => q{Verdana 10},
            width   => 20 
        })->pack(qw/-side top -anchor w/);

        $BW->progress($bottom);

        $mw->bind('<Return>' => \&_cat);
		$CL->{-auto} and $CL->{-runit} = 1;
    } elsif (-d $CL->{-target} and !-d $CL->{-source}) {
        $STATUS     = qq{Can't find files at "-source" dir [$CL->{-source}]};
    } elsif (!-d $CL->{-target} and -d $CL->{-source}) {
        $STATUS     = qq{Can't "-target" dir [$CL->{-target}]};
    } else {
        $STATUS     = HELP;
    }
    $middle->Label(
        -textvariable   => \$STATUS,
        -bg             => BG,
        -fg             => FG,
        -wraplength     => $BW->{-w} - 10,
        -justify        => 'left',
        -font           => 'Consolas 10',
    )->pack(qw/-anchor w -side top -padx 0/);
}

sub _cat {
    my $count   = new ReadDir($CL->{-source});
    my $t       = scalar $count->Get(-type => 'files');
    my $c       = 0;
    my $funcf   = sub { 
        my $src             = shift;
        my $f               = shift;
        my $ctime           = (stat "$src/$f")[9];
        my ($dd,$mm,$yy)    = (localtime ($ctime))[3,4,5];
        my $dest            = sprintf "%s/%04d%02d%02d", 
            $CL->{-target}, $yy+1900, $mm+1, $dd;

        mkpath ($dest,0,0755) unless -d $dest;

        ### make sure we're not overwriting, it's inefficient
        unless (-s "$dest/$f") {
            copy ("$src/$f", "$dest/$f");
            return 1;
        }
        return 0;
    };
    my %hit     = ();
    my $mw      = $BW->{-mw};

    foreach my $e (split /,/, ($CL->{-ex}||'')) {
        $hit{uc $e} = 0;
    }

    $mw->{button}->configure(-state => 'disabled');
    $mw->bind('<Return>', '');

    &_read_dirs(
        $CL->{-source},
        $funcf,
        \$c,
        $t,
        \%hit
    );

    $mw->{buttonLabel} = 'Done';
    $mw->bind('<Escape>', sub { exit(0); } );

    $STATUS = $c . "/" . $t . " Files copied\n";

    foreach (sort { $hit{$b} <=> $hit{$a} } keys %hit) {
        $hit{$_} or next;
        $STATUS .= $hit{$_} > 0 
            ? (sprintf "%d/%s ", $hit{$_}, $_)
            : (sprintf "%s ", lc $_);
    }
    
    $BW->{-progress} = 100;
    $mw->update;
}

sub _read_dirs {
    my ($dir,$funcf,$c,$t,$ext) = (@_);

    if (opendir my $dh, $dir) {
        my @objs    = grep !/^\./ && !/^\d{8}$/, readdir($dh);
        closedir $dh;

        foreach my $obj (@objs) {
            if ($obj =~ /\.(.*)$/) {
                my $e = uc $1;
                if (defined $ext->{$e} && $ext->{$e} <= 0) {
                    $ext->{$e}--;
                    next;
                }
                $ext->{$e}++;
            }
            if (-d "$dir/$obj") {
                &_read_dirs("$dir/$obj", $funcf, $c, $t, $ext);
            } else {
                $STATUS             = "$dir\n$obj";
                $$c                += &$funcf($dir,$obj);
                $BW->{-progress}    = $$c/$t*100;
                $BW->{-mw}->{buttonLabel} = $$c . '/' . $t;
                $BW->{-mw}->update;
            }
        }
    }
}

1;

