#!perl -w

use strict;

use Win32::GUI;

my $VERSION = "0.12";
my %objects = ();

my $Menu = Win32::GUI::MakeMenu(
    "&File" => "File",
    "   >   &New" => "FileNew",
    "   >   &Open" => "FileOpen",
    "   >   &Save" => "FileSave",
    "   >   Save &As" => "FileSaveAs",
    "   >   &Close" => "FileClose",
    "   >   -" => 0,
    "   >   &Repride" => "FileRepride",
    "   >   -" => 0,
    "   >   E&xit" => "FileExit",
);

my $Window = new Win32::GUI::Window(
    -name   => "Window",
    -left   => 100,
    -top    => 100,
    -width  => 800,
    -height => 500,
    -title  => "PRIDE version ".$VERSION,
    -menu   => $Menu,
);

my $Status = $Window->AddStatusBar(
    -name => "Status",
    -text => "PRIDE version $VERSION - Ready",
);

my $EditorFont = new Win32::GUI::Font(
    -name => "Courier New", 
    -height => 16,
);

my $EditorClass = new Win32::GUI::Class(
    -name => "PRIDE_${VERSION}_Editor",
    -extends => "RichEdit",
    -widget => "RichEdit",
);

my $Editor = $Window->AddRichEdit(
    -class     => $EditorClass,
    -name      => "Editor",
    -multiline => 1,
    -left      => 0,
    -top       => 28,
    -width     => $Window->ScaleWidth,
    -height    => $Window->ScaleHeight-28-$Status->Height,
    -font      => $EditorFont,
    -exstyle   => WS_EX_CLIENTEDGE,
    -style     => WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL
                | ES_LEFT | ES_MULTILINE | ES_AUTOHSCROLL | ES_AUTOVSCROLL,
);

$Editor->SendMessage(1093, 0, 1);

my $SelectObject = $Window->AddCombobox(
    -name      => "SelectObject",
    -left      => 0,
    -top       => 5,
    -width     => $Window->ScaleWidth/2,
    -height    => 300,
    -style     => Win32::GUI::constant("WS_VISIBLE", 0) | 2 | Win32::GUI::constant("WS_NOTIFY", 0),
);

my $SelectSub = $Window->AddCombobox(
    -name      => "SelectSub",
    -left      => $Window->ScaleWidth/2,
    -top       => 5,
    -width     => $Window->ScaleWidth/2,
    -height    => 300,
    -style     => Win32::GUI::constant("WS_VISIBLE", 0) | 2 | Win32::GUI::constant("WS_NOTIFY", 0),
);

my $GotoWindow = new Win32::GUI::DialogBox(
    -name => "GotoWindow",
    -width => 200,
    -height => 100,
    -text => "Goto...",
);

my $GotoLabel = $GotoWindow->AddLabel(
    -text => "Line:",
    -left => 5,
    -top => 10,
);

my $GotoLine = $GotoWindow->AddTextfield(
    -name => "GotoLine",
    -left => 5,
    -top => 25,
    -width => 190,
    -height => 22, -tabstop => 1,
);

my $GotoOK = $GotoWindow->AddButton(
    -name => "GotoOK",
    -left => 5,
    -top => 50,
    -height => 22,
    -width => 90,
    -text => "OK", -tabstop => 1,
);

my $GotoCancel = $GotoWindow->AddButton(
    -name => "GotoCancel",
    -left => 100,
    -top => 50,
    -height => 22,
    -width => 90,
    -text => "Cancel", -tabstop => 1,
);

$Window->Show();

my $FILE = ($ARGV[0] or $0);
LoadFile($FILE);

Win32::GUI::Dialog();
print "Bye bye from PRIDE version $VERSION...\n";

sub Window_Terminate {
    if(OkToClose()) {
        return -1;
    } else {
        return 1;
    }
}

sub Window_Resize {
    $Editor->Resize($Window->ScaleWidth, $Window->ScaleHeight-28-$Status->Height);
    $Status->Resize($Window->ScaleWidth, $Status->Height);
    $Status->Move(0, $Window->ScaleHeight-$Status->Height);
}

sub Window_Activate {
    $Editor->SetFocus();
}

