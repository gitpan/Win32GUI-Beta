
# use strict; # Win32::Registry is not strict safe...
use Win32::GUI;

use Win32::Registry qw(HKEY_LOCAL_MACHINE);

my $VERSION = "0.19";

my $DEBUG = 0;

my %items;
my %InfoCache;

my $PmxWindow_left;
my $PmxWindow_top;
my $PmxWindow_width;
my $PmxWindow_height;
my $PmxViewExDump;
my $PmxViewScripts;
my $PmxSaveSettings;

ReadConfig();

my $Menu = Win32::GUI::MakeMenu(
    "&File"                       => "File",
    "   > &Properties"            => "FileProps",
    "   > &View POD"              => "FilePod",
    "   > &Dump"                  => "FileDump",
    "   > -"                      => 0,
    "   > E&xit"                  => "FileExit",
    "&View"                       => "View",
    "   > &Scripts (PL)"          => { -name => "ViewPL", -checked => $PmxViewScripts },
    "   > E&xtended Dump"         => { -name => "ViewExtendedDump", -checked => $PmxViewExDump },
    "   > -"                      => 0,
    "   > &Refresh"               => "ViewRefresh",
    "   > Perl &Version"          => "ViewPerlVersion",
    "&Settings"                   => "Settings",
    "   > &Save settings on exit" => { -name => "SettingsSave", -checked => $PmxSaveSettings },
    "   > &Reset settings"        => "SettingsReset",
    "&?"                          => "Help",
    "   > &About PMX"             => "HelpAbout",
);

my $PopMenu = Win32::GUI::MakeMenu(
    "POP with POD"         => "POPUP_POD",
    "   >&Properties"      => {-name => "PopProps1", -default => 1},
    "   >&View POD"        => "PopPod",
    "   >&Dump"            => "PopDump1",
    "POP without POD"      => "POPUP_NOPOD",
    "   >&Properties"      => {-name => "PopProps2", -default => 1},
    "   >&Dump"            => "PopDump2",
    "POP for DLLs"         => "POPUP_DLL",
    "   >&Properties"      => {-name => "PopProps3", -default => 1},
);

my $Icon = new Win32::GUI::Icon("camel.ico");

my $WinClass = new Win32::GUI::Class(
    -name   => "PMX version $VERSION Window Class",
    -icon   => $Icon,
    -visual => 1,
);

my $Window = new Win32::GUI::Window(
    -name   => "Window",
    -text   => "PMX version ".$VERSION,
    -height => $PmxWindow_height, 
    -width  => $PmxWindow_width,
    -left   => $PmxWindow_left, 
    -top    => $PmxWindow_top,
    -menu   => $Menu,
    -class  => $WinClass,
);

my $IL = new Win32::GUI::ImageList(16, 16, 24, 4, 10);
my $IL_UNKFOLDER = $IL->Add("unkfolder.bmp");
my $IL_FOLDER    = $IL->Add("folder.bmp");
my $IL_MODULE    = $IL->Add("module.bmp");
my $IL_DLL       = $IL->Add("dll.bmp");
my $result = $IL->BackColor(hex("00FF00"));

my $Status = $Window->AddStatusBar(
    -name => "Status",
);

my $DIRS = $Window->AddTabStrip(
    -name    => "Dirs",
    -left    => 0, 
    -top     => 0,
    -width   => $Window->ScaleWidth, 
    -height  => $Window->ScaleHeight-$Status->Height,
    -visible => 1,
);

my $I;
my %dirs;
my @Tabs;
foreach $I (0..$#INC) {
    if(!exists($dirs{lc($INC[$I])})) {
        $DIRS->InsertItem(-text => lc($INC[$I]));
        $dirs{lc($INC[$I])} = 1;
        push(@Tabs, $INC[$I]);
    }
}

my $TV = new Win32::GUI::TreeView(
    $DIRS,
    -name      => "Tree",
    -text      => "hello world!",
    -left      => 0, 
    -top       => 20,
    -width     => $DIRS->ScaleWidth, 
    -height    => $DIRS->ScaleHeight,
    -lines     => 1, 
    -rootlines => 1,
    -buttons   => 1,
    -visible   => 1,
    -imagelist => $IL,
);

