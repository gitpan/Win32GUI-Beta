
/*
 * GUI.XS
 * 29 Jan 97 by Aldo Calpini <dada@divinf.it>
 *
 * XS interface to the Win32 GUI
 *
 * # @(#)VERSION=Beta
 * # @(#)DATE=28.05.98
 *
 */

/*
 * Uncomment the next two lines (in increasing
 * verbose order) for debugging info
 */
// #define WIN32__GUI__DEBUG
// #define WIN32__GUI__STRONG__DEBUG

#define  WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winuser.h>
#include <commctrl.h>
#include <commdlg.h>
#include <wtypes.h>
#include <richedit.h>

/* needed? */
#include <ctl3d.h>

#include "resource.h"

#define __TEMP_WORD  WORD   /* perl defines a WORD, yikes! */

/* Perl includes */
#ifdef NT_BUILD_NUMBER

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#else

#if defined(__cplusplus)
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#if defined(__cplusplus)
}
#endif

#endif

#undef WORD
#define WORD __TEMP_WORD

/* Section for the constant definitions. */
#define CROAK croak
#define MAX_EVENT_NAME 255

#define WM_EXITLOOP (WM_APP+1)    /* custom message (to exit from the Dialog() function) */

/* some Perl macros */
#define SETIV(index,value) sv_setiv(ST(index), value)
#define SETPV(index,string) sv_setpv(ST(index), string)
#define SETPVN(index, buffer, length) sv_setpvn(ST(index), (char*)buffer, length)

#define NEW(x,v,n,t)  (v = (t*)safemalloc((MEM_SIZE)((n) * sizeof(t))))
#define SvIV(sv) (SvIOK(sv) ? SvIVX(sv) : sv_2iv(sv))
#define SvPV(sv, lp) (SvPOK(sv) ? ((lp = SvCUR(sv)), SvPVX(sv)) : sv_2pv(sv, &lp))

#define PERLPUSHMARK(p) if (++markstack_ptr == markstack_max)   \
            markstack_grow();           \
            *markstack_ptr = (p) - stack_base

#define PERLXPUSHs(s)   do {\
        if (stack_max - sp < 1) {\
                sp = stack_grow(sp, sp, 1);\
            }\
  (*++sp = (s)); } while (0)

#ifdef NT_BUILD_NUMBER
#define boolSV(b) ((b) ? &sv_yes : &sv_no)
#endif

/* object types (for switch()ing) */
#define WIN32__GUI__WINDOW      0
#define WIN32__GUI__DIALOG      1

#define WIN32__GUI__STATIC      11
#define WIN32__GUI__BUTTON      12
#define WIN32__GUI__EDIT        13
#define WIN32__GUI__LISTBOX     14
#define WIN32__GUI__COMBOBOX    15  

#define WIN32__GUI__CHECKBOX    21  
#define WIN32__GUI__RADIOBUTTON 22

#define WIN32__GUI__TOOLBAR     30
#define WIN32__GUI__PROGRESS    31
#define WIN32__GUI__STATUS      32
#define WIN32__GUI__TAB         33
#define WIN32__GUI__RICHEDIT    34
#define WIN32__GUI__LISTVIEW    35
#define WIN32__GUI__TREEVIEW    36


/* an extension to Window's CREATESTRUCT structure */

typedef struct tagPERLCREATESTRUCT {
    CREATESTRUCT cs;
    /*
    CREATESTRUCT has the following members:
        LPVOID      lpCreateParams; 
        HINSTANCE   hInstance;     
        HMENU       hMenu;     
        HWND        hwndParent; 
        int         cy;     
        int         cx;     
        int         y;     
        int         x; 
        LONG        style;     
        LPCTSTR     lpszName;     
        LPCTSTR     lpszClass; 
        DWORD       dwExStyle; 
    */    
    HIMAGELIST  hImageList;
    HV*         parent;
    char *      szWindowName;
    char *      szWindowFunction;
    HFONT       hFont;
    int         nClass;
} PERLCREATESTRUCT, *LPPERLCREATESTRUCT;

/* macros to get data from either the blessed object or the SV passed */

#define handle_From(i) ( \
    (SvROK((i))) ? ( \
        (hv_fetch((HV*)SvRV((i)), "handle", 6, 0) != NULL) ? \
            SvIV(*(hv_fetch((HV*)SvRV((i)), "handle", 6, 0))) \
            : NULL \
    ) : SvIV((i)) \
)

#define classname_From(i) ( \
    (SvROK((i))) ? ( \
        (hv_fetch((HV*)SvRV((i)), "name", 4, 0) != NULL) ? \
            SvPV(*(hv_fetch((HV*)SvRV((i)), "name", 4, 0)), na) \
            : NULL \
    ) : SvPV((i), na) \
)

/* other useful things */

#define SwitchFlag(style, flag, switch) \
    if(switch == 0) { \
        if(style & flag) { \
            style ^= flag; \
        } \
    } else { \
        if(!(style & flag)) { \
            style |= flag; \
        } \
    }

#ifdef NT_BUILD_NUMBER
/* pointer to the perl object */
static CPerl *theperl;
#endif

/* default procedures for controls (not really to beused yet) */
static WNDPROC DefButtonProc;
static WNDPROC DefListboxProc;
static WNDPROC DefTabStripProc;
static WNDPROC DefRichEditProc;

/* constants definition */
#include "constants.c"

/* 
 * ###############
 * helper routines
 * ###############
 */

void CalcControlSize(int *nWidth, int *nHeight, LPCTSTR szText, 
                     HWND hParent, int add_x, int add_y) {
    SIZE mySize;
    HDC hdc;
    if(*nWidth == 0 || *nHeight == 0) {
        hdc = GetDC(hParent);
        if(GetTextExtentPoint(hdc, szText, strlen(szText), &mySize)) {
            if(*nWidth == 0) *nWidth = mySize.cx + add_x;
            if(*nHeight == 0) *nHeight = mySize.cy + add_y;
        }
        ReleaseDC(hParent, hdc);
    }
}

// get the object's name
// return FALSE if no name found
BOOL GetObjectName(HWND hwnd, char *Name) {
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    HV* obj;
    SV** name;
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    obj = (HV*) GetWindowLong(hwnd, GWL_USERDATA);
    name = hv_fetch(obj, "name", 4, FALSE);
    if(name == NULL) return FALSE;
    strcat(Name, (char *) SvPV(*name, na));
    return TRUE;
}

// get the object's name AND class (integer)
BOOL GetObjectNameAndClass(HWND hwnd, char *Name, int *obj_class) {
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    HV* obj;
    SV** name;
    SV** type;
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    obj = (HV*) GetWindowLong(hwnd, GWL_USERDATA);
    name = hv_fetch(obj, "name", 4, FALSE);
    if(name == NULL) return FALSE;
    strcat(Name, (char *) SvPV(*name, na));
    type = hv_fetch(obj, "type", 4, FALSE);
    if(type == NULL) return FALSE;
    *obj_class = SvIV(*type);
#ifdef WIN32__GUI__STRONG__DEBUG
    printf("GetObjectNameAndClass: Name='%s', Class=%d\n", Name, *obj_class);
#endif
    return TRUE;
}

// get a menu's name from the ID
// return FALSE if no name found
BOOL GetMenuName(int nID, char *Name) {
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    HV* hash;
    SV** obj;
    SV** name;
    char temp[80];
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    hash = perl_get_hv("Win32::GUI::Menus", FALSE);
    itoa(nID, temp, 10);
    obj = hv_fetch(hash, temp, strlen(temp), FALSE);
    if(obj == NULL) return FALSE;
    name = hv_fetch( ( (HV*) SvRV(*obj)), "name", 4, FALSE);
    if(name == NULL) return FALSE;
    strcat(Name, (char *) SvPV(*name, na));
    return TRUE;
}

DWORD CALLBACK RichEditSave(DWORD dwCookie, LPBYTE pbBuff, LONG cb, LONG FAR *pcb) {
    HANDLE hfile;
    hfile = (HANDLE) dwCookie;
    WriteFile(hfile, (LPCVOID) pbBuff, (DWORD) cb, (LPDWORD) pcb, NULL);
    return(0);
}
 
DWORD CALLBACK RichEditLoad(DWORD dwCookie, LPBYTE pbBuff, LONG cb, LONG FAR *pcb) {
    HANDLE hfile;
    hfile = (HANDLE) dwCookie;
    ReadFile(hfile, (LPVOID) pbBuff, (DWORD) cb, (LPDWORD) pcb, NULL);
    return(0);
}

/* 
 * ###########################################
 * message loops and event processing routines
 * ###########################################
 */

// calls an event without arguments
// Name must be pre-filled
int DoEvent_Generic(char *Name) {
    int PerlResult;
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int count;
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    PerlResult = 1;
#ifdef WIN32__GUI__DEBUG
    printf("EVENT: %s\n", Name);
#endif
    if(perl_get_cv(Name, FALSE) != NULL) {
        dSP;
        dTARG;
        ENTER ;
        SAVETMPS;
        PUSHMARK(sp) ;
        PUTBACK ;
        count = perl_call_pv(Name, G_EVAL|G_NOARGS);
        SPAGAIN ;
        if(count > 0) PerlResult = POPi;
        PUTBACK ;
        FREETMPS ;
        LEAVE ;
    }
    return PerlResult;
}

// same as above, but with a long argument
int DoEvent_Long(char *Name, long argh) {
    int PerlResult;
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int count;
#ifdef NT_BUILD_NUMBER    
    pPerl = theperl;
#endif
    PerlResult = 1;
#ifdef WIN32__GUI__DEBUG
    printf("EVENT: %s\n", Name);
#endif
    if(perl_get_cv(Name, FALSE) != NULL) {
        dSP;
        dTARG;
        ENTER ;
        SAVETMPS;
        PUSHMARK(sp) ;
        XPUSHs(sv_2mortal(newSViv(argh)));
        PUTBACK ;
        count = perl_call_pv(Name, G_EVAL|G_ARRAY);
        SPAGAIN ;
        if(count > 0) PerlResult = POPi;
        PUTBACK ;
        FREETMPS ;
        LEAVE ;
    }
    return PerlResult;
}


// calls a toolbar's WM_COMMAND event
// adds "_ButtonClick" to Name
int DoEvent_ButtonClick(char *Name, WPARAM wParam) {
    int PerlResult;
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int count;
#ifdef NT_BUILD_NUMBER    
    pPerl = theperl;
#endif
    PerlResult = 1;
    strcat(Name, "_ButtonClick");
#ifdef WIN32__GUI__DEBUG
    printf("EVENT: %s\n", Name);
#endif
    if(perl_get_cv(Name, FALSE) != NULL) {
        dSP;
        dTARG;
        ENTER ;
        SAVETMPS;
        PUSHMARK(sp) ;
        XPUSHs(sv_2mortal(newSViv(LOWORD(wParam))));
        PUTBACK ;
        count = perl_call_pv(Name, G_EVAL|G_ARRAY);
        SPAGAIN ;
        if(count > 0) PerlResult = POPi;
        PUTBACK ;
        FREETMPS ;
        LEAVE ;
    }
    return PerlResult;
}


// calls a listview's item event
int DoEvent_ListView(char *Name, LPARAM lParam) {
    int PerlResult;
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int count;
    LPNM_LISTVIEW lv_notify;
    long argh;   
#ifdef NT_BUILD_NUMBER    
    pPerl = theperl;
#endif
    PerlResult = 1;
    lv_notify = (LPNM_LISTVIEW) lParam;
    switch(lv_notify->hdr.code) {
    case LVN_ITEMCHANGED:
        strcat(Name, "_ItemClick");
        argh = (long) lv_notify->iItem;
        break;
    case LVN_COLUMNCLICK:
        strcat(Name, "_ColumnClick");
        argh = (long) lv_notify->iSubItem;
        break;
    }
#ifdef WIN32__GUI__DEBUG
    printf("EVENT: %s\n", Name);
#endif
    if(perl_get_cv(Name, FALSE) != NULL) {
        dSP;
        dTARG;
        ENTER ;
        SAVETMPS;
        PUSHMARK(sp) ;    
        XPUSHs(sv_2mortal(newSViv(argh)));
        PUTBACK ;
        count = perl_call_pv(Name, G_EVAL|G_ARRAY);
        SPAGAIN ;
        if(count > 0) PerlResult = POPi;
        PUTBACK ;
        FREETMPS ;
        LEAVE ;
    }
    return PerlResult;
}


// calls a treeview's node event
int DoEvent_TreeView(char *Name, LPARAM lParam) {
    int PerlResult;
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int count;
    LPNM_TREEVIEW tv_notify;   
#ifdef NT_BUILD_NUMBER    
    pPerl = theperl;
#endif
    PerlResult = 1;
    tv_notify = (LPNM_TREEVIEW) lParam;
    switch(tv_notify->hdr.code) {
    case TVN_SELCHANGED:
        strcat(Name, "_NodeClick");
        break;
    case TVN_ITEMEXPANDED:
        if(tv_notify->action == TVE_COLLAPSE)
            strcat(Name, "_Collapse");
        else
            strcat(Name, "_Expand");
        break;
    }
#ifdef WIN32__GUI__DEBUG
    printf("EVENT: %s\n", Name);
#endif
    if(perl_get_cv(Name, FALSE) != NULL) {
        dSP;
        dTARG;
        ENTER ;
        SAVETMPS;
        PUSHMARK(sp) ;
        XPUSHs(sv_2mortal(newSViv((long) tv_notify->itemNew.hItem)));
        PUTBACK ;
        count = perl_call_pv(Name, G_EVAL|G_ARRAY);
        SPAGAIN ;
        if(count > 0) PerlResult = POPi;
        PUTBACK ;
        FREETMPS ;
        LEAVE ;
    }
    return PerlResult;
}


// calls a WM_MOUSEMOVE event
// adds "_MouseMove" to Name
int DoEvent_MouseMove(char *Name, WPARAM wParam, LPARAM lParam) {
    int PerlResult;
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int count;
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    PerlResult = 1;
    strcat(Name, "_MouseMove");
#ifdef WIN32__GUI__DEBUG
    printf("EVENT: %s\n", Name);
#endif
    if(perl_get_cv(Name, FALSE) != NULL) {
        dSP;
        dTARG;
        ENTER ;
        SAVETMPS;
        PUSHMARK(sp) ;
        XPUSHs(sv_2mortal(newSViv(wParam)));
        XPUSHs(sv_2mortal(newSViv(LOWORD(lParam))));
        XPUSHs(sv_2mortal(newSViv(HIWORD(lParam))));
        PUTBACK ;
        count = perl_call_pv(Name, G_EVAL|G_ARRAY);
        SPAGAIN ;
        if(count > 0) PerlResult = POPi;
        PUTBACK ;
        FREETMPS ;
        LEAVE ;
    }
    return PerlResult;
}

// calls a WM_(L/R)BUTTON(UP/DOWN) event
// Name must be pre-filled
int DoEvent_MouseButton(char *Name, WPARAM wParam, LPARAM lParam) {
    int PerlResult;
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int count;
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    PerlResult = 1;
#ifdef WIN32__GUI__DEBUG
    printf("EVENT: %s\n", Name);
#endif
    if(perl_get_cv(Name, FALSE) != NULL) {
        dSP;
        dTARG;
        ENTER ;
        SAVETMPS;
        PUSHMARK(sp) ;
        XPUSHs(sv_2mortal(newSViv(wParam)));
        XPUSHs(sv_2mortal(newSViv(LOWORD(lParam))));
        XPUSHs(sv_2mortal(newSViv(HIWORD(lParam))));
        PUTBACK ;
        count = perl_call_pv(Name, G_EVAL|G_ARRAY);
        SPAGAIN ;
        if(count > 0) PerlResult = POPi;
        PUTBACK ;
        FREETMPS ;
        LEAVE ;
    }
    return PerlResult;
}

// Win32::GUI::Button message loop
LRESULT CALLBACK ButtonMsgLoop(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int PerlResult;
    char Name[MAX_EVENT_NAME];
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    PerlResult = 1;
    strcpy(Name, "main::");
    if(GetObjectName(hwnd, Name)) {
        switch(uMsg) {
        case WM_MOUSEMOVE:
            PerlResult = DoEvent_MouseMove(Name, wParam, lParam);
            break;
        // to implement:
        // MouseUp
        // MouseDown
        // KeyPress
        }
    }
    if(PerlResult == 0) {
        return 0;
    } else {
        return DefButtonProc(hwnd, uMsg, wParam, lParam);
    }
}

// Win32::GUI::Listbox message loop
LRESULT CALLBACK ListboxMsgLoop(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int PerlResult;
    char Name[MAX_EVENT_NAME];
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
    PerlResult = 1;
    strcpy((char *) Name, "main::");
    if(GetObjectName(hwnd, Name)) {
        switch(uMsg) {
        case WM_MOUSEMOVE:
            PerlResult = DoEvent_MouseMove(Name, wParam, lParam);
            break;
        // to implement:
        // MouseUp
        // MouseDown
        // KeyPress
        }
    }
    if(PerlResult == 0) {
        return 0;
    } else {
        return DefListboxProc(hwnd, uMsg, wParam, lParam);
    }

}

// Win32::GUI::RichEdit message loop
LRESULT CALLBACK RichEditMsgLoop(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int PerlResult;
    char Name[MAX_EVENT_NAME];
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif
#ifdef WIN32__GUI__STRONG__DEBUG
    printf("RichEditMsgLoop got (%ld, %d, %ld, %ld)\n", hwnd, uMsg, wParam, lParam);
#endif
    PerlResult = 1;
    strcpy((char *) Name, "main::");
    if(GetObjectName(hwnd, Name)) {
        switch(uMsg) {
        case WM_MOUSEMOVE:
            PerlResult = DoEvent_MouseMove(Name, wParam, lParam);
            break;
        case WM_LBUTTONDOWN:
            strcat((char *) Name, "_LButtonDown");
            PerlResult = DoEvent_MouseButton(Name, wParam, lParam);
            break;
        case WM_LBUTTONUP:
            strcat((char *) Name, "_LButtonUp");
            PerlResult = DoEvent_MouseButton(Name, wParam, lParam);
            break;
        case WM_RBUTTONDOWN:
            strcat((char *) Name, "_RButtonDown");
            PerlResult = DoEvent_MouseButton(Name, wParam, lParam);
            break;
        case WM_RBUTTONUP:
            strcat((char *) Name, "_RButtonUp");
            PerlResult = DoEvent_MouseButton(Name, wParam, lParam);
            break;
        case WM_CHAR:
            strcat(Name, "_KeyPress");
            PerlResult = DoEvent_Long(Name, wParam);
            break;
        // to implement:
        // MouseUp
        // MouseDown
        }
    }
    if(PerlResult == 0) {
        return 0;
    } else {
        return DefRichEditProc(hwnd, uMsg, wParam, lParam);
    }

}

