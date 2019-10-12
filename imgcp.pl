#!perl -w

use lib qw(lib);
use strict;
use CmdLine;
use Tk;
use BasicWindow;
use ReadDir;
use File::Path;
use File::Copy;
use Win32::DriveInfo;

use constant PRODUCT    => 'imgcp v1.6';
use constant FG         => '#EAEAEA';
use constant BG         => '#4F6D7A';
use constant HBG        => '#869CA5';
use constant SPACEREQ   => 1024 * 1024 * 1024; #243419574272;
use constant AUTOEX     => q{ind,inp,bin,bdm,cpi,dat,mpl,thm,pod,xml,bnp,int,txt,html,ctg,url,sav};
use constant HELP       => <<EOT;
imgcp -source D: -target C:\/tmp -auto -ex tmp,ext

-source \x{2022} Drive to copy from
-target \x{2022} Where to copy files to
-auto   \x{2022} Start copying immediately
-ex     \x{2022} List of extensions to exclude
-test   \x{2022} Test only, don't copy
EOT
use vars qw /$STATUS $BW $CL/;
select((select(STDOUT), $|=1)[0]);

$CL     = CmdLine->new(@ARGV);
$BW     = BasicWindow->new(
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

    $CL->{-source}            ||= '';
    $CL->{-target}            ||= '';
    $CL->{-tinfo}               = _drive_type($CL->{-target});
    $CL->{-sinfo}               = _drive_type($CL->{-source});
    my $datasize                = $CL->{-sinfo}->{total} - $CL->{-sinfo}->{free};
    my $sizereq                 = $CL->{-tinfo}->{free} ? ($datasize / $CL->{-tinfo}->{free}) * 100 : 0;

    $mw->bind('<Escape>' => sub { exit(0); });

    if (!$CL->{-source} || !$CL->{-target}) {
        $STATUS     = HELP;
    } elsif ($CL->{-tinfo}->{type} eq q{unknown} or $CL->{-tinfo}->{free} < SPACEREQ or $sizereq > 90) {
        $STATUS     = sprintf q{Destination (%s) is invalid or does not have enough storage space (%s)!},
                        $CL->{-target}, _space($CL->{-tinfo}->{free});
    } elsif (-d $CL->{-source} && -d $CL->{-target}) {
        $mw->{buttonLabel}      = q{Start copy};
        $mw->{button}           = $BW->button($middle, {
            text    => \$mw->{buttonLabel},
            cb      => \&_cat,
            font    => q{Verdana 10},
            width   => 20
        })->pack(qw/-side top -anchor w/);

        $BW->progress($bottom);
        $STATUS     = sprintf qq{From %s %s %s (%s data)\nTo %s %s %s (%s free)\nStorage required: %d%%},
                        $CL->{-source},
                        _space($CL->{-sinfo}->{total}),
                        $CL->{-sinfo}->{type},
                        _space($datasize),
                        $CL->{-target},
                        _space($CL->{-tinfo}->{total}),
                        $CL->{-tinfo}->{type},
                        _space($CL->{-tinfo}->{free}),
                        $sizereq;

        $mw->bind('<Escape>' => undef);
        $mw->bind('<Return>' => \&_cat);
        $CL->{-auto} and $CL->{-runit} = 1;
    } elsif (-d $CL->{-target} and !-d $CL->{-source}) {
        $STATUS     = qq{Can't find files at "-source" dir [$CL->{-source}]};
    } elsif (!-d $CL->{-target} and -d $CL->{-source}) {
        $STATUS     = qq{Can't "-target" dir [$CL->{-target}]};
    } else {
        $STATUS     = HELP;
    }

    _get_target_dirs($CL->{-target});

    $middle->Label(
        -textvariable   => \$STATUS,
        -bg             => BG,
        -fg             => FG,
        -wraplength     => $BW->{-w} - 10,
        -justify        => 'left',
        -font           => 'Consolas 10',
    )->pack(qw/-anchor w -side top -padx 0/);
}

sub _newfilename {
    my $fname   = $_[0];
    my $itr     = 0;
    do {
        $itr++;
        $fname =~ s/\.([^.]+)$/_$itr.$1/;
    } while (-e $fname);
    return $fname;
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
        my $yymmdd          = sprintf "%04d%02d%02d", $yy+1900, $mm+1, $dd;
        my $dest            = sprintf "%s/%s", $CL->{-target}, $yymmdd;
        my $destprev        = $CL->{-datedir}->{$yymmdd};

        ### check if a version of destination already exists
        foreach (@$destprev) {
            my $filepath    = $CL->{-target}.'/'.$_.'/'.$f;
            my $tar_size    = -s $filepath;
            my $src_size    = -s "$src/$f";

            ### check if dest file is same as source
            if ($src_size == $tar_size) {
                return 0;
            } elsif (-e $filepath) {
                ### collision, rename old file
                $CL->{-test} and printf "DUP $filepath\n";
                my $newf    = _newfilename($filepath);
                rename ($filepath, $newf);
            }
        }

        mkpath ($dest,0,0755) unless -d $dest;

        ### make sure we're not overwriting, it's inefficient
        unless (-s "$dest/$f") {
            if ($CL->{-test}) {
                if (open my $touch, ">$dest/$f") {
                    close $touch;
                    return 1;
                }
            } elsif (copy ("$src/$f", "$dest/$f")) {
                return 1;
            }
            return -1;
        }
        return 0;
    };
    my %hit     = ();
    my $mw      = $BW->{-mw};
    $CL->{-ex}  = AUTOEX . ',' . ($CL->{-ex}||'');

    foreach my $e (split /,/, $CL->{-ex}) {
        $hit{uc $e} = 0;
    }

    $mw->{button}->configure(-state => 'disabled');
    $mw->bind('<Return>' => '');

    &_read_dirs(
        $CL->{-source},
        $funcf,
        \$c,
        \$t,
        \%hit
    );

    $mw->bind('<Escape>', sub { exit(0); } );

    my %goodbad     = ();
    foreach (sort { $hit{$b} <=> $hit{$a} } keys %hit) {
        $hit{$_} or next;
        my $key         = $hit{$_} > 0 ? 'good' : 'bad';
        $goodbad{$key}{label}   .= sprintf "%d\x{2219}%s ", abs($hit{$_}), $_;
        $goodbad{$key}{count}   += abs($hit{$_});
    }
    my $info        = sprintf qq{Targets %d\x{2219}\x{2219}\x{203a} %s\nIgnored %d\x{2219}\x{2219}\x{203a} %s},
                        $goodbad{good}{count},
                        $goodbad{good}{label},
                        $goodbad{bad}{count},
                        lc $goodbad{bad}{label};

    if ($c > 0 && $c == $goodbad{good}{count}) {
        $STATUS = qq{FINISHED: $c file(s) copied\n$info};
        $BW->{-progress} = 100;
    } elsif ($c > 0) {
        $STATUS = sprintf qq{ERROR: %d/%d file(s) copied\n%s},
            $c, $goodbad{good}{count}, $info;
    } elsif ($c < 0) {
        $STATUS = sprintf qq{ERROR: No space left on device (needs > %s)\n%s},
            _space(SPACEREQ), $info;
    } else {
        $STATUS = sprintf qq{ERROR: Nothing copied out of %d file(s)!\n%s},
            $goodbad{good}{count}, $info;
    }
    $mw->{button}->packForget;

    $mw->update;
}

sub _get_target_dirs {
    my $dir         = shift;
    $CL->{-datedir} = ();

    if (opendir my $dh, $dir) {
        my @objs    = grep /^\d{8}/, readdir($dh);
        closedir $dh;

        foreach my $obj (@objs) {
            next unless $obj =~ /^(\d{8}).*$/;
            push @{ $CL->{-datedir}{$1} }, $&;
        }
    }
}

sub _read_dirs {
    my ($dir,$funcf,$c,$t,$ext) = (@_);

    $CL->{-test} and printf "$dir\n";

    if (opendir my $dh, $dir) {
        #my @objs    = grep !/^\./ && !/^\d{8}$/, readdir($dh);
        my @objs    = grep !/^\./, readdir($dh);
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
            } elsif ($obj =~ /\.(.*)$/) {
                ### copy only files with extensions
                ### check disk space before copy
                if (_has_space("$dir/$obj")) {
                    $STATUS             = "$dir\n$obj";
                    my $res             = &$funcf($dir,$obj);
                    if ($res < 0) {
                        $$c             = -1;
                        last;
                    }
                    $$c                += $res;
                    $BW->{-progress}    = $$c/$$t*100;
                    $BW->{-mw}->{buttonLabel} = $$c . '/' . $$t;
                    $BW->{-mw}->update;
                } else {
                    $$c                 = -1;
                    last;
                }
            } else {
                ### files without extensions, don't count
                $$t--;
            }
        }
    }
}