my $PerlVersion = new Win32::GUI::DialogBox(
    -title   => "Perl Version",
    -left    => 110, -top => 110,
    -width   => 400, -height => 300,
    -name    => "PerlVersion",
    -style   => WS_BORDER 
              | DS_MODALFRAME 
              | WS_POPUP 
              | WS_CAPTION 
              | WS_SYSMENU,
    -exstyle => WS_EX_DLGMODALFRAME 
              | WS_EX_WINDOWEDGE 
              | WS_EX_CONTEXTHELP 
              | WS_EX_CONTROLPARENT,

);
my $PerlVersionText = $PerlVersion->AddLabel(
    -left   => 5, 
    -top    => 5,
    -text   => "I'm a placeholder",
    -name   => "PerlVersionText",
    -width  => $PerlVersion->ScaleWidth-20, 
    -height => $PerlVersion->ScaleHeight-50,
);

my $PerlVersionOK = $PerlVersion->AddButton(
    -text   => "OK",
    -left   => $PerlVersion->ScaleWidth/2-25,
    -top    => $PerlVersion->ScaleHeight-30,
    -width  => 50,
    -height => 20,
    -name   => "PerlVersionOK",
);

my $ModuleWindow = new Win32::GUI::DialogBox(
    -title   => "Module Properties",
    -left    => 110, 
    -top     => 110,
    -width   => 400, 
    -height  => 400,
    -name    => "ModuleWindow",
    -style   => WS_BORDER 
              | DS_MODALFRAME 
              | WS_POPUP 
              | WS_CAPTION 
              | WS_SYSMENU,
    -exstyle => WS_EX_DLGMODALFRAME 
              | WS_EX_WINDOWEDGE 
              | WS_EX_CONTEXTHELP 
              | WS_EX_CONTROLPARENT,
);


my $ModuleTabs = $ModuleWindow->AddTabStrip(
    -left    => 5,
    -top     => 5,
    -name    => "ModuleTabs",
    -tabstop => 1,
    -width   => $ModuleWindow->ScaleWidth-10,
    -height  => $ModuleWindow->ScaleHeight-45,
);
$ModuleTabs->InsertItem(-text => "General");
$ModuleTabs->InsertItem(-text => "Dump");

my($cx, $cy) = $ModuleWindow->GetTextExtentPoint32("I'm a placeholder");

my $lblleft   = 15;
my $fldleft   = 80;
my $fldwidth  = $ModuleWindow->ScaleWidth-$fldleft-20;
my $top       = 40;
my $interline = $cy*1.5;

my $ModuleNameLbl = $ModuleWindow->AddLabel(
    -text => "Name:",
    -left => $lblleft,
    -top  => $top,
);
my $ModuleName = $ModuleWindow->AddLabel(
    -text  => "I'm a placeholder",
    -left  => $fldleft,
    -top   => $top,
    -width => $fldwidth,
    -name  => "ModuleName",
);

$top += $interline;

my $ModuleVersionLbl = $ModuleWindow->AddLabel(
    -text => "Version:",
    -left => $lblleft,
    -top  => $top,
);
my $ModuleVersion = $ModuleWindow->AddLabel(
    -text  => "I'm a placeholder",
    -left  => $fldleft,
    -top   => $top,
    -width => $fldwidth,
    -name  => "ModuleVersion",
);

$top += $interline;

my $ModuleTypeLbl = $ModuleWindow->AddLabel(
    -text => "Type:",
    -left => $lblleft,
    -top  => $top,
);
my $ModuleType = $ModuleWindow->AddLabel(
    -text  => "I'm a placeholder",
    -left  => $fldleft,
    -top   => $top,
    -width => $fldwidth,
    -name  => "ModuleType",
);

$top += $interline;

my $ModuleFileLbl = $ModuleWindow->AddLabel(
    -text => "Filename:",
    -left => $lblleft,
    -top  => $top,
);
my $ModuleFile = $ModuleWindow->AddLabel(
    -text  => "I'm a placeholder",
    -left  => $fldleft,
    -top   => $top,
    -width => $fldwidth,
    -name  => "ModuleFile",
);

$top += $interline;

my $ModuleSizeLbl = $ModuleWindow->AddLabel(
    -text => "File size:",
    -left => $lblleft,
    -top  => $top,
);
my $ModuleSize = $ModuleWindow->AddLabel(
    -text  => "I'm a placeholder",
    -left  => $fldleft,
    -top   => $top,
    -width => $fldwidth,
    -name  => "ModuleSize",
);

$top += $interline*1.5;

