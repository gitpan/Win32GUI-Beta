#######################################################################
#
# Win32::GUI - Perl-Win32 Graphical User Interface Extension
# ^^^^^^^^^^
# 29 Jan 97 by Aldo Calpini <dada@divinf.it>
#
# Version: Beta (28 May 1998)
#
#######################################################################

package Win32::GUI;

require Exporter;       # to export the constants to the main:: space
require DynaLoader;     # to dynuhlode the module.

# Reserves GUI in the main namespace for us (uhmmm...)
*GUI:: = \%Win32::GUI::;

#######################################################################
# STATIC OBJECT PROPERTIES
#
$VERSION = "Beta";
%callbacks = ();
%menucallbacks = ();
$MenuIdCounter = 1;

@MyPackages = qw(
    Win32::GUI::Button
    Win32::GUI::Checkbox
    Win32::GUI::Combobox
    Win32::GUI::Label
    Win32::GUI::ListView
    Win32::GUI::Listbox
    Win32::GUI::ProgressBar
    Win32::GUI::RadioButton
    Win32::GUI::RichEdit
    Win32::GUI::StatusBar
    Win32::GUI::TabStrip
    Win32::GUI::Textfield
    Win32::GUI::Toolbar

    Win32::GUI::Window
    Win32::GUI::DialogBox

    Win32::GUI::Bitmap
    Win32::GUI::Class
    Win32::GUI::Font
    Win32::GUI::Icon
    Win32::GUI::Menu
    Win32::GUI::MenuButton
    Win32::GUI::MenuItem    
);