// Win32::GUI::Window message loop (WndProc)
LRESULT CALLBACK WindowMsgLoop(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    int PerlResult;
    char Name[MAX_EVENT_NAME];
    int obj_class;
    LPNMHDR notify;
    LPNM_TREEVIEW tv_notify;
    LPNM_LISTVIEW lv_notify;
    LV_KEYDOWN FAR * lv_keydown;
    TV_KEYDOWN FAR * tv_keydown;
#ifdef WIN32__GUI__STRONG__DEBUG
    printf("WindowMsgLoop got (%ld, %d, %ld, %ld)\n", hwnd, uMsg, wParam, lParam);
#endif
#ifdef NT_BUILD_NUMBER                        
    pPerl = theperl;
#endif
    PerlResult = 1;

    strcpy(Name, "main::");

    switch(uMsg) {
    case WM_ACTIVATE:
        if(GetObjectName(hwnd, Name)) {
            if(LOWORD(wParam) == WA_INACTIVE) {
                strcat(Name, "_Deactivate");
            } else {
                strcat(Name, "_Activate");
            }
            PerlResult = DoEvent_Generic(Name);
        }
        break;

    case WM_SYSCOMMAND:
        if(GetObjectName(hwnd, Name)) {
            switch(wParam) {
            case SC_CLOSE:
                strcat(Name, "_Terminate");
                PerlResult = DoEvent_Generic(Name);
                break;
            }
        }
        break;

    case WM_SIZE:
        if(GetObjectName(hwnd, Name)) {
            strcat(Name, "_Resize");
            PerlResult = DoEvent_Generic(Name);
        }
        break;

    case WM_COMMAND:
        if(HIWORD(wParam) == 0 && lParam == NULL) {
            // menu command processing
            if(GetMenuName(LOWORD(wParam), Name)) {
                strcat(Name, "_Click");
                PerlResult = DoEvent_Generic(Name);
            }
        } else {
            if(GetObjectNameAndClass((HWND) lParam, Name, &obj_class)) {
                switch(obj_class) {
                case WIN32__GUI__BUTTON:
                case WIN32__GUI__CHECKBOX:
                case WIN32__GUI__RADIOBUTTON:
                    switch(HIWORD(wParam)) {
                    case BN_SETFOCUS:
                        strcat((char *) Name, "_GotFocus");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case BN_KILLFOCUS:
                        strcat((char *) Name, "_LostFocus");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case BN_CLICKED:
                        strcat((char *) Name, "_Click");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case BN_DBLCLK:
                        strcat((char *) Name, "_DblClick");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    default:
                        strcat((char *) Name, "_Anonymous");
#ifdef WIN32__GUI__STRONG__DEBUG
                        printf("WindowMsgLoop: WM_COMMAND NotifyCode=%d\n", HIWORD(wParam));
#endif
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    }
                    break;
                case WIN32__GUI__LISTBOX:
                    switch(HIWORD(wParam)) {
                    case LBN_SETFOCUS:
                        strcat((char *) Name, "_GotFocus");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case LBN_KILLFOCUS:
                        strcat((char *) Name, "_LostFocus");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case LBN_SELCHANGE:
                        strcat((char *) Name, "_Click");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case LBN_DBLCLK:
                        strcat((char *) Name, "_DblClick");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    default:
                        strcat((char *) Name, "_Anonymous");
#ifdef WIN32__GUI__STRONG__DEBUG
                        printf("WindowMsgLoop: WM_COMMAND NotifyCode=%d\n", HIWORD(wParam));
#endif
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    }
                    break;

                case WIN32__GUI__EDIT:
                case WIN32__GUI__RICHEDIT:
                    switch(HIWORD(wParam)) {
                    case EN_SETFOCUS:
                        strcat((char *) Name, "_GotFocus");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case EN_KILLFOCUS:
                        strcat((char *) Name, "_LostFocus");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case EN_CHANGE:
                        strcat((char *) Name, "_Change");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    default:
                        strcat((char *) Name, "_Anonymous");
#ifdef WIN32__GUI__STRONG__DEBUG
                        printf("WindowMsgLoop: WM_COMMAND NotifyCode=%d\n", HIWORD(wParam));
#endif
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    }
                    break;

                case WIN32__GUI__STATIC:
                    switch(HIWORD(wParam)) {
                    case STN_CLICKED:
                        strcat((char *) Name, "_Click");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    case STN_DBLCLK:
                        strcat((char *) Name, "_DblClick");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    default:
                        strcat((char *) Name, "_Anonymous");
#ifdef WIN32__GUI__STRONG__DEBUG
                        printf("WindowMsgLoop: WM_COMMAND NotifyCode=%d\n", HIWORD(wParam));
#endif
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    }
                    break;

                case WIN32__GUI__COMBOBOX:
                    switch(HIWORD(wParam)) {
                    case CBN_SELCHANGE:
                        strcat((char *) Name, "_Change");
                        PerlResult = DoEvent_Generic(Name);
                        break;
                    }
                    break;

                case WIN32__GUI__TOOLBAR:
                    strcat((char *) Name, "_ButtonClick");
                    PerlResult = DoEvent_Long(Name, LOWORD(wParam));
                    break;

                }
            }
        }
        break;


    case WM_NOTIFY:
        notify = (LPNMHDR) lParam;
        if(GetObjectNameAndClass(notify->hwndFrom, Name, &obj_class)) {
            switch(obj_class) {

            case WIN32__GUI__LISTVIEW:
                lv_notify = (LPNM_LISTVIEW) lParam;
                switch(notify->code) {
                case LVN_ITEMCHANGED:
                    strcat((char *) Name, "_ItemClick");
                    PerlResult = DoEvent_Long(Name, lv_notify->iItem);
                    break;                    
                case LVN_COLUMNCLICK:
                    strcat((char *) Name, "_ColumnClick");
                    PerlResult = DoEvent_Long(Name, lv_notify->iSubItem);
                    break;
                case LVN_KEYDOWN:
                    lv_keydown = (LV_KEYDOWN FAR *) lParam;
                    strcat((char *) Name, "_KeyDown");
                    PerlResult = DoEvent_Long(Name, lv_keydown->wVKey);
                    break;
                }
                break;
                
            case WIN32__GUI__TREEVIEW:
                tv_notify = (LPNM_TREEVIEW) lParam;
                switch(notify->code) {
                case TVN_ITEMEXPANDED:
                    if(tv_notify->action == TVE_COLLAPSE)
                        strcat(Name, "_Collapse");
                    else
                        strcat(Name, "_Expand");
                    PerlResult = DoEvent_Long(Name, (long) tv_notify->itemNew.hItem);
                    break;
                case TVN_SELCHANGED:
                    strcat(Name, "_NodeClick");
                    PerlResult = DoEvent_Long(Name, (long) tv_notify->itemNew.hItem);
                    break;
                case TVN_KEYDOWN:
                    tv_keydown = (TV_KEYDOWN FAR *) lParam;
                    strcat((char *) Name, "_KeyDown");
                    PerlResult = DoEvent_Long(Name, tv_keydown->wVKey);
                    break;                    
                }
                break;
            // this is handled by standard NM_CLICK below...
            // case WIN32__GUI__TAB:
            //    switch(notify->code) {
            //    case TCN_SELCHANGE:
            //        strcat((char *) Name, "_Click");
            //        PerlResult = DoEvent_Generic(Name);
            //        break;
            //    }
            //    break;
            }
            // ###############################################
            // standard notifications (true for all controls?)
            // ###############################################
            switch(notify->code) {
            case NM_CLICK:
                strcat((char *) Name, "_Click");
                PerlResult = DoEvent_Generic(Name);
                break;
            case NM_RCLICK:
                strcat((char *) Name, "_RightClick");
                PerlResult = DoEvent_Generic(Name);
                break;                
            case NM_DBLCLK:
                strcat((char *) Name, "_DblClick");
                PerlResult = DoEvent_Generic(Name);
                break;
            case NM_RDBLCLK:
                strcat((char *) Name, "_DblRightClick");
                PerlResult = DoEvent_Generic(Name);
                break;                
            case NM_SETFOCUS:
                strcat((char *) Name, "_GotFocus");
                PerlResult = DoEvent_Generic(Name);
                break;
            case NM_KILLFOCUS:
                strcat((char *) Name, "_LostFocus");
                PerlResult = DoEvent_Generic(Name);
                break;
            }            
        }
    }

    if(PerlResult == -1) {
        PostMessage(hwnd, WM_EXITLOOP, -1, 0);
        return 0;
    } else {
        if(PerlResult == 0) {
            return 0;
        } else {
            return DefWindowProc(hwnd, uMsg, wParam, lParam);
        }
    }
}

// Win32::GUI::TabStrip message loop (WndProc)
LRESULT CALLBACK TabStripMsgLoop(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    // a TabStrip acts like a container, so we simply
    // redirect the messages to our parent and call the default Proc.
    HWND hwndParent;

    if(uMsg == WM_COMMAND || uMsg == WM_NOTIFY) {
        hwndParent = (HWND) GetWindowLong(hwnd, GWL_HWNDPARENT);
        SendMessage(hwndParent, uMsg, wParam, lParam);
        return 0;
    } else {
        return DefTabStripProc(hwnd, uMsg, wParam, lParam);
    }
}

// obsolete (?) Win32::GUI::Window message loop
LRESULT CALLBACK MsgLoop(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
#ifdef NT_BUILD_NUMBER
    CPerl *pPerl;
#endif
    HV* cb_hash;
    SV** cb_ref;
    int i;
    int *Items;
    int Count;
    int PerlResult = 1;
    char temp[80];
    int send_to = 0;
    // 0 = DefWindowProc
    // 1 = function: perl_call_sv(cb_ref...
    // 2 = function or DefWindowProc
#ifdef NT_BUILD_NUMBER
    pPerl = theperl;
#endif

    dSP;
    dTARG;
    
    ENTER ;
    SAVETMPS;

    PUSHMARK(sp) ;
    EXTEND(sp,4) ;
    PUSHs(sv_2mortal(newSViv((long)hwnd)));
    PUSHs(sv_2mortal(newSViv((long)uMsg)));
    PUSHs(sv_2mortal(newSViv((long)wParam)));
    PUSHs(sv_2mortal(newSViv((long)lParam)));
    PUTBACK ;

    if(uMsg == WM_COMMAND) {
        
        if(lParam == NULL) {
            // Menu Option
            if(HIWORD(wParam) == 0) {
                cb_hash = perl_get_hv("Win32::GUI::menucallbacks", FALSE);
                ltoa((long) LOWORD(wParam), temp, 10);
                if(hv_exists(cb_hash, temp, strlen(temp))) {
                    cb_ref = hv_fetch(cb_hash, temp, strlen(temp), FALSE);
                    send_to = 1; // cb_ref
                } else {
                    send_to = 2;
                }
            } else {
                send_to = 2; // ...hwnd or Def
            }
        } else {
            cb_hash = perl_get_hv("Win32::GUI::callbacks", FALSE);
            ltoa((long)lParam, temp, 10);
            if(hv_exists(cb_hash, temp, strlen(temp))) {
                cb_ref = hv_fetch(cb_hash, temp, strlen(temp), FALSE);
                send_to = 1; // cb_ref
            } else {
                send_to = 2; // ...hwnd or Def
            }
        }
    } else if(uMsg == WM_NOTIFY) {
        LPNMHDR nmhdr = (LPNMHDR) lParam;
        HWND hwnd = nmhdr->hwndFrom;
        UINT id = nmhdr->idFrom;
        UINT code = nmhdr->code;
        cb_hash = perl_get_hv("Win32::GUI::callbacks", FALSE);
        ltoa((long)hwnd, temp, 10);
        if(hv_exists(cb_hash, temp, strlen(temp))) {
            cb_ref = hv_fetch(cb_hash, temp, strlen(temp), FALSE);
            send_to = 1; // cb_ref
        } else {
            send_to = 2; // ...hwnd or Def
        }
    } else {
        send_to = 2;
    }

    switch(send_to) {
    case 2:
        cb_hash = perl_get_hv("Win32::GUI::callbacks", FALSE);
        ltoa((long)hwnd, temp, 10);
        if(hv_exists(cb_hash, temp, strlen(temp))) {

            cb_ref = hv_fetch(cb_hash, temp, strlen(temp), FALSE);

            perl_call_pv((char *)SvPV(*cb_ref, na), G_ARRAY);

            SPAGAIN ;
            PerlResult = POPi;
            PUTBACK ;
        }
        break;
    case 1:
        perl_call_pv((char *)SvPV(*cb_ref, na), G_ARRAY);
        SPAGAIN ;
        PerlResult = POPi;
        PUTBACK ;
        break;
    }
    FREETMPS ;
    LEAVE ;

    if(PerlResult == -1) {
#ifdef WIN32__GUI__DEBUG
        printf("MsgLoop: posting WM_EXITLOOP to %ld...\n", hwnd);
#endif
        PostMessage(hwnd, WM_EXITLOOP, -1, 0);
        return 0;
    } else {
        if(PerlResult == 0) {
            return 0;
        } else {
            return DefWindowProc(hwnd, uMsg, wParam, lParam);
        }
    }
}

/* 
  ########################
  options parsing routines
  ########################
*/

void ParseWindowOptions(int from_i, LPPERLCREATESTRUCT perlcs) {
    int i, next_i;
    char * option;
    char * classname;
    dXSARGS;
    next_i = -1;
    for(i = from_i; i < items; i++) {
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-class") == 0) {
                next_i = i + 1;
                perlcs->cs.lpszClass = (LPCTSTR) classname_From(ST(next_i));
            } else if(strcmp(option, "-text") == 0
            || strcmp(option, "-title") == 0) {
                next_i = i + 1;
                perlcs->cs.lpszName = (LPCTSTR) SvPV(ST(next_i), na);
            } else if(strcmp(option, "-style") == 0) {
                next_i = i + 1;
                perlcs->cs.style = (DWORD) SvIV(ST(next_i));
            } else if(strcmp(option, "-exstyle") == 0) {
                next_i = i + 1;
                perlcs->cs.dwExStyle = (DWORD) SvIV(ST(next_i));
            } else if(strcmp(option, "-left") == 0) {
                next_i = i + 1;
                perlcs->cs.x = (int) SvIV(ST(next_i));
            } else if(strcmp(option, "-top") == 0) {
                next_i = i + 1;
                perlcs->cs.y = (int) SvIV(ST(next_i));
            } else if(strcmp(option, "-width") == 0) {
                next_i = i + 1;
                perlcs->cs.cx = (int) SvIV(ST(next_i));
            } else if(strcmp(option, "-height") == 0) {
                next_i = i + 1;
                perlcs->cs.cy = (int) SvIV(ST(next_i));
            } else if(strcmp(option, "-parent") == 0) {
                next_i = i + 1;
                perlcs->cs.hwndParent = (HWND) handle_From(ST(next_i));
                perlcs->parent = (HV*) SvRV(ST(next_i));
            } else if(strcmp(option, "-menu") == 0) {
                next_i = i + 1;
                perlcs->cs.hMenu = (HMENU) handle_From(ST(next_i));
            } else if(strcmp(option, "-instance") == 0) {
                next_i = i + 1;
                perlcs->cs.hInstance = (HINSTANCE) SvIV(ST(next_i));
            } else if(strcmp(option, "-data") == 0) {
                next_i = i + 1;
/* ! */
                // pPointer = (LPVOID) SvPV(ST(next_i), na);
            } else if(strcmp(option, "-name") == 0) {
                next_i = i + 1;
                perlcs->szWindowName = SvPV(ST(next_i), na);
            } else if(strcmp(option, "-function") == 0) {
                next_i = i + 1;
                perlcs->szWindowFunction = SvPV(ST(next_i), na);
            } else if(strcmp(option, "-font") == 0) {
                next_i = i + 1;
                perlcs->hFont = (HFONT) handle_From(ST(next_i));
            } else if(strcmp(option, "-visible") == 0) {
                next_i = i + 1;
                SwitchFlag(perlcs->cs.style, WS_VISIBLE, SvIV(ST(next_i)));
            } else if(strcmp(option, "-disabled") == 0) {
                next_i = i + 1;
                SwitchFlag(perlcs->cs.style, WS_DISABLED, SvIV(ST(next_i)));
            } else if(strcmp(option, "-group") == 0) {
                next_i = i + 1;
                SwitchFlag(perlcs->cs.style, WS_GROUP, SvIV(ST(next_i)));
            } else if(strcmp(option, "-tabstop") == 0) {
                next_i = i + 1;
                SwitchFlag(perlcs->cs.style, WS_TABSTOP, SvIV(ST(next_i)));
            }
            // ######################
            // class-specific parsing
            // ######################
            switch(perlcs->nClass) {

            case WIN32__GUI__STATIC:
                if(strcmp(option, "-align") == 0) {
                    next_i = i + 1;
                    if(strcmp(SvPV(ST(next_i), na), "left") == 0) {
                        SwitchFlag(perlcs->cs.style, SS_LEFT, 1);
                        SwitchFlag(perlcs->cs.style, SS_CENTER, 0);
                        SwitchFlag(perlcs->cs.style, SS_RIGHT, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "center") == 0) {
                        SwitchFlag(perlcs->cs.style, SS_LEFT, 0);
                        SwitchFlag(perlcs->cs.style, SS_CENTER, 1);
                        SwitchFlag(perlcs->cs.style, SS_RIGHT, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "right") == 0) {
                        SwitchFlag(perlcs->cs.style, SS_LEFT, 0);
                        SwitchFlag(perlcs->cs.style, SS_CENTER, 0);
                        SwitchFlag(perlcs->cs.style, SS_RIGHT, 1);
#ifndef NT_BUILD_NUMBER
                    } else {
                        if(dowarn) warn("Win32::GUI: Invalid value for -align!");
                    }
#endif
                } else if(strcmp(option, "-notify") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, SS_NOTIFY, SvIV(ST(next_i)));
                }
                break;

            case WIN32__GUI__EDIT:
                if(strcmp(option, "-align") == 0) {
                    next_i = i + 1;
                    if(strcmp(SvPV(ST(next_i), na), "left") == 0) {
                        SwitchFlag(perlcs->cs.style, ES_LEFT, 1);
                        SwitchFlag(perlcs->cs.style, ES_CENTER, 0);
                        SwitchFlag(perlcs->cs.style, ES_RIGHT, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "center") == 0) {
                        SwitchFlag(perlcs->cs.style, ES_LEFT, 0);
                        SwitchFlag(perlcs->cs.style, ES_CENTER, 1);
                        SwitchFlag(perlcs->cs.style, ES_RIGHT, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "right") == 0) {
                        SwitchFlag(perlcs->cs.style, ES_LEFT, 0);
                        SwitchFlag(perlcs->cs.style, ES_CENTER, 0);
                        SwitchFlag(perlcs->cs.style, ES_RIGHT, 1);
#ifndef NT_BUILD_NUMBER
                    } else {
                        if(dowarn) warn("Win32::GUI: Invalid value for -align!");
                    }
#endif
                } else if(strcmp(option, "-multiline") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, ES_MULTILINE, SvIV(ST(next_i)));
                } else if(strcmp(option, "-keepselection") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, ES_NOHIDESEL, SvIV(ST(next_i)));
                } else if(strcmp(option, "-readonly") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, ES_READONLY, SvIV(ST(next_i)));
                } else if(strcmp(option, "-password") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, ES_PASSWORD, SvIV(ST(next_i)));
                }
                break;

            case WIN32__GUI__BUTTON:
            case WIN32__GUI__RADIOBUTTON:
            case WIN32__GUI__CHECKBOX:
                if(strcmp(option, "-align") == 0) {
                    next_i = i + 1;
                    if(strcmp(SvPV(ST(next_i), na), "left") == 0) {
                        SwitchFlag(perlcs->cs.style, BS_LEFT, 1);
                        SwitchFlag(perlcs->cs.style, BS_CENTER, 0);
                        SwitchFlag(perlcs->cs.style, BS_RIGHT, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "center") == 0) {
                        SwitchFlag(perlcs->cs.style, BS_LEFT, 0);
                        SwitchFlag(perlcs->cs.style, BS_CENTER, 1);
                        SwitchFlag(perlcs->cs.style, BS_RIGHT, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "right") == 0) {
                        SwitchFlag(perlcs->cs.style, BS_LEFT, 0);
                        SwitchFlag(perlcs->cs.style, BS_CENTER, 0);
                        SwitchFlag(perlcs->cs.style, BS_RIGHT, 1);
#ifndef NT_BUILD_NUMBER
                    } else {
                        if(dowarn) warn("Win32::GUI: Invalid value for -align!");
                    }
#endif
                } else if(strcmp(option, "-valign") == 0) {
                    next_i = i + 1;
                    if(strcmp(SvPV(ST(next_i), na), "top") == 0) {
                        SwitchFlag(perlcs->cs.style, BS_TOP, 1);
                        SwitchFlag(perlcs->cs.style, BS_VCENTER, 0);
                        SwitchFlag(perlcs->cs.style, BS_BOTTOM, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "center") == 0) {
                        SwitchFlag(perlcs->cs.style, BS_TOP, 0);
                        SwitchFlag(perlcs->cs.style, BS_VCENTER, 1);
                        SwitchFlag(perlcs->cs.style, BS_BOTTOM, 0);
                    } else if(strcmp(SvPV(ST(next_i), na), "bottom") == 0) {
                        SwitchFlag(perlcs->cs.style, BS_TOP, 0);
                        SwitchFlag(perlcs->cs.style, BS_VCENTER, 0);
                        SwitchFlag(perlcs->cs.style, BS_BOTTOM, 1);
#ifndef NT_BUILD_NUMBER
                    } else {
                        if(dowarn) warn("Win32::GUI: Invalid value for -valign!");
                    }
#endif
                } else if(strcmp(option, "-ok") == 0) {
                    next_i = i + 1;
                    if(SvIV(ST(next_i)) != 0) {
                        perlcs->cs.hMenu = (HMENU) IDOK;
                    }
                } else if(strcmp(option, "-cancel") == 0) {
                    next_i = i + 1;
                    if(SvIV(ST(next_i)) != 0) {
                        perlcs->cs.hMenu = (HMENU) IDCANCEL;
                    }
                }
                break;
                
            case WIN32__GUI__LISTBOX:
                if(strcmp(option, "-multisel") == 0) {
                    next_i = i + 1;
                    if(SvIV(ST(next_i)) == 0) {
                        SwitchFlag(perlcs->cs.style, LBS_MULTIPLESEL, 0);
                        SwitchFlag(perlcs->cs.style, LBS_EXTENDEDSEL, 0);
                    } else if(SvIV(ST(next_i)) == 1) {
                        SwitchFlag(perlcs->cs.style, LBS_MULTIPLESEL, 1);
                        SwitchFlag(perlcs->cs.style, LBS_EXTENDEDSEL, 0);
                    } else if(SvIV(ST(next_i)) == 2) {
                        SwitchFlag(perlcs->cs.style, LBS_MULTIPLESEL, 1);
                        SwitchFlag(perlcs->cs.style, LBS_EXTENDEDSEL, 1);
#ifndef NT_BUILD_NUMBER
                    } else {
                        if(dowarn) warn("Win32::GUI: Invalid value for -multisel!");
                    }
#endif
                }
                break;

            case WIN32__GUI__TAB:
                if(strcmp(option, "-imagelist") == 0) {
                    next_i = i + 1;
                    perlcs->hImageList = (HIMAGELIST) handle_From(ST(next_i));
                } else if(strcmp(option, "-multiline") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, TCS_MULTILINE, SvIV(ST(next_i)));
                }

                break;

            case WIN32__GUI__LISTVIEW:
                if(strcmp(option, "-imagelist") == 0) {
                    next_i = i + 1;
                    perlcs->hImageList = (HIMAGELIST) handle_From(ST(next_i));
                } else if(strcmp(option, "-showselalways") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, LVS_SHOWSELALWAYS, SvIV(ST(next_i)));
                }

                break;
            case WIN32__GUI__TREEVIEW:
                if(strcmp(option, "-lines") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, TVS_HASLINES, SvIV(ST(next_i)));
                } else if(strcmp(option, "-rootlines") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, TVS_LINESATROOT, SvIV(ST(next_i)));
                } else if(strcmp(option, "-buttons") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, TVS_HASBUTTONS, SvIV(ST(next_i)));
                } else if(strcmp(option, "-imagelist") == 0) {
                    next_i = i + 1;
                    perlcs->hImageList = (HIMAGELIST) handle_From(ST(next_i));
                } else if(strcmp(option, "-showselalways") == 0) {
                    next_i = i + 1;
                    SwitchFlag(perlcs->cs.style, TVS_SHOWSELALWAYS, SvIV(ST(next_i)));
                }
                break;                
            }
        } else {
            next_i = -1;
        }
    }
}

