
use Win32::GUI;

$NinetyFiveFont = new Win32::GUI::Font(
    -name   => "MS Sans Serif", 
    -height => 14,
);

$Menu = new GUI::Menu();
$Options = $Menu->AddMenuButton(
    -text => "&Options", 
    -id   => 1,
);
$Exit = $Options->AddMenuItem(
    -text => "E&xit", 
    -id   => 9, 
    -name => "Exit"
);
$Dummy = $Options->AddMenuItem(
    -separator => 1, 
    -item      => 9, 
    -id        => 8,
);
$HasImages = $Options->AddMenuItem(
    -text  => "I&mages", 
    -item  => 8, 
    -id    => 7, 
    -name  => "HasImages", 
    -state => 8,
);
$HasButtons = $Options->AddMenuItem(
    -text  => "&Buttons", 
    -item  => 7, 
    -id    => 6, 
    -name  => "HasButtons", 
    -state => 8,
);
$RootLines = $Options->AddMenuItem(
    -text  => "&Root lines", 
    -item  => 6, 
    -id    => 5, 
    -name  => "RootLines", 
    -state => 8,
);
$HasLines = $Options->AddMenuItem(
    -text  => "&Lines", 
    -item  => 5, 
    -id    => 4, 
    -name  => "HasLines", 
    -state => 8,
);
$Font = $Options->AddMenuItem(
    -text => "Choose &font...", 
    -item => 4, 
    -id   => 3, 
    -name => "Font",
);
$Indent = $Options->AddMenuItem(
    -text => "Set &indent...", 
    -item => 3, 
    -id   => 2, 
    -name => "Indent",
);

$Window = new GUI::Window(
    -name   => "Window",
    -text   => "Win32::GUI TEST - TreeView",
    -height => 200, 
    -width  => 300,
    -left   => 100, 
    -top    => 100,
    -font   => $NinetyFiveFont,
    -menu   => $Menu,
);

$B1 = new Win32::GUI::Bitmap("node.bmp");
$B2 = new Win32::GUI::Bitmap("node_sel.bmp");

$IL = new Win32::GUI::ImageList(16, 16, 0, 2, 10);
$IL->Add($B1, 0);
$IL->Add($B2, 0);

$TV = $Window->AddTreeView(
    -name      => "Tree",
    -text      => "hello world!",
    -width     => $Window->ScaleWidth, 
    -height    => $Window->ScaleHeight,
    -left      => 0, 
    -top       => 0,
    -lines     => 1, 
    -rootlines => 1,
    -buttons   => 1,
    -visible   => 1,
    -imagelist => $IL,
);

$IndentWin = new GUI::Window(
    -text   => "Treeview Indent",
    -name   => "IndentWin",
    -width  => 200,
    -height => 100, 
    -left   => 110, 
    -top    => 110,
    -font   => $NinetyFiveFont,
);

$IndentVal = $IndentWin->AddLabel(
    -text => "Indent value = ".$TV->Indent(),
    -name => "IndentVal",
    -left => 10, 
    -top  => 10,
);

$IndentNew = $IndentWin->AddTextfield(
    -text   =>  $TV->Indent(),
    -name   =>  "IndentNew",
    -left   =>  10, 
    -top    => 40,
    -width  => 100, 
    -height => 25,
);

$IndentSet = $IndentWin->AddButton(
    -text => "Set", 
    -name => "IndentSet",
    -left => 130, 
    -top  => 40
);
                            
$TV1 = $TV->InsertItem(
    -text          => "ROOT", 
    -image         => 0, 
    -selectedimage => 1
);

$TV3 = $TV->InsertItem(
    -parent        => $TV1, 
    -text          => "SUB 2", 
    -image         => 0, 
    -selectedimage => 1
);

$TV2 = $TV->InsertItem(
    -parent        => $TV1, 
    -text          => "SUB 1", 
    -image         => 0, 
    -selectedimage => 1
);

$Window->Show();

Win32::GUI::Dialog();

sub Window_Terminate {
    $Window->PostQuitMessage(0);
}

sub Window_Resize {
    $TV->Resize($Window->ScaleWidth, $Window->ScaleHeight);
}

sub Tree_NodeClick {
    print "Click on node $_[0]\n";
}

sub Tree_Expand {
    print "Expanded node $_[0]\n";
}

sub Tree_Collapse {
    print "Collapsed node $_[0]\n";
}

sub Indent_Click {
    $Window->Disable();    
    $IndentVal->Text("Indent value = ".$TV->Indent());
    $IndentNew->Text($TV->Indent());
    $IndentWin->Show();
    $IndentNew->SetFocus();
    $IndentNew->Select(0, length($IndentNew->Text()));
    return 1;
}

sub IndentSet_Click {
    $TV->Indent($IndentNew->Text());
    $IndentWin->Hide();
    $Window->Enable();
}

sub Font_Click {
    $Window->Disable();
    my @font = GUI::ChooseFont();
    if($font[0] eq "-name") {
        undef $TreeviewFont;
        $TreeviewFont = new GUI::Font(@font);
        $TV->SetFont($TreeviewFont);
        # $TV->Change(-font => $TreeviewFont);
    }
    $Window->Enable();
}

sub Exit_Click {
    $Window->PostQuitMessage(0);
}

sub HasLines_Click {
    $HasLines->Checked(!$HasLines->Checked);
    print "TV.Style is: ", $TV->GetWindowLong(-16), "\n";
    $TV->Change(-lines => $HasLines->Checked);
    print "TV.Style after -lines => ",$HasLines->Checked," is: ", $TV->GetWindowLong(-16), "\n";
}

sub RootLines_Click {
    $RootLines->Checked(($RootLines->Checked) ? 0 : 1);
    $TV->Change(-rootlines => $RootLines->Checked);
}

sub HasButtons_Click {
    $HasButtons->Checked(($HasButtons->Checked) ? 0 : 1);
    $TV->Change(-buttons => $HasButtons->Checked);
}

sub HasImages_Click {
    if($HasImages->Checked) {
        $HasImages->Checked(0);
        $TV->SetImageList(0);
    } else {
        $HasImages->Checked(1);
        $TV->SetImageList($IL);
    }
}
