
use Win32::GUI;

$M = Win32::GUI::MakeMenu(
    "&File"     => "File",
    " > &Open"  => "Open",
    " > E&xit"  => "Exit",
    "&Bitmap"   => "Bitmap",
    " > &Resize window to bitmap" => "Resize",
);

$W = new GUI::Window(
    -title    => "Win32::GUI TEST - Bitmap",
    -left     => 100, 
    -top      => 100, 
    -width    => 400, 
    -height   => 400,
    -style    => WS_OVERLAPPEDWINDOW,
    -menu     => $M,
    -name     => "Window",
) or print_and_die("new Window");

$B = new GUI::Bitmap('zapotec.bmp') or print_and_die("new Bitmap");

($width, $height) = ($W->GetClientRect)[2..3];

$BITMAP = $W->AddLabel(
    -left => 0, 
    -top => 0,
    -width => $width, 
    -height => $height,
    -style => 14 | WS_VISIBLE,
    -name => "Bitmap",
);

$BITMAP->SetImage($B);
$BITMAP->Resize($width, $height);

$W->Show;

Win32::GUI::Dialog();

sub Window_Resize {
    $BITMAP->Resize($W->ScaleWidth, $W->ScaleHeight);
}

sub Window_Terminate {
    $W->PostQuitMessage(0);
}

sub Open_Click {
    my $file = "*.bmp\0" . " " x 260;
    $file = GUI::GetOpenFileName(-file => $file);
    print $file, "\n";
    undef $B;
    $B = new GUI::Bitmap($file);
    if($B) {
        $BITMAP->SetImage($B);
        Window_Resize();
    }
}

sub Resize_Click {
    my ($x, $y) = $B->Info();
    if($x and $y) {
        $W->Resize($x, $y);
    } else {
        print "Can't get bitmap size...\n";
    }
}

sub Exit_Click {
    $W->PostQuitMessage(0);
}

sub print_and_die {
    my($text) = @_;
    my $err = Win32::GetLastError();
    die "$text: Error $err\n";
}
