#!perl -w

use strict;
use CmdLine;
use Tk;
use Ptk::BasicWindow;
use ReadDir;
use File::Path;
use File::Copy;
use File::Spec;

use constant PRODUCT    => 'imgdedup v1.0';
use constant FG         => '#EAEAEA';
use constant BG         => '#4F6D7A';
use constant HBG        => '#869CA5';
use constant HELP       => <<EOT;
imgdedup -target C:\\tmp\\chosen

-target   \x{2022} Remove duplicate files matched in this dir
-test     \x{2022} Test only, don't remove
EOT

use  constant SUMMARY   => <<EOT;
Target  \x{2219}\x{2219}\x{203a} %s
Removed \x{2219}\x{2219}\x{203a} %d
Ignored \x{2219}\x{2219}\x{203a} %d
Unique  \x{2219}\x{2219}\x{203a} %d
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

MainLoop;

exit (0);

sub main {
    my $mw      = $BW->{-mw};
    my $top     = $mw->Frame(-bg,BG)->pack(qw/-pady 5 -padx 5 -fill both/);
    my $middle  = $top->Frame(-bg,BG)->pack(qw/-side left -fill y -anchor w/);
    my $bottom  = $mw->Frame(-bg,BG)->pack(qw/-side bottom/);

   ($CL->{-target},
    $CL->{-dir},
    $CL->{-name})       = _get_paths($CL->{-target});
    $CL->{-tcount}      = _get_target_files($CL->{-target});

    $mw->bind('<Escape>' => sub { exit(0); });

	if (!$CL->{-dir} || !$CL->{-target}) {
        $STATUS     = HELP;
    } elsif ($CL->{-tcount} <= 0) {
        $STATUS     = qq{Target dir $CL->{-name} has no files};
    } elsif (-d $CL->{-dir} && -d $CL->{-target}) {
        $mw->{buttonLabel}      = qq{Remove $CL->{-tcount} Duplicates};
        $mw->{button}           = $BW->button($middle, {
            text    => \$mw->{buttonLabel},
            cb      => \&_cat,
            font    => q{Verdana 10},
            width   => 20 
        })->pack(qw/-side top -anchor w/);

        $BW->progress($bottom);
        $STATUS     = sprintf qq{Removing %d duplicates using %s from\n%s},
            $CL->{-tcount},
            $CL->{-name},
            $CL->{-dir};

        $mw->bind('<Escape>' => undef);
        $mw->bind('<Return>' => \&_cat);
    } elsif (-d $CL->{-target} and !-d $CL->{-dir}) {
        $STATUS     = qq{Can't find files at "-dir" dir [$CL->{-dir}]};
    } elsif (!-d $CL->{-target} and -d $CL->{-dir}) {
        $STATUS     = qq{Can't find files at "-target" dir [$CL->{-target}]};
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

sub _get_target_files {
    my $dir         = shift;

    if (opendir my $dh, $dir) {
        my @objs    = grep !/^\./, readdir($dh);
        closedir $dh;

        foreach my $obj (@objs) {
            $CL->{-rmlist}{lc $obj}    = 1;
        }
        return scalar @objs;
    }
    return 0;
}

sub _get_paths {
    my $target              = $_[0] || return ('','','');
    my ($vol,$path,$prog)   =
        File::Spec->splitpath(File::Spec->rel2abs($target));

    return ("$vol$path$prog", "$vol$path", "$prog");
}

sub _cat {
    my $count   = new ReadDir($CL->{-dir});
    my $t       = scalar $count->Get(-type => 'files');
    my $c       = 0;
    my $funcf   = sub { 
        my $src             = shift;
        my $f               = shift;

        if ($CL->{-rmlist}{lc $f}) {
            $CL->{-rmlist}{lc $f}++;
            unless ($CL->{-test}) {
                unlink "$src/$f";
            }
            return 1;
        }
        $CL->{-unique}++;
        return 0;
    };
    my %hit     = ();
    my $mw      = $BW->{-mw};

    $mw->{button}->configure(-state => 'disabled');
    $mw->bind('<Return>' => '');

    &_read_dirs(
        $CL->{-dir},
        $funcf,
        \$c,
        \$t
    );

    $mw->bind('<Escape>', sub { exit(0); } );

    my %goodbad     = ();
    foreach (keys %{ $CL->{-rmlist} }) {
        my $key         = $CL->{-rmlist}{$_} > 1 ? 'good' : 'bad';
        $goodbad{$key}  ++;
    }
    my $info        = sprintf SUMMARY,
                        $CL->{-name},
                        $goodbad{good},
                        $goodbad{bad},
                        $CL->{-unique};
    
    if ($c > 0) {
        $STATUS = qq{FINISHED: $c out of $t files scanned\n$info};
        $BW->{-progress} = 100;
    } else {
        $STATUS = sprintf qq{ERROR: Nothing removed %d file(s)!\n%s},
            $CL->{-unique}, $info;
    }
    $mw->{button}->packForget;

    $mw->update;
}

sub _read_dirs {
    my ($dir,$funcf,$c,$t) = (@_);

    if (opendir my $dh, $dir) {
        my @objs    = grep !/^\./, readdir($dh);
        closedir $dh;

        $CL->{-test} and printf "$dir (%d)\n", scalar @objs;

        foreach my $obj (@objs) {
            if (-d "$dir$obj" && $obj ne $CL->{-name}) {
                &_read_dirs("$dir$obj", $funcf, $c, $t);
            } elsif ($obj =~ /\.(.*)$/) {
                $STATUS             = "$dir\n$obj";
                my $res             = &$funcf($dir,$obj);
                if ($res < 0) {
                    $$c             = -1;
                    last;
                }
                $$c                ++;
                $BW->{-progress}    = $$c/$$t*100;
                $BW->{-mw}->{buttonLabel} = sprintf q{%d/%d (%d)},
                    $$c, $$t, $$t - $$c;
                $BW->{-mw}->update;
            } else {
                ### files without extensions, don't count
                $$t--;
            }
        }
    }
}

1;