void ParseMenuItemOptions(int from_i, LPMENUITEMINFO mii, UINT* myItem) {
    int i, next_i;
    char * option;
    int textlength;
    dXSARGS;
    next_i = -1;
    for(i = from_i; i < items; i++) {
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-mask") == 0) {
                next_i = i + 1;
                mii->fMask = (UINT) SvIV(ST(next_i));
            }
            if(strcmp(option, "-flag") == 0) {
                next_i = i + 1;
                mii->fType = (UINT) SvIV(ST(next_i));
            }
            if(strcmp(option, "-state") == 0) {
                SwitchFlag(mii->fMask, MIIM_STATE, 1);
                next_i = i + 1;
                mii->fState = (UINT) SvIV(ST(next_i));
            }
            if(strcmp(option, "-id") == 0) {
                SwitchFlag(mii->fMask, MIIM_ID, 1);
                next_i = i + 1;
                mii->wID = (UINT) SvIV(ST(next_i));
            }
            if(strcmp(option, "-submenu") == 0) {
                SwitchFlag(mii->fMask, MIIM_SUBMENU, 1);
                next_i = i + 1;
                mii->hSubMenu = (HMENU) handle_From(ST(next_i));
            }
            if(strcmp(option, "-data") == 0) {
                SwitchFlag(mii->fMask, MIIM_DATA, 1);
                next_i = i + 1;
                mii->dwItemData = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(option, "-text") == 0) {
                SwitchFlag(mii->fMask, MIIM_TYPE, 1);
                SwitchFlag(mii->fType, MFT_STRING, 1);
                next_i = i + 1;
                mii->dwTypeData = SvPV(ST(next_i), textlength);
                mii->cch = textlength;
#ifdef WIN32__GUI__DEBUG
                printf("!XS(ParseMenuItemOptions): dwTypeData='%s' cch=%d\n", mii->dwTypeData, mii->cch);
#endif
            }
            if(strcmp(option, "-item") == 0) {
                next_i = i + 1;
                *myItem = SvIV(ST(next_i));
            }
            if(strcmp(option, "-separator") == 0) {
                SwitchFlag(mii->fMask, MIIM_TYPE, 1);
                next_i = i + 1;
                SwitchFlag(mii->fType, MFT_SEPARATOR, SvIV(ST(next_i)));
            }
            if(strcmp(option, "-default") == 0) {
                SwitchFlag(mii->fMask, MIIM_STATE, 1);
                next_i = i + 1;
                SwitchFlag(mii->fState, MFS_DEFAULT, SvIV(ST(next_i)));
            }
            if(strcmp(option, "-checked") == 0) {
                SwitchFlag(mii->fMask, MIIM_STATE, 1);
                next_i = i + 1;
                SwitchFlag(mii->fState, MFS_CHECKED, SvIV(ST(next_i)));
            }
            if(strcmp(option, "-enabled") == 0) {
                SwitchFlag(mii->fMask, MIIM_STATE, 1);
                next_i = i + 1;
                SwitchFlag(mii->fState, MFS_ENABLED, SvIV(ST(next_i)));
            }

        } else {
            next_i = -1;
        }
    }
}


/* 
 * ############################
 * Win32::GUI General functions
 * ############################
 */

MODULE = Win32::GUI     PACKAGE = Win32::GUI

PROTOTYPES: DISABLE

HINSTANCE
LoadLibrary(name)
    char *name;
CODE:
    RETVAL = LoadLibrary(name);
OUTPUT:
    RETVAL

bool
FreeLibrary(library)
    HINSTANCE library;
CODE:
    RETVAL = FreeLibrary(library);
OUTPUT:
    RETVAL

void
GetPerlWindow()
PPCODE:
    char OldPerlWindowTitle[1024];
    char NewPerlWindowTitle[1024];
    HWND hwndFound;
    HINSTANCE hinstanceFound;
    // this is an hack from M$'s Knowledge Base
    // to get the HWND of the console in which
    // Perl is running (and Hide() it :-).
    GetConsoleTitle(OldPerlWindowTitle, 1024);
    wsprintf(NewPerlWindowTitle, 
             "PERL-%d-%d",
             GetTickCount(),
             GetCurrentProcessId());

    SetConsoleTitle(NewPerlWindowTitle);
    Sleep(40);
    hwndFound = FindWindow(NULL, NewPerlWindowTitle);

    // another hack to get the program's instance
#ifdef NT_BUILD_NUMBER
    hinstanceFound = GetModuleHandle("GUI.PLL");
#else
    hinstanceFound = GetModuleHandle("GUI.DLL");
#endif
    // hinstanceFound = (HINSTANCE) GetWindowLong(hwndFound, GWL_HINSTANCE);
    // sv_hinstance = perl_get_sv("Win32::GUI::hinstance", TRUE);
    // sv_setiv(sv_hinstance, (IV) hinstanceFound);
    SetConsoleTitle(OldPerlWindowTitle);
    if(GIMME == G_ARRAY) {
        EXTEND(SP, 2);
        XST_mIV(0, (long) hwndFound);
        XST_mIV(1, (long) hinstanceFound);
        XSRETURN(2);
    } else {
        XSRETURN_IV((long) hwndFound);
    }


DWORD
constant(name,arg)
    char *name
    int arg
CODE:
#ifdef NT_BUILD_NUMBER
    RETVAL = constant(pPerl, name, arg);
#else
    RETVAL = constant(name, arg);
#endif
OUTPUT:
    RETVAL

void
RegisterClassEx(...)
PPCODE:
    WNDCLASSEX wcx; 
    SV* sv_hinstance;
    HINSTANCE hinstance;
    char * option;
    int i, next_i;

    wcx.cbSize = sizeof(WNDCLASSEX);   // size of structure 

    wcx.style = CS_HREDRAW | CS_VREDRAW; // redraw if size changes 
    wcx.cbClsExtra = 0; // no extra class memory 
    wcx.cbWndExtra = 0; // no extra window memory 
    wcx.hInstance = 0;  // handle of instance  [dada] !!!
    wcx.lpfnWndProc = WindowMsgLoop;    // points to window procedure 
#ifdef NT_BUILD_NUMBER
    hinstance = GetModuleHandle("GUI.PLL");
#else
    hinstance = GetModuleHandle("GUI.DLL");
#endif
    wcx.hIcon = LoadIcon(hinstance, MAKEINTRESOURCE(IDI_DEFAULTICON));
    wcx.hIconSm = NULL;
    wcx.hCursor = NULL;
    wcx.lpszMenuName = NULL;

    for(i = 0; i < items; i++) {
        if(strcmp(SvPV(ST(i), na), "-extends") == 0) {
            next_i = i + 1;
            if(!GetClassInfoEx((HINSTANCE) NULL, 
                               (LPCTSTR) SvPV(ST(next_i), na),
                               &wcx)) {
#ifndef NT_BUILD_NUMBER
                if(dowarn) warn("Win32::GUI: Class '%s' not found!\n", SvPV(ST(next_i), na));
#endif
                XSRETURN_NO;
            }
        }
    }

    next_i = -1;
    for(i = 0; i < items; i++) {
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-name") == 0) {
                next_i = i + 1;
                wcx.lpszClassName = (char *) SvPV(ST(next_i), na);
            }
            if(strcmp(option, "-color") == 0) {
                next_i = i + 1;
                wcx.hbrBackground = (HBRUSH) SvIV(ST(next_i));
            }
            if(strcmp(option, "-visual") == 0) {
                next_i = i + 1;
                // -visual = 0 is obsolete
                if(SvIV(ST(next_i)) == 0) {
                    wcx.lpfnWndProc = MsgLoop;
                }
            }
            if(strcmp(option, "-widget") == 0) {
                next_i = i + 1;
                if(strcmp(SvPV(ST(next_i), na), "Button") == 0) {
                    DefButtonProc = wcx.lpfnWndProc;
                    wcx.lpfnWndProc = ButtonMsgLoop;
                } else if(strcmp(SvPV(ST(next_i), na), "Listbox") == 0) {
                    DefListboxProc = wcx.lpfnWndProc;
                    wcx.lpfnWndProc = ListboxMsgLoop;
                } else if(strcmp(SvPV(ST(next_i), na), "TabStrip") == 0) {
                    DefTabStripProc = wcx.lpfnWndProc;
                    wcx.lpfnWndProc = TabStripMsgLoop;
                } else if(strcmp(SvPV(ST(next_i), na), "RichEdit") == 0) {
                    DefRichEditProc = wcx.lpfnWndProc;
                    wcx.lpfnWndProc = RichEditMsgLoop;
                }
            }
            if(strcmp(option, "-style") == 0) {
                next_i = i + 1;
                wcx.style = SvIV(ST(next_i));
            }

            if(strcmp(option, "-icon") == 0) {
                next_i = i + 1;
                wcx.hIcon = (HICON) handle_From(ST(next_i));
            }
            if(strcmp(option, "-cursor") == 0) {
                next_i = i + 1;
                wcx.hCursor = (HCURSOR) handle_From(ST(next_i));
            }
            if(strcmp(option, "-menu") == 0) {
                next_i = i + 1;
                wcx.lpszMenuName = (char *) SvPV(ST(next_i), na);
            }
        } else {
            next_i = -1;
        }
    }
    
    // Register the window class. 
    if(RegisterClassEx(&wcx)) {
        XSRETURN_YES;
    } else {
        XSRETURN_NO;
    } 


    # obsoleted, use Create() instead
void
CreateWindowEx(...)
PPCODE:
    HWND myhandle;
    int i, next_i;
    HWND  hParent;
    HMENU hMenu;
    HINSTANCE hInstance;
    LPVOID pPointer;
    DWORD dwStyle;
    DWORD dwExStyle;
    LPCTSTR szClassname;
    LPCTSTR szText;
    int nX, nY, nWidth, nHeight;

    hParent = NULL;
    hMenu = NULL;
    hInstance = NULL;
    pPointer = NULL;
    dwStyle = 0;
    dwExStyle = 0;
    szText = NULL;
    
    next_i = -1;
    for(i = 0; i < items; i++) {
        //printf("ST(%d): ", i);
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-exstyle") == 0) {
                next_i = i + 1;
                dwExStyle = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-class") == 0) {
                next_i = i + 1;
                szClassname = (LPCTSTR) SvPV(ST(next_i), na);
                //printf("szClassname = '%s'\n", szClassname);
            }
            if(strcmp(SvPV(ST(i), na), "-text") == 0
            || strcmp(SvPV(ST(i), na), "-title") == 0) {
                next_i = i + 1;
                szText = (LPCTSTR) SvPV(ST(next_i), na);
            }
            if(strcmp(SvPV(ST(i), na), "-style") == 0) {
                //printf("got -style\n");
                next_i = i + 1;
                dwStyle = (DWORD) SvIV(ST(next_i));
            }
            
            if(strcmp(SvPV(ST(i), na), "-left") == 0) {
                //printf("got -left\n");
                next_i = i + 1;
                nX = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-top") == 0) {
                //printf("got -top\n");
                next_i = i + 1;
                nY = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-height") == 0) {
                //printf("got -height\n");
                next_i = i + 1;
                nHeight = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-width") == 0) {
                //printf("got -width\n");
                next_i = i + 1;
                nWidth = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-parent") == 0) {
                //printf("got -parent\n");
                next_i = i + 1;
                hParent = (HWND) handle_From(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-menu") == 0) {
                //printf("got -menu\n");
                next_i = i + 1;
                hMenu = (HMENU) handle_From(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-instance") == 0) {
                //printf("got -instance\n");
                next_i = i + 1;
                hInstance = (HINSTANCE) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-data") == 0) {
                //printf("got -data\n");
                next_i = i + 1;
                pPointer = (LPVOID) SvPV(ST(next_i), na);
            }

        } else {
            next_i = -1;
        }
    }
#ifdef WIN32__GUI__DEBUG
    printf("Done parsing parameters...\n");
    printf("dwExStyle = %ld\n", dwExStyle);
    printf("szClassname = %s\n", szClassname);
    printf("szText = %s\n", szText);
    printf("dwStyle = %ld\n", dwStyle);
    printf("nX = %d\n", nX);
    printf("nY = %d\n", nY);
    printf("nWidth = %d\n", nWidth);
    printf("nHeight = %d\n", nHeight);
    printf("hParent = %ld\n", hParent);
    printf("hMenu = %ld\n", hMenu);
    printf("hInstance = %ld\n", hInstance);
    printf("pPointer = %ld\n", pPointer);
#endif
    if(myhandle = CreateWindowEx(dwExStyle,
                                 szClassname,
                                 szText,
                                 dwStyle,
                                 nX,
                                 nY,
                                 nWidth,
                                 nHeight,
                                 hParent,
                                 hMenu,
                                 hInstance,
                                 pPointer)) {
        // printf("CreateWindowEx OK...\n");                                 
        XSRETURN_IV((long) myhandle);
    } else {
        // printf("CreateWindowEx FAILED (%d)\n", GetLastError());
        XSRETURN_NO;
    }


void
Create(...)
PPCODE:
    HWND myhandle;
    int first_i;
    PERLCREATESTRUCT perlcs;
    int nClass;
    LPVOID pPointer;
    SV* tempsv;    
    HV* self;
    HV* windows;
    HV* parent;
    SV** font;
    char temp[80];
    
    ZeroMemory(&perlcs, sizeof(PERLCREATESTRUCT));

    self = (HV*) SvRV(ST(0));
    perlcs.nClass = SvIV(ST(1));

    // #######################################
    // fill the default parameters for classes
    // #######################################
    switch(perlcs.nClass) {
    case WIN32__GUI__WINDOW:
        perlcs.cs.style = WS_OVERLAPPEDWINDOW;
        break;
    case WIN32__GUI__DIALOG:
        perlcs.cs.style = WS_BORDER | DS_MODALFRAME | WS_POPUP | WS_CAPTION | WS_SYSMENU;
        perlcs.cs.dwExStyle = WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE 
                            | WS_EX_CONTEXTHELP | WS_EX_CONTROLPARENT;
        break;
    case WIN32__GUI__BUTTON:
        perlcs.cs.lpszClass = "BUTTON";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | BS_PUSHBUTTON;
        break;
    case WIN32__GUI__CHECKBOX:
        perlcs.cs.lpszClass = "BUTTON";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | BS_AUTOCHECKBOX;
        break;
    case WIN32__GUI__RADIOBUTTON:
        perlcs.cs.lpszClass = "BUTTON";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | BS_AUTORADIOBUTTON;
        break;
    case WIN32__GUI__STATIC:
        perlcs.cs.lpszClass = "STATIC";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | SS_LEFT;
        break;
    case WIN32__GUI__EDIT:
        perlcs.cs.lpszClass = "EDIT";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | WS_BORDER | ES_LEFT; // evtl. DS_3DLOOK?
        perlcs.cs.dwExStyle = WS_EX_CLIENTEDGE;
        break;
    case WIN32__GUI__LISTBOX:
        perlcs.cs.lpszClass = "LISTBOX";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD;
        perlcs.cs.dwExStyle = WS_EX_CLIENTEDGE;            
        break;
    case WIN32__GUI__COMBOBOX:
        perlcs.cs.lpszClass = "COMBOBOX";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD;
        perlcs.cs.dwExStyle = WS_EX_CLIENTEDGE;            
        break;
    case WIN32__GUI__PROGRESS:
        perlcs.cs.lpszClass = PROGRESS_CLASS;
        perlcs.cs.style = WS_VISIBLE | WS_CHILD;
        perlcs.cs.dwExStyle = WS_EX_CLIENTEDGE;            
        break;
    case WIN32__GUI__STATUS:
        perlcs.cs.lpszClass = STATUSCLASSNAME;
        perlcs.cs.style = WS_VISIBLE | WS_CHILD;
        break;
    case WIN32__GUI__TAB:
        perlcs.cs.lpszClass = WC_TABCONTROL;
        perlcs.cs.style = WS_VISIBLE | WS_CHILD;
        break;
    case WIN32__GUI__TOOLBAR:
        perlcs.cs.lpszClass = TOOLBARCLASSNAME;
        perlcs.cs.style = WS_VISIBLE | WS_CHILD;
        break;
    case WIN32__GUI__LISTVIEW:
        perlcs.cs.lpszClass = WC_LISTVIEW;
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | WS_BORDER | LVS_SHOWSELALWAYS;
        break;
    case WIN32__GUI__TREEVIEW:
        perlcs.cs.lpszClass = WC_TREEVIEW;
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | WS_BORDER | TVS_SHOWSELALWAYS;
        break;
    case WIN32__GUI__RICHEDIT:
        perlcs.cs.lpszClass = "RichEdit";
        perlcs.cs.style = WS_VISIBLE | WS_CHILD | ES_MULTILINE;
        perlcs.cs.dwExStyle = WS_EX_CLIENTEDGE;
        break;
    }          
    first_i = 2;
    if(SvROK(ST(2))) {
        perlcs.cs.hwndParent = (HWND) handle_From(ST(2));
        perlcs.parent = (HV*) SvRV(ST(2));
        first_i = 3;
    }
    // ####################
    // options parsing loop
    // ####################
    ParseWindowOptions(first_i, &perlcs);

    // ##################################
    // post-processing default parameters
    // ##################################
    switch(perlcs.nClass) {
    case WIN32__GUI__WINDOW:
    case WIN32__GUI__DIALOG:
        if(perlcs.cs.lpszClass == NULL) {
            if(perlcs.szWindowName == NULL) {
                tempsv = perl_get_sv("Win32::GUI::StandardWinClass", FALSE);
                perlcs.cs.lpszClass = classname_From(tempsv);
            } else {
                tempsv = perl_get_sv("Win32::GUI::StandardWinClassVisual", FALSE);
                perlcs.cs.lpszClass = classname_From(tempsv);
            }
#ifdef WIN32__GUI__STRONG__DEBUG
            printf("Create: using class '%s'\n", perlcs.cs.lpszClass);
#endif
        }
        break;
    case WIN32__GUI__BUTTON:
        CalcControlSize(&(perlcs.cs.cx), &(perlcs.cs.cy), perlcs.cs.lpszName, perlcs.cs.hwndParent, 16, 8);
        break;
    case WIN32__GUI__CHECKBOX:
        CalcControlSize(&(perlcs.cs.cx), &(perlcs.cs.cy), perlcs.cs.lpszName, perlcs.cs.hwndParent, 16, 8);
        break;
    case WIN32__GUI__RADIOBUTTON:
        CalcControlSize(&(perlcs.cs.cx), &(perlcs.cs.cy), perlcs.cs.lpszName, perlcs.cs.hwndParent, 16, 8);
        break;
    case WIN32__GUI__STATIC:
        CalcControlSize(&(perlcs.cs.cx), &(perlcs.cs.cy), perlcs.cs.lpszName, perlcs.cs.hwndParent, 0, 0);
        break;
    }          
    // ###############################
    // default styles for all controls
    // ###############################
    if(perlcs.nClass != WIN32__GUI__WINDOW && perlcs.nClass != WIN32__GUI__DIALOG) {
        SwitchFlag(perlcs.cs.style, WS_CHILD, 1);
    }
