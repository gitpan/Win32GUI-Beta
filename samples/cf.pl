

use Win32::GUI;

@ret = GUI::ChooseFont(-name => "Courier New", 
                       -height => 140, 
                       -size => 180,
                       -italic => 1,
                       -ttonly => 1,
                       -fixedonly => 1,
                       -script => 0,
                       -effects => 1,
                       );

if($#ret > 0) {
    print "ChooseFont returned:\n";
    %ret = @ret;
    foreach $key (keys(%ret)) {
        print "\t$key=$ret{$key}\n";
    }
} else {
    if(GUI::CommDlgExtendedError()) {
        print "ERROR. CommDlgExtendedError is: ", GUI::CommDlgExtendedError(), "\n";    
    } else {
        print "You cancelled.\n";
    }
}