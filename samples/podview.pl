

use Win32::GUI;
use Win32::Registry;
use Pod::RTF;

$VERSION = "1.00.151";
$DEBUG = 0;

$NORMAL = GUI::LoadCursorFromFile("arrow_1.cur");
$HAND = GUI::LoadCursorFromFile("harrow.cur");

GUI::SetCursor($NORMAL);

# Minimize the Perl's DOS window
($DOShwnd, $DOShinstance) = GUI::GetPerlWindow();
GUI::CloseWindow($DOShwnd);

# you can eventually...
# GUI::Hide($DOShwnd);

ReadConfig();

$Menu = Win32::GUI::MakeMenu(
    "&File" => "File",
    "   >   &Open" => "MenuOpen",
    "   >   &Reload" => "MenuReload",
    "   >   &Save RTF" => "MenuSave",
    "   >   -" => 0,
    "   >   &1 $MRU{1}" => "MenuMRU1",
    "   >   &2 $MRU{2}" => "MenuMRU2",
    "   >   &3 $MRU{3}" => "MenuMRU3",
    "   >   &4 $MRU{4}" => "MenuMRU4",
    "   >   -" => 0,
    "   >   E&xit" => "MenuExit",
    "&Options" => "Options",
    "   >   Choose &normal &font..." => "MenuNormalFont",
    "   >   Choose &fixed font..." => "MenuFixedFont",
    "   >   Choose &heads color..." => "MenuHeadColor",
    "   >   Choose &links color..." => "MenuLinkColor",
    "   >   -", => 0,
    "   >   &Save options" => "MenuSaveConfig",
);


$Window = new GUI::Window(
    -name => "Window",
    -text => "Perl POD Viewer",
    -width => 640, -height => 480, 
    -left => 100,  -top => 100,
    -menu => $Menu,
);

$REC = new GUI::Class(
    -name => "PodView_RichEdit",
    -extends => "RichEdit",
    -widget => "RichEdit",
);

$POD = $Window->AddRichEdit(
    -name => "POD",
    # -class => $REC, # still testing this...
    -text => "",
    -left => 10, 
    -top => 10,
    -width => 280, 
    -height => 180,
    -exstyle => WS_EX_CLIENTEDGE,
    -style => WS_CHILD | WS_VISIBLE | WS_VSCROLL 
            | ES_LEFT | ES_MULTILINE | ES_AUTOVSCROLL,
);

$Status = $Window->AddStatusBar(
    -text => "PodView $VERSION Ready"
);

$Progress = new GUI::ProgressBar(
    $Status,
    -width  => 150,
    -height => $Status->Height-3,
    -left   => $Status->Width-150,
    -top    => 2,
);

$NoPOD = $Window->AddLabel( 
    -text    => "No POD found in file.",
    -name    => "NoPOD",
    -visible => 0,
);

LoadPod($ARGV[0] or $0);

$Window->Show();
$Window->Show(); # twice to avoid being preset by a 'start minimized' shortcut

Win32::GUI::Dialog();

# Restore the DOS window 
GUI::Show($DOShwnd);


######################################################################
# SUBROUTINES
#

sub LoadPod {
    my $ticks = Win32::GetTickCount();
    my($file) = @_;
    $file = $PODFILE unless $file;
    $Status->Text("Loading $file...");
    $Status->Update;
    if(-f $file) {
        if(open(TMP, ">podview.rtf")) {
            binmode(TMP);
            Pod::RTF::pod2rtf($file, *TMP);
            close(TMP);
            if(-s "podview.rtf" > 0) {
                $POD->Load("podview.rtf");
                $POD->Show;
                $NoPOD->Hide;
                my $elapsed = Win32::GetTickCount();
                $elapsed -= $ticks;
                $Status->Text("$file loaded in " . ($elapsed/1000) . " seconds.");
            } else {
                $Status->Text("PodView $VERSION Ready");
                $POD->Hide;
                $NoPOD->Show;
            }
        } else {
            Win32::GUI::MessageBox("Can't create temporary file!\n");
            $Status->Text("PodView $VERSION Ready");
        }
    } else {
        Win32::GUI::MessageBox($dummy, "Can't open file '$file'\n");
        $Status->Text("PodView $VERSION Ready");
    }
}