#ifdef WIN32__GUI__STRONG__DEBUG        
    printf("XS(Create): Done parsing parameters...\n");
    printf("XS(Create): dwExStyle = 0x%x\n", perlcs.cs.dwExStyle);
    printf("XS(Create): szClassname = %s\n", perlcs.cs.lpszClass);
    printf("XS(Create): szName = %s\n", perlcs.cs.lpszName);
    printf("XS(Create): dwStyle = 0x%x\n", perlcs.cs.style);
    printf("XS(Create): nX = %d\n", perlcs.cs.x);
    printf("XS(Create): nY = %d\n", perlcs.cs.y);
    printf("XS(Create): nWidth = %d\n", perlcs.cs.cx);
    printf("XS(Create): nHeight = %d\n", perlcs.cs.cy);
    printf("XS(Create): hParent = %ld\n", perlcs.cs.hwndParent);
    printf("XS(Create): hMenu = %ld\n", perlcs.cs.hMenu);
    printf("XS(Create): hInstance = %ld\n", perlcs.cs.hInstance);
//    printf("XS(Create): pPointer = %ld\n", pPointer);
#endif    
    // ###################################
    // and finally, creation of the window
    // ###################################
    if(myhandle = CreateWindowEx(perlcs.cs.dwExStyle,
                                 perlcs.cs.lpszClass,
                                 perlcs.cs.lpszName,
                                 perlcs.cs.style,
                                 perlcs.cs.x,
                                 perlcs.cs.y,
                                 perlcs.cs.cx,
                                 perlcs.cs.cy,
                                 perlcs.cs.hwndParent,
                                 perlcs.cs.hMenu,
                                 perlcs.cs.hInstance,
                                 NULL)) {
        // ##################################
        // ok, we can fill this object's hash
        // ##################################
        ltoa((long) myhandle, temp, 10);
        hv_store(self, "handle", 6, newSViv((long) myhandle), 0);
        hv_store(self, "type", 4, newSViv((long) perlcs.nClass), 0);
        // store the -name parameter...
        if(perlcs.szWindowName != NULL) {
            hv_store(self, "name", 4, newSVpv((char *)perlcs.szWindowName, 0), 0);
        }
        // ... or the -function (obsolete?)
        // if(perlcs.lpszWindowFunction != NULL) {
        //     windows = perl_get_hv("Win32::GUI::callbacks", FALSE);
        //     hv_store(windows, temp, strlen(temp), newSVpv((char *)perlcs.lpszWindowFunction, 0), 0);
        // }
        // if(perlcs.cs.hwndParent != NULL)
        //     hv_store(self, "parent", 6, newSViv((long) perlcs.cs.hwndParent), 0);
        // set the font for the control
        if(perlcs.hFont != NULL) {
            hv_store(self, "font", 4, newSViv((long) perlcs.hFont), 0);
            SendMessage(myhandle, WM_SETFONT, (WPARAM) perlcs.hFont, 0);
        } else if(perlcs.cs.hwndParent != NULL) {
            font = hv_fetch(perlcs.parent, "font", 4, FALSE);
            if(font != NULL) {
                perlcs.hFont = (HFONT) handle_From(*font);
                SendMessage(myhandle, WM_SETFONT, (WPARAM) perlcs.hFont, 0);
            } else {
                perlcs.hFont = (HFONT) GetStockObject(DEFAULT_GUI_FONT);
                SendMessage(myhandle, WM_SETFONT, (WPARAM) perlcs.hFont, 0);
            }
        }           
        // #####################################################
        // other post-creation class-specific initializations...
        // #####################################################
        switch(perlcs.nClass) {
        case WIN32__GUI__TOOLBAR:
            SendMessage(myhandle, TB_BUTTONSTRUCTSIZE, (WPARAM) sizeof(TBBUTTON), 0);
            break;
        case WIN32__GUI__TAB:
            if(perlcs.hImageList != NULL) 
                TabCtrl_SetImageList(myhandle, perlcs.hImageList);
            break;            
        case WIN32__GUI__LISTVIEW:
            if(perlcs.hImageList != NULL) 
                ListView_SetImageList(myhandle, perlcs.hImageList, TVSIL_NORMAL);
            break;            
        case WIN32__GUI__TREEVIEW:
            if(perlcs.hImageList != NULL) 
                TreeView_SetImageList(myhandle, perlcs.hImageList, TVSIL_NORMAL);
            // later i'll cope with TVSIL_STATE too...
            break;            
        }        
        // ###########################################################
        // store a pointer to the Perl object in the window's USERDATA
        // ###########################################################
        SetWindowLong(myhandle, GWL_USERDATA, (long) self);
        XSRETURN_IV((long) myhandle);
    } else {
        XSRETURN_NO;
    }

void
Change(handle,...)
    HWND handle
PREINIT:
    PERLCREATESTRUCT perlcs;
    int visibleSeen;
    SV* tempsv;
    SV** type;
    HV* self;
    HV* windows;
    char temp[80];
PPCODE:
    ZeroMemory(&perlcs, sizeof(PERLCREATESTRUCT));

    self = (HV*) SvRV(ST(0));
    type = hv_fetch(self, "type", 4, 0);
    if(type == NULL) {
        perlcs.nClass = 0;
    } else {
        perlcs.nClass = SvIV(*type);
    }
#ifdef WIN32__GUI__STRONG__DEBUG
    printf("XS(Change): nClass=%d\n", perlcs.nClass);
#endif
    // #####################
    // retrieve windows data
    // #####################
    perlcs.cs.style = GetWindowLong(handle, GWL_STYLE);
    perlcs.cs.dwExStyle = GetWindowLong(handle, GWL_EXSTYLE);
    
    ParseWindowOptions(1, &perlcs);

    // ###############################
    // default styles for all controls
    // ###############################
    if(perlcs.nClass != WIN32__GUI__WINDOW && perlcs.nClass != WIN32__GUI__DIALOG) {
        SwitchFlag(perlcs.cs.style, WS_CHILD, 1);
    }
    // ###############
    // Perform changes
    // ###############
    if(perlcs.cs.lpszName != NULL)
        SetWindowText(handle, perlcs.cs.lpszName);
    SetWindowLong(handle, GWL_STYLE, perlcs.cs.style);
    SetWindowLong(handle, GWL_EXSTYLE, perlcs.cs.dwExStyle);
    if(perlcs.cs.x != 0 || perlcs.cs.y != 0)
        SetWindowPos(handle, (HWND) NULL, perlcs.cs.x, perlcs.cs.y, 0, 0,
                             SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOSIZE);
    if(perlcs.cs.cx != 0 || perlcs.cs.cy != 0)
        SetWindowPos(handle, (HWND) NULL, 0, 0, perlcs.cs.cx, perlcs.cs.cy,
                             SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOMOVE);
    if(perlcs.cs.hMenu != NULL)
        SetMenu(handle, perlcs.cs.hMenu);
    XSRETURN_YES;


DWORD
Dialog(...)
PPCODE:
    HWND hwnd;
    MSG msg;
    HWND phwnd;
    HWND thwnd;
    SV** type;
    HV* self;
    int stayhere;
    BOOL fIsDialog;
    stayhere = 1;
    fIsDialog = FALSE;

    if(items > 0) {
        hwnd = (HWND) handle_From(ST(0));
    } else {
        hwnd = NULL;
    }
    
    while (stayhere) {
        stayhere = GetMessage(&msg, hwnd, 0, 0);
        if(msg.message == WM_EXITLOOP) {
            stayhere = 0;
            msg.wParam = -1;
        } else {
            if(stayhere == -1) {
                stayhere = 0;
                msg.wParam = -2; // an error occurred...
            } else {
                // trace back to the window's parent
                phwnd = msg.hwnd;
                while(thwnd = GetParent(phwnd)) {
                    phwnd = thwnd;
                }
                // now see if the parent window is a DialogBox
                fIsDialog = FALSE;
                self = (HV*) GetWindowLong(phwnd, GWL_USERDATA);
                type = hv_fetch(self, "type", 4, FALSE);
                if(type != NULL) {
                    if(SvIV(*type) == WIN32__GUI__DIALOG) {
                        fIsDialog = TRUE;
                    }
                }
                if(fIsDialog) {
                    if(!IsDialogMessage(phwnd, &msg)) {
                        TranslateMessage(&msg); 
                        DispatchMessage(&msg); 
                    }
                } else {
                    TranslateMessage(&msg); 
                    DispatchMessage(&msg); 
                }
            }
        }
    } 
    XSRETURN_IV((long) msg.wParam);


DWORD
oldDialog(...)
PPCODE:
    HWND hwnd;
    MSG msg;
    int stayhere;
    stayhere = 1;

    if(items > 0) {
        hwnd = (HWND) handle_From(ST(0));
    } else {
        hwnd = NULL;
    }
    
    while (stayhere) {
        stayhere = GetMessage(&msg, hwnd, 0, 0);
        if(msg.message == WM_EXITLOOP) {
            stayhere = 0;
            msg.wParam = -1;
        } else {
            if(stayhere == -1) {
                stayhere = 0;
                msg.wParam = -2; // an error occurred...
            } else {
                // result = GetMessage(&msg, (HWND) handle_From(ST(0)), 0, 0);
                TranslateMessage(&msg); 
                DispatchMessage(&msg); 
            }
        }
    } 
    XSRETURN_IV((long) msg.wParam);


HCURSOR
LoadCursorFromFile(filename)
    LPCTSTR filename
CODE:
    RETVAL = LoadCursorFromFile(filename);
OUTPUT:
    RETVAL

HBITMAP
LoadImage(filename,iType=IMAGE_BITMAP,iX=0,iY=0,iFlags=LR_LOADFROMFILE)
    LPCTSTR filename
    UINT iType
    int iX
    int iY
    UINT iFlags
CODE:
    RETVAL = LoadImage((HINSTANCE) NULL, filename, iType, iX, iY, iFlags);
OUTPUT:
    RETVAL

HCURSOR
SetCursor(cursor)
    HCURSOR cursor
CODE:
    RETVAL = SetCursor(cursor);
OUTPUT:
    RETVAL

HCURSOR
GetCursor()
CODE:
    RETVAL = GetCursor();
OUTPUT:
    RETVAL

void
GetClassName(handle)
    HWND handle
PREINIT:
    LPTSTR lpClassName;
    int nMaxCount;
PPCODE:
    nMaxCount = 256;
    lpClassName = (LPTSTR) safemalloc(nMaxCount);
    if(GetClassName(handle, lpClassName, nMaxCount) > 0) {
        EXTEND(SP, 1);
        XST_mPV(0, lpClassName);
        safefree(lpClassName);
        XSRETURN(1);
    } else {
        safefree(lpClassName);
        XSRETURN_NO;
    }

HWND
FindWindow(classname,windowname)
    LPCTSTR classname
    LPCTSTR windowname
CODE:
    if(strlen(classname) == 0) classname = NULL;
    if(strlen(windowname) == 0) windowname = NULL;
    RETVAL = FindWindow(classname, windowname);
OUTPUT:
    RETVAL

LONG
GetWindowLong(handle,index)
    HWND handle
    int index
CODE:
    RETVAL = GetWindowLong(handle, index);
OUTPUT:
    RETVAL

LONG
SetWindowLong(handle,index,value)
    HWND handle
    int  index
    LONG value
CODE:
    RETVAL = SetWindowLong(handle, index, value);
OUTPUT:
    RETVAL

HWND
GetWindow(handle,command)
    HWND handle
    UINT command
CODE:
    RETVAL = GetWindow(handle, command);
OUTPUT:
    RETVAL

BOOL
Show(handle,command=SW_SHOWNORMAL)
    HWND handle
    int command
CODE:
    RETVAL = ShowWindow(handle, command);
OUTPUT:
    RETVAL

BOOL
Hide(handle)
    HWND handle
CODE:
    RETVAL = ShowWindow(handle, SW_HIDE);
OUTPUT:
    RETVAL

BOOL
Update(handle)
    HWND handle
CODE:
    RETVAL = UpdateWindow(handle);
OUTPUT:
    RETVAL

BOOL
InvalidateRect(handle, ...)
    HWND handle
PREINIT:
    RECT rect;
    LPRECT lpRect;
    BOOL bErase;
CODE:
    if(items != 2 && items != 6) {
        CROAK("Usage: InvalidateRect(handle, flag);\n   or: InvalidateRect(handle, left, top, right, bottom, flag);\n");
    }
    if(items == 2) {
        lpRect = (LPRECT) NULL;
        bErase = (BOOL) SvIV(ST(1));
    } else {
        rect.left   = SvIV(ST(1));
        rect.top    = SvIV(ST(2));
        rect.right  = SvIV(ST(3));
        rect.bottom = SvIV(ST(4));
        bErase      = (BOOL) SvIV(ST(5));
        lpRect      = &rect;
    }
    RETVAL = InvalidateRect(handle, lpRect, bErase);
OUTPUT:
    RETVAL

BOOL
DestroyWindow(handle)
    HWND handle
CODE:
    RETVAL = DestroyWindow(handle);
OUTPUT:
    RETVAL

void
GetMessage(handle,min=0,max=0)
    HWND handle
    UINT min
    UINT max
PREINIT:
    MSG msg;
    BOOL result;
PPCODE:
    result = GetMessage(&msg, handle, min, max);
    if(result == -1) {
        XSRETURN_NO;
    } else {
        EXTEND(SP, 7);
        XST_mIV(0, result);
        XST_mIV(1, msg.message);
        XST_mIV(2, msg.wParam);
        XST_mIV(3, msg.lParam);
        XST_mIV(4, msg.time);
        XST_mIV(5, msg.pt.x);
        XST_mIV(6, msg.pt.y);
        XSRETURN(7);
    } 

void
GetCursorPos()
PREINIT:
    POINT point;
PPCODE:
    if(GetCursorPos(&point)) {
        EXTEND(SP, 2);
        XST_mIV(0, point.x);
        XST_mIV(1, point.y);
        XSRETURN(2);
    } else {
        XSRETURN_NO;
    } 


LRESULT
SendMessage(handle,msg,wparam,lparam)
    HWND handle
    UINT msg
    WPARAM wparam
    LPARAM lparam
CODE:
    RETVAL = SendMessage(handle, msg, wparam, lparam);
OUTPUT:
    RETVAL

LRESULT
PostMessage(handle,msg,wparam,lparam)
    HWND handle
    UINT msg
    WPARAM wparam
    LPARAM lparam
CODE:
    RETVAL = PostMessage(handle, msg, wparam, lparam);
OUTPUT:
    RETVAL

void
PostQuitMessage(...)
PPCODE:
    int exitcode;
    if(items > 0)
        exitcode = SvIV(ST(items-1));
    else
        exitcode = 0;
    PostQuitMessage(exitcode);

BOOL
PeekMessage(handle, min=0, max=0, message=&sv_undef)
    HWND handle
    UINT min
    UINT max
    SV* message
PREINIT:
    MSG msg;
CODE:
    ZeroMemory(&msg, sizeof(msg));
    RETVAL = PeekMessage(&msg, handle, min, max, PM_NOREMOVE);
    if(message != &sv_undef && SvROK(message)) {
        if(SvTYPE(SvRV(message)) == SVt_PVAV) {
            av_clear((AV*) SvRV(message));
            av_push((AV*) SvRV(message), sv_2mortal(newSViv((long) msg.hwnd)));
            av_push((AV*) SvRV(message), sv_2mortal(newSViv(msg.message)));
            av_push((AV*) SvRV(message), sv_2mortal(newSViv(msg.wParam)));
            av_push((AV*) SvRV(message), sv_2mortal(newSViv(msg.lParam)));
            av_push((AV*) SvRV(message), sv_2mortal(newSViv(msg.time)));
            av_push((AV*) SvRV(message), sv_2mortal(newSViv(msg.pt.x)));
            av_push((AV*) SvRV(message), sv_2mortal(newSViv(msg.pt.y)));
#ifndef NT_BUILD_NUMBER
        } else {
            if(dowarn) warn("Win32::GUI: fourth parameter to PeekMessage is not an array reference");
#endif
        }
    }
OUTPUT:
    RETVAL

void
Text(handle,...)
    HWND handle
ALIAS:
    Win32::GUI::Caption = 1
PREINIT:
    char *myBuffer;
    int myLength;
PPCODE:
    if(items > 2) {
        CROAK("Usage: Text(handle, [value]);\n");
    }
    if(items == 1) {
        myLength = GetWindowTextLength(handle)+1;
        if(myLength) {
            myBuffer = (char *) safemalloc(myLength);
            if(GetWindowText(handle, myBuffer, myLength)) {
                EXTEND(SP, 1);
                XST_mPV(0, myBuffer);
                safefree(myBuffer);
                XSRETURN(1);
            }
            safefree(myBuffer);
        }
        XSRETURN_NO;
    } else {
        XSRETURN_IV((long) SetWindowText(handle, (LPCTSTR) SvPV(ST(1), na)));
    }

BOOL
Move(handle,x,y)
    HWND handle
    int x
    int y
CODE:
    RETVAL = SetWindowPos(handle, (HWND) NULL, x, y, 0, 0,
                          SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOSIZE);
OUTPUT:
    RETVAL

BOOL
Resize(handle,x,y)
    HWND handle
    int x
    int y
CODE:
    RETVAL = SetWindowPos(handle, (HWND) NULL, 0, 0, x, y, 
                          SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOMOVE);
OUTPUT:
    RETVAL


void
GetClientRect(handle)
    HWND handle
PREINIT:
    RECT myRect;
PPCODE:
    if(GetClientRect(handle, &myRect)) {
        EXTEND(SP, 4);
        XST_mIV(0, myRect.left);
        XST_mIV(1, myRect.top);
        XST_mIV(2, myRect.right);
        XST_mIV(3, myRect.bottom);        
        XSRETURN(4);
    } else {
        XSRETURN_NO;
    }

void
GetWindowRect(handle)
    HWND handle
PREINIT:
    RECT myRect;
PPCODE:
    if(GetWindowRect(handle, &myRect)) {
        EXTEND(SP, 4);
        XST_mIV(0, myRect.left);
        XST_mIV(1, myRect.top);
        XST_mIV(2, myRect.right);
        XST_mIV(3, myRect.bottom);        
        XSRETURN(4);
    } else {
        XSRETURN_NO;
    }

void
Width(handle,...)
    HWND handle
PREINIT:
    RECT myRect;
PPCODE:
    if(items > 2) {
        croak("Usage: Width(handle, [value]);\n");
    }

    if(!GetWindowRect(handle, &myRect)) XSRETURN_NO;

    if(items == 1) {
        EXTEND(SP, 1);
        XST_mIV(0, (myRect.right-myRect.left));
        XSRETURN(1);
    } else {
        if(SetWindowPos(handle, (HWND) NULL, 0, 0, 
                        (int) SvIV(ST(1)),
                        (int) (myRect.bottom-myRect.top),
                        SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOMOVE)) {
            XSRETURN_YES;
        } else {
            XSRETURN_NO;
        }
    }

void
Height(handle,...)
    HWND handle
PREINIT:
    RECT myRect;
PPCODE:
    if(items > 2) {
        croak("Usage: Height(handle, [value]);\n");
    }

    if(!GetWindowRect(handle, &myRect)) XSRETURN_NO;

    if(items == 1) {
        EXTEND(SP, 1);
        XST_mIV(0, (myRect.bottom-myRect.top));
        XSRETURN(1);
    } else {
        if(SetWindowPos(handle, (HWND) NULL, 0, 0,
                        (int) (myRect.right-myRect.left),
                        (int) SvIV(ST(1)),
                        SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOMOVE)) {
            XSRETURN_YES;
        } else {
            XSRETURN_NO;
        }
    }

void
Left(handle,...)
    HWND handle
PREINIT:
    RECT myRect;
PPCODE:
    if(items > 2) {
        croak("Usage: Left(handle, [value]);\n");
    }

    if(!GetWindowRect(handle, &myRect)) XSRETURN_NO;

    if(items == 1) {
        EXTEND(SP, 1);
        XST_mIV(0, myRect.left);
        XSRETURN(1);
    } else {
        if(SetWindowPos(handle, (HWND) NULL,
                        (int) SvIV(ST(1)), (int) myRect.top,
                        0, 0,
                        SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOSIZE)) {
            XSRETURN_YES;
        } else {
            XSRETURN_NO;
        }
    }

void
Top(handle,...)
    HWND handle
PREINIT:
    RECT myRect;
PPCODE:
    if(items > 2) {
        croak("Usage: Top(handle, [value]);\n");
    }
    if(!GetWindowRect(handle, &myRect)) XSRETURN_NO;
    if(items == 1) {
        EXTEND(SP, 1);
        XST_mIV(0, myRect.top);
        XSRETURN(1);
    } else {
        if(SetWindowPos(handle, (HWND) NULL,
                        (int) myRect.left, (int) SvIV(ST(1)),
                        0, 0,
                        SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOSIZE)) {
            XSRETURN_YES;
        } else {
            XSRETURN_NO;
        }
    }