my $ModuleCtimeLbl = $ModuleWindow->AddLabel(
    -text => "Creation\r\ntime:",
    -left => $lblleft,
    -top  => $top-$cy,
    -height => 30,
);
my $ModuleCtime = $ModuleWindow->AddLabel(
    -text  => "I'm a placeholder",
    -left  => $fldleft,
    -top   => $top,
    -width => $fldwidth,
    -name  => "ModuleCtime",
);

$top += $interline*1.5;

my $ModuleMtimeLbl = $ModuleWindow->AddLabel(
    -text => "Modification\r\ntime:",
    -left => $lblleft,
    -top  => $top-$cy,
    -height => 30,
);
my $ModuleMtime = $ModuleWindow->AddLabel(
    -text  => "I'm a placeholder",
    -left  => $fldleft,
    -top   => $top,
    -width => $fldwidth,
    -name  => "ModuleMtime",
);

no strict 'subs';

my $ModuleDump = $ModuleWindow->AddTextfield(
    -multiline => 1,
    -top       => 40,
    -left      => 10,
    -width     => $ModuleWindow->ScaleWidth-20,
    -height    => $ModuleTabs->ScaleHeight-50,
    -tabstop   => 1,
    -visible   => 0,
    -style     => ES_MULTILINE | ES_HSCROLL | ES_VSCROLL | WS_VSCROLL,
);

use strict 'subs';

my $ModuleViewPod = $ModuleWindow->AddButton(
    -text    => "View POD",
    -left    => $ModuleWindow->ScaleWidth-110,
    -top     => 300,
    -width   => 80,
    -tabstop => 1,
    -name    => "ModuleViewPod",
);

my $ModuleWindowClose = $ModuleWindow->AddButton(
    -text    => "Close",
    -left    => $ModuleWindow->ScaleWidth-90,
    -top     => 345,
    -width   => 80,
    -tabstop => 1,
    -menu    => 2,
    -name    => "ModuleWindowClose",
);

my $AboutWindow = new Win32::GUI::DialogBox(
    -title   => "About PMX...",
    -left    => 110, 
    -top     => 110,
    -width   => 200, 
    -height  => 150,
    -name    => "AboutWindow",
    -style   => DS_MODALFRAME
              | WS_CAPTION
              | WS_POPUP,
    -exstyle => WS_EX_DLGMODALFRAME 
              | WS_EX_CONTROLPARENT,    
);

my $AboutIcon = new Win32::GUI::Label(
    $AboutWindow,
    -top => 5,
    -left => 5,
    -height => 32,
    -width => 32,
    -style => 3,
    -name => "AboutIcon", 
    -visible => 1,
);
# 368 == STM_SETICON
$AboutIcon->SendMessage(368, $Icon->{handle}, 0);

my $AboutTitleFont = new Win32::GUI::Font(-name => "Times New Roman", -height => 16, -bold => 1);

my $AboutTitle = $AboutWindow->AddLabel(
    -top => 13,
    -left => 42,
    -height => 32,
    -width => $AboutWindow->ScaleWidth-47,
    -name => "AboutTitle", 
    -text => "PMX Version $VERSION",
    -font => $AboutTitleFont,
);

my $AboutDetails = $AboutWindow->AddLabel(
    -top => 42,
    -left => 5,
    -height => $AboutWindow->ScaleHeight-62,
    -width => $AboutWindow->ScaleWidth-10,
    -name => "AboutTitle", 
    -text => "Author: Aldo Calpini\r\nContact: dada\@divinf.it\r\nDate: 17 May 1998\r\n\r\n",
);

my $AboutOK = $AboutWindow->AddButton(
    -left => 0,
    -top => 0,
    -text => "    OK    ",
    -name => "AboutOK", 
    -visible => 1,
    -default => 1,
    -ok => 1,
);
$AboutOK->Move(
    $AboutWindow->ScaleWidth-$AboutOK->Width,
    $AboutWindow->ScaleHeight-$AboutOK->Height,
);

AddModules($INC[0], 0);

$Window->Show;
$Window->Show; # twice to avoid being preset by a 'start minimized' shortcut

my $retcode = Win32::GUI::Dialog();

print "exiting with return code $retcode\n" if $DEBUG;

#==================
sub Window_Resize {
#==================
    $DIRS->Resize($Window->ScaleWidth, $Window->ScaleHeight-$Status->Height);
    $TV->Move(0, 22);
    $TV->Resize($DIRS->ScaleWidth, $DIRS->ScaleHeight-22);
    $Status->Move(0, $Window->ScaleHeight-$Status->Height);
    $Status->Resize($Window->ScaleWidth, $Status->Height);
    return 1;
}

