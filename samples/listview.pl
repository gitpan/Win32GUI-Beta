
use Win32::GUI;

print "hwnd = $Win32::GUI::hwnd\n";
print "hinstance = $Win32::GUI::hinstance\n";

# GUI::Show($Win32::GUI::hwnd, 6);

#$Icon = new GUI::Icon("perl.ico");
#print "Icon: $Icon->{handle}\n";

$Window = new GUI::Window(
    -name => "Window",
    -style => WS_OVERLAPPEDWINDOW,
    -text => "Win32::GUI TEST - ListView",
    -height => 200, -width => 300,
    -left => 100, -top => 100,
);

$IL = new GUI::ImageList(16, 16, 24, 3, 10);
$IL->Add("button.bmp");
$IL->Add("open.bmp");
$IL->Add("new.bmp");


$LV = new GUI::ListView($Window,
                        -name => "ListView",
                        -text => "hello world!",
                        -left => 10, -top => 10,
                        -width => 280, -height => 180,
                        -imagelist => $IL,
);

$LV1 = $Window->AddButton(-name => "LV1", -text => "Big Icons",
                          -left => 10, -top => 200,
);

$LV2 = $Window->AddButton(-name => "LV2", -text => "Small Icons",
                          -left => 10, -top => 230,
);

$LV3 = $Window->AddButton(-name => "LV3", -text => "List",
                          -left => 10, -top => 260,
);

$LV4 = $Window->AddButton(-name => "LV4", -text => "Details",
                          -left => 10, -top => 290,
);

$width = $LV->ScaleWidth;

$LV->InsertColumn(-index => 0, -width => $width/2, -text => "Name");
$LV->InsertColumn(-index => 1, -subitem => 1, -width => $width/2, -text => "Description");

$LV->InsertItem(-item => 0, -text => "ciao", -image => 0);
$LV->SetItem(-item => 0, -subitem => 1, -text => "greetings");
$LV->InsertItem(-item => 1, -text => "abracabra", -image => 1);
$LV->SetItem(-item => 1, -subitem => 1, -text => "magic word");

$LV->TextColor(hex("0000FF"));

$Window->Show();

$Window->Dialog();

GUI::Show($Win32::GUI::hwnd);


sub LV1_Click {
    print "BIG Icons!\n";
    $LV->View(0);
}

sub LV2_Click {
    print "small Icons!\n";
    $LV->View(2);
}

sub LV3_Click {
    print "List!\n";
    $LV->View(3);
}

sub LV4_Click {
    print "Details!\n";
    $LV->View(1);
}