@ISA = qw( Exporter DynaLoader );
@EXPORT = qw(
    BS_3STATE
    BS_AUTO3STATE
    BS_AUTOCHECKBOX
    BS_AUTORADIOBUTTON
    BS_CHECKBOX
    BS_DEFPUSHBUTTON
    BS_GROUPBOX
    BS_LEFTTEXT
    BS_NOTIFY
    BS_OWNERDRAW
    BS_PUSHBUTTON
    BS_RADIOBUTTON
    BS_USERBUTTON
    BS_BITMAP
    BS_BOTTOM
    BS_CENTER
    BS_ICON
    BS_LEFT
    BS_MULTILINE
    BS_RIGHT
    BS_RIGHTBUTTON
    BS_TEXT
    BS_TOP
    BS_VCENTER

    COLOR_3DFACE
    COLOR_ACTIVEBORDER
    COLOR_ACTIVECAPTION
    COLOR_APPWORKSPACE
    COLOR_BACKGROUND
    COLOR_BTNFACE
    COLOR_BTNSHADOW
    COLOR_BTNTEXT
    COLOR_CAPTIONTEXT
    COLOR_GRAYTEXT
    COLOR_HIGHLIGHT
    COLOR_HIGHLIGHTTEXT
    COLOR_INACTIVEBORDER
    COLOR_INACTIVECAPTION
    COLOR_MENU
    COLOR_MENUTEXT
    COLOR_SCROLLBAR
    COLOR_WINDOW
    COLOR_WINDOWFRAME
    COLOR_WINDOWTEXT 

    DS_3DLOOK 
    DS_ABSALIGN 
    DS_CENTER 
    DS_CENTERMOUSE 
    DS_CONTEXTHELP 
    DS_CONTROL 
    DS_FIXEDSYS 
    DS_LOCALEDIT 
    DS_MODALFRAME 
    DS_NOFAILCREATE 
    DS_NOIDLEMSG 
    DS_RECURSE 
    DS_SETFONT 
    DS_SETFOREGROUND 
    DS_SYSMODAL 

    ES_AUTOHSCROLL
    ES_AUTOVSCROLL
    ES_CENTER
    ES_LEFT
    ES_LOWERCASE
    ES_MULTILINE
    ES_NOHIDESEL
    ES_NUMBER
    ES_OEMCONVERT
    ES_PASSWORD
    ES_READONLY
    ES_RIGHT
    ES_UPPERCASE
    ES_WANTRETURN

    GW_CHILD
    GW_HWNDFIRST
    GW_HWNDLAST
    GW_HWNDNEXT
    GW_HWNDPREV
    GW_OWNER

    IMAGE_BITMAP 
    IMAGE_CURSOR 
    IMAGE_ICON 

    LR_DEFAULTCOLOR
    LR_MONOCHROME
    LR_COLOR
    LR_COPYRETURNORG
    LR_COPYDELETEORG
    LR_LOADFROMFILE
    LR_LOADTRANSPARENT
    LR_DEFAULTSIZE
    LR_LOADMAP3DCOLORS
    LR_CREATEDIBSECTION
    LR_COPYFROMRESOURCE
    LR_SHARED

    MB_ABORTRETRYIGNORE
    MB_OK
    MB_OKCANCEL
    MB_RETRYCANCEL
    MB_YESNO
    MB_YESNOCANCEL
    MB_ICONEXCLAMATION
    MB_ICONWARNING
    MB_ICONINFORMATION
    MB_ICONASTERISK
    MB_ICONQUESTION
    MB_ICONSTOP
    MB_ICONERROR
    MB_ICONHAND
    MB_DEFBUTTON1
    MB_DEFBUTTON2
    MB_DEFBUTTON3
    MB_DEFBUTTON4
    MB_APPLMODAL
    MB_SYSTEMMODAL
    MB_TASKMODAL
    MB_DEFAULT_DESKTOP_ONLY
    MB_HELP
    MB_RIGHT
    MB_RTLREADING
    MB_SETFOREGROUND
    MB_TOPMOST
    MB_SERVICE_NOTIFICATION
    MB_SERVICE_NOTIFICATION_NT3X

    MF_STRING
    MF_POPUP

    SM_ARRANGE 
    SM_CLEANBOOT 
    SM_CMOUSEBUTTONS 
    SM_CXBORDER 
    SM_CYBORDER 
    SM_CXCURSOR
    SM_CYCURSOR 
    SM_CXDLGFRAME
    SM_CYDLGFRAME 
    SM_CXDOUBLECLK
    SM_CYDOUBLECLK 
    SM_CXDRAG
    SM_CYDRAG 
    SM_CXEDGE
    SM_CYEDGE 
    SM_CXFIXEDFRAME
    SM_CYFIXEDFRAME 
    SM_CXFRAME
    SM_CYFRAME 
    SM_CXFULLSCREEN
    SM_CYFULLSCREEN 
    SM_CXHSCROLL
    SM_CYHSCROLL 
    SM_CXHTHUMB 
    SM_CXICON
    SM_CYICON 
    SM_CXICONSPACING
    SM_CYICONSPACING 
    SM_CXMAXIMIZED
    SM_CYMAXIMIZED 
    SM_CXMAXTRACK
    SM_CYMAXTRACK 
    SM_CXMENUCHECK
    SM_CYMENUCHECK 
    SM_CXMENUSIZE
    SM_CYMENUSIZE 
    SM_CXMIN
    SM_CYMIN 
    SM_CXMINIMIZED
    SM_CYMINIMIZED 
    SM_CXMINSPACING
    SM_CYMINSPACING 
    SM_CXMINTRACK
    SM_CYMINTRACK 
    SM_CXSCREEN
    SM_CYSCREEN 
    SM_CXSIZE
    SM_CYSIZE 
    SM_CXSIZEFRAME
    SM_CYSIZEFRAME 
    SM_CXSMICON
    SM_CYSMICON 
    SM_CXSMSIZE
    SM_CYSMSIZE 
    SM_CXVSCROLL
    SM_CYVSCROLL 
    SM_CYCAPTION 
    SM_CYKANJIWINDOW 
    SM_CYMENU 
    SM_CYSMCAPTION 
    SM_CYVTHUMB 
    SM_DBCSENABLED 
    SM_DEBUG 
    SM_MENUDROPALIGNMENT 
    SM_MIDEASTENABLED 
    SM_MOUSEPRESENT 
    SM_MOUSEWHEELPRESENT 
    SM_NETWORK 
    SM_PENWINDOWS 
    SM_SECURE 
    SM_SHOWSOUNDS 
    SM_SLOWMACHINE 
    SM_SWAPBUTTON

    WM_CREATE
    WM_DESTROY
    WM_MOVE
    WM_SIZE
    WM_ACTIVATE
    WM_SETFOCUS
    WM_KILLFOCUS
    WM_ENABLE
    WM_SETREDRAW
    WM_COMMAND
    WM_KEYDOWN
    WM_SETCURSOR
    WM_KEYUP

    WS_BORDER
    WS_CAPTION
    WS_CHILD
    WS_CHILDWINDOW
    WS_CLIPCHILDREN
    WS_CLIPSIBLINGS
    WS_DISABLED
    WS_DLGFRAME
    WS_GROUP
    WS_HSCROLL
    WS_ICONIC
    WS_MAXIMIZE
    WS_MAXIMIZEBOX
    WS_MINIMIZE
    WS_MINIMIZEBOX
    WS_OVERLAPPED
    WS_OVERLAPPEDWINDOW
    WS_POPUP
    WS_POPUPWINDOW
    WS_SIZEBOX
    WS_SYSMENU
    WS_TABSTOP
    WS_THICKFRAME
    WS_TILED
    WS_TILEDWINDOW
    WS_VISIBLE
    WS_VSCROLL

    WS_EX_ACCEPTFILES
    WS_EX_APPWINDOW
    WS_EX_CLIENTEDGE
    WS_EX_CONTEXTHELP
    WS_EX_CONTROLPARENT
    WS_EX_DLGMODALFRAME
    WS_EX_LEFT
    WS_EX_LEFTSCROLLBAR
    WS_EX_LTRREADING
    WS_EX_MDICHILD
    WS_EX_NOPARENTNOTIFY
    WS_EX_OVERLAPPEDWINDOW
    WS_EX_PALETTEWINDOW
    WS_EX_RIGHT
    WS_EX_RIGHTSCROLLBAR
    WS_EX_RTLREADING
    WS_EX_STATICEDGE
    WS_EX_TOOLWINDOW
    WS_EX_TOPMOST
    WS_EX_TRANSPARENT
    WS_EX_WINDOWEDGE
);