#=====================
sub Window_Terminate {
#=====================
    if($Menu->{SettingsSave}->Checked()) {
        my $key;
        $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada", $key)
        or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada", $key);
        $key->Close();
        undef $key;
        $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada\\PMX", $key)
        or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada\\PMX", $key);
        if($key) {
            $PmxWindow_left = $Window->Left;
            $PmxWindow_top = $Window->Top;
            $PmxWindow_width = $Window->Width;
            $PmxWindow_height = $Window->Height;
            $PmxViewExDump = $Menu->{ViewExtendedDump}->Checked();
            $PmxViewScripts = $Menu->{ViewPL}->Checked();

            WriteConfig($key);
            $key->Close();
        }
    }
    return -1;
}

#====================
sub Window_Activate {
#====================
    $TV->SetFocus();
    return 0;
}

#===============
sub Dirs_Click {
#===============
    my $dir = $DIRS->SelectedItem;
    if(defined($dir)) {
        $TV->Clear;
        AddModules($Tabs[$dir], 0);
    }
}

#=================
sub Tree_KeyDown {
#=================
    my($key) = @_;
    #          Enter         Numpad +       Normal +
    if($key == 13 or $key == 107 or $key == 187) {
        my %itemdata = $TV->GetItem($TV->SelectedItem);
        if($itemdata{-image} == $IL_UNKFOLDER) {
            ExpandDir($TV->SelectedItem);
            $TV->Expand($TV->SelectedItem);
            return 0;
        } else {
            Tree_DblClick() if $key == 13; # Enter
            return 0;
        }
    }
    return 1;
}

#===================
sub Tree_NodeClick {
#===================
    my %itemdata = $TV->GetItem($TV->SelectedItem);
    if($itemdata{-image} == $IL_MODULE) {
        GetInfo($TV->SelectedItem);
        $Menu->{'FileProps'}->Enabled(1);
        $Menu->{'FileDump'}->Enabled(1);
    } elsif($itemdata{-image} == $IL_DLL) {
        $Menu->{'FileProps'}->Enabled(1);
        $Menu->{'FilePod'}->Enabled(0);
        $Menu->{'FileDump'}->Enabled(0);
    } else {
        $Status->Text("");
        $Menu->{'FileProps'}->Enabled(0);
        $Menu->{'FilePod'}->Enabled(0);
        $Menu->{'FileDump'}->Enabled(0);
    }
    return 0;
}

#==================
sub Tree_DblClick {
#==================
    my %itemdata = $TV->GetItem($TV->SelectedItem);
    if($itemdata{-image} == $IL_UNKFOLDER) {
        ExpandDir($TV->SelectedItem);
    } elsif($itemdata{-image} == $IL_MODULE
         or $itemdata{-image} == $IL_DLL) {
        FileProps_Click();
    }
    return 0;
}

#====================
sub Tree_RightClick {
#====================
    my($X, $Y) = Win32::GUI::GetCursorPos();
    my($TVI, $flags) = $TV->HitTest($X-$TV->Left, $Y-$TV->Top);
    print "TV.HitTest.TVI = $TVI\n" if $DEBUG;
    print "TV.HitTest.flags = $flags\n" if $DEBUG;

    if($TVI) {
        $TV->Select($TVI);
        my %itemdata = $TV->GetItem($TVI);
        print "Selected Item: ", $itemdata{-text}, "\n" if $DEBUG;
        if($itemdata{-image} == $IL_MODULE) {
            if($ModuleViewPod->IsEnabled()) {
                $Window->TrackPopupMenu($PopMenu->{POPUP_POD}, $X, $Y);
            } else {
                $Window->TrackPopupMenu($PopMenu->{POPUP_NOPOD}, $X, $Y);
            }
        } elsif($itemdata{-image} == $IL_DLL) {
            $Window->TrackPopupMenu($PopMenu->{POPUP_DLL}, $X, $Y);
        }
    }
    return 1;
}

