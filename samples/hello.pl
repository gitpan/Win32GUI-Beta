#!perl -w
#
# Simple Win32::GUI script to create a button that prints "Hello, world".  
# Click on the button to terminate the program.
# 
# (rewritten from Tk's demos/hello)

use Win32::GUI;
$MW = new Win32::GUI::Window(
    -title   => 'hello.pl',
    -left    => 100,
    -top     => 100,
    -width   => 150,
    -height  => 100,
    -name    => 'MainWindow',
    -visible => 1,
);
$hello = $MW->AddButton(
    -text    => 'Hello, world', 
    -name    => 'Hello',
    -left    => 25,
    -top     => 25,
);

Win32::GUI::Dialog();

sub MainWindow_Terminate {
    $MW->PostQuitMessage(1);
}

sub Hello_Click {
    print STDOUT "Hello, world\n"; 
    $MW->PostQuitMessage(0);
}