#######################################################################
# This AUTOLOAD is used to 'autoload' constants from the constant()
# XS function.  If a constant is not found then control is passed
# to the AUTOLOAD in AutoLoader.
#

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    $!=0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
    #if ($! =~ /Invalid/) {
    #    $AutoLoader::AUTOLOAD = $AUTOLOAD;
    #    goto &AutoLoader::AUTOLOAD;
    #} else {
        ($pack,$file,$line) = caller; # undef $pack;
        die "Your vendor has not defined Win32::GUI macro $pack::$constname, used at $file line $line.";
    #}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

#######################################################################
# PUBLIC METHODS
#

sub Version {
    return $VERSION;
}

sub SetFont {
    my($self, $font) = @_; 
    $self = $self->{handle} if ref($self);
    $font = $font->{handle} if ref($font);
    # 48 == WM_SETFONT
    return Win32::GUI::SendMessage($self, 48, $font, 0);
}

sub GetFont {
    my($self) = shift; 
    $self = $self->{handle} if ref($handle);
    # 49 == WM_GETFONT
    return Win32::GUI::SendMessage($self, 49, 0, 0);
}

sub SetIcon {
    my($self, $icon) = @_; 
    $self = $self->{handle} if ref($self);
    $icon = $icon->{handle} if ref($icon);
    # 128 == WM_SETICON
    return Win32::GUI::SendMessage($self, 128, $icon, 0);
}

sub SetRedraw {
    my($self, $value) = @_; 
    $self = $self->{handle} if ref($self);
    # 11 == WM_SETREDRAW
    my $r = Win32::GUI::SendMessage($self, 11, $value, 0);
    return $r;
}