DWORD
ScaleWidth(handle)
    HWND handle
PREINIT:
    RECT myRect;
CODE:
    if(GetClientRect(handle, &myRect)) {
        RETVAL = myRect.right;
    } else {
        RETVAL = 0;
    }
OUTPUT:
    RETVAL

DWORD
ScaleHeight(handle)
    HWND handle
PREINIT:
    RECT myRect;
CODE:
    if(GetClientRect(handle, &myRect)) {
        RETVAL = myRect.bottom;
    } else {
        RETVAL = 0;
    }
OUTPUT:
    RETVAL
    
BOOL
BringWindowToTop(handle)
    HWND handle
CODE:
    RETVAL = BringWindowToTop(handle);
OUTPUT:
    RETVAL

UINT
ArrangeIconicWindows(handle)
    HWND handle
CODE:
    RETVAL = ArrangeIconicWindows(handle);
OUTPUT:
    RETVAL

HWND
GetDesktopWindow(...)
CODE:
   RETVAL = GetDesktopWindow();
OUTPUT:
   RETVAL

HWND
GetForegroundWindow(...)
CODE:
   RETVAL = GetForegroundWindow();
OUTPUT:
   RETVAL

BOOL
SetForegroundWindow(handle)
    HWND handle
CODE:
    RETVAL = SetForegroundWindow(handle);
OUTPUT:
    RETVAL

BOOL
IsZoomed(handle)
    HWND handle
CODE:
    RETVAL = IsZoomed(handle);
OUTPUT:
    RETVAL

BOOL
IsIconic(handle)
    HWND handle
CODE:
    RETVAL = IsIconic(handle);
OUTPUT:
    RETVAL

BOOL
IsWindow(handle)
    HWND handle
CODE:
    RETVAL = IsWindow(handle);
OUTPUT:
    RETVAL

BOOL
IsVisible(handle)
    HWND handle
CODE:
    RETVAL = IsWindowVisible(handle);
OUTPUT:
    RETVAL

BOOL
IsEnabled(handle)
    HWND handle
CODE:
    RETVAL = IsWindowEnabled(handle);
OUTPUT:
    RETVAL

BOOL
Enable(handle,flag=TRUE)
    HWND handle
    BOOL flag
CODE:
    RETVAL = EnableWindow(handle, flag);
OUTPUT:
    RETVAL

BOOL
Disable(handle)
    HWND handle
CODE:
    RETVAL = EnableWindow(handle, FALSE);
OUTPUT:
    RETVAL

BOOL
OpenIcon(handle)
    HWND handle
ALIAS:
    Win32::GUI::Restore = 1
CODE:
    RETVAL = OpenIcon(handle);
OUTPUT:
    RETVAL

BOOL
CloseWindow(handle)
    HWND handle
ALIAS:
    Win32::GUI::Minimize = 1
CODE:
    RETVAL = CloseWindow(handle);
OUTPUT:
    RETVAL

HWND
WindowFromPoint(x,y)
    LONG x
    LONG y
PREINIT:
    POINT myPoint;
CODE:
    myPoint.x = x;
    myPoint.y = y;
    RETVAL = WindowFromPoint(myPoint);
OUTPUT:
    RETVAL

HWND
GetTopWindow(handle)
    HWND handle
CODE:
    RETVAL = GetTopWindow(handle);
OUTPUT:
    RETVAL

HWND
GetActiveWindow(...)
CODE:
    RETVAL = GetActiveWindow();
OUTPUT:
    RETVAL

HWND
GetFocus(...)
CODE:
    RETVAL = GetFocus();
OUTPUT:
    RETVAL

HWND
SetFocus(handle)
    HWND handle
CODE:
    RETVAL = SetFocus(handle);
OUTPUT:
    RETVAL

void
GetTextExtentPoint32(handle,font=NULL,string)
    HWND handle
    HFONT font
    char * string
PREINIT:
    STRLEN cbString;
    char *szString;
    HDC hdc;
    SIZE mySize;
PPCODE:
    szString = SvPV(ST(1), cbString);
    hdc = GetDC(handle);
#ifdef WIN32__GUI__DEBUG
    printf("XS(GetTextExtentPoint32).font=%ld\n", font);
    printf("XS(GetTextExtentPoint32).string=%s\n", string);
#endif
    if(font)
        SelectObject(hdc, (HGDIOBJ) font);
    if(GetTextExtentPoint(hdc, szString, (int)cbString, &mySize)) {
        EXTEND(SP, 2);
        XST_mIV(0, mySize.cx);
        XST_mIV(1, mySize.cy);
        ReleaseDC(handle, hdc);
        XSRETURN(2);
    } else {
        ReleaseDC(handle, hdc);
        XSRETURN_NO;
    }

BOOL
TrackPopupMenu(handle,hmenu,x,y,flags=TPM_LEFTALIGN|TPM_TOPALIGN|TPM_LEFTBUTTON)
    HWND handle
    HMENU hmenu
    int x
    int y
    UINT flags
CODE:
    RETVAL = TrackPopupMenu(hmenu, flags, x, y, 0, handle, (CONST RECT*) NULL);
OUTPUT:
    RETVAL


 #############################################
 # DC-related functions (2D window graphic...)
 #############################################

int
PlayEnhMetaFile(handle,filename)
    HWND handle
    LPCTSTR filename
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
    COLORREF color;
    STRLEN textlen;
    HENHMETAFILE hmeta;
    RECT rect;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        if(hmeta = GetEnhMetaFile(filename)) {
            GetClientRect(handle, &rect);
            RETVAL = PlayEnhMetaFile(hdc, hmeta, &rect);
            DeleteEnhMetaFile(hmeta);
        } else {
#ifdef WIN32__GUI__DEBUG
            printf("XS(PlayEnhMetaFile): GetEnhMetaFile failed, error = %d\n", GetLastError());
#endif
            RETVAL = 0;
        }
    }
OUTPUT:
    RETVAL

int
PlayWinMetaFile(handle,filename)
    HWND handle
    LPCTSTR filename
PREINIT:
    HDC hdc;
    HMETAFILE hwinmeta;
    HENHMETAFILE hmeta;
    RECT rect;
    UINT size;
    LPVOID data;
CODE:
#ifdef WIN32__GUI__DEBUG
    printf("XS(PlayWinMetaFile): filename = %s\n", filename);
#endif
    SetLastError(0);
    hwinmeta = GetMetaFile(filename);
#ifdef WIN32__GUI__DEBUG
    printf("XS(PlayWinMetaFile): hwinmeta = %ld\n", hwinmeta);
    printf("XS(PlayWinMetaFile): GetLastError = %ld\n", GetLastError());
#endif
    size = GetMetaFileBitsEx(hwinmeta, 0, NULL);
#ifdef WIN32__GUI__DEBUG
    printf("XS(PlayWinMetaFile): size = %d\n", size);
#endif
    data = (LPVOID) safemalloc(size);
    GetMetaFileBitsEx(hwinmeta, size, data);
    hmeta = SetWinMetaFileBits(size, (CONST BYTE *) data, NULL, NULL);
#ifdef WIN32__GUI__DEBUG
    printf("XS(PlayWinMetaFile): hmeta = %ld\n", hmeta);
#endif
    hdc = GetDC(handle);
    GetClientRect(handle, &rect);
    SetLastError(0);
    RETVAL = PlayEnhMetaFile(hdc, hmeta, &rect);
#ifdef WIN32__GUI__DEBUG
    printf("XS(PlayWinMetaFile): GetLastError after PlayEnhMetaFile = %d\n", GetLastError());
#endif
    DeleteEnhMetaFile(hmeta);
    ReleaseDC(handle, hdc);
    safefree(data);
OUTPUT:
    RETVAL


HDC
CreateEnhMetaFile(handle, filename, description=NULL)
    HWND handle
    LPCTSTR filename
    LPCTSTR description
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
    RECT rect;
    int iWidthMM, iHeightMM, iWidthPels, iHeightPels;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = 0;
    } else {
        hdc = (HDC) SvIV(*tmp);
        iWidthMM = GetDeviceCaps(hdc, HORZSIZE); 
        iHeightMM = GetDeviceCaps(hdc, VERTSIZE); 
        iWidthPels = GetDeviceCaps(hdc, HORZRES); 
        iHeightPels = GetDeviceCaps(hdc, VERTRES); 
        GetClientRect(handle, &rect);
        rect.left = (rect.left * iWidthMM * 100)/iWidthPels; 
        rect.top = (rect.top * iHeightMM * 100)/iHeightPels; 
        rect.right = (rect.right * iWidthMM * 100)/iWidthPels; 
        rect.bottom = (rect.bottom * iHeightMM * 100)/iHeightPels; 
        RETVAL = CreateEnhMetaFile(hdc, filename, &rect, description);
    }
OUTPUT:
    RETVAL

HENHMETAFILE
CloseEnhMetaFile(hdc)
    HDC hdc
CODE:
    RETVAL = CloseEnhMetaFile(hdc);
OUTPUT:
    RETVAL

BOOL
DeleteEnhMetaFile(hmeta)
    HENHMETAFILE hmeta
CODE:
    RETVAL = DeleteEnhMetaFile(hmeta);
OUTPUT:
    RETVAL


    #HDC GetOrInitDC(SV* obj) {
    #    CPerl *pPerl;
    #    HDC hdc;
    #    HWND hwnd;
    #    SV** obj_dc;
    #    SV** obj_hwnd;
    #
    #    pPerl = theperl;
    #
    #    obj_dc = hv_fetch((HV*)SvRV(obj), "dc", 2, 0);
    #    if(obj_dc != NULL) {
    ##ifdef WIN32__GUI__DEBUG
    #        printf("!XS(GetOrInitDC): obj{dc} = %ld\n", SvIV(*obj_dc));
    ##endif
    #        return (HDC) SvIV(*obj_dc);
    #    } else {
    #        obj_hwnd = hv_fetch((HV*)SvRV(obj), "handle", 6, 0);
    #        hwnd = (HWND) SvIV(*obj_hwnd);
    #        hdc = GetDC(hwnd);
    ##ifdef WIN32__GUI__DEBUG
    #        printf("!XS(GetOrInitDC): GetDC = %ld\n", hdc);
    ##endif
    #        hv_store((HV*) SvRV(obj), "dc", 2, newSViv((long) hdc), 0);
    #        return hdc;
    #    }
    #}
    #
    #
    #XS(XS_Win32__GUI_DrawText) {
    #
    #    dXSARGS;
    #    if(items < 4 || items > 7) {
    #        CROAK("usage: DrawText($handle, $text, $left, $top, [$width, $height, $format]);\n");
    #    }
    #    
    #    HDC hdc = GetOrInitDC(ST(0));
    #    RECT myRect;
    #
    #    STRLEN cbString;
    #    char *szString = SvPV(ST(1), cbString);
    #
    #    myRect.left   = (LONG) SvIV(ST(2));
    #    myRect.top    = (LONG) SvIV(ST(3));
    #
    #    if(items >4) {
    #        myRect.right  = (LONG) SvIV(ST(4));
    #        myRect.bottom = (LONG) SvIV(ST(5));
    #    } else {
    #        SIZE mySize;
    #        GetTextExtentPoint(hdc, szString, (int)cbString, &mySize);
    #        myRect.right  = myRect.left + (UINT) mySize.cx;
    #        myRect.bottom = myRect.top  + (UINT) mySize.cy;
    #    }
    #
    #    UINT uFormat = DT_LEFT;
    #
    #    if(items == 7) {
    #        uFormat = (UINT) SvIV(ST(6));
    #    }
    #
    #    BOOL result = DrawText(hdc, 
    #                           szString,
    #                           cbString,
    #                           &myRect,
    #                           uFormat);
    #    XSRETURN_IV((long) result);
    #}
    #
    #
    #
    #
    #XS(XS_Win32__GUI_ReleaseDC) {
    #
    #    dXSARGS;
    #    if(items != 1) {
    #        CROAK("usage: ReleaseDC($handle);\n");
    #    }
    #    
    #    HWND hwnd = (HWND) handle_From(ST(0));
    #    HDC hdc = GetOrInitDC(ST(0));
    #
    #    ReleaseDC(hwnd, hdc);
    #    hv_delete((HV*) SvRV(ST(0)), "dc", 2, 0);
    #
    #    XSRETURN_NO;
    #}
    #
    #

long
TextOut(handle, x, y, text)
    HWND handle
    int x
    int y
    char * text
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
    COLORREF color;
    STRLEN textlen;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        textlen = strlen(text);
        RETVAL = (long) TextOut(hdc, x, y, text, textlen);
    }
OUTPUT:
    RETVAL

long
SetTextColor(handle, red, green=0, blue=0)
    HWND handle
    DWORD red
    DWORD green
    DWORD blue
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
    COLORREF color;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        if(items == 2) {
            color = (COLORREF) SvIV(ST(1));
        } else {
            color = RGB((BYTE) red, (BYTE) green, (BYTE) blue);
        }
        RETVAL = SetTextColor(hdc, color);
    }
OUTPUT:
    RETVAL

long
GetTextColor(handle)
    HWND handle
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        RETVAL = GetTextColor(hdc);
    }
OUTPUT:
    RETVAL

long
SetBkMode(handle, mode)
    HWND handle
    int mode
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
    COLORREF color;
    STRLEN textlen;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        RETVAL = (long) SetBkMode(hdc, mode);
    }
OUTPUT:
    RETVAL

int
GetBkMode(handle)
    HWND handle
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
    COLORREF color;
    STRLEN textlen;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        RETVAL = GetBkMode(hdc);
    }
OUTPUT:
    RETVAL

long
MoveTo(handle, x, y)
    HWND handle
    int x
    int y
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        RETVAL = MoveToEx(hdc, x, y, NULL);
    }
OUTPUT:
    RETVAL

long
Circle(handle, x, y, width, height=-1)
    HWND handle
    int x
    int y
    int width
    int height
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        if(height == -1) {
            width *= 2;
            height = width;
        }
        RETVAL = (long) Arc(hdc, x, y, width-x, height-y, 0, 0, 0, 0);
    }
OUTPUT:
    RETVAL


long
LineTo(handle, x, y)
    HWND handle
    int x
    int y
PREINIT:
    HV* self;
    HDC hdc;
    SV** tmp;
CODE:
    self = (HV*) SvRV(ST(0));
    tmp = hv_fetch(self, "DC", 2, 0);
    if(tmp == NULL) {
        RETVAL = -1;
    } else {
        hdc = (HDC) SvIV(*tmp);
        RETVAL = LineTo(hdc, x, y);
    }
OUTPUT:
    RETVAL

    #}
    #
    #XS(XS_Win32__GUI_DrawEdge) {
    #
    #    dXSARGS;
    #    if(items != 7) {
    #        CROAK("usage: DrawEdge($handle, $left, $top, $width, $height, $edge, $flags);\n");
    #    }
    #    
    #    HDC hdc = GetOrInitDC(ST(0));
    #    RECT myRect;
    #    myRect.left   = (LONG) SvIV(ST(1));
    #    myRect.top    = (LONG) SvIV(ST(2));
    #    myRect.right  = (LONG) SvIV(ST(3));
    #    myRect.bottom = (LONG) SvIV(ST(4));
    #
    #    XSRETURN_IV((long) DrawEdge(hdc, 
    #                           &myRect,
    #                           (UINT) SvIV(ST(5)),
    #                           (UINT) SvIV(ST(6))));
    #}

void
BeginPaint(...)
PPCODE:
    HV* self;
    HWND hwnd;
    HDC hdc;
    int i;
    PAINTSTRUCT ps;
    char tmprgb[16];
    self = (HV*) SvRV(ST(0));
    hwnd = (HWND) SvIV(*hv_fetch(self, "handle", 6, 0));
    if(hwnd) {
        if(hdc = BeginPaint(hwnd, &ps)) {
            hv_store(self, "DC", 2, newSViv((long) hdc), 0);
            hv_store(self, "ps.hdc", 6, newSViv((long) ps.hdc), 0);
            hv_store(self, "ps.fErase", 9, newSViv((long) ps.fErase), 0);
            hv_store(self, "ps.rcPaint.left", 15, newSViv((long) ps.rcPaint.left), 0);
            hv_store(self, "ps.rcPaint.top", 14, newSViv((long) ps.rcPaint.top), 0);
            hv_store(self, "ps.rcPaint.right", 16, newSViv((long) ps.rcPaint.right), 0);
            hv_store(self, "ps.rcPaint.bottom", 17, newSViv((long) ps.rcPaint.bottom), 0);
            hv_store(self, "ps.fRestore", 11, newSViv((long) ps.fRestore), 0);
            hv_store(self, "ps.fIncUpdate", 13, newSViv((long) ps.fIncUpdate), 0);
            for(i=0;i<=31;i++) {
                sprintf(tmprgb, "ps.rgbReserved%02d", i);
                hv_store(self, tmprgb, 16, newSViv((long) ps.rgbReserved[i]), 0);
            }
            XSRETURN_YES;
        } else {
            XSRETURN_NO;
        }
    } else {
        XSRETURN_NO;
    }
    