# not used, see Pod::RTF
sub OldLoadPod {
    my $ticks = Win32::GetTickCount();
    my($file) = @_;
    $file = $PODFILE unless $file;
    $size = -s $file;

    $NoPOD->Hide;
    $POD->Show;
    $POD->Update;

    undef %normal;
    $normal{-autocolor} = 1;
    $normal{-height} = 240;
    $normal{-name} = $NORMAL_FONT_NAME;
    $normal{-bold} = 0;
    $normal{-italic} = 0;
    $normal{-underline} = 0;

    if(open(FILE, $file)) {

        # clear the text box and don't update it
        $POD->Text("");
        $POD->SetRedraw(0);

        # starts with normal format
        $POD->SendMessage(177, -1, 0);
        $POD->SetCharFormat(%normal);

        $Progress->SetPos(0);
        $Progress->Show;
        $Status->Text("Loading $file...");
        $Status->Update;

        $podfound = 0;
        $pod = 0;
        while(<FILE>) {
            next unless($pod or /^=head(\d)/);
            chomp;
            if($pod == 0) {
                # print "OUTSIDE POD\n";
                if(/^=head(\d)\s+(.*)$/) {
                    $n = $1;
                    $name = $2;
                    $pod = 1;
                    $podfound = 1;
                    undef %format;
                    $format{-color} = $HEAD_COLOR;
                    $format{-height} = 240+(7-$n)*20;
                    $format{-bold} = 1 if $n == 1;
                    PodAddText($name, %format);
                    # $POD->SendMessage(177, -1, 0);            
                    # $POD->SetCharFormat(%format);
                    # $POD->ReplaceSel($name);
                    # print ">!> $name\n";
                    $POD->SendMessage(177, -1, 0);
                    $POD->SetCharFormat(%normal);
                }
            } else {
                if(/^$/) {
                    if($over and not $item) {
                        # undef $atext;
                        # $atext = $POD->Text();
                        # $parastart = rindex($atext, "\n", length($atext)-1)+1;
                        # $POD->SendMessage(177, $parastart, length($atext)+2);
                        # print "--- Indenting ($parastart, ", length($atext)+2, "):\n", join("\n", split(/[\r\n]+/, substr($atext, $parastart, length($atext)+2))), "\n";

                        $POD->SendMessage(177, $para, length($POD->Text));

                        undef %format;
                        $format{-offset} = 0;
                        $format{-startindent} = $over*100;
                        $POD->SetParaFormat(%format);
                    }
                    $POD->SendMessage(177, -1, 0);                
                    if(!$item) {
                        $POD->ReplaceSel("\r\n\r\n");
                    } else {
                        $POD->ReplaceSel("\r\n");
                    }
                    $POD->SendMessage(177, -1, 0);                
                    $item = 0;
                } elsif(/^=cut/) {
                    $pod = 0;
                } elsif(/^=head(\d)\s+(.*)$/) {
                    $n = $1;
                    $name = $2;
                    undef %format;
                    $format{-color} = $HEAD_COLOR;
                    $format{-height} = 240+(7-$n)*20;
                    $format{-bold} = 1 if $n == 1;
                    # $POD->SendMessage(177, -1, 0);
                    # $POD->SetCharFormat(%format);
                    # $POD->SendMessage(177, -1, 0);
                    # $POD->ReplaceSel($name);
                    PodAddText($name, %format);
                    $POD->SendMessage(177, -1, 0);
                    $POD->SetCharFormat(%normal);
                    # print ">!> $name\n";
                } elsif(/^=over\s*(\d*)/) {
                    $over = ($1 or 4);
                    #undef %format;
                    #$format{-offset} = $over*100;
                    #$format{-startindent} = $over*100;
                    #$POD->SetParaFormat(%format);
                    #print "Paraformatting ", $n*100, "\n";
                    $item = 1;
                    # print "got over=$over, item=$item\n";
                    $para = length($POD->Text);
                } elsif(/^=back/) {
                    # print "got back\n";
                    undef %format;
                    $format{-offset} = 0;
                    $format{-startindent} = 0;
                    $POD->SetParaFormat(%format);
                    $over = 0;
                    $item = 0;
                } elsif(/^=item\s*(.*)$/) {
                    $item = $1;
                    if($item) {
                        undef %format;
                        $format{-bold} = 1;
                        $pitem = PodAddText($item, %format);
                        $atext = $POD->Text();
                        $POD->SendMessage(177, length($atext)-length($pitem), length($atext)+2);
                        undef %format;
                        $format{-offset} = 0;
                        $format{-startindent} = 0;
                        $POD->SetParaFormat(%format);
                        $POD->SendMessage(177, -1, 0);
                        # $POD->SendMessage(183, 0, 0);
                        $POD->SetCharFormat(%normal);
                    }
                    $item = 1;
                } elsif(/^\s+/) {
                    undef %format;
                    $format{-name} = $FIXED_FONT_NAME;
                    $format{-height} = 200;
                    $POD->SendMessage(177, -1, 0);
                    $POD->SetCharFormat(%format);
                    $POD->ReplaceSel($_."\r\n");
                    $POD->SendMessage(177, -1, 0);
                    $POD->SetCharFormat(%normal);
                    $item = 0;
                    # $para = length($POD->Text);
                } else {
                    $atext = $POD->Text();
                    $POD->SendMessage(177, -1, 0);
                    $POD->ReplaceSel(" ") unless $atext =~ /\s$/;
                    PodAddText($_, %normal);
                    $item = 0;
                }
            }
            $Progress->SetPos(tell(FILE)*100/$size);
            $Progress->Update;
        }
        close(FILE);

        $Progress->Hide;

        $POD->SetCharFormat(%normal);
        $POD->SendMessage(177, 1, 2);
        $POD->SendMessage(177, -1, 1);
        
        # repaint the text box
        $POD->SetRedraw(1);
        $POD->InvalidateRect(1);
        #$POD->Update;
        
        $Window->Caption("Perl POD Viewer - $file");
        $PODFILE = $file;
        
        my $elapsed = Win32::GetTickCount();
        $elapsed -= $ticks;
        $Status->Text("$file loaded in " . ($elapsed/1000) . " seconds.");
    } else {
        Win32::GUI::MessageBox("Cant open file '$file'\n");
    }        
    if(not $podfound) {
        $POD->Hide;
        $NoPOD->Show;
    }
}