sub MakeMenu {
    my(@menudata) = @_;
    my $i;
    my $M = new Win32::GUI::Menu();
    my $text;
    my %data;
    my $level;
    my %last;
    my $parent;
    for($i = 0; $i <= $#menudata; $i+=2) {
        $text = $menudata[$i];
        undef %data;
        if(ref($menudata[$i+1])) {
            %data = %{$menudata[$i+1]};
        } else {
            $data{-name} = $menudata[$i+1];
        }
        $level = 0;
        $level++ while($text =~ s/^\s*>\s*//);

        if($level == 0) {            
            # ${"main::".$data{-name}} = $M->AddMenuButton(
            # print "M->$data{-name} = M->AddMenuButton();\n";
            $M->{$data{-name}} = $M->AddMenuButton(            
                -id => $MenuIdCounter++,
                -text => $text,
                %data,
            );
            # print "M->$data{-name} = ".$M->{$data{-name}}."\n";
            $last{$level} = $data{-name};
            $last{$level+1} = "";
        } elsif($level == 1) {
            $parent = $last{$level-1};
            # ${"main::".$data{-name}} = $lastname->AddMenuItem(
            # print "M->$data{-name} = M->${parent}->AddMenuItem(".($MenuIdCounter+1).");\n";
            if($text eq "-") {
                $data{-name} = "dummy$MenuIdCounter";
                $M->{$data{-name}} = $M->{$parent}->AddMenuItem(
                    -item => 0,
                    -id => $MenuIdCounter++,
                    -separator => 1,
                );
            } else {
                $M->{$data{-name}} = $M->{$parent}->AddMenuItem(
                    -item => 0,
                    -id => $MenuIdCounter++,
                    -text => $text,
                    %data,
                );
            }
            # print "M->$data{-name} = ".$M->{$data{-name}}."\n";
            $last{$level} = $data{-name};
            $last{$level+1} = "";
        } else {
            $parent = $last{$level-1};
            if(!$M->{$parent."_Submenu"}) {
                $M->{$parent."_Submenu"} = new GUI::Menu();
                # print "M->${parent}_Submenu = ".$M->{$parent."_Submenu"}."\n";
                $M->{$parent."_SubmenuButton"} = $M->{$parent."_Submenu"}->AddMenuButton(
                    -id => $MenuIdCounter++,
                    -text => $parent,
                    -name => $parent."_SubmenuButton",
                );
                # print "M->${parent}_SubmenuButton = ".$M->{$parent."_SubmenuButton"}."\n";
                $M->{$parent}->SetMenuItemInfo(-submenu => $M->{$parent."_SubmenuButton"});
                # print "M->${parent}->SetMenuItemInfo(-submenu => M->${parent}_SubmenuButton);\n";
            }
            # print "M->$data{-name} = M->${parent}_SubmenuButton->AddMenuItem(".($MenuIdCounter+1).");\n";
            if($text eq "-") {
                $data{-name} = "dummy$MenuIdCounter";
                $M->{$data{-name}} = $M->{$parent."_SubmenuButton"}->AddMenuItem(
                    -item => 0,
                    -id => $MenuIdCounter++,
                    -separator => 1,
                );
            } else {
                $M->{$data{-name}} = $M->{$parent."_SubmenuButton"}->AddMenuItem(
                    -item => 0,
                    -id => $MenuIdCounter++,
                    -text => $text,
                    %data,
                );
            }
            $last{$level} = $data{-name};
            $last{$level+1} = "";
        }
    }
    return $M;
}



# This is the generalized constructor.
# It works pretty well for almost all controls.
# However, other kind of objects may overload it.
sub _new {
    # this is always Win32::GUI (class of _new);
    my $xclass = shift;

    # the window type passed by new():
    my $type = shift;

    # this is the real class:
    my $class = shift;
    my $self = {};
    bless($self, $class);

    my (@input) = @_;

    my $handle = Win32::GUI::Create($self, $type, @input);
    if($handle) {
        $Win32::GUI::Windows{$handle} = $self;
        return $self;
    } else {
        return undef;
    }
}

#######################################################################
# SUB-PACKAGES 
#


#######################################################################
# PACKAGE: Font
#
package Win32::GUI::Font;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    my $self = {};

    my $handle = Create(@_);
    
    if($handle) {
        $self->{'handle'} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

#######################################################################
# PACKAGE: Bitmap
#
package Win32::GUI::Bitmap;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    my $self = {};

    my $handle = Win32::GUI::LoadImage(@_);
                                    
    if($handle) {
        $self->{'handle'} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

#######################################################################
# PACKAGE: Icon
#
package Win32::GUI::Icon;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    my $file = shift;
    my $self = {};

    my $handle = Win32::GUI::LoadImage($file, Win32::GUI::constant("IMAGE_ICON", 0));

    if($handle) {
        $self->{'handle'} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

#######################################################################
# PACKAGE: Class 
#
package Win32::GUI::Class;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    my %args = @_;
    my $self = {};

    $args{-color} = Win32::GUI::constant("COLOR_WINDOW", 0) 
                  unless exists($args{-color});    

    my $handle = Win32::GUI::RegisterClassEx(%args);
   
    if($handle) {
        $self->{'name'}   = $args{-name};
        $self->{'handle'} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

#######################################################################
# PACKAGE: Window 
#
package Win32::GUI::Window;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__WINDOW", 0), @_);
}

sub AddButton      { return Win32::GUI::Button->new(@_); }
sub AddLabel       { return Win32::GUI::Label->new(@_); }
sub AddCheckbox    { return Win32::GUI::Checkbox->new(@_); }
sub AddRadioButton { return Win32::GUI::RadioButton->new(@_); }
sub AddTextfield   { return Win32::GUI::Textfield->new(@_); }
sub AddListbox     { return Win32::GUI::Listbox->new(@_); }
sub AddCombobox    { return Win32::GUI::Combobox->new(@_); }
sub AddStatusBar   { return Win32::GUI::StatusBar->new(@_); }
sub AddProgressBar { return Win32::GUI::ProgressBar->new(@_); }
sub AddTabStrip    { return Win32::GUI::TabStrip->new(@_); }
sub AddToolbar     { return Win32::GUI::Toolbar->new(@_); }
sub AddListView    { return Win32::GUI::ListView->new(@_); }
sub AddTreeView    { return Win32::GUI::TreeView->new(@_); }
sub AddRichEdit    { return Win32::GUI::RichEdit->new(@_); }

sub AddMenu {
    my $self = shift;
    $self = $self->{handle} if ref($self);
    my $menu = Win32::GUI::Menu->new();
    my $r = Win32::GUI::SetMenu($self, $menu->{'handle'});
    # print "SetMenu=$r\n";
    return $menu;
}

#######################################################################
# PACKAGE: DialogBox
#
package Win32::GUI::DialogBox;
@ISA = qw(Win32::GUI::Window);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__DIALOG", 0), @_);
}

sub AddButton      { return Win32::GUI::Button->new(@_); }
sub AddLabel       { return Win32::GUI::Label->new(@_); }
sub AddCheckbox    { return Win32::GUI::Checkbox->new(@_); }
sub AddRadioButton { return Win32::GUI::RadioButton->new(@_); }
sub AddTextfield   { return Win32::GUI::Textfield->new(@_); }
sub AddListbox     { return Win32::GUI::Listbox->new(@_); }
sub AddCombobox    { return Win32::GUI::Combobox->new(@_); }
sub AddStatusBar   { return Win32::GUI::StatusBar->new(@_); }
sub AddProgressBar { return Win32::GUI::ProgressBar->new(@_); }
sub AddTabStrip    { return Win32::GUI::TabStrip->new(@_); }
sub AddToolbar     { return Win32::GUI::Toolbar->new(@_); }
sub AddListView    { return Win32::GUI::ListView->new(@_); }
sub AddTreeView    { return Win32::GUI::TreeView->new(@_); }
sub AddRichEdit    { return Win32::GUI::RichEdit->new(@_); }

sub AddMenu {
    my $self = shift;
    $self = $self->{handle} if ref($self);
    my $menu = Win32::GUI::Menu->new();
    my $r = Win32::GUI::SetMenu($self, $menu->{'handle'});
    return $menu;
}

#######################################################################
# PACKAGE: Button 
#
package Win32::GUI::Button;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__BUTTON", 0), @_);
}


#######################################################################
# PACKAGE: RadioButton 
#
package Win32::GUI::RadioButton;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__RADIOBUTTON", 0), @_);
}

sub Checked {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $check = shift;
    if(defined($check)) {
        # 241 == BM_SETCHECK
        return Win32::GUI::SendMessage($self, 241, $check, 0);
    } else {    
        # 240 == BM_GETCHECK
        return Win32::GUI::SendMessage($self, 240, 0, 0);
    }
}

#######################################################################
# PACKAGE: Checkbox 
#
package Win32::GUI::Checkbox;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__CHECKBOX", 0), @_);
}