#============
sub GetInfo {
#============
    my($item) = @_;
    my %itemdata = $TV->GetItem($item);
    my $name = GetFullPath($item);
    my $pname = GetPerlPath($item);
    $name .= ".pm" unless $name =~ /\.(pl|pm|dll)$/i;
    if(!exists($InfoCache{$name})) {
        $InfoCache{$name} = {};
        if($itemdata{-image} == $IL_MODULE) {
            $InfoCache{$name}->{version} = $pname;
            if(-f $name) {
                print "GetInfo: opening $name...\n" if $DEBUG;
                open(PM, "<$name");
                while(<PM>) {
                    if(/\$version\s*=\s*['"]?([^'";]*)['"]?;/i) {
                        $InfoCache{$name}->{version} .= " Version: $1";
                    }
                    if(/^=head/) {
                        $InfoCache{$name}->{haspod} = 1;
                    }
                }
                close(PM);
            }
        } elsif($itemdata{-image} == $IL_DLL) {
            $InfoCache{$name}->{version} = "";
            $InfoCache{$name}->{haspod} = 0;
        }
    }
    $Status->Text($InfoCache{$name}->{version});
    if($InfoCache{$name}->{haspod} == 1) {
        $ModuleViewPod->Enable();
        $Menu->{'FilePod'}->Enabled(1);
    } else {
        $ModuleViewPod->Disable();
        $Menu->{'FilePod'}->Enabled(0);
    }
}

#==============
sub ExpandDir {
#==============
    my($node) = @_;
    if($node) {
        my $name = "";
        my $n = 0;
        $name = GetFullPath($node);
        if(-d $name) {
            $TV->Clear($node);
            $TV->ChangeItem($node, -image => $IL_FOLDER);
            AddModules($name, $node);
        }
    }
    return 1;
}

#================
sub GetPerlPath {
#================
    my($node) = @_;
    my $name = "";
    my $n = $node;
    my $delim;
    while($items{$TV->GetParent($n)}) {
        $delim = ($name =~ /^::/) ? "" : "::";
        $delim = "" if $name eq "";
        $name = $items{$TV->GetParent($n)} . $delim . $name;
        $n = $TV->GetParent($n) if $TV->GetParent($n);
    }
    $delim = ($name =~ /::$/) ? "" : "::";
    $delim = "" if $name eq "";
    $name .= $delim . $items{$node};
    return $name;
}