sub LoadFile {
    my($FILE) = @_;
    my $DEBUG = 0;
    print "FILE: $FILE\n" if $DEBUG;
    open(FILE, $FILE) or return 0;
    my $file = "";
    my $object;
    my $parent;
    my $sub;
    my $c = 1;
    while(<FILE>) {
        chomp;
        # converts tabs in 4 spaces
        s/\t/    /g;
        if(/\$(.+)\s*=\s*new Win32::GUI::/) {
            $object = $1;
            $object =~ s/^\s*//;
            $object =~ s/\s*$//;
            print "Found object: [$object]\n" if $DEBUG;
            $SelectObject->AddString($object);
            $SelectObject->Text($object);
            if(exists($objects{$object})) {
                push(@{$objects{$object}}, "<definition>;".length($file));
            } else {
                $objects{$object} = [ "<definition>;".length($file) ];
            }
        }
        if(/\$(.+)\s*=\s*\$(.+)->Add/) {
            $object = $1;
            $parent = $2;
            $object =~ s/^\s*//;
            $object =~ s/\s*$//;
            $parent =~ s/^\s*//;
            $parent =~ s/\s*$//;
            print "Found object: [$object] (parent: [$parent])\n" if $DEBUG;
            print "objects(parent): $objects{$parent}\n" if $DEBUG;
            if(exists($objects{$parent})) {
                $SelectObject->AddString($object);
                $SelectObject->Text($object);
                push(@{$objects{$object}}, "<definition>;".length($file));
            }
        }
        if(/sub ([^\s{]+)_([^\s{]+)/) {
            $parent = $1;
            $sub    = $2;
            if(exists($objects{$parent})) {
                push(@{$objects{$parent}}, $sub.";".length($file));
            }
        }
        # $file .= $c++." ".$_."\r\n";
        $file .= $_."\r\n";
    }
    close(FILE);
    $Editor->Text($file);
    $Window->Caption("PRIDE Version $VERSION - $FILE");
    $Editor->SetFocus();
    return 1;
}

sub SelectObject_Change {
    my $object = $SelectObject->GetString($SelectObject->SelectedItem);
    print "Selected object: $object\n";
    $SelectSub->Clear();
    my $sub;
    my $name;
    foreach $sub (@{$objects{$object}}) {
        ($name, undef) = split(/;/, $sub, 2);
        $SelectSub->AddString($name);
    }
}

sub SelectSub_Change {
    my $object;
    my $ssub;
    my $issub = $SelectSub->SelectedItem;
    my $isobject = $SelectObject->SelectedItem;
    if($isobject >= 0) {
        $object = $SelectObject->GetString($SelectObject->SelectedItem);
    } else {
        return 1;
    }
    if($issub >= 0) {
        $ssub = $SelectSub->GetString($SelectSub->SelectedItem);
    } else {
        return 1;
    }
    my $sub;
    my $name;
    my $pos;
    foreach $sub (@{$objects{$object}}) {
        ($name, $pos) = split(/;/, $sub, 2);
        if($name eq $ssub) {
            print "Object: $object / Sub: $ssub / Pos: $pos\n";
            # $Editor->Select($pos-1, $pos+1);
            $Editor->SendMessage(177, $pos, $pos);
            $Editor->SendMessage(183, 0, 0);
            $Editor->Update();
            $Editor->SetFocus();
        }
    }
}

sub FileRepride_Click {
    # system("perl $0");
    if(OkToClose()) {
        my $pid;
        my $file;
        if($FILE !~ /^[a-z]:\\/i) {
            $file = Win32::GetCwd."\\".$FILE;
        } else {
            $file = $FILE;
        }
        print "Executing p:\\perl5\\bin\\perl.exe $file ...\n";
        my $r = Win32::Spawn("p:\\perl5\\bin\\perl.exe", "p:\\perl5\\bin\\perl.exe $file", $pid);
        my $err = Win32::GetLastError();
        print "Repride r=$r err=$err pid=$pid\n";
        return -1;
    } else {
        return 1;
    }
}


sub FileExit_Click {
    if(OkToClose()) {
        return -1;
    } else {
        return 1;
    }
}

sub FileSave_Click {
    # make a backup copy
    open(BAKFILE, ">$FILE.bak");
    open(OLDFILE, "<$FILE");
    while(<OLDFILE>) { print <BAKFILE>; }
    close(BAKFILE);
    close(OLDFILE);

    open(FILE, ">$FILE");
    my $text = $Editor->Text();
    $text =~ s/\r\n/\n/g;
    print FILE $text;
    close(FILE);
    $text = $Window->Text();
    if($text =~ s/ \*$//) {
        $Window->Text($text);
    }
}


sub FileClose_Click {
    if(OkToClose()) {
        $Editor->Text("");
        $FILE = "untitled.pl";
        $Window->Text("PRIDE version $VERSION - untitled.pl");
    }
}

sub FileNew_Click {
    if(OkToClose()) {
        $Editor->Text("");
        $FILE = "untitled.pl";
        $Window->Text("PRIDE version $VERSION - untitled.pl");
    }
}

sub Editor_KeyPress {
    my($key) = @_;

    if($key == 7) {
        $GotoWindow->Move(
            $Window->Left+($Window->ScaleWidth-$GotoWindow->Width)/2,
            $Window->Top+($Window->ScaleHeight-$GotoWindow->Height)/2,
        );
        $GotoWindow->Show();
        $GotoLine->SetFocus();
        $Window->Disable();
        return 0;
    } else {
        print "Editor_KeyPress got $key\n";
        return 1;
    }
}

sub GotoWindow_Terminate {
    GotoCancel_Click();
}

sub GotoCancel_Click {
    $GotoWindow->Hide();
    $Window->Enable();
    return 1;
}

sub GotoOK_Click {
    $GotoWindow->Hide();
    $Window->Enable();
    GotoLine($GotoLine->Text);
    return 1;
}

sub GotoLine {
    my($line) = @_;
    print "Line=$line\n";
    my $EM_GETFIRSTVISIBLELINE = 206;
    my $fvl = $Editor->SendMessage($EM_GETFIRSTVISIBLELINE, 0, 0);
    print "FVL=$fvl\n";
    my $diff = ($line-1) - $fvl;
    print "DIFF=$diff\n";
    my $EM_LINESCROLL = 182;
    $Editor->SendMessage($EM_LINESCROLL, 0, $diff);
    my ($ci, $li) = $Editor->CharFromPos(1, 1);
    print "CI=$ci\n";
    $Editor->Select($ci, $ci);
    my $EM_SCROLLCARET = 183;
    $Editor->SendMessage($EM_SCROLLCARET, 0, 0);
    $Editor->SetFocus();
}

sub Editor_Change {
    my $text = $Window->Text;
    if($text !~ /\*$/) {
        $Window->Text($text." *");
    }
    return 1;
}

sub OkToClose {
    # if($Editor->Modified()) {
    if($Window->Text =~ /\*$/) {
        my $answer = Win32::GUI::MessageBox(0, "Save changes to $FILE ?", "PRIDE", 3+48);
        if($answer == 3) { # IDCANCEL
            return 0;
        } elsif($answer == 6) {
            FileSave_Click();
            return 1;
        } elsif($answer == 7) {
            return 1;
        }
    } else {
        return 1;
    }
    return 0;
}