sub GetCheck {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 240 == BM_GETCHECK
    return Win32::GUI::SendMessage($self, 240, 0, 0);
}

sub SetCheck {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $check = shift;
    $check = 1 unless defined($check);
    # 241 == BM_SETCHECK
    return Win32::GUI::SendMessage($self, 241, $check, 0);
}

sub Checked {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $check = shift;
    if(defined($check)) {
        # 241 == BM_SETCHECK
        return Win32::GUI::SendMessage($self, 241, $check, 0);
    } else {    
        # 240 == BM_GETCHECK
        return Win32::GUI::SendMessage($self, 240, 0, 0);
    }
}

#######################################################################
# PACKAGE: Label 
#
package Win32::GUI::Label;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__STATIC", 0), @_);
}

sub SetImage {
    my $self = shift;
    my $image = shift;
    $self = $self->{'handle'} if ref($self);
    $image = $image->{'handle'} if ref($image);
    my $type = Win32::GUI::constant("IMAGE_BITMAP", 0);
    # 370 == STM_SETIMAGE
    return Win32::GUI::SendMessage($self, 370, $type, $image);
}


#######################################################################
# PACKAGE: Textfield 
#
package Win32::GUI::Textfield;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__EDIT", 0), @_);
}

sub Select {
    my($self, $wparam, $lparam) = @_;
    $self = $self->{'handle'} if ref($self);
    # 177 == EM_SETSEL
    return Win32::GUI::SendMessage($self, 177, $wparam, $lparam);
}