#================
sub GetFullPath {
#================
    my($node) = @_;
    my $name = "";
    my $n = $node;
    my $delim;
    while($items{$TV->GetParent($n)}) {
        $delim = ($name =~ /^\//) ? "" : "/";
        $name = $items{$TV->GetParent($n)} . $delim . $name;
        $n = $TV->GetParent($n) if $TV->GetParent($n);
    }
    $delim = ($name =~ /\/$/) ? "" : "/";
    $name .= $delim . $items{$node};
    $name = $Tabs[$DIRS->SelectedItem]."/".$name;
    $name =~ s/[\\\/]+/\\/g;
    return $name;
}

#===============
sub AddModules {
#===============
    my($dir, $parent) = @_;
    my $TVI;
    my $image;
    opendir(LIB, $dir) or print "Can't open dir $dir!\n";
    my @files = readdir(LIB);
    closedir(LIB);
    my $file;
    my $ModulesToAdd = "p[ml]";
    $ModulesToAdd = "pm" if $Menu->{ViewPL}->Checked() == 0;

    # print "found $#files files.\n";
    my $dirs = 0;
    my $files = 0;
    foreach $file (sort CaseInsensitive @files) {
        next if $file =~ /^(.|..)$/;
        if(-d $dir."/".$file) {
            $TVI = $TV->InsertItem(-parent => $parent, -text => $file, -image => $IL_UNKFOLDER);
            $items{$TVI} = $file;
            # $TV->Select($TVI);
            # ExpandDir($TVI);
            $dirs++;
        } else {
            # print "FILE = $file\n";
            next unless ($file =~ /\.$ModulesToAdd$/i or $file =~ /\.[pd]ll$/i);
            $files++;
            $image = $IL_MODULE;
            $image = $IL_DLL if $file =~ /\.[pd]ll$/i;
            $file =~ s/\.pm$//i;
            $TVI = $TV->InsertItem(-parent => $parent, -text => $file, -image => $image);
            # print "ITEMS($TVI) = $file\n";
            $items{$TVI} = $file;
        }
    }
    $Status->Text(
        "Found $files file"
        .(($files==1)? "":"s")." and $dirs director"
        .(($dirs==1)? "y":"ies")
    );
}

#=================
sub ViewPL_Click {
#=================
    $Menu->{ViewPL}->Checked(!$Menu->{ViewPL}->Checked());
}

#===========================
sub ViewExtendedDump_Click {
#===========================
    $Menu->{ViewExtendedDump}->Checked(!$Menu->{ViewExtendedDump}->Checked());
}

#======================
sub ViewRefresh_Click {
#======================
    %InfoCache = ();
    Dirs_Click();
}

#=======================
sub SettingsSave_Click {
#=======================
    $Menu->{SettingsSave}->Checked(!$Menu->{SettingsSave}->Checked());
    $PmxSaveSettings = $Menu->{SettingsSave}->Checked();
    my $key;
    $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada", $key)
    or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada", $key);
    $key->Close() if $key;
    undef $key;
    $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada\\PMX", $key)
    or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada\\PMX", $key);
    if($key) {
        $key->SetValueEx("SaveSettings", 0, 1, $PmxSaveSettings);
        $key->Close();
    }
    return 1;
}

#========================
sub SettingsReset_Click {
#========================
    my $key;
    $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada", $key)
    or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada", $key);
    $key->Close();
    undef $key;
    $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada\\PMX", $key)
    or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada\\PMX", $key);
    if($key) {
        undef $PmxWindow_left;
        undef $PmxWindow_top;
        undef $PmxWindow_width;
        undef $PmxWindow_height;
        undef $PmxViewExDump;
        undef $PmxViewScripts;
        WriteConfig($key);
        $key->Close();
    }
    $Window->Move($PmxWindow_left, $PmxWindow_top);
    $Window->Resize($PmxWindow_width, $PmxWindow_height);
    $Menu->{ViewPL}->Checked($PmxViewScripts);
    $Menu->{ViewExtendedDump}->Checked($PmxViewExDump);
}


#===================
sub FileExit_Click {
#===================
    Window_Terminate();
}


#==========================
sub ViewPerlVersion_Click {
#==========================
    #my $v = `perl -v`;
    #print "$]\n";
    #$v =~ s/\n/\r\n/g;
    #$PerlVersionText->Text($v);
    #$PerlVersion->Show();
    #$Window->Disable();
    Win32::GUI::MessageBox(0, "This is perl, version $]", "Perl Version", 64);
}

#========================
sub PerlVersionOK_Click {
#========================
    $PerlVersion->Hide();
    $Window->Enable();
    $Window->BringWindowToTop();
}
sub PerlVersion_Terminate { PerlVersionOK_Click(); }

#====================
sub CaseInsensitive { uc($b) cmp uc($a); }
#====================

#====================
sub FileProps_Click {
#====================
    GetProps();
    $ModuleTabs->Select(0);
    ModuleTabs_Click();
    $ModuleWindow->Show();
    $Window->Disable();
}
sub PopProps1_Click { FileProps_Click(); }
sub PopProps2_Click { FileProps_Click(); }
sub PopProps3_Click { FileProps_Click(); }

#===================
sub FileDump_Click {
#===================
    GetProps();
    # DoModuleDump();
    $ModuleTabs->Select(1);
    ModuleTabs_Click();
    $ModuleWindow->Show();
    $Window->Disable();
}
sub PopDump1_Click { FileDump_Click(); }
sub PopDump2_Click { FileDump_Click(); }

#=============
sub GetProps {
#=============
    my $node = $TV->SelectedItem;
    my $name = GetFullPath($node);
    my %nodedata = $TV->GetItem($node);
    my $pname = GetPerlPath($node);
    if($nodedata{-image} == $IL_MODULE) {
        
        $name .= ".pm" unless $name =~ /\.p[lm]$/i;
        $ModuleWindow->Text($pname." Properties");
        $ModuleName->Text($pname);
        my $mversion;
        if(-f $name) {
            open(PM, "<$name");
            while(<PM>) {
                if(/\$version\s*=\s*['"]?([^'";]*)['"]?;/i) {
                    #$mversion = eval($1);
                    $mversion = $1;
                    seek(PM, 0, 2);
                }
            }
            close(PM);
        }
        if($mversion) {
            $ModuleVersion->Text($mversion);
        } else {
            $ModuleVersion->Text("");
        }
        if($name =~ /\.pm$/i) {     
            $ModuleType->Text("Module");
        } else {
            $ModuleType->Text("Script");
        }
    } elsif($nodedata{-image} == $IL_DLL) {
        $ModuleName->Text($nodedata{-text});
        $ModuleVersion->Text("");
        $ModuleType->Text("Loadable object");
    }
    $ModuleFile->Text($name);
    my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks)           = stat($name);
    $ModuleSize->Text($size);
    $ModuleCtime->Text(scalar(localtime($ctime)));
    $ModuleMtime->Text(scalar(localtime($mtime)));
}

