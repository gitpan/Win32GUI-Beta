

use Win32::GUI;

$file = "\0" . " " x 256;

$ret = GUI::GetOpenFileName(-title => "Testing...",
                            -file => "\0" . " " x 256);

if($ret) {
    print "GetOpenFileName returned: '$ret'\n";
} else {
    if(GUI::CommDlgExtendedError()) {
        print "ERROR. CommDlgExtendedError is: ", GUI::CommDlgExtendedError(), "\n";    
    } else {
        print "You cancelled.\n";
    }
}