#######################################################################
# PACKAGE: Listbox 
#
package Win32::GUI::Listbox;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__LISTBOX", 0), @_);
}

sub SelectedItem {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 392 == LB_GETCURSEL
    return Win32::GUI::SendMessage($self, 392, 0, 0);
}
sub ListIndex { SelectedItem(@_); }

sub Select {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $item = shift;
    # 390 == LB_SETCURSEL
    my $r = Win32::GUI::SendMessage($self, 390, $item, 0);
    return $r;
}

sub Reset {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 388 == LB_RESETCONTENT
    my $r = Win32::GUI::SendMessage($self, 388, 0, 0);
    return $r;
}
sub Clear { Reset(@_); }

sub RemoveItem {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $item = shift;
    # 386 == LB_DELETESTRING
    my $r = Win32::GUI::SendMessage($self, 386, $item, 0);
    return $r;
}

sub Count {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 395 == LB_GETCOUNT
    my $r = Win32::GUI::SendMessage($self, 395, 0, 0);
    return $r;
}

sub ItemHeight {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $item = shift or 0;
    # 417 == LB_GETITEMHEIGHT
    my $r = Win32::GUI::SendMessage($self, 417, $item, 0);
    return $r;
}

#######################################################################
# PACKAGE: Combobox
#
package Win32::GUI::Combobox;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__COMBOBOX", 0), @_);
}