#========================
sub ModuleViewPod_Click {
#========================
    my $node = $TV->SelectedItem;
    my $name = GetFullPath($node);
    $name .= ".pm" unless $name =~ /\.p[lm]$/i;
    if($ModuleWindow->IsVisible()) {
        $ModuleWindow->Disable();
    } else {
        $Window->Disable();
    }
    system("$^X podview.pl $name");
    # my $pid;
    # Win32::Spawn("$^X", "podview.pl $name", $pid);
    if($ModuleWindow->IsVisible()) {
        $ModuleWindow->Enable();
        $ModuleWindow->SetForegroundWindow();
    } else {
        $Window->Enable();
        $Window->SetForegroundWindow();
    }
    return 1;
}
sub PopPod_Click { ModuleViewPod_Click(); }
sub FilePod_Click { ModuleViewPod_Click(); }

#============================
sub ModuleWindowClose_Click {
#============================
    $Window->Enable();
    $Window->SetForegroundWindow();
    Window_Activate();
    $ModuleWindow->Hide();
    return 1;
}
sub ModuleWindow_Terminate { ModuleWindowClose_Click(); }

#=====================
sub ModuleTabs_Click {
#=====================
    my $control;
    print "Got ModuleTabs_Click (", $ModuleTabs->SelectedItem, ")\n" if $DEBUG;
    my @controls = (
        $ModuleNameLbl, $ModuleName,
        $ModuleVersionLbl, $ModuleVersion,
        $ModuleTypeLbl, $ModuleType,
        $ModuleFileLbl, $ModuleFile,
        $ModuleCtimeLbl, $ModuleCtimeLbl,
        $ModuleMtimeLbl, $ModuleMtimeLbl,
        $ModuleViewPod,
    );
    if($ModuleTabs->SelectedItem == 0) {
        foreach $control (@controls) {
            $control->Show();
        }
        $ModuleDump->Hide();
    } else {
        foreach $control (@controls) {
            $control->Hide();
        }
        DoModuleDump();
        $ModuleDump->Show();
    }
}

#====================
sub HelpAbout_Click {
#====================
    $AboutWindow->Show();
    $Window->Disable();
    AboutWindow_Resize();
}

#==================
sub AboutOK_Click {
#==================
    $Window->Enable();
    $Window->SetForegroundWindow();
    Window_Activate();
    $AboutWindow->Hide();
    return 1;
}

#==========================
sub AboutWindow_Terminate {
#==========================
    AboutOK_Click();
    return 0;
}

#=================
sub DoModuleDump {
#=================
    no strict 'refs';
    my $name = $ModuleName->Text();
    print "useing $name..." if $DEBUG;
    my $use = eval("use $name;");
    print "used\n" if $DEBUG;
    if(!$@) {
        my $output = DumpNames(\%{$name.'::'}, $name.'::', $name.'::');
        #my $expr = "use $name; DumpNames(\%".$name."::, '".$name."::', '".$name."::');";
        $ModuleDump->Text($output);
    } else {
        Win32::GUI::MessageBox(0, $@, "Error using $name", 16);
        $ModuleDump->Text("");
    }
    return 1;
}

