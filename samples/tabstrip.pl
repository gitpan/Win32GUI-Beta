
use Win32::GUI;

$W = new GUI::Window(
    -title    => "Win32::GUI TEST - TabStrip",
    -left     => 100, 
    -top      => 100, 
    -width    => 300, 
    -height   => 200,
    -name     => "Window",
);

$IL = new GUI::ImageList(16, 16, 8, 3, 10);
$IMG_ONE   = $IL->Add("one.bmp");
$IMG_TWO   = $IL->Add("two.bmp");
$IMG_THREE = $IL->Add("three.bmp");

print "IL.BackColor = ", $IL->BackColor(), "\n";
print "IL.BackColor(",hex("FFFFFF"), ") = ", $IL->BackColor(hex("FFFFFF")), "\n";
print "IL.BackColor = ", $IL->BackColor(), "\n";

$TS = $W->AddTabStrip(
    -left   => 0,   
    -top    => 0, 
    -width  => $W->ScaleWidth, 
    -height => $W->ScaleHeight,
    -name   => "Tab",
    -imagelist => $IL,
);
$TS->InsertItem(-text => "First", -image => 0);
$TS->InsertItem(-text => "Second", -image => 1);
$TS->InsertItem(-text => "Third", -image => 2);

$cur = new Win32::GUI::Label(
    $TS,
    -text     => "Click a tab...",
    -left     => 5,
    -top      => 50,
);

$W->Show;

Win32::GUI::Dialog();

sub Window_Resize {
    $TS->Resize($W->ScaleWidth, $W->ScaleHeight);
}

sub Window_Terminate {
    return -1;
}

sub Tab_Click {
    my @tabs = ("First", "Second", "Third");
    $cur->Text($tabs[$TS->SelectedItem()]);
}