sub SelectedItem {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 327 == CB_GETCURSEL
    return Win32::GUI::SendMessage($self, 327, 0, 0);
}
sub ListIndex { SelectedItem(@_); }


sub Select {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $item = shift;
    # 334 == CB_SETCURSEL
    my $r = Win32::GUI::SendMessage($self, 334, $item, 0);
    return $r;
}

sub Reset {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 331 == CB_RESETCONTENT
    my $r = Win32::GUI::SendMessage($self, 331, 0, 0);
    return $r;
}
sub Clear { Reset(@_); }

sub RemoveItem {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $item = shift;
    # 324 == CB_DELETESTRING
    my $r = Win32::GUI::SendMessage($self, 324, $item, 0);
    return $r;
}

sub Count {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 326 == CB_GETCOUNT
    my $r = Win32::GUI::SendMessage($self, 326, 0, 0);
    return $r;
}

sub ItemHeight {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 340 == CB_GETITEMHEIGHT
    my $item = shift or 0;
    my $r = Win32::GUI::SendMessage($self, 340, $item, 0);
    return $r;
}


#######################################################################
# PACKAGE: ProgressBar
#
package Win32::GUI::ProgressBar;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__PROGRESS", 0), @_);
}

sub SetPos {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $pos = shift;
    # 1026 == PBM_SETPOS
    return Win32::GUI::SendMessage($self, 1026, $pos, 0);
}

sub StepIt {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $pos = shift;
    # 1029 == PBM_STEPIT
    return Win32::GUI::SendMessage($self, 1029, 0, 0);
}

sub SetRange {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my ($min, $max) = @_;
    $max = $min, $min = 0 unless defined($max);
    # 1025 == PBM_SETRANGE
    # return Win32::GUI::SendMessage($self, 1025, 0, ($max + $min >> 8));
    return Win32::GUI::SendMessage($self, 1025, 0, ($min | $max << 16));
    
}

sub SetStep {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my $step = shift;
    $step = 10 unless $step;
    # 1028 == PBM_SETSTEP
    return Win32::GUI::SendMessage($self, 1028, $step, 0);
}


#######################################################################
# PACKAGE: StatusBar
#
package Win32::GUI::StatusBar;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__STATUS", 0), @_);
}


#######################################################################
# PACKAGE: TabStrip
#
package Win32::GUI::TabStrip;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__TAB", 0), @_);
}

sub SelectedItem {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 4875 == TCM_GETCURSEL
    return Win32::GUI::SendMessage($self, 4875, 0, 0);
}

sub Select {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    # 4876 == TCM_SETCURSEL
    return Win32::GUI::SendMessage($self, 4876, shift, 0);
}


#######################################################################
# PACKAGE: Toolbar
#
package Win32::GUI::Toolbar;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__TOOLBAR", 0), @_);
}

sub SetBitmapSize {
    my $self = shift;
    $self = $self->{'handle'} if ref($self);
    my ($x, $y) = @_;
    $x = 16 unless defined($x);
    $y = 15 unless defined($y);
    # 1056 == TB_SETBITMAPSIZE
    return Win32::GUI::SendMessage($self, 1056, 0, ($x | $y << 16));
}


#######################################################################
# PACKAGE: RichEdit
#
package Win32::GUI::RichEdit;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__RICHEDIT", 0), @_);
}


#######################################################################
# PACKAGE: ListView
#
package Win32::GUI::ListView;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__LISTVIEW", 0), @_);
}

#######################################################################
# PACKAGE: TreeView
#
package Win32::GUI::TreeView;
@ISA = qw(Win32::GUI);

sub new {
    return Win32::GUI->_new(Win32::GUI::constant("WIN32__GUI__TREEVIEW", 0), @_);
}