# this code was originally taken
# from a PerlScript sample by ActiveState
#====================
sub DumpNames(\%$$) {
#====================
    no strict 'refs';
    my ($package,$packname,$pname) =  @_;
    my $symname = 0;
    my $value = 0; 
    my $key = 0;
    my $i = 0;
    $pname =~ s/main::(.+)/$1/;
    my @found = ();
    my $sym;
    my %sym;
    my @sym;
    my %flags;
    my $spname;

    print "DumpNames called for $packname ($pname) = $package\n" if $DEBUG;

    my $ret = "";

    @found = ();
    foreach $symname (sort keys %$package) {
        push(@found, $symname) if defined %{$pname.$symname} and $symname =~ /::$/;
    }
    if($#found > -1) {
        $ret .= "$pname Packages\r\n";
        foreach $symname (@found) {
            next if $symname eq 'main::';            
            $ret .= "\t$symname\r\n";
        }
    }

    if ($packname ne 'main::') {

        @found = ();   
        foreach $symname (sort keys %$package) {
            push(@found, $symname) if defined &{$pname.$symname};
        }
        if($#found > -1) {
            $ret .= "$pname Functions\r\n";
            foreach $symname (@found) {
                $ret .= "\t$symname()\r\n";
            }
        }

        @found = ();
        foreach $symname (sort keys %$package) {
            push(@found, $symname) if defined ${$pname.$symname};
        }
        if($#found > -1) {
            $ret .= "$pname Scalars\r\n";
            foreach $symname (@found) {
                $ret .= "\t\$$symname = ".${$pname.$symname}."\r\n";

            }
        }

        @found = ();
        foreach $symname (sort keys %$package) {
            push(@found, $symname) if defined @{$pname.$symname};
        }
        if($#found > -1) {
            $ret .= "$pname Lists\r\n";
            foreach $symname (@found) {
                if($Menu->{ViewExtendedDump}->Checked) {
                    $ret .= "\t\@$symname = (\r\n";
                    foreach (sort @{$$package{$symname}}) {
                        $ret .= "\t\t$_\r\n";
                    }
                    $ret .= "\t);\r\n";
                } else {
                    $ret .= "\t\@$symname\r\n";
                }
                
            }
        }

        @found = ();
        foreach $symname (sort keys %$package) {
            push(@found, $symname) if defined %{$pname.$symname} and $symname !~ /::$/;
        }
        if($#found > -1) {
            $ret .= "$pname Hashes\r\n";
            foreach $symname (@found) {
                if($Menu->{ViewExtendedDump}->Checked) {
                    $ret .= "\t\%$symname = (\r\n";
                    foreach (sort keys %{$$package{$symname}}) {
                        $ret .= "\t\t$_ => ${$$package{$symname}}{$_}\r\n";
                    }
                    $ret .= "\t);\r\n";
                } else {
                    $ret .= "\t\%$symname\r\n";
                }
            }
        }
    }
    $ret .= "\r\n";
    
    # if ($packname ne 'main::') {
    #    return;
    # }

    foreach $symname (sort keys %$package) {
        if (defined %{$pname.$symname} and $symname =~ /::$/ and $symname ne 'main::') {
            $spname = $packname . $symname;
            next if $spname =~ /PMX::/ and $flags{'self'} == 0;
            print "Dumping $symname ($spname)...\n" if $DEBUG;
            $ret .= DumpNames(\%{$spname}, $spname, $spname);
        }
    }
    return $ret;
}

#===============
sub ReadConfig {
#===============
    my $key;
    my $val;
    my $name;
    $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada", $key)
    or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada", $key);
    $key->Close();
    undef $key;
    $main::HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada\\PMX", $key)
    or $main::HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada\\PMX", $key);
    if($key) {
        $key->GetValues($val);
        
        #foreach $name (keys %$val) {
        #    print "\t$name = $val->{$name}[2]\n";
        #}

        $PmxWindow_left   = $val->{'left'}[2];
        $PmxWindow_top    = $val->{'top'}[2];
        $PmxWindow_width  = $val->{'width'}[2];
        $PmxWindow_height = $val->{'height'}[2];

        $PmxViewExDump    = $val->{'ViewExDump'}[2];
        $PmxViewScripts   = $val->{'ViewScripts'}[2];

        $PmxSaveSettings  = $val->{'SaveSettings'}[2];

        WriteConfig($key);
        $key->Close();
    } else {
        WriteConfig();
    }        
}

#================
sub WriteConfig {
#================
    my($key) = @_;

    # put default values where needed
    $PmxWindow_left = 100 unless defined($PmxWindow_left);
    $PmxWindow_top = 100 unless defined($PmxWindow_top);
    $PmxWindow_width = 400 unless defined($PmxWindow_width);
    $PmxWindow_height = 300 unless defined($PmxWindow_height);
    $PmxViewExDump = 0 unless defined($PmxViewExDump);
    $PmxViewScripts = 0 unless defined($PmxViewScripts);
    $PmxSaveSettings = 1 unless defined($PmxSaveSettings);

    # write in the registry (note: 1 is REG_SZ)
    if($key) {
        $key->SetValueEx("left", 0, 1, $PmxWindow_left);
        $key->SetValueEx("top", 0, 1, $PmxWindow_top);
        $key->SetValueEx("width", 0, 1, $PmxWindow_width);
        $key->SetValueEx("height", 0, 1, $PmxWindow_height);
        $key->SetValueEx("ViewExDump", 0, 1, $PmxViewExDump);
        $key->SetValueEx("ViewScripts", 0, 1, $PmxViewScripts);
        $key->SetValueEx("SaveSettings", 0, 1, $PmxSaveSettings);
    }
}