sub _has_space {
    my $file    = shift;
    my $drive   = $CL->{-target};
    if ($drive  =~ /^([^:]+):/) {
        $drive  = $1;
    }
    my $free    = (Win32::DriveInfo::DriveSpace($drive))[6];

    if ((stat $file)[7]+SPACEREQ > $free) {
        return 0;
    }
    return 1;
}

sub _space {
    my $bytes           = shift || 0;
    if ($bytes >= (1024 * 1024 * 1024)) {
        return sprintf qq{%d GB}, $bytes / (1024 * 1024 * 1024);
    } elsif ($bytes >= (1024 * 1024)) {
        return sprintf qq{%d MB}, $bytes / (1024 * 1024);
    }
    return sprintf qq{%d KB}, $bytes / 1024;
}

sub _drive_type {
    my $drive   = $_[0];
    if ($drive  =~ /^([^:]+):/) {
        $drive  = $1;
    }
    my $type                = Win32::DriveInfo::DriveType($drive);
    my ($total,$free)       = (Win32::DriveInfo::DriveSpace($drive))[5,6];

    if      (!$type)     { $type = q{unknown};   }
    elsif   ($type == 2) { $type = q{removable}; }
    elsif   ($type == 3) { $type = q{fixed};     }
    elsif   ($type == 4) { $type = q{network};   }
    elsif   ($type == 5) { $type = q{cd-rom};    }
    elsif   ($type == 6) { $type = q{ram};       }
    else                 { $type = q{unknown};   }

    return {
        type    => $type,
        total   => $total || 0,
        free    => $free  || 0
    };
}

1;