sub PodAddText {
    my($text, %origformat) = @_;
    my($before, $after, $podcmd, $inside);
    my %format;
    my $parsedtext = "";
    while ($text =~ /^(.*?)([BICFL])<([^>]*)>(.*)$/) {
        $before = $1;
        $podcmd = $2;
        $inside = $3;
        $after  = $4;
        # print "Adding:\n\t$before\n";
        $POD->SendMessage(177, -1, 0);
        $POD->SetCharFormat(%origformat);
        $POD->ReplaceSel($before);
        $parsedtext .= $before;
        %format = %origformat;
        $format{-bold} = 1 if $podcmd eq "B";
        $format{-italic} = 1 if $podcmd eq "I";
        if($podcmd eq "C" or $podcmd eq "F") {
            $format{-name} = $FIXED_FONT_NAME;
            # $format{-height} = 200 unless $format{-height};
            #if($format{-height}) {
            #    $format{-height} -= 40; # ???
            #} else {
            #    $format{-height} = 200;
            #}
        }
        if($podcmd eq "L") {
            $format{-color} = $L_COLOR;
            $format{-autocolor} = 0;
            $format{-underline} = 1;
        }
        $POD->SendMessage(177, -1, 0);
        $POD->SetCharFormat(%format);
        $POD->SendMessage(177, -1, 0);
        $POD->ReplaceSel($inside);
        #print "adding ($inside) with: \n";
        #foreach $k (keys(%format)) {
        #    print "\t$k=$format{$k}\n";
        #}
        
        $parsedtext .= $inside;
        # print "Adding($podcmd):\n\t$inside\n";
        $POD->SendMessage(177, -1, 0);
        $POD->SetCharFormat(%normal);
        $text = $after;
    }
    $POD->SendMessage(177, -1, 0);
    $POD->SetCharFormat(%origformat);
    $POD->ReplaceSel($text);
    $parsedtext .= $text;
    return $parsedtext;
}    