void
EndPaint(...)
PPCODE:
    HV* self;
    HWND hwnd;
    HDC hdc;
    SV** tmp;
    int i;
    PAINTSTRUCT ps;
    char tmprgb[16];
    BOOL result;

    self = (HV*) SvRV(ST(0));
    if(self) {
        tmp = hv_fetch(self, "ps.hdc", 6, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.hdc = (HDC) SvIV(*tmp);
        tmp = hv_fetch(self, "ps.fErase", 9, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.fErase = (BOOL) SvIV(*tmp);
        tmp = hv_fetch(self, "ps.rcPaint.left", 15, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.rcPaint.left = (LONG) SvIV(*tmp);
        tmp = hv_fetch(self, "ps.rcPaint.top", 14, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.rcPaint.top = (LONG) SvIV(*tmp);
        tmp = hv_fetch(self, "ps.rcPaint.right", 16, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.rcPaint.right = (LONG) SvIV(*tmp);
        tmp = hv_fetch(self, "ps.rcPaint.bottom", 17, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.rcPaint.bottom = (LONG) SvIV(*tmp);
        tmp = hv_fetch(self, "ps.fRestore", 11, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.fRestore = (BOOL) SvIV(*tmp);
        tmp = hv_fetch(self, "ps.fIncUpdate", 13, 0);
        if(tmp == NULL) XSRETURN_NO;
        ps.fIncUpdate = (BOOL) SvIV(*tmp);
        for(i=0;i<=31;i++) {
            sprintf(tmprgb, "ps.rgbReserved%02d", i);
            tmp = hv_fetch(self, tmprgb, 16, 0);
            if(tmp == NULL) XSRETURN_NO;
            ps.rgbReserved[i] = (BYTE) SvIV(*tmp);
        }
        result = EndPaint(hwnd, &ps);
        hv_delete(self, "DC", 2, 0);
        hv_delete(self, "ps.hdc", 6, 0);
        hv_delete(self, "ps.fErase", 9, 0);
        hv_delete(self, "ps.rcPaint.left", 15, 0);
        hv_delete(self, "ps.rcPaint.top", 14, 0);
        hv_delete(self, "ps.rcPaint.right", 16, 0);
        hv_delete(self, "ps.rcPaint.bottom", 17, 0);
        hv_delete(self, "ps.fRestore", 11, 0);
        hv_delete(self, "ps.fIncUpdate", 13, 0);
        for(i=0;i<=31;i++) {
            sprintf(tmprgb, "ps.rgbReserved%02d", i);
            hv_delete(self, tmprgb, 16, 0);
        }
        hv_delete(self, "DC", 2, 0);
        XSRETURN_IV((long) result);
    } else {
        XSRETURN_NO;
    }



 #####################
 # Common Dialog Boxes
 #####################

int 
MessageBox(handle=NULL, text, caption=NULL, type=MB_ICONWARNING|MB_OK)
    HWND handle
    LPCTSTR text
    LPCTSTR caption
    UINT type
CODE:
    RETVAL = MessageBox(handle, text, caption, type);
OUTPUT:
    RETVAL

void
GetOpenFileName(...)
PPCODE:
    OPENFILENAME ofn;
    BOOL retval;
    int i, next_i;
    char filename[MAX_PATH];
    char *option;

    ZeroMemory(&ofn, sizeof(OPENFILENAME));
    ofn.lStructSize = sizeof(OPENFILENAME);
    ofn.hwndOwner = NULL;
    ofn.lpstrFilter = NULL;
    ofn.lpstrCustomFilter = NULL;
    ofn.nFilterIndex = 0;
    ofn.lpstrFileTitle = NULL;
    ofn.lpstrInitialDir = NULL;
    ofn.lpstrTitle = NULL;
    ofn.lpstrDefExt = NULL;
    ofn.lpTemplateName = NULL;
    ofn.Flags = 0;
    filename[0] = 0;
    ofn.lpstrFile = filename;
    ofn.nMaxFile = MAX_PATH;

    next_i = -1;
    for(i = 0; i < items; i++) {
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-owner") == 0) {
                next_i = i + 1;
                ofn.hwndOwner = (HWND) handle_From(ST(next_i));
            }
            if(strcmp(option, "-title") == 0) {
                next_i = i + 1;
                ofn.lpstrTitle = SvPV(ST(next_i), na);
            }
            if(strcmp(option, "-directory") == 0) {
                next_i = i + 1;
                ofn.lpstrInitialDir = SvPV(ST(next_i), na);
            }
            if(strcmp(option, "-file") == 0) {
                next_i = i + 1;
                strcpy(filename, SvPV(ST(next_i), na));
            }
        } else {
            next_i = -1;
        }
    }
    retval = GetOpenFileName(&ofn);
    if(retval) {
        EXTEND(SP, 1);
        XST_mPV( 0, ofn.lpstrFile);
        XSRETURN(1);
    } else {
        XSRETURN_NO;
    }


void
ChooseColor(...)
PPCODE:
    CHOOSECOLOR cc;
    COLORREF lpCustColors[16];
    BOOL retval;
    int i, next_i;
    unsigned int lpstrLen;

    ZeroMemory(&cc, sizeof(CHOOSECOLOR));
    cc.lStructSize = sizeof(CHOOSECOLOR);
    cc.hwndOwner = NULL;
    cc.lpCustColors = lpCustColors;
    cc.lpTemplateName = NULL;
    cc.Flags = 0;
    cc.rgbResult = 0;

    next_i = -1;
    for(i = 0; i < items; i++) {
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-owner") == 0) {
                next_i = i + 1;
                cc.hwndOwner = (HWND) handle_From(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-color") == 0) {
                next_i = i + 1;
                cc.rgbResult = (COLORREF) SvIV(ST(next_i));
                cc.Flags = cc.Flags | CC_RGBINIT;
            }
        } else {
            next_i = -1;
        }
    }

    retval = ChooseColor(&cc);

    if(retval) {
        EXTEND(SP, 1);
        XST_mIV(0, cc.rgbResult);
        XSRETURN(1);
    } else {
        XSRETURN_NO;
    }


void
ChooseFont(...)
PPCODE:
    CHOOSEFONT cf;
    static LOGFONT lf;
    BOOL retval;
    int i, next_i;
    char *option;
    unsigned int lpstrLen;

    ZeroMemory(&cf, sizeof(CHOOSEFONT));
    cf.lStructSize = sizeof(CHOOSEFONT);
    cf.hwndOwner = NULL;
    cf.lpLogFont = &lf;    
    cf.lpTemplateName = NULL;
    cf.Flags = CF_SCREENFONTS;

    next_i = -1;
    for(i = 0; i < items; i++) {
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-owner") == 0) {
                next_i = i + 1;
                cf.hwndOwner = (HWND) handle_From(ST(next_i));
            }
            if(strcmp(option, "-size") == 0) {
                next_i = i + 1;
                cf.iPointSize = SvIV(ST(next_i));
            }
            if(strcmp(option, "-height") == 0) {
                next_i = i + 1;
                lf.lfHeight = SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);

            }
            if(strcmp(option, "-width") == 0) {
                next_i = i + 1;
                lf.lfWidth = SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-escapement") == 0) {
                next_i = i + 1;
                lf.lfEscapement = SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-orientation") == 0) {
                next_i = i + 1;
                lf.lfOrientation = SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-weight") == 0) {
                next_i = i + 1;
                lf.lfWeight = (int) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-bold") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) lf.lfWeight = 700;
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-italic") == 0) {
                next_i = i + 1;
                lf.lfItalic = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-underline") == 0) {
                next_i = i + 1;
                lf.lfUnderline = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-strikeout") == 0) {
                next_i = i + 1;
                lf.lfStrikeOut = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-charset") == 0) {
                next_i = i + 1;
                lf.lfCharSet = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-outputprecision") == 0) {
                next_i = i + 1;
                lf.lfOutPrecision = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-clipprecision") == 0) {
                next_i = i + 1;
                lf.lfClipPrecision = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-quality") == 0) {
                next_i = i + 1;
                lf.lfQuality = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-family") == 0) {
                next_i = i + 1;
                lf.lfPitchAndFamily = (BYTE) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-name") == 0
            || strcmp(option, "-face") == 0) {
                next_i = i + 1;
                strncpy(lf.lfFaceName, SvPV(ST(next_i), na), 32);
                SwitchFlag(cf.Flags, CF_INITTOLOGFONTSTRUCT, 1);
            }
            if(strcmp(option, "-color") == 0) {
                next_i = i + 1;
                cf.rgbColors = (DWORD) SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_EFFECTS, 1);
            }
            if(strcmp(option, "-ttonly") == 0) {
                next_i = i + 1;
                SwitchFlag(cf.Flags, CF_TTONLY, SvIV(ST(next_i)));
            }
            if(strcmp(option, "-fixedonly") == 0) {
                next_i = i + 1;
                SwitchFlag(cf.Flags, CF_FIXEDPITCHONLY, SvIV(ST(next_i)));
            }
            if(strcmp(option, "-effects") == 0) {
                next_i = i + 1;
                SwitchFlag(cf.Flags, CF_EFFECTS, SvIV(ST(next_i)));
            }
            if(strcmp(option, "-script") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) == 0) {
                    SwitchFlag(cf.Flags, CF_NOSCRIPTSEL, 1);
                } else {
                    SwitchFlag(cf.Flags, CF_NOSCRIPTSEL, 0);
                }
            }
            if(strcmp(option, "-minsize") == 0) {
                next_i = i + 1;
                cf.nSizeMin = SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_LIMITSIZE, 1);
            }
            if(strcmp(option, "-maxsize") == 0) {
                next_i = i + 1;
                cf.nSizeMax = SvIV(ST(next_i));
                SwitchFlag(cf.Flags, CF_LIMITSIZE, 1);
            }


        } else {
            next_i = -1;
        }
    }
    retval = ChooseFont(&cf);
    if(retval) {
        EXTEND(SP, 18);
        XST_mPV( 0, "-name");
        XST_mPV( 1, lf.lfFaceName);
        XST_mPV( 2, "-height");
        XST_mIV( 3, lf.lfHeight);
        XST_mPV( 4, "-width");
        XST_mIV( 5, lf.lfWidth);
        XST_mPV( 6, "-weight");
        XST_mIV( 7, lf.lfWeight);
        XST_mPV( 8, "-size");
        XST_mIV( 9, cf.iPointSize);
        XST_mPV(10, "-italic");
        XST_mIV(11, lf.lfItalic);
        XST_mPV(12, "-underline");
        XST_mIV(13, lf.lfUnderline);
        XST_mPV(14, "-strikeout");
        XST_mIV(15, lf.lfStrikeOut);
        XST_mPV(16, "-color");
        XST_mIV(17, cf.rgbColors);
        // XST_mPV(18, "-style");
        // XST_mPV(19, cf.lpszStyle);
        // XSRETURN(20);
        XSRETURN(18);
    } else
        XSRETURN_NO;

DWORD
CommDlgExtendedError(...)
CODE:
    RETVAL = CommDlgExtendedError();
OUTPUT:
    RETVAL


 ################################################
 # Win32::GUI::Menu functions (not really yet...)
 ################################################

HMENU
CreateMenu(...)
CODE:
    RETVAL = CreateMenu();
OUTPUT:
    RETVAL

HMENU
CreatePopupMenu(...)
CODE:
    RETVAL = CreatePopupMenu();
OUTPUT:
    RETVAL

BOOL
SetMenu(handle,menu)
    HWND handle
    HMENU menu
CODE:
    RETVAL = SetMenu(handle, menu);
OUTPUT:
    RETVAL
    
HMENU
GetMenu(handle)
    HWND handle
CODE:
    RETVAL = GetMenu(handle);
OUTPUT:
    RETVAL

BOOL
DrawMenuBar(handle)
    HWND handle
CODE:
    RETVAL = DrawMenuBar(handle);
OUTPUT:
    RETVAL

BOOL
DestroyMenu(hmenu)
    HMENU hmenu
CODE:
    RETVAL = DestroyMenu(hmenu);
OUTPUT:
    RETVAL

BOOL
InsertMenuItem(...)
PREINIT:
    MENUITEMINFO myMII;
    int i, next_i;
    UINT myItem;    
CODE:
    ZeroMemory(&myMII, sizeof(MENUITEMINFO));
    myMII.cbSize = sizeof(MENUITEMINFO);
    myItem = 0;

    ParseMenuItemOptions(1, &myMII, &myItem);

    myMII.hbmpChecked = NULL;
    myMII.hbmpUnchecked = NULL;

    RETVAL = InsertMenuItem(
        (HMENU) handle_From(ST(0)),
        myItem,
        FALSE,
        &myMII
    );
OUTPUT:
    RETVAL

BOOL
SetMenuItemInfo(...)
PREINIT:
    MENUITEMINFO myMII;
    int i, next_i;
    UINT myItem;
    HMENU hMenu;
    SV** parentmenu;
CODE:
    if(SvROK(ST(0))) {
        parentmenu = hv_fetch((HV*)SvRV((ST(0))), "menu", 4, 0);
        if(parentmenu != NULL) {
            hMenu = (HMENU) SvIV(*parentmenu);
            myItem = SvIV(*(hv_fetch((HV*)SvRV(ST(0)), "id", 2, 0)));
        } else {            
            hMenu = (HMENU) handle_From(ST(0));
        }
    }
    ZeroMemory(&myMII, sizeof(MENUITEMINFO));
    myMII.cbSize = sizeof(MENUITEMINFO);
    ParseMenuItemOptions(1, &myMII, &myItem);
    myMII.hbmpChecked = NULL;
    myMII.hbmpUnchecked = NULL;
#ifdef WIN32__GUI__DEBUG
    printf("XS(SetMenuItemInfo): hMenu=%ld\n", hMenu);
    printf("XS(SetMenuItemInfo): myItem=%d\n", myItem);
#endif
    RETVAL = SetMenuItemInfo(
        hMenu,
        myItem,
        FALSE,
        &myMII
    );
OUTPUT:
    RETVAL

void
Checked(...)
PPCODE:
    MENUITEMINFO myMII;
    int i;
    UINT myItem;
    HMENU hMenu;
    SV** parentmenu;

    if(SvROK(ST(0))) {
        parentmenu = hv_fetch((HV*)SvRV((ST(0))), "menu", 4, 0);
        if(parentmenu != NULL) {
            hMenu = (HMENU) SvIV(*parentmenu);
            myItem = SvIV(*(hv_fetch((HV*)SvRV(ST(0)), "id", 2, 0)));
            i = 1;
        } else {            
            hMenu = (HMENU) handle_From(ST(0));
            myItem = SvIV(ST(1));
            i = 2;
        }
    }
    ZeroMemory(&myMII, sizeof(MENUITEMINFO));
    myMII.cbSize = sizeof(MENUITEMINFO);
    myMII.fMask = MIIM_STATE;
    if(GetMenuItemInfo(hMenu,
                       myItem,
                       FALSE,
                       &myMII)) {
        if(items > i) {
            myMII.fMask = MIIM_STATE;
            SwitchFlag(myMII.fState, MFS_CHECKED, SvIV(ST(i)));
            XSRETURN_IV(SetMenuItemInfo(hMenu,
                                        myItem,
                                        FALSE,
                                        &myMII));
        } else {
            XSRETURN_IV((myMII.fState & MFS_CHECKED) ? 1 : 0);
        }
    } else {
        XSRETURN_NO;
    }

void
Enabled(...)
PPCODE:
    MENUITEMINFO myMII;
    int i, x;
    UINT myItem;
    HMENU hMenu;
    SV** parentmenu;

    if(SvROK(ST(0))) {
        parentmenu = hv_fetch((HV*)SvRV((ST(0))), "menu", 4, 0);
        if(parentmenu != NULL) {
            hMenu = (HMENU) SvIV(*parentmenu);
            myItem = SvIV(*(hv_fetch((HV*)SvRV(ST(0)), "id", 2, 0)));
            i = 1;
        } else {            
            hMenu = (HMENU) handle_From(ST(0));
            myItem = SvIV(ST(1));
            i = 2;
        }
    }
    ZeroMemory(&myMII, sizeof(MENUITEMINFO));
    myMII.cbSize = sizeof(MENUITEMINFO);
    myMII.fMask = MIIM_STATE;
    if(GetMenuItemInfo(hMenu,
                       myItem,
                       FALSE,
                       &myMII)) {
        if(items > i) {
            myMII.fMask = MIIM_STATE;
            x = (SvIV(ST(i))) ? 0 : 1;
            SwitchFlag(myMII.fState, MFS_DISABLED, x);
            XSRETURN_IV(SetMenuItemInfo(hMenu,
                                        myItem,
                                        FALSE,
                                        &myMII));
        } else {
            XSRETURN_IV((myMII.fState & MFS_DISABLED) ? 0 : 1);
        }
    } else {
        XSRETURN_NO;
    }



BOOL
DESTROY(handle)
    HMENU handle
CODE:
    RETVAL = DestroyMenu(handle);
OUTPUT:
    RETVAL


HGDIOBJ
SelectObject(handle,hgdiobj)
    HWND handle
    HGDIOBJ hgdiobj
CODE:
    RETVAL = SelectObject(handle, hgdiobj);
OUTPUT:
    RETVAL

BOOL
DeleteObject(hgdiobj)
    HGDIOBJ hgdiobj
CODE:
    RETVAL = DeleteObject(hgdiobj);
OUTPUT:
    RETVAL

HGDIOBJ
GetStockObject(object)
    int object
CODE:
    RETVAL = GetStockObject(object);
OUTPUT:
    RETVAL


int
GetSystemMetrics(index)
    int index
CODE:
    RETVAL = GetSystemMetrics(index);
OUTPUT:
    RETVAL


  #################################
  # Win32::GUI::DialogBox functions
  #################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::DialogBox

DWORD
Dialog(...)
PPCODE:
    HWND hwnd;
    MSG msg;
    int stayhere;
    stayhere = 1;

    if(items > 0) {
        hwnd = (HWND) handle_From(ST(0));
    } else {
        hwnd = NULL;
    }
    
    while (stayhere) {
        stayhere = GetMessage(&msg, hwnd, 0, 0);
        if(msg.message == WM_EXITLOOP) {
            stayhere = 0;
            msg.wParam = -1;
        } else {
            if(stayhere == -1) {
                stayhere = 0;
                msg.wParam = -2; // an error occurred...
            } else {
                if(!IsDialogMessage(hwnd, &msg)) {
                    TranslateMessage(&msg); 
                    DispatchMessage(&msg); 
                }
            }
        }
    } 
    XSRETURN_IV((long) msg.wParam);


  #################################
  # Win32::GUI::Textfield functions
  #################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::Textfield

LRESULT
ReplaceSel(handle,string,flag=TRUE)
    HWND handle
    LPCTSTR string
    BOOL flag
CODE:
    RETVAL = SendMessage(
        handle, EM_REPLACESEL, (WPARAM) flag, (LPARAM) string
    );
OUTPUT:
    RETVAL

BOOL
ReadOnly(handle,...)
    HWND handle
CODE:
    if(items > 1)
        RETVAL = SendMessage(
            handle, EM_SETREADONLY, (WPARAM) (BOOL) SvIV(ST(1)), 0
        );
    else
        RETVAL = (GetWindowLong(handle, GWL_STYLE) & ES_READONLY);
OUTPUT:
    RETVAL


BOOL
Modified(handle,...)
    HWND handle
CODE:
    if(items > 1)
        RETVAL = SendMessage(
            handle, EM_SETMODIFY, (WPARAM) (UINT) SvIV(ST(1)), 0
        );
    else
        RETVAL = SendMessage(handle, EM_GETMODIFY, 0, 0);
OUTPUT:
    RETVAL

BOOL
Undo(handle)
    HWND handle
CODE:
    if (SendMessage(handle, EM_CANUNDO, 0, 0)) 
        RETVAL = SendMessage(handle, EM_UNDO, 0, 0); 
    else
        RETVAL = 0;
OUTPUT:
    RETVAL

  ###############################
  # Win32::GUI::Listbox functions
  ###############################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::Listbox

LRESULT
AddString(handle,string)
    HWND handle
    LPCTSTR string
CODE:
    RETVAL = SendMessage(handle, LB_ADDSTRING, 0, (LPARAM) string);
OUTPUT:
    RETVAL

LRESULT
InsertItem(handle,string,index=-1)
    HWND handle
    LPCTSTR string
    WPARAM index
CODE:
    RETVAL = SendMessage(handle, LB_INSERTSTRING, index, (LPARAM) string);
OUTPUT:
    RETVAL


void
GetString(handle,index)
    HWND handle
    WPARAM index
PREINIT:
    STRLEN cbString;
    char *szString;
PPCODE:
    cbString = SendMessage(handle, LB_GETTEXTLEN, index, 0);
    szString = (char *) safemalloc(cbString);
    if(SendMessage(handle, LB_GETTEXT, 
                   index, (LPARAM) (LPCTSTR) szString) != LB_ERR) {
        EXTEND(SP, 1);
        XST_mPV(0, szString);
        safefree(szString);
        XSRETURN(1);
    } else {
        safefree(szString);
        XSRETURN_NO;
    }



  ################################
  # Win32::GUI::Combobox functions
  ################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::Combobox

LRESULT
AddString(handle,string)
    HWND handle
    LPCTSTR string
CODE:
    RETVAL = SendMessage(handle, CB_ADDSTRING, 0, (LPARAM) string);
OUTPUT:
    RETVAL

LRESULT
InsertItem(handle,string,index=-1)
    HWND handle
    LPCTSTR string
    WPARAM index
CODE:
    RETVAL = SendMessage(handle, CB_INSERTSTRING, index, (LPARAM) string);
OUTPUT:
    RETVAL

void
GetString(handle,index)
    HWND handle
    WPARAM index
PREINIT:
    STRLEN cbString;
    char *szString;
PPCODE:
    cbString = SendMessage(handle, CB_GETLBTEXTLEN, index, 0);
    szString = (char *) safemalloc(cbString);
    if(SendMessage(handle, CB_GETLBTEXT, 
                   index, (LPARAM) (LPCTSTR) szString) != LB_ERR) {
        EXTEND(SP, 1);
        XST_mPV(0, szString);
        safefree(szString);
        XSRETURN(1);
    } else {
        safefree(szString);
        XSRETURN_NO;
    }


  ################################
  # Win32::GUI::TabStrip functions
  ################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::TabStrip

int
InsertItem(handle,...)
    HWND handle
PREINIT:
    TC_ITEM Item;
    int iIndex;
    int iText;
    unsigned int chText;
    int i, next_i;
CODE:
    ZeroMemory(&Item, sizeof(TC_ITEM));
    iIndex = TabCtrl_GetItemCount(handle)+1;
    next_i = -1;
    for(i = 1; i < items; i++) {
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-image") == 0) {
                next_i = i + 1;
                Item.mask = Item.mask | TCIF_IMAGE;
                Item.iImage = SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-index") == 0) {
                next_i = i + 1;
                iIndex = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-text") == 0) {
                next_i = i + 1;
                Item.pszText = SvPV(ST(next_i), chText);
                Item.cchTextMax = (int) chText;
                Item.mask = Item.mask | TCIF_TEXT;
            }
        } else {
            next_i = -1;
        }
    }
    RETVAL = TabCtrl_InsertItem(handle, iIndex, &Item);
OUTPUT:
    RETVAL

BOOL
ChangeItem(handle,item,...)
    HWND handle
    int item
PREINIT:
    TC_ITEM Item;
    int iIndex;
    int iText;
    unsigned int chText;
    int i, next_i;
CODE:
    ZeroMemory(&Item, sizeof(TC_ITEM));
    next_i = -1;
    for(i = 2; i < items; i++) {
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-image") == 0) {
                next_i = i + 1;
                Item.mask = Item.mask | TCIF_IMAGE;
                Item.iImage = SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-text") == 0) {
                next_i = i + 1;
                Item.pszText = SvPV(ST(next_i), chText);
                Item.cchTextMax = (int) chText;
                Item.mask = Item.mask | TCIF_TEXT;
            }
        } else {
            next_i = -1;
        }
    }
    RETVAL = TabCtrl_SetItem(handle, item, &Item);
OUTPUT:
    RETVAL

int
Count(handle)
    HWND handle
CODE:
    RETVAL = TabCtrl_GetItemCount(handle);
OUTPUT:
    RETVAL

BOOL
Reset(handle)
    HWND handle
CODE:
    RETVAL = TabCtrl_DeleteAllItems(handle);
OUTPUT:
    RETVAL

BOOL
DeleteItem(handle,item)
    HWND handle
    int item
CODE:
    RETVAL = TabCtrl_DeleteItem(handle, item);
OUTPUT:
    RETVAL

void
GetString(handle,item)
    HWND handle
    int item
PREINIT:
    char *szString;
    TC_ITEM tcItem;