#######################################################################
# PACKAGE: ImageList
#
package Win32::GUI::ImageList;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    my $handle = Win32::GUI::ImageList::Create(@_);
    if($handle) {
        $self->{'handle'} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

sub Add {
    my($self, $bitmap, $bitmapMask) = @_;
    $bitmap = new Win32::GUI::Bitmap($bitmap) unless ref($bitmap);
    if(defined($bitmapMask)) {
        $bitmapMask = new Win32::GUI::Bitmap($bitmapMask) unless ref($bitmapMask);
        $self->AddBitmap($bitmap, $bitmapMask);
    } else {
        $self->AddBitmap($bitmap);
    }
}
        
#######################################################################
# PACKAGE: Menu 
#
package Win32::GUI::Menu;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    $class = "Win32::" . $class if $class =~ /^GUI::/;
    my $self={};

    my $handle = Win32::GUI::CreateMenu();
    
    if($handle) {
        $self->{'handle'} = $handle;
        bless($self, $class);
        return $self;
    } else {
        return undef;
    }
}

sub AddMenuButton {
    return Win32::GUI::MenuButton->new(@_);
}

#######################################################################
# PACKAGE: MenuButton 
#
package Win32::GUI::MenuButton;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    $class = "Win32::" . $class if $class =~ /^GUI::/;
    my $menu = shift;
    $menu = $menu->{'handle'} if ref($menu);
    # print "new MenuButton: menu=$menu\n";
    my %args = @_;
    my $self = {};

    my $handle = Win32::GUI::CreatePopupMenu();
                                    
    if($handle) {
        $args{-submenu} = $handle;
        Win32::GUI::InsertMenuItem($menu, %args);
        $self->{'handle'} = $handle;
        bless($self, $class);
        if($args{-name}) {
            $Win32::GUI::Menus{$args{-id}} = $self;
            $self->{name} = $args{-name};
        }                
        return $self;
    } else {
        return undef;
    }
}

sub AddMenuItem {
    return Win32::GUI::MenuItem->new(@_);
}

#######################################################################
# PACKAGE: MenuItem 
#
package Win32::GUI::MenuItem;
@ISA = qw(Win32::GUI);

sub new {
    my $class = shift;
    $class = "Win32::" . $class if $class =~ /^GUI::/;
    my $menu = shift;
    return undef unless ref($menu) =~ /^Win32::GUI::Menu/;
    my %args = @_;
    my $self = {};

    my $handle = Win32::GUI::InsertMenuItem($menu, %args);
    
    if($handle) {
        $self->{'handle'} = $handle;
        $Win32::GUI::menucallbacks{$args{-id}} = $args{-function} if $args{-function};
        $self->{'id'} = $args{-id};
        $self->{'menu'} = $menu->{'handle'};
        bless($self, $class);
        if($args{-name}) {
            $Win32::GUI::Menus{$args{-id}} = $self;
            $self->{name} = $args{-name};
        }                        
        return $self;
    } else {
        return undef;
    }
}


#######################################################################
# dynamically load in the GUI.pll module.
#

package Win32::GUI;

bootstrap Win32::GUI;

# Preloaded methods go here.

$Win32::GUI::StandardWinClass = 
    Win32::GUI::Class->new(-name => "PerlWin32GUI_STD_OBSOLETED");
#print "StandardWinClass = $Win32::GUI::StandardWinClass\n";    

$Win32::GUI::StandardWinClassVisual = 
    Win32::GUI::Class->new(-name => "PerlWin32GUI_STD", -visual => 1);
#print "StandardWinClassVisual = $Win32::GUI::StandardWinClassVisual\n";    

$Win32::GUI::RICHED = Win32::GUI::LoadLibrary("RICHED32");

END {
    # print "Freeing library RICHED32\n";
    Win32::GUI::FreeLibrary($Win32::GUI::RICHED);
}

#Currently Autoloading is not implemented in Perl for win32
# Autoload methods go after __END__, and are processed by the autosplit program.

1;
__END__