sub ReadConfig {
    my $key;
    $HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada", $key)
    or 
    $HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada", $key);
    $key->Close();
    undef $key;
    $HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada\\PodView", $key)
    or 
    $HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada\\PodView", $key);
    if($key) {
        my($val, $name);
        $key->GetValues($val);
        
        #foreach $name (keys %$val) {
        #    print "\t$name = $val->{$name}[2]\n";
        #}
        
        $L_COLOR = $val->{'L_COLOR'}[2];
        $HEAD_COLOR = $val->{'HEAD_COLOR'}[2];
        $NORMAL_FONT_NAME = $val->{'NORMAL_FONT_NAME'}[2];
        $FIXED_FONT_NAME = $val->{'FIXED_FONT_NAME'}[2];

        for $i (1..4) {
            $MRU{$i} = $val->{'MRU'.$i}[2];
            $MRU{$i} =~ s/\0//g;

            # there are still some problems with SetMenuItemInfo()

            # $MRU{$i} = "ciao mamma";
            # print "Setting MenuMRU$i to \&$i $MRU{$i}\n";
            # print "MenuMRU$i = ", $Menu->{'MenuMRU'.$i}, "\n";
            # $Menu->{'MenuMRU'.$i}->SetMenuItemInfo(-text => "\&$i ".$MRU{$i});
            # $Menu->{'MenuMRU'.$i}->SetMenuItemInfo(-text => $MRU{$i});
        }

        DefaultConfig($key);
        $key->Close();
    } else {
        DefaultConfig();
    }        
}

sub DefaultConfig {
    my($key) = @_;
    
    if(!$L_COLOR) {
        $L_COLOR = hex("FF0000");
        $key->SetValueEx("L_COLOR", 0, REG_SZ, $L_COLOR) if $key;
    }
    if(!$HEAD_COLOR) {
        $HEAD_COLOR = hex("008000");
        $key->SetValueEx("HEAD_COLOR", 0, REG_SZ, $HEAD_COLOR) if $key;
    }
    if(!$NORMAL_FONT_NAME) {
        $NORMAL_FONT_NAME = "Times New Roman";
        $key->SetValueEx("NORMAL_FONT_NAME", 0, REG_SZ, $NORMAL_FONT_NAME) if $key;
    }
    if(!$FIXED_FONT_NAME) {
        $FIXED_FONT_NAME = "Courier New";
        $key->SetValueEx("FIXED_FONT_NAME", 0, REG_SZ, $FIXED_FONT_NAME) if $key;
    }
}

sub AddToMRU {
    my($file) = @_;
    my $key;

    for $i (reverse 2..4) {
        $MRU{$i} = $MRU{$i-1};
    }
    $MRU{1} = $file;
    WriteMRU();    
}

sub WriteMRU {
    my $key;
    my $U;
    $HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada", $key)
    or 
    $HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada", $key);
    $key->Close();
    undef $key;
    $HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada\\PodView", $key)
    or 
    $HKEY_LOCAL_MACHINE->Create("SOFTWARE\\dada\\PodView", $key);
    if($key) {
        foreach $U (keys %MRU) {
            $key->SetValueEx("MRU$U", 0, REG_SZ, $MRU{$U});
        }
        $key->Close();
    }        
}
    

######################################################################
# EVENTS :-)
#

sub Window_Resize {
    ($width, $height) = ($Window->GetClientRect)[2..3];
    $POD->Move(0, 0);
    $POD->Resize($width, $height-$Status->Height);
    $Status->Resize($width, $height);
    $Progress->Move($Status->Width-150, 2);
    $NoPOD->Move($width/2-$NoPOD->Width/2, $height/2-$NoPOD->Height/2);
}

sub Window_Terminate {
    WriteMRU();
    return -1;
}

sub MenuExit_Click {
    WriteMRU();
    return -1;
}

sub MenuSave_Click {
    if($PODFILE) {
        $POD->Save($PODFILE.".rtf");
    }
}

sub MenuReload_Click {
    LoadPod();
}

sub MenuOpen_Click {
    my $file = GUI::GetOpenFileName();
    if($DEBUG) {
        print "GetOpenFileName returned $ret\n";
        print "CommDlgExtendedError is ", GUI::CommDlgExtendedError(), "\n";
        print "LastError is ", Win32::GetLastError(), "\n";
    }
    if($file) {
        LoadPod($file);
        AddToMRU($file);
    }
}

