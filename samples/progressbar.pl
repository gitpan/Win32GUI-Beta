
use Win32::GUI;
use Win32::Sound;

$W = new GUI::Window(
    -title    => "Win32::GUI TEST - Progess Bar",
    -left     => 100, 
    -top      => 100, 
    -width    => 400, 
    -height   => 150,
    -font     => $F,
    -function => "main::WindowProc",
    -name     => "Window",
) or print_and_die("new Window");

$tX = 5;
$MIN_L = $W->AddLabel(-text => "Min.:", -left => $tX, -top => 5);
$tX += $MIN_L->Width + 10;
$sX1 = $tX;
$MIN = $W->AddTextfield(-left => $tX, -top => 5, -width => 80, -height => 20, -text => "0");
$tX += $MIN->Width + 10;
$sX2 = $tX;
$MAX_L = $W->AddLabel(-text => "Max.:", -left => $tX, -top => 5);
$tX += $MAX_L->Width + 10;
$sX3 = $tX;
$MAX = $W->AddTextfield(-left => $tX, -top => 5, -width => 80, -height => 20, -text => "100");
$tX += $MAX->Width + 10;
$sX4 = $tX;
$SET = $W->AddButton(-text => "Set", -left => $tX, -top => 5, -name => "SetRange");

$tY = 5 + $MAX->Height * 2;
$tX = 5;
$ACT_L = $W->AddLabel(-text => "Actual:", -left => $tX, -top => $tY);
$tX = $sX1;
$ACT = $W->AddTextfield(-text => "10", -left => $tX, -top => $tY, - width => 80, -height => 20);
$tX = $sX2;
$INC_L = $W->AddLabel(-text => "Inc.:", -left => $tX, -top => $tY);
$tX = $sX3;
$INC = $W->AddTextfield(-text => "10", -left => $tX, -top => $tY, - width => 80, -height => 20);
$tX = $sX4;
$POS = $W->AddButton(-text => "Pos", -left => $tX, -top => $tY, -name => "SetPosition");
$tX += $POS->Width + 10;
$UP = $W->AddButton(-text => "+", -left => $tX, -top => $tY, -name => "ProgressUp");
$tX += $UP->Width + 10;
$DN = $W->AddButton(-text => "-", -left => $tX, -top => $tY, -name => "ProgressDown");

$tX += $DN->Width + 10;

$W->Resize($tX, $W->Height);

$tY = 5 + $MAX->Height * 2 + $ACT->Height * 2;
$tW = $W->Width / 2;
$PB = new Win32::GUI::ProgressBar($W, -left => ($W->Width - $tW) / 2, -top => $tY, 
                                      -width => $tW, -height => 20,
                                 ) or print_and_die("new ProgressBar");
                                 
$PB->SetPos(10);

#window_resize();

$W->Show;

$return = $W->Dialog();
print "Dialog: $return\n";

sub SetPosition_Click {
    $PB->SetStep($INC->Text);
    $PB->SetPos($ACT->Text);
}

sub ProgressUp_Click {
    Win32::Sound::Play("SystemDefault", SND_ASYNC), return 1 if $ACT->Text == $MAX->Text;
    my $pos = $PB->SetPos(0);
    $PB->SetPos($pos);
    my $new = $pos + $INC->Text;
    $new = $MAX->Text if $new > $MAX->Text;
    $PB->SetPos($new);
    $ACT->Text($new);
}

sub ProgressDown_Click {
    Win32::Sound::Play("SystemDefault", SND_ASYNC), return 1 if $ACT->Text == $MIN->Text;
    my $inc = $INC->Text;
    my $pos = $PB->SetPos(0);
    $PB->SetPos($pos);
    my $new = $pos - $INC->Text;
    $new = $MIN->Text if $new < $MIN->Text;
    $PB->SetPos($new);
    $ACT->Text($new);
}


sub SetRange_Click {
    $PB->SetRange($MIN->Text, $MAX->Text);
}

sub print_and_die {
    my($text) = @_;
    my $err = Win32::GetLastError();
    die "$text: Error $err\n";
}

sub Window_Resize {
    if($PB) {
        my $tW = $W->ScaleWidth / 2;
        my $tY = ($MAX->Height * 2) + ($ACT->Height * 2) + 5;
        $PB->Move(($W->ScaleWidth-$tW)/2, $tY);
        $PB->Resize($tW, $W->ScaleHeight-$tY-20);
    }    
}

sub millisleep {
    my ($ms) = @_;
    my $ctick = Win32::GetTickCount;
    my $etick = $ctick + $ms;
    while ($ctick < $etick) { $ctick = Win32::GetTickCount; }
}