PPCODE:
    szString = (char *) safemalloc(1024);
    tcItem.pszText = szString;
    tcItem.cchTextMax = 1024;
    tcItem.mask = TCIF_TEXT;
    if(TabCtrl_GetItem(handle, item, &tcItem)) {
        EXTEND(SP, 1);
        XST_mPV(0, szString);
        safefree(szString);
        XSRETURN(1);
    } else {
        safefree(szString);
        XSRETURN_NO;
    }


  ###############################
  # Win32::GUI::Toolbar functions
  ###############################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::Toolbar

LRESULT
AddBitmap(handle,bitmap,numbuttons)
    HWND handle
    HBITMAP bitmap
    WPARAM numbuttons
PREINIT:
    TBADDBITMAP TbAddBitmap;
CODE:
    TbAddBitmap.hInst = (HINSTANCE) NULL;
    TbAddBitmap.nID = (UINT) bitmap;

    RETVAL = SendMessage(handle, TB_ADDBITMAP, numbuttons,
                         (LPARAM) (LPTBADDBITMAP) &TbAddBitmap);
OUTPUT:
    RETVAL

LRESULT
AddString(handle,string)
    HWND handle
    char * string
PREINIT:
    char *Strings;
    int i;
    unsigned int szLen, totLen;
    LPARAM lParam;
CODE:
    totLen = 0;
    #    // the function should accept an array of strings,
    #    // but actually doesn't work...
    #    
    #    for(i = 1; i < items; i++) {
    #        Strings = SvPV(ST(i), szLen);
    #        printf("AddString: szLen(%d) = %d\n", i, szLen);
    #        totLen += szLen+1;
    #    }
    #    totLen++;
    #    printf("AddString: totLen = %d\n", totLen);
    #    Strings = (char *) safemalloc(totLen);
    #
    #    totLen = 0;
    #    char *tmpStrings = Strings;
    #    for(i = 1; i < items; i++) {
    #        strcat(tmpStrings, SvPV(ST(i), szLen));
    #        totLen += szLen+1;
    #        
    #    }
    #    Strings[totLen++] = '\0';
    // only one string allowed
    Strings = SvPV(ST(1), szLen);
    Strings = (char *) safemalloc(szLen+2);
    strcpy(Strings, string);   
    Strings[szLen+1] = '\0';
#ifdef WIN32__GUI__DEBUG
    printf("AddString: Strings='%s', len=%d\n", Strings, szLen);

    for(i=0; i<=szLen+1; i++) {
        printf("AddString: Strings[%d]='%d'\n", i, Strings[i]);
    }
#endif
    lParam = (LPARAM) MAKELONG(Strings, 0);
#ifdef WIN32__GUI__DEBUG
    printf("AddString: handle=%ld\n", handle);
    printf("AddString: Strings=%ld\n", Strings);
    printf("AddString: lParam=%ld\n", lParam);
#endif
    RETVAL = SendMessage(handle, TB_ADDSTRING, 0, (LPARAM) Strings);
#ifdef WIN32__GUI__DEBUG
    printf("AddString: SendMessage.result = %ld", RETVAL);
#endif
    safefree(Strings);
OUTPUT:
    RETVAL


LRESULT
AddButtons(handle,number,...)
    HWND handle
    UINT number
PREINIT:
    LPTBBUTTON buttons;
    int i, q, b;
CODE:
    if(items != 2 + number * 5) {
        CROAK("AddButtons: wrong number of parameters (expected %d, got %d)!\n", 2+number*5, items);
    }
    buttons = (LPTBBUTTON) safemalloc(sizeof(TBBUTTON)*number);
    q = 0;
    b = 0;
    for(i = 2; i < items; i++) {
        switch(q) {
        case 0:
            buttons[b].iBitmap = (int) SvIV(ST(i));
            break;
        case 1:
            buttons[b].idCommand = (int) SvIV(ST(i));
            break;
        case 2:
            buttons[b].fsState = (BYTE) SvIV(ST(i));
            break;
        case 3:
            buttons[b].fsStyle = (BYTE) SvIV(ST(i));
            break;
        case 4:
            buttons[b].iString = (int) SvIV(ST(i));
        }
        q++;
        if(q == 5) { 
            buttons[b].dwData = 0;
            q = 0; 
            b++; 
        }
    }
    RETVAL = SendMessage(handle, TB_ADDBUTTONS,
                         (WPARAM) number,
                         (LPARAM) (LPTBBUTTON) buttons);
    safefree(buttons);
OUTPUT:
    RETVAL

LRESULT
ButtonStructSize(handle)
    HWND handle
CODE:
    RETVAL = SendMessage(handle, TB_BUTTONSTRUCTSIZE,
                         (WPARAM) sizeof(TBBUTTON), 0);
OUTPUT:
    RETVAL


  ################################
  # Win32::GUI::RichEdit functions
  ################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::RichEdit

LRESULT
SetCharFormat(handle,...)
    HWND handle
PREINIT:
    CHARFORMAT cf;
    int i, next_i;    
CODE:
    ZeroMemory(&cf, sizeof(CHARFORMAT));
    cf.cbSize = sizeof(CHARFORMAT);
    next_i = -1;
    for(i = 1; i < items; i++) {
        //printf("ST(%d): ", i);
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-bold") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) {
                    cf.dwEffects = cf.dwEffects | CFE_BOLD;
                }
                cf.dwMask = cf.dwMask | CFM_BOLD;
            }
            if(strcmp(SvPV(ST(i), na), "-italic") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) {
                    cf.dwEffects = cf.dwEffects | CFE_ITALIC;
                }
                cf.dwMask = cf.dwMask | CFM_ITALIC;
            }
            if(strcmp(SvPV(ST(i), na), "-underline") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) {
                    cf.dwEffects = cf.dwEffects | CFE_UNDERLINE;
                }
                cf.dwMask = cf.dwMask | CFM_UNDERLINE;
            }
            if(strcmp(SvPV(ST(i), na), "-strikeout") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) {
                    cf.dwEffects = cf.dwEffects | CFE_STRIKEOUT;
                }
                cf.dwMask = cf.dwMask | CFM_STRIKEOUT;
            }
            if(strcmp(SvPV(ST(i), na), "-color") == 0) {
                next_i = i + 1;
                cf.crTextColor = (COLORREF) SvIV(ST(next_i));
                cf.dwMask = cf.dwMask | CFM_COLOR;
            }
            if(strcmp(SvPV(ST(i), na), "-autocolor") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) {
                    cf.dwEffects = cf.dwEffects | CFE_AUTOCOLOR;
                    cf.dwMask = cf.dwMask | CFM_COLOR;
                }
            }
            if(strcmp(SvPV(ST(i), na), "-height") == 0
            || strcmp(SvPV(ST(i), na), "-size") == 0) {
                next_i = i + 1;
                cf.yHeight = (LONG) SvIV(ST(next_i));
                cf.dwMask = cf.dwMask | CFM_SIZE;
            }
            if(strcmp(SvPV(ST(i), na), "-name") == 0) {
                next_i = i + 1;
                strncpy((char *)cf.szFaceName, SvPV(ST(next_i), na), 32);
                cf.dwMask = cf.dwMask | CFM_FACE;
            }
        } else {
            next_i = -1;
        }
    }
    RETVAL = SendMessage(handle, EM_SETCHARFORMAT, 
                         (WPARAM) (UINT) SCF_SELECTION, 
                         (LPARAM) (CHARFORMAT FAR *) &cf);
OUTPUT:
    RETVAL
    
LRESULT
SetParaFormat(handle,...)
    HWND handle
PREINIT:
    PARAFORMAT pf;
    int i, next_i;
CODE:
    ZeroMemory(&pf, sizeof(PARAFORMAT));
    pf.cbSize = sizeof(PARAFORMAT);
    next_i = -1;
    for(i = 1; i < items; i++) {
        //printf("ST(%d): ", i);
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-numbering") == 0
            || strcmp(SvPV(ST(i), na), "-bullet") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) {
                    pf.wNumbering = PFN_BULLET;
                } else {
                    pf.wNumbering = 0;
                }
                pf.dwMask = pf.dwMask | PFM_NUMBERING;
            }
            if(strcmp(SvPV(ST(i), na), "-align") == 0) {
                next_i = i + 1;
                if(strcmp(SvPV(ST(next_i), na), "left") == 0) {
                    pf.wAlignment = PFA_LEFT;
                    pf.dwMask = pf.dwMask | PFM_ALIGNMENT;
                } else if(strcmp(SvPV(ST(next_i), na), "center") == 0) {
                    pf.wAlignment = PFA_CENTER;
                    pf.dwMask = pf.dwMask | PFM_ALIGNMENT;
                } else if(strcmp(SvPV(ST(next_i), na), "right") == 0) {
                    pf.wAlignment = PFA_RIGHT;
                    pf.dwMask = pf.dwMask | PFM_ALIGNMENT;
                }
            }
            if(strcmp(SvPV(ST(i), na), "-offset") == 0) {
                next_i = i + 1;
                pf.dxOffset = SvIV(ST(next_i));
                pf.dwMask = pf.dwMask | PFM_OFFSET;
            }
            if(strcmp(SvPV(ST(i), na), "-startindent") == 0) {
                next_i = i + 1;
                pf.dxStartIndent = SvIV(ST(next_i));
                pf.dwMask = pf.dwMask | PFM_STARTINDENT;
            }

            if(strcmp(SvPV(ST(i), na), "-right") == 0) {
                next_i = i + 1;
                pf.dxRightIndent = SvIV(ST(next_i));
                pf.dwMask = pf.dwMask | PFM_RIGHTINDENT;
            }
        } else {
            next_i = -1;
        }
    }
    RETVAL = SendMessage(handle, EM_SETPARAFORMAT, 0, 
                         (LPARAM) (PARAFORMAT FAR *) &pf);
OUTPUT:
    RETVAL

void
GetCharFormat(handle,flag=1)
    HWND handle
    BOOL flag
PREINIT:
    CHARFORMAT cf;
    DWORD dwMask;
    int si;
PPCODE:
    ZeroMemory(&cf, sizeof(CHARFORMAT));
    cf.cbSize = sizeof(CHARFORMAT);
    dwMask = SendMessage(
        handle, EM_GETCHARFORMAT, (WPARAM) flag, (LPARAM) (CHARFORMAT FAR *) &cf
    );
    si = 0;
    if(dwMask & CFM_BOLD) {
        if(cf.dwEffects & CFE_BOLD) {
            EXTEND(SP, 2);
            XST_mPV(si++, "-bold");
            XST_mIV(si++, 1);
        }
    }
    if(dwMask & CFM_COLOR) {
        EXTEND(SP, 2);
        XST_mPV(si++, "-color");
        XST_mIV(si++, (long) cf.crTextColor);
    }
    if(dwMask & CFM_FACE) {
        EXTEND(SP, 2);
        XST_mPV(si++, "-name");
        XST_mPV(si++, cf.szFaceName);
    }
    if(dwMask & CFM_ITALIC) {
        if(cf.dwEffects & CFE_ITALIC) {
            EXTEND(SP, 2);
            XST_mPV(si++, "-italic");
            XST_mIV(si++, 1);
        }
    }
    if(dwMask & CFM_SIZE) {
        EXTEND(SP, 2);
        XST_mPV(si++, "-name");
        XST_mIV(si++, cf.yHeight);
    }
    if(dwMask & CFM_STRIKEOUT) {
        if(cf.dwEffects & CFE_STRIKEOUT) {
            EXTEND(SP, 2);
            XST_mPV(si++, "-strikeout");
            XST_mIV(si++, 1);
        }
    }
    if(dwMask & CFM_UNDERLINE) {
        if(cf.dwEffects & CFE_UNDERLINE) {
            EXTEND(SP, 2);
            XST_mPV(si++, "-underline");
            XST_mIV(si++, 1);
        }
    }
    XSRETURN(si);

void
CharFromPos(handle,x,y)
    HWND handle
    int x
    int y
PREINIT:
    POINT p;
    LRESULT cfp;
PPCODE:
    ZeroMemory(&p, sizeof(POINT));
    p.x = x;
    p.y = y;
    cfp = SendMessage(handle, EM_CHARFROMPOS, 0, (LPARAM) &p);
    if(cfp == -1) {
        XSRETURN_IV(-1);
    } else {
        EXTEND(SP, 2);
        XST_mIV(0, LOWORD(cfp));
        XST_mIV(1, HIWORD(cfp));
        XSRETURN(2);
    }

void
PosFromChar(handle,index)
    HWND handle
    LPARAM index
PREINIT:
    POINT p;
CODE:
    ZeroMemory(&p, sizeof(POINT));
    SendMessage(handle, EM_POSFROMCHAR, (WPARAM) &p, index);
    EXTEND(SP, 2);
    XST_mIV(0, p.x);
    XST_mIV(1, p.y);
    XSRETURN(2);   



LRESULT
ReplaceSel(handle,string,flag=TRUE)
    HWND handle
    LPCTSTR string
    BOOL flag
CODE:
    RETVAL = SendMessage(handle, EM_REPLACESEL, 
                         (WPARAM) flag, (LPARAM) string);
OUTPUT:
    RETVAL

LRESULT
Select(handle,start,end)
    HWND handle
    LONG start
    LONG end
PREINIT:
    CHARRANGE cr;
CODE:
    ZeroMemory(&cr, sizeof(CHARRANGE));
    cr.cpMin = start;
    cr.cpMax = end;
    RETVAL = SendMessage(
        handle, EM_EXSETSEL, 0, (LPARAM) (CHARRANGE FAR *) &cr
    );
OUTPUT:
    RETVAL

void
Selection(handle)
    HWND handle
PREINIT:
    CHARRANGE cr;
PPCODE:
    ZeroMemory(&cr, sizeof(CHARRANGE));
    SendMessage(
        handle, EM_EXGETSEL, 0, (LPARAM) (CHARRANGE FAR *) &cr
    );
    EXTEND(SP, 2);
    XST_mIV(0, cr.cpMin);
    XST_mIV(1, cr.cpMax);
    XSRETURN(2);


LRESULT
Save(handle,filename,format=SF_RTF)
    HWND handle
    LPCTSTR filename
    WPARAM format
PREINIT:
    HANDLE hfile;
    EDITSTREAM estream;
CODE:
    hfile = CreateFile(filename, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    estream.dwCookie = (DWORD) hfile;
    estream.dwError = 0;
    estream.pfnCallback = (EDITSTREAMCALLBACK) RichEditSave;

    RETVAL = SendMessage(handle, EM_STREAMOUT,
                         format, (LPARAM) &estream);
    CloseHandle(hfile);
OUTPUT:
    RETVAL

LRESULT
Load(handle,filename,format=SF_RTF)
    HWND handle
    LPCTSTR filename
    WPARAM format
PREINIT:
    HANDLE hfile;
    EDITSTREAM estream;
CODE:
    hfile = CreateFile(filename, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    estream.dwCookie = (DWORD) hfile;
    estream.dwError = 0;
    estream.pfnCallback = (EDITSTREAMCALLBACK) RichEditLoad;

    RETVAL = SendMessage(handle, EM_STREAMIN,
                         format, (LPARAM) &estream);
    CloseHandle(hfile);
OUTPUT:
    RETVAL


  ################################
  # Win32::GUI::ListView functions
  ################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::ListView

int
InsertColumn(handle,...)
    HWND handle
PREINIT:
    LV_COLUMN Column;
    unsigned int tlen;
    int i, next_i;
    int iCol;
    char * option;
CODE:
    ZeroMemory(&Column, sizeof(LV_COLUMN));
    next_i = -1;
    for(i = 1; i < items; i++) {
        //printf("ST(%d): ", i);
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-text") == 0) {
                next_i = i + 1;
                Column.pszText = SvPV(ST(next_i), tlen);
                Column.cchTextMax = tlen;
                Column.mask = Column.mask | LVCF_TEXT;
            }
            if(strcmp(option, "-align") == 0) {
                next_i = i + 1;
                if(strcmp(SvPV(ST(next_i), na), "right") == 0) {
                    Column.fmt = LVCFMT_RIGHT;
                    Column.mask = Column.mask | LVCF_FMT;
                } else if(strcmp(SvPV(ST(next_i), na), "left") == 0) {
                    Column.fmt = LVCFMT_LEFT;
                    Column.mask = Column.mask | LVCF_FMT;
                } else if(strcmp(SvPV(ST(next_i), na), "center") == 0) {
                    Column.fmt = LVCFMT_CENTER;
                    Column.mask = Column.mask | LVCF_FMT;
                }
            }
            if(strcmp(option, "-width") == 0) {
                next_i = i + 1;
                Column.cx = SvIV(ST(next_i));
                Column.mask = Column.mask | LVCF_WIDTH;
            }
            if(strcmp(option, "-index") == 0
            || strcmp(option, "-item") == 0) {
                next_i = i + 1;
                iCol = SvIV(ST(next_i));
            }
            if(strcmp(option, "-subitem") == 0) {
                next_i = i + 1;
                Column.iSubItem = SvIV(ST(next_i));
                Column.mask = Column.mask | LVCF_SUBITEM;
            }
        } else {
            next_i = -1;
        }
    }
    if(!Column.mask & LVCF_FMT) {
        Column.fmt = LVCFMT_LEFT;
        Column.mask = Column.mask | LVCF_FMT;
    }
    // evtl. autofill iCol too...

    RETVAL = ListView_InsertColumn(handle, iCol, &Column);
OUTPUT:
    RETVAL

int
InsertItem(handle,...)
    HWND handle
PREINIT:
    LV_ITEM Item;
    unsigned int tlen;
    int i, next_i;
    char * option;
CODE:
    ZeroMemory(&Item, sizeof(LV_ITEM));
    next_i = -1;
    for(i = 1; i < items; i++) {
        //printf("ST(%d): ", i);
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-text") == 0) {
                next_i = i + 1;
                Item.pszText = SvPV(ST(next_i), tlen);
                Item.cchTextMax = tlen;
                Item.mask = Item.mask | LVIF_TEXT;
            }
            if(strcmp(option, "-item") == 0
            || strcmp(option, "-index") == 0) {
                next_i = i + 1;
                Item.iItem = SvIV(ST(next_i));
            }
            if(strcmp(option, "-image") == 0) {
                next_i = i + 1;
                Item.iImage = SvIV(ST(next_i));
                Item.mask = Item.mask | LVIF_IMAGE;                
            }            
            if(strcmp(option, "-subitem") == 0) {
                next_i = i + 1;
                Item.iSubItem = SvIV(ST(next_i));
            }
        } else {
            next_i = -1;
        }
    }
    RETVAL = ListView_InsertItem(handle, &Item);
OUTPUT:
    RETVAL

int
SetItem(handle,...)
    HWND handle
PREINIT:
    LV_ITEM Item;
    unsigned int tlen;
    int i, next_i;
    char * option;
CODE:
    ZeroMemory(&Item, sizeof(LV_ITEM));
    next_i = -1;
    for(i = 1; i < items; i++) {
        //printf("ST(%d): ", i);
        if(next_i == -1) {
            option = SvPV(ST(i), na);
            if(strcmp(option, "-text") == 0) {
                next_i = i + 1;
                Item.pszText = SvPV(ST(next_i), tlen);
                Item.cchTextMax = tlen;
                Item.mask = Item.mask | LVIF_TEXT;
            }
            if(strcmp(option, "-item") == 0
            || strcmp(option, "-index") == 0) {
                next_i = i + 1;
                Item.iItem = SvIV(ST(next_i));
            }
            if(strcmp(option, "-subitem") == 0) {
                next_i = i + 1;
                Item.iSubItem = SvIV(ST(next_i));
            }            
            if(strcmp(option, "-image") == 0) {
                next_i = i + 1;
                Item.iImage = SvIV(ST(next_i));
                Item.mask = Item.mask | LVIF_IMAGE;
            }
        } else {
            next_i = -1;
        }
    }
    RETVAL = ListView_SetItem(handle, &Item);
OUTPUT:
    RETVAL

long
View(handle,...)
    HWND handle
PREINIT:
    DWORD dwStyle;
    DWORD dwView;
CODE:
    if(items > 2)
        CROAK("Usage: View(handle, [view]);\n");

    // Get the current window style. 
    dwStyle = GetWindowLong(handle, GWL_STYLE); 
    if(items == 2) {
        dwView = SvIV(ST(1));
        // Only set the window style if the view bits have changed. 
        if ((dwStyle & LVS_TYPEMASK) != dwView) 
            SetWindowLong(handle, GWL_STYLE, 
                          (dwStyle & ~LVS_TYPEMASK) | dwView); 
        dwStyle = GetWindowLong(handle, GWL_STYLE); 
        RETVAL = (dwStyle & LVS_TYPEMASK);
    } else
        RETVAL = (dwStyle & LVS_TYPEMASK);    
OUTPUT:
    RETVAL

int
Count(handle)
    HWND handle
CODE:
    RETVAL = ListView_GetItemCount(handle);
