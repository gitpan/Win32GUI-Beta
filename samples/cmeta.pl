
use Win32::GUI;

$W = new GUI::Window(
    -left => 100,
    -top => 100,
    -width => 400,
    -height => 400,
    -title => "EMF Creator",
    -name => "Window",
);

$W->Show();

$W->BeginPaint();

$DC = $W->CreateEnhMetaFile("prova.emf");
print "CreateEnhMetaFile returned $DC\n";

$ORIGDC = $W->{'DC'};
$W->{'DC'} = $DC;

Draw();

# sleep(1);

$META = Win32::GUI::CloseEnhMetaFile($DC);
print "CloseEnhMetaFile returned $META\n";

$rc = Win32::GUI::DeleteEnhMetaFile($META);
print "DeleteEnhMetaFile returned $rc\n";

$W->{'DC'} = $ORIGDC;

Draw();

$W->EndPaint();


Win32::GUI::Dialog();

sub Window_Terminate {
    return -1;
}

sub Window_Resize {
    
    $W->BeginPaint();

    $DC = $W->CreateEnhMetaFile("prova.emf");
    print "CreateEnhMetaFile returned $DC\n";

    $ORIGDC = $W->{'DC'};
    $W->{'DC'} = $DC;

    Draw();

    $META = Win32::GUI::CloseEnhMetaFile($DC);
    print "CloseEnhMetaFile returned $META\n";

    $rc = Win32::GUI::DeleteEnhMetaFile($META);
    print "DeleteEnhMetaFile returned $rc\n";

    $W->{'DC'} = $ORIGDC;

    Draw();

    $W->EndPaint();
}

sub Draw {
    $X = $W->ScaleWidth;
    $Y = $W->ScaleHeight;
    $r = 0;
    $g = 0;
    $b = 0;
    if($X > 500) {
        $W->MoveTo(0, $Y/2);
        $W->LineTo($X, $Y/2);
        $r = 255;
    }
    if($Y > 500) {
        $W->MoveTo(X/2, 0);
        $W->LineTo($X/2, $Y);
        $g = 255;
    }
  
    $W->LineTo(0, 0);
    $W->LineTo($X, $Y);
    $W->LineTo($X, 0);
    $W->LineTo(0, $Y);
    $W->Circle(0, 0, $X, $Y);
    $W->SetTextColor($r, $g, $b);
    $W->SetBkMode(1);
    ($TW, $TH) = $W->GetTextExtentPoint32("$X x $Y");
    $W->TextOut($X/2-$TW/2, $Y/2-$TH/2, "$X x $Y");
}