
use Win32::GUI;

$W = new GUI::Window(
    -title    => "Win32::GUI TEST - Toolbar",
    -left     => 100, 
    -top      => 100, 
    -width    => 300, 
    -height   => 200,
    -style    => WS_OVERLAPPEDWINDOW,
    -name     => "Window",
) or print_and_die("new Window");

$TB = $W->AddToolbar(
    -left   =>  0,   
    -top    => 0, 
    -width  => $W->ScaleWidth-10, 
    -height => 100,
    -name   => "Toolbar",
);

$B = new GUI::Bitmap("tools.bmp");

$TB->SetBitmapSize(16, 16);

$TB->AddBitmap($B, 3);

$TB->AddString("ONE");
$TB->AddString("TWO");
$TB->AddString("THREE");

$TB->AddButtons(
    3,
    0, 1, 4, 0, 0,
    1, 2, 4, 0, 1,
    2, 3, 4, 0, 2,
);

$W->Show;

$return = $W->Dialog();
print "Dialog: $return\n";

sub print_and_die {
    my($text) = @_;
    my $err = Win32::GetLastError();
    die "$text: Error $err\n";
}

sub Window_Resize {
    $TB->Resize($W->ScaleWidth-10, 100);
}

sub Toolbar_ButtonClick {
    my($button) = @_;
    print "Toolbar: clicked button $button\n";
}