OUTPUT:
    RETVAL

BOOL
DeleteItem(handle,index)
    HWND handle
    int index
CODE:
    RETVAL = ListView_DeleteItem(handle, index);
OUTPUT:
    RETVAL

HWND
EditLabel(handle,index)
    HWND handle
    int index
CODE:
    RETVAL = ListView_EditLabel(handle, index);
OUTPUT:
    RETVAL

BOOL
Clear(handle)
    HWND handle
CODE:
    RETVAL = ListView_DeleteAllItems(handle);
OUTPUT:
    RETVAL
    
BOOL
DeleteColumn(handle,index)
    HWND handle
    int index
CODE:
    RETVAL = ListView_DeleteColumn(handle, index);
OUTPUT:
    RETVAL

UINT
SelectedItems(handle)
    HWND handle
CODE:
    RETVAL = ListView_GetSelectedCount(handle);
OUTPUT:
    RETVAL


void
Select(handle,item)
    HWND handle
    int item
PREINIT:
    UINT state;
    UINT mask; 
CODE:
    state = LVIS_FOCUSED | LVIS_SELECTED;
    mask = 0xFFFFFFFF;
    ListView_SetItemState(handle, item, state, mask);

void
HitTest(handle,x,y)
    HWND handle
    LONG x
    LONG y
PREINIT:
    LV_HITTESTINFO ht;
PPCODE:
    ht.pt.x = x;
    ht.pt.y = y;
    ListView_HitTest(handle, &ht);
    if(GIMME == G_ARRAY) {
        EXTEND(SP, 2);
        XST_mIV(0, (long) ht.iItem);
        XST_mIV(1, ht.flags);
        XSRETURN(2);
    } else {
        XSRETURN_IV((long) ht.iItem);
    }
    
int
GetStringWidth(handle,string)
    HWND handle
    LPCSTR string
CODE:
    RETVAL = ListView_GetStringWidth(handle, string);
OUTPUT:
    RETVAL

int
GetFirstVisible(handle)
    HWND handle
CODE:
    RETVAL = ListView_GetTopIndex(handle);
OUTPUT:
    RETVAL

BOOL
EnsureVisible(handle,index,flag=TRUE)
    HWND handle
    int index
    BOOL flag
CODE:
    RETVAL = ListView_EnsureVisible(handle, index, flag);
OUTPUT:
    RETVAL

HIMAGELIST
SetImageList(handle,imagelist,type=LVSIL_NORMAL)
    HWND handle
    HIMAGELIST imagelist
    WPARAM type
CODE:
    RETVAL = ListView_SetImageList(handle, imagelist, type);
OUTPUT:
    RETVAL

COLORREF
TextColor(handle,...)
    HWND handle
PREINIT:
    COLORREF crColor;
CODE:
    if(items > 2) {
        CROAK("Usage: TextColor(handle, [color]);\n");
    }
    if(items == 2) {
        crColor = (COLORREF) SvIV(ST(1));
        if(ListView_SetTextColor(handle, crColor))
            RETVAL = ListView_GetTextColor(handle);
        else
            RETVAL = -1;
    } else
        RETVAL = ListView_GetTextColor(handle);
OUTPUT:
    RETVAL
    
COLORREF
TextBkColor(handle,...)
    HWND handle
PREINIT:
    COLORREF crColor;
CODE:    
    if(items > 2) {
        CROAK("Usage: TextBkColor(handle, [color]);\n");
    }
    if(items == 2) {
        crColor = (COLORREF) SvIV(ST(1));
        if(ListView_SetTextBkColor(handle, crColor)) 
            RETVAL = ListView_GetTextBkColor(handle);
        else
            RETVAL = -1;
    } else
        RETVAL = ListView_GetTextBkColor(handle);
OUTPUT:
    RETVAL


  ################################
  # Win32::GUI::TreeView functions
  ################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::TreeView

HTREEITEM
InsertItem(handle,...)
    HWND handle
PREINIT:
    TV_ITEM Item;
    TV_INSERTSTRUCT Insert;
    unsigned int tlen;
    int i, next_i;
    int imageSeen, selectedImageSeen;
CODE:
    ZeroMemory(&Item, sizeof(TV_ITEM));
    ZeroMemory(&Insert, sizeof(TV_INSERTSTRUCT));
    Insert.hParent = NULL;
    Insert.hInsertAfter = TVI_FIRST;

    imageSeen = 0;
    selectedImageSeen = 0;
    
    next_i = -1;
    for(i = 1; i < items; i++) {
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-text") == 0) {
                next_i = i + 1;
                Item.pszText = SvPV(ST(next_i), tlen);
                Item.cchTextMax = tlen;
                Item.mask = Item.mask | TVIF_TEXT;
            }
            if(strcmp(SvPV(ST(i), na), "-image") == 0) {
                next_i = i + 1;
                imageSeen = 1;                
                Item.iImage = SvIV(ST(next_i));
                Item.mask = Item.mask | TVIF_IMAGE;
            }
            if(strcmp(SvPV(ST(i), na), "-selectedimage") == 0) {
                next_i = i + 1;
                selectedImageSeen = 1;                
                Item.iSelectedImage = SvIV(ST(next_i));
                Item.mask = Item.mask | TVIF_SELECTEDIMAGE;
            }
            if(strcmp(SvPV(ST(i), na), "-parent") == 0) {
                next_i = i + 1;
                Insert.hParent = (HTREEITEM) handle_From(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-item") == 0
            || strcmp(SvPV(ST(i), na), "-index") == 0) {
                next_i = i + 1;
                Insert.hInsertAfter = (HTREEITEM) handle_From(ST(next_i));
            }
        } else {
            next_i = -1;
        }
    }
    if(selectedImageSeen == 0 && imageSeen != 0) {
        Item.iSelectedImage = Item.iImage;
        Item.mask = Item.mask | TVIF_SELECTEDIMAGE;
    }
    Insert.item = Item;    
    RETVAL = TreeView_InsertItem(handle, &Insert);
OUTPUT:
    RETVAL

BOOL
ChangeItem(handle,item,...)
    HWND handle
    HTREEITEM item;
PREINIT:
    int i, next_i, imageSeen, selectedImageSeen;
    unsigned int tlen;
    TV_ITEM Item;
CODE:
    ZeroMemory(&Item, sizeof(TV_ITEM));
    Item.hItem = item;
    imageSeen = 0;
    selectedImageSeen = 0;
    next_i = -1;
    for(i = 2; i < items; i++) {
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-text") == 0) {
                next_i = i + 1;
                Item.pszText = SvPV(ST(next_i), tlen);
                Item.cchTextMax = tlen;
                Item.mask = Item.mask | TVIF_TEXT;
            }
            if(strcmp(SvPV(ST(i), na), "-image") == 0) {
                next_i = i + 1;
                imageSeen = 1;
                Item.iImage = SvIV(ST(next_i));
                Item.mask = Item.mask | TVIF_IMAGE;
            }
            if(strcmp(SvPV(ST(i), na), "-selectedimage") == 0) {
                next_i = i + 1;
                selectedImageSeen = 1;
                Item.iSelectedImage = SvIV(ST(next_i));
                Item.mask = Item.mask | TVIF_SELECTEDIMAGE;
            }
        } else {
            next_i = -1;
        }
    }
    if(selectedImageSeen == 0 && imageSeen != 0) {
        Item.iSelectedImage = Item.iImage;
        Item.mask = Item.mask | TVIF_SELECTEDIMAGE;
    }
    RETVAL = TreeView_SetItem(handle, &Item);
OUTPUT:
    RETVAL

void
GetItem(handle,item)
    HWND handle
    HTREEITEM item
PREINIT:
    TV_ITEM tv_item;
    char pszText[1024];
PPCODE:
    ZeroMemory(&tv_item, sizeof(TV_ITEM));
    tv_item.hItem = item;
    tv_item.mask = TVIF_CHILDREN | TVIF_HANDLE | TVIF_IMAGE 
                 | TVIF_PARAM | TVIF_SELECTEDIMAGE
                 | TVIF_TEXT ;
    tv_item.pszText = pszText;
    tv_item.cchTextMax = 1024;
    if(TreeView_GetItem(handle, &tv_item)) {
        EXTEND(SP, 8);
        XST_mPV(0, "-text");
        XST_mPV(1, tv_item.pszText);
        XST_mPV(2, "-image");
        XST_mIV(3, tv_item.iImage);
        XST_mPV(4, "-selectedimage");
        XST_mIV(5, tv_item.iSelectedImage);
        XST_mPV(6, "-children");
        XST_mIV(7, tv_item.cChildren);
        XSRETURN(8);
    } else {
        XSRETURN_NO;
    }

BOOL
DeleteItem(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_DeleteItem(handle,item);
OUTPUT:
    RETVAL

BOOL
Reset(handle)
    HWND handle
CODE:
    RETVAL = TreeView_DeleteAllItems(handle);
OUTPUT:
    RETVAL

BOOL
Clear(handle,...)
    HWND handle
CODE:
    if(items != 1 && items != 2)
        croak("Usage: Clear(handle, [item]);\n");
    if(items == 1)
        RETVAL = TreeView_DeleteAllItems(handle);
    else
        RETVAL = TreeView_Expand(handle, 
                                 (HTREEITEM) SvIV(ST(1)), 
                                 TVE_COLLAPSE | TVE_COLLAPSERESET);
OUTPUT:
    RETVAL

HIMAGELIST
SetImageList(handle,imagelist,type=TVSIL_NORMAL)
    HWND handle
    HIMAGELIST imagelist
    WPARAM type
CODE:
    RETVAL = TreeView_SetImageList(handle, imagelist, type);
OUTPUT:
    RETVAL

BOOL
Expand(handle,item,flag=TVE_EXPAND)
    HWND handle
    HTREEITEM item
    UINT flag
CODE:
    RETVAL = TreeView_Expand(handle, item, flag);
OUTPUT:
    RETVAL

BOOL
Collapse(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_Expand(handle, item, TVE_COLLAPSE);
OUTPUT:
    RETVAL

HTREEITEM
GetRoot(handle)
    HWND handle
CODE:
    RETVAL = TreeView_GetRoot(handle);
OUTPUT:
    RETVAL
    
HTREEITEM
GetParent(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_GetParent(handle, item);
OUTPUT:
    RETVAL


HTREEITEM
GetChild(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_GetChild(handle, item);
OUTPUT:
    RETVAL

HTREEITEM
GetNextSibling(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_GetNextSibling(handle, item);
OUTPUT:
    RETVAL

HTREEITEM
GetPrevSibling(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_GetPrevSibling(handle, item);
OUTPUT:
    RETVAL


UINT
Count(handle)
    HWND handle
CODE:
    RETVAL = TreeView_GetCount(handle);
OUTPUT:
    RETVAL

HTREEITEM
Select(handle,item,flag=TVGN_CARET)
    HWND handle
    HTREEITEM item
    WPARAM flag
CODE:
    RETVAL = TreeView_Select(handle, item, flag);
OUTPUT:
    RETVAL

HTREEITEM
SelectedItem(handle)
    HWND handle
CODE:
    RETVAL = TreeView_GetSelection(handle);
OUTPUT:
    RETVAL

void
HitTest(handle,x,y)
    HWND handle
    LONG x
    LONG y
PREINIT:
    TV_HITTESTINFO ht;
PPCODE:
    ht.pt.x = x;
    ht.pt.y = y;
    TreeView_HitTest(handle, &ht);
    if(GIMME == G_ARRAY) {
        EXTEND(SP, 2);
        XST_mIV(0, (long) ht.hItem);
        XST_mIV(1, ht.flags);
        XSRETURN(2);
    } else {
        XSRETURN_IV((long) ht.hItem);
    }

UINT
Indent(handle,...)
    HWND handle
PREINIT:
    UINT indent;
CODE:
    if(items > 2)
        croak("Usage: Indent(handle, [indent]);\n");
    if(items == 2)
        RETVAL = TreeView_SetIndent(handle, (UINT) SvIV(ST(1)));
    else
        RETVAL = TreeView_GetIndent(handle);
OUTPUT:
    RETVAL
    
BOOL
Sort(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_SortChildren(handle, item, 0);
OUTPUT:
    RETVAL

BOOL
EnsureVisible(handle,item)
    HWND handle
    HTREEITEM item
CODE:
    RETVAL = TreeView_EnsureVisible(handle, item);
OUTPUT:
    RETVAL
    
  #################################
  # Win32::GUI::ImageList functions
  #################################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::ImageList

HIMAGELIST
Create(cx,cy,flags,cInitial,cGrow)
    int cx
    int cy
    UINT flags
    int cInitial
    int cGrow
CODE:
    RETVAL = ImageList_Create(cx, cy, flags, cInitial, cGrow);
OUTPUT:
    RETVAL


int
AddBitmap(handle, bitmap, bitmapMask=NULL)
    HIMAGELIST handle
    HBITMAP bitmap
    HBITMAP bitmapMask
CODE:
    RETVAL = ImageList_Add(handle, bitmap, bitmapMask);
OUTPUT:
    RETVAL

int
Replace(handle, index, bitmap, bitmapMask)
    HIMAGELIST handle
    int index
    HBITMAP bitmap
    HBITMAP bitmapMask
CODE:
    RETVAL = ImageList_Replace(handle, index, bitmap, bitmapMask);
OUTPUT:
    RETVAL


int
Remove(handle,index)
    HIMAGELIST handle
    int index
CODE:
    RETVAL = ImageList_Remove(handle, index);
OUTPUT:
    RETVAL

int
Clear(handle)
    HIMAGELIST handle
    int index
CODE:
    RETVAL = ImageList_RemoveAll(handle);
OUTPUT:
    RETVAL


int
Count(handle)
    HIMAGELIST handle
CODE:
    RETVAL = ImageList_GetImageCount(handle);
OUTPUT:
    RETVAL

int
BackColor(handle,...)
    HIMAGELIST handle
PREINIT:
    COLORREF color;
CODE:
    if(items > 2)
        croak("Usage: BackColor(handle, [color]);\n");
    if(items == 2) {
        color = (COLORREF) SvIV(ST(1));
        RETVAL = ImageList_SetBkColor(handle, color);
    } else
        RETVAL = ImageList_GetBkColor(handle);
OUTPUT:
    RETVAL

void
Size(handle,...)
    HIMAGELIST handle
PREINIT:
    int cx, cy;
    BOOL result;
PPCODE:
    if(items != 1 && items != 3)
        croak("Usage: Size(handle);\n   or: Size(handle, x, y);\n");
    if(items == 1) {
        if(ImageList_GetIconSize(handle, &cx, &cy)) {
            EXTEND(SP, 2);
            XST_mIV(0, cx);
            XST_mIV(1, cy);
            XSRETURN(2);
        } else
            XSRETURN_NO;
    } else {
        result = ImageList_SetIconSize(handle, (int) SvIV(ST(1)), (int) SvIV(ST(2)));
        EXTEND(SP, 1);
        XST_mIV(0, result);
        XSRETURN(1);
    }
    
BOOL
DESTROY(handle)
    HIMAGELIST handle
CODE:
    RETVAL = ImageList_Destroy(handle);
OUTPUT:
    RETVAL  
    
  ##############################
  # Win32::GUI::Bitmap functions
  ##############################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::Bitmap

void
Info(handle)
    HBITMAP handle
PREINIT:
    BITMAPINFO bInfo;
PPCODE:
    ZeroMemory(&bInfo, sizeof(BITMAPINFO));
#ifdef WIN32__GUI__DEBUG
    printf("XS(Info): handle=%ld\n", handle);
#endif
    bInfo.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bInfo.bmiHeader.biBitCount = 0; // don't care about colors, just general infos
    if(GetDIBits(NULL,          // handle of device context 
                 handle,        // handle of bitmap 
                 0,             // first scan line to set in destination bitmap 
                 0,             // number of scan lines to copy 
                 NULL,          // address of array for bitmap bits 
                 &bInfo,        // address of structure with bitmap data 
                 DIB_RGB_COLORS // RGB or palette index 
                )) {
        EXTEND(SP, 9);
        XST_mIV(0, bInfo.bmiHeader.biWidth);
        XST_mIV(1, bInfo.bmiHeader.biHeight);
        XST_mIV(2, bInfo.bmiHeader.biBitCount);
        XST_mIV(3, bInfo.bmiHeader.biCompression);
        XST_mIV(4, bInfo.bmiHeader.biSizeImage);
        XST_mIV(5, bInfo.bmiHeader.biXPelsPerMeter);
        XST_mIV(6, bInfo.bmiHeader.biYPelsPerMeter);
        XST_mIV(7, bInfo.bmiHeader.biClrUsed);
        XST_mIV(8, bInfo.bmiHeader.biClrImportant);
        XSRETURN(9);
    } else {
#ifdef WIN32__GUI__DEBUG
        printf("XS(Info): GetDIBits failed...\n");
        printf("XS(Info): bInfo.bmiHeader.biWidth=%d\n", bInfo.bmiHeader.biWidth);
#endif
        XSRETURN_NO;
    }

BOOL
DESTROY(handle)
    HBITMAP handle
CODE:
    RETVAL = DeleteObject((HGDIOBJ) handle);
OUTPUT:
    RETVAL
    
 ############################
 # Win32::GUI::Font functions
 ############################

MODULE = Win32::GUI     PACKAGE = Win32::GUI::Font

void
Create(...)
PPCODE:
    int nHeight;
    int nWidth;
    int nEscapement;
    int nOrientation;
    int fnWeight;
    DWORD fdwItalic;
    DWORD fdwUnderline;
    DWORD fdwStrikeOut;
    DWORD fdwCharSet;
    DWORD fdwOutputPrecision;
    DWORD fdwClipPrecision;
    DWORD fdwQuality;                      
    DWORD fdwPitchAndFamily;                      
    char lpszFace[32];                        // pointer to typeface name string
    int i, next_i;
    
    nHeight = 0;                              // logical height of font
    nWidth = 0;                               // logical average character width
    nEscapement = 0;                          // angle of escapement
    nOrientation = 0;                         // base-line orientation angle
    fnWeight = 400;                           // font weight
    fdwItalic = 0;                            // italic attribute flag
    fdwUnderline = 0;                         // underline attribute flag
    fdwStrikeOut = 0;                         // strikeout attribute flag
    fdwCharSet = DEFAULT_CHARSET;             // character set identifier
    fdwOutputPrecision = OUT_DEFAULT_PRECIS;  // output precision
    fdwClipPrecision = CLIP_DEFAULT_PRECIS;   // clipping precision
    fdwQuality = DEFAULT_QUALITY;             // output quality
    fdwPitchAndFamily = DEFAULT_PITCH 
                      | FF_DONTCARE;          // pitch and family

    next_i = -1;
    for(i = 0; i < items; i++) {
        if(next_i == -1) {
            if(strcmp(SvPV(ST(i), na), "-height") == 0) {
                next_i = i + 1;
                nHeight = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-width") == 0) {
                next_i = i + 1;
                nWidth = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-escapement") == 0) {
                next_i = i + 1;
                nEscapement = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-orientation") == 0) {
                next_i = i + 1;
                nOrientation = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-weight") == 0) {
                next_i = i + 1;
                fnWeight = (int) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-bold") == 0) {
                next_i = i + 1;
                if(SvIV(ST(next_i)) != 0) fnWeight = 700;
            }
            if(strcmp(SvPV(ST(i), na), "-italic") == 0) {
                next_i = i + 1;
                fdwItalic = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-underline") == 0) {
                next_i = i + 1;
                fdwUnderline = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-strikeout") == 0) {
                next_i = i + 1;
                fdwStrikeOut = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-charset") == 0) {
                next_i = i + 1;
                fdwCharSet = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-outputprecision") == 0) {
                next_i = i + 1;
                fdwOutputPrecision = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-clipprecision") == 0) {
                next_i = i + 1;
                fdwClipPrecision = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-quality") == 0) {
                next_i = i + 1;
                fdwQuality = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-family") == 0) {
                next_i = i + 1;
                fdwPitchAndFamily = (DWORD) SvIV(ST(next_i));
            }
            if(strcmp(SvPV(ST(i), na), "-name") == 0) {
                next_i = i + 1;
                strncpy(lpszFace, SvPV(ST(next_i), na), 32);
            }

        } else {
            next_i = -1;
        }
    }
    XSRETURN_IV((long) CreateFont(nHeight,
                                  nWidth,
                                  nEscapement,
                                  nOrientation,
                                  fnWeight,
                                  fdwItalic,
                                  fdwUnderline,
                                  fdwStrikeOut,
                                  fdwCharSet,
                                  fdwOutputPrecision,
                                  fdwClipPrecision,
                                  fdwQuality,
                                  fdwPitchAndFamily,
                                  (LPCTSTR) lpszFace));

BOOL
DESTROY(handle)
    HFONT handle
CODE:
    RETVAL = DeleteObject((HGDIOBJ) handle);
OUTPUT:
    RETVAL