sub MenuHeadColor_Click {
    my $c = GUI::ChooseColor(-color => $HEAD_COLOR);
    $HEAD_COLOR = $c if $c;
}

sub MenuLinkColor_Click {
    my $c = GUI::ChooseColor(-color => $L_COLOR);
    $L_COLOR = $c if $c;
}

sub MenuNormalFont_Click {
    my @f = GUI::ChooseFont(-name => $NORMAL_FONT_NAME, -noscript => 1);
    if($f[0]) {
        my %f = @f;
        $NORMAL_FONT_NAME = $f{-name};
    }
}

sub MenuFixedFont_Click {
    my @f = GUI::ChooseFont(-name => $FIXED_FONT_NAME, -noscript => 1, -fixedonly => 1);
    if($f[0]) {
        my %f = @f;
        $FIXED_FONT_NAME = $f{-name};
    }
}

sub MenuSaveConfig_Click {
    my $key;
    $HKEY_LOCAL_MACHINE->Open("SOFTWARE\\dada\\PodView", $key);
    if($key) {
        $key->SetValueEx("L_COLOR", 0, REG_SZ, $L_COLOR);
        $key->SetValueEx("HEAD_COLOR", 0, REG_SZ, $HEAD_COLOR);
        $key->SetValueEx("NORMAL_FONT_NAME", 0, REG_SZ, $NORMAL_FONT_NAME);
        $key->SetValueEx("FIXED_FONT_NAME", 0, REG_SZ, $FIXED_FONT_NAME);
        $key->Close();
    } else {
        Win32::GUI::MessageBox("ERROR: Unable to save config...");
    }
}

#===============================================================================
# still testing this...

$IBEAM = 32513;
$ARROW = 32512;

sub POD_MouseMove {
    # print "Got POD_MouseMove\n";
    my($shifts, $x, $y) = @_;
    my $Cursor;
    ($ci, $li) = $POD->CharFromPos($x, $y);
    if($ci) {
        # 11 == WM_SETREDRAW
        $POD->SendMessage(11, 0, 0);
        $POD->Disable();
        my($ss, $se) = $POD->Selection();
        $POD->Select($ci, $ci);
        my %format = $POD->GetCharFormat();
        $Cursor = ($se <= $ci and $ci >= $ss) ? $ARROW : $IBEAM;
        $POD->Select($ss, $se);
        $POD->SendMessage(11, 1, 0);
        $POD->Enable();
        $POD->InvalidateRect(0);
        if($format{-color} == $L_COLOR) {
            GUI::SetCursor($HAND); # if GUI::GetCursor() != $HAND;
        } else {
            GUI::SetCursor($Cursor);
        }
    #} else {
    #    GUI::SetCursor(32513);
    }
    while ($POD->PeekMessage(512, 512)) {
        $POD->GetMessage();
    }
    return 1;

}


sub POD_LButtonDown {
    my($shifts, $x, $y) = @_;
    my $ci;
    my $li;
    ($ci, $li) = $POD->CharFromPos($x, $y);
    if($ci) {
        $POD->Select($ci, $ci) if $ci;
        my %format = $POD->GetCharFormat();
        if($format{-color} == $L_COLOR) {
            $Status->Text("that's a link");
        } elsif($format{-color} == $HEAD_COLOR) {
            $Status->Text("YUPPI! it's a head!");
        } else {
            $Status->Text("nopi, it's text.");
        }
    } else {
        $Status->Text("nothing selected.");
    }
    return 1;

}
#===============================================================================

sub MenuMRU1_Click {
    LoadPod($MRU{1}) if $MRU{1};
}

sub MenuMRU2_Click {
    LoadPod($MRU{2}) if $MRU{2};
}

sub MenuMRU3_Click {
    LoadPod($MRU{3}) if $MRU{3};
}

sub MenuMRU4_Click {
    LoadPod($MRU{4}) if $MRU{4};
}

######################################################################
# POD - also "About PodView..." :-)
#

=head1 NAME

PodView - Plain Old Documentation Viewer

=head1 SYNOPSIS

    perl podview.pl [filename]

=head1 DESCRIPTION

This was done to test the Win32::GUI module.

=head1 AUTHOR

Aldo Calpini ( I<dada@divinf.it> )

=cut


