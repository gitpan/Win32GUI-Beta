use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'  => 'Win32::GUI',
    'VERSION_FROM' => 'GUI.pm',
    'dist'  => {COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
    'LDLOADLIBS' => 'kernel32.lib user32.lib gdi32.lib comdlg32.lib comctl32.lib',
#    'INC'  => '-I.\\include',
);
