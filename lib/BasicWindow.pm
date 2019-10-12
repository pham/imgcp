package BasicWindow;

use strict;
use Tk;
use Tk::ProgressBar;

use Args;
use Common qw/ckargv/;

use constant ICON2     => << '.';
R0lGODlhIAAgAPMAAAAAAAOa5AOb5AKa5QOa5QKb5QOb5QOb5gSa5QSb5QSb5gOc
5QSc5ASc5QSc5gAAACH5BAEAAAAALAAAAAAgACAAAASEEMhJq7046827/yDWhN1x
kFtjGASarYfhXskK2PO0rIlkFDmAauWYGAS51WoxEchcSiWlcCLFok9j1oOVVlig
Lm663TDEhuK3ykEb2Fqu2+KUoy3jjbsMIPAxe3h/F4FfPXZdFQGDGAV3EwoGAyFi
AVqMGghYPjEISWJBFE6eoaWmpxcRADs=
.

use constant PRODUCT => 'Basic Window v1.2';
use constant BG      => '#ffffff';
use constant FG      => '#000000';
use constant WIDTH   => 300;
use constant HEIGHT  => 200;

sub new {
    my $class       = shift;
    my $self        = {};

    bless $self, $class;

    $self->_init(@_);
    return $self;
}

sub _init {
    my $self        = shift;
    %$self          = Args::validate(@_);
    
    $self->{-product} ||= PRODUCT;
    $self->{-bg}      ||= BG;
    $self->{-fg}      ||= FG;
    $self->{-w}       ||= WIDTH;
    $self->{-h}       ||= HEIGHT;
    $self->{-progress}  = 0;

    $self->_create_main;
}

sub _create_main {
    my $self        = shift;
    $self->{-mw}    = new Tk::MainWindow(
        -title  => $self->{-product}, 
        -fg     => $self->{-fg}, 
        -bg     => $self->{-bg}
    );

    $self->{-mw}->geometry($self->{-w}. "x" . $self->{-h} . "+100+100");
    $self->{-mw}->resizable(0,0);
    $self->{-mw}->Icon(
        -image, $self->{-mw}->Photo(-data => ICON2, -format => 'gif')
    );

    $self->{-exitsub} and
        $self->{-mw}->bind( '<Escape>' => $self->{-exitsub} );
}

sub fullscreen {
    my $self        = shift;
    my %opts        = Args::validate(@_);
    my $t           = $self->{-mw}->Toplevel;
    my ($w,$h)      = $t->maxsize;

    $t->overrideredirect(1);
    $t->geometry("${w}x${h}-0-0");
    $t->configure(qw/-bg black/);
    $t->focus;

    $opts{-exitkey} and
        $t->bind ($opts{-exitkey} => sub { $t->destroy } );

    return $t;
}

sub progress {
    my $self        = shift;
    my $parent      = shift;

    $parent->ProgressBar(
        -length         => $self->{-w},
        -variable       => \$self->{-progress},
        -colors         => [0, $self->{-bg}],
        -troughcolor    => $self->{-fg},
        qw/-width 10 -from 0 -to 100 -blocks 100 -gap 0/
    )->pack;
}

sub button {
    my $self        = shift;
    my $parent      = shift;
    my $opt         = ckargv(shift,
        [qw/text cb !anchor !border !width !font/]);

    return $parent->Button( 
        -bg                 => $self->{-hbg},
        -fg                 => $self->{-fg},
        -anchor             => $opt->{anchor}   || 'w',
        -font               => $opt->{font}     || 'Arial 9',
        -borderwidth        => $opt->{border}   || 0,
        -width              => $opt->{width}    || 10,
        -textvariable       => $opt->{text},
        -command            => sub { &{$opt->{cb}} },
        -activebackground   => $self->{-fg},
        -disabledforeground => $self->{-bg}
    );
}

1;
