package Pod::RTF;

=head1 NAME

Pod::RTF - convert POD data to Rich Text Format

=head1 SYNOPSIS

    use Pod::RTF;

    pod2rtf("perlfunc.pod");

=head1 DESCRIPTION

Pod::RTF is a module that can convert documentation in the POD format (such
as can be found throughout the Perl distribution) into Rich Text Format.

=head1 AUTHOR

Aldo Calpini E<lt>F<dada@divinf.it>E<gt>.
Based on Pod::Text by Tom Christiansen E<lt>F<tchrist@mox.perl.com>E<gt>

=head1 TODO

A lot of cleanup work, support user defined fonts and colors, and maybe 
learn something more on Rich Text Format.

=cut

require Exporter;
@ISA = Exporter;
@EXPORT = qw(pod2rtf);

use vars qw($VERSION);
$VERSION = "0.2001";

$termcap=0;

$opt_alt_format = 0;

#$use_format=1;

$UNDL = "\x1b[4m";
$INV = "\x1b[7m";
$BOLD = "\x1b[1m";
$NORM = "\x1b[0m";

sub pod2rtf {
@_ = ("<&STDIN") unless @_;
local($file,*OUTPUT) = @_;
*OUTPUT = *STDOUT if @_<2;

local $: = $:;
$: = " \n" if $opt_alt_format;  # Do not break ``-L/lib/'' into ``- L/lib/''.

$/ = "";

$FANCY = 0;

$cutting = 1;
$DEF_INDENT = 4;
$indent = $DEF_INDENT;
$needspace = 0;
$begun = "";

open(IN, $file) || die "Couldn't open $file: $!";

# _RTF_HEADER
print OUTPUT q({\rtf1\ansi\deff0\deftab720{\fonttbl{\f0\fswiss MS Sans Serif;}{\f1\froman\fcharset2 Symbol;}{\f2\fswiss Arial;}{\f3\fmodern Courier New;}}
{\colortbl\red0\green0\blue0;\red0\green128\blue0;\red0\green0\blue255;}
\deflang1040\plain\f2
);

POD_DIRECTIVE: while (<IN>) {
    if ($cutting) {
    next unless /^=/;
    $cutting = 0;
    }
    if ($begun) {
        if (/^=end\s+$begun/) {
             $begun = "";
        }
        elsif ($begun eq "text") {
            print OUTPUT $_;
        }
        next;
    }
    1 while s{^(.*?)(\t+)(.*)$}{
    $1
    . (' ' x (length($2) * 8 - length($1) % 8))
    . $3
    }me;
    # Translate verbatim paragraph
    if (/^\s/) {
        verbatim_output($_);
        next;
    }

    if (/^=for\s+(\S+)\s*(.*)/s) {
        if ($1 eq "text") {
            print OUTPUT $2,"";
        } else {
            # ignore unknown for
        }
        next;
    }
    elsif (/^=begin\s+(\S+)\s*(.*)/s) {
        $begun = $1;
        if ($1 eq "text") {
            print OUTPUT $2."";
        }
        next;
    }

sub prepare_for_output {

    s/\\/\\\\/g;
    s/\s*$/"\n\\par\\li".($indent*100)." "/e;
    &init_noremap;

    # need to hide E<> first; they're processed in clear_noremap
    s/(E<[^<>]+>)/noremap($1)/ge;
    $maxnest = 10;
    while ($maxnest-- && /[A-Z]</) {
    s/B<(.*?)>/\\plain\\b $1\\plain  /sg;
    s/C<(.*?)>/\\plain\\f3 $1\\plain\\f0  /sg;
    s/F<(.*?)>/\\plain\\f3 $1\\plain\\f0  /sg;
    s/I<(.*?)>/\\plain\\i $1\\plain  /sg;
    s/X<.*?>//sg;
    # LREF: a manpage(3f)
    s:L<([a-zA-Z][^\s\/]+)(\([^\)]+\))?>:the $1$2 manpage:g;
    # LREF: an =item on another manpage
    s{
        L<
        ([^/]+)
        /
        (
            [:\w]+
            (\(\))?
        )
        >
    } {the "$2" entry in the $1 manpage}gx;

    # LREF: an =item on this manpage
    s{
       ((?:
        L<
        /
        (
            [:\w]+
            (\(\))?
        )
        >
        (,?\s+(and\s+)?)?
      )+)
    } { internal_lrefs($1) }gex;

    # LREF: a =head2 (head1?), maybe on a manpage, maybe right here
    # the "func" can disambiguate
    s{
        L<
        (?:
            ([a-zA-Z]\S+?) / 
        )?
        "?(.*?)"?
        >
    }{
        do {
        $1  # if no $1, assume it means on this page.
            ?  "the section on \"$2\" in the $1 manpage"
            :  "the section on \"$2\""
        }
    }sgex;

        s/[A-Z]<(.*?)>/$1/sg;
    }
    clear_noremap(1);
}

    &prepare_for_output;

    if (s/^=//) {
    # $needspace = 0;       # Assume this.
    # s/\n/ /g;
    ($Cmd, $_) = split(' ', $_, 2);
    # clear_noremap(1);
    if ($Cmd eq 'cut') {
        $cutting = 1;
    }
    elsif ($Cmd eq 'pod') {
        $cutting = 0;
    }
    elsif ($Cmd eq 'head1') {
        makespace();
        print OUTPUT "\\par\n\\par\\plain\\f2\\fs36\\cf1\\li0\\b ";
        print OUTPUT;
        print OUTPUT "\\plain\\f2\\fs24 ";
        # print OUTPUT uc($_);
        $needspace = $opt_alt_format;
    }
    elsif ($Cmd eq 'head2') {
        makespace();
        print OUTPUT "\\par\n\\par\\plain\\f2\\fs24\\cf1\\li",($DEF_INDENT/2*100),"\\b ";
        print OUTPUT;
        print OUTPUT "\n\\par\\plain\\f2\\fs24 ";
        $needspace = $opt_alt_format;

    }
    elsif ($Cmd eq 'over') {
        push(@indent,$indent);
        $indent += ($_ + 0) || $DEF_INDENT;
    }
    elsif ($Cmd eq 'back') {
        $indent = pop(@indent);
        warn "Unmatched =back\n" unless defined $indent;
    }
    elsif ($Cmd eq 'item') {
        makespace();
        # s/\A(\s*)\*/$1\xb7/ if $FANCY;
        # s/^(\s*\*\s+)/$1 /;
        {
        if (length() + 3 < $indent) {
            my $paratag = $_;
            $_ = <IN>;
            if (/^=/) {  # tricked!
            local($indent) = $indent[$#index - 1] || $DEF_INDENT;
            output($paratag);
            redo POD_DIRECTIVE;
            }
            &prepare_for_output;
            IP_output($paratag, $_);
        } else {
            local($indent) = $indent[$#index - 1] || $DEF_INDENT;
            output($_, 0);
        }
        }
    }
    else {
        warn "Unrecognized directive: $Cmd\n";
    }
    }
    else {
    # clear_noremap(1);
    makespace();
    output($_);
    }
}
print OUTPUT "\0";
close(IN);

}

#########################################################################

sub makespace {
    if ($needspace) {
    print OUTPUT "\\par\\li".($tag_indent*100)." \n";
    $needspace = 0;
    }
}

sub IP_output {
    local($tag, $_) = @_;
    local($tag_indent) = $indent[$#index - 1] || $DEF_INDENT;
    $tag =~ s/\s*$//;
    #$tag =~ s/\\/\\\\/g;
    s/\s+/ /g;
    s/^ //;
    #s/\\/\\\\/g;
    print OUTPUT "\\par\\li".($tag_indent*100)." ".$tag;
    print OUTPUT "\\par\\li".($indent*100)." ".$_;
}

sub output {
    local($_) = @_;
    #s/\\/\\\\/g;
    s/\n/ \n/gm;
    print OUTPUT "\\par\\li".($indent*100)." ";
    print OUTPUT;
    print OUTPUT "\n";
}

sub verbatim_output {
    local($_) = @_;
    s/\\/\\\\/g;
    s/\n/ \n\\par /gm;
    print OUTPUT "\\par\\plain\\f3 ";
    print OUTPUT;
    print OUTPUT "\\plain\\f0 ";
}

sub noremap {
    local($thing_to_hide) = shift;
    $thing_to_hide =~ tr/\000-\177/\200-\377/;
    return $thing_to_hide;
}

sub init_noremap {
    die "unmatched init" if $mapready++;
    #mask off high bit characters in input stream
    s/([\200-\377])/"E<".ord($1).">"/ge;
}

sub clear_noremap {
    my $ready_to_print = $_[0];
    die "unmatched clear" unless $mapready--;
    tr/\200-\377/\000-\177/;
    # now for the E<>s, which have been hidden until now
    # otherwise the interative \w<> processing would have
    # been hosed by the E<gt>
    s {
        E<
        (
            ( \d+ )
            | ( [A-Za-z]+ )
        )
        >   
    } {
     do {
        defined $2
        ? chr($2)
        : do {
            warn "Unknown escape: E<$1> in $_";
            "E<$1>";
        }
     }
    }egx if $ready_to_print;
}

sub internal_lrefs {
    local($_) = shift;
    s{L</([^>]+)>}{$1}g;
    my(@items) = split( /(?:,?\s+(?:and\s+)?)/ );
    my $retstr = "the ";
    my $i;
    for ($i = 0; $i <= $#items; $i++) {
    $retstr .= "C<$items[$i]>";
    $retstr .= ", " if @items > 2 && $i != $#items;
    $retstr .= " and " if $i+2 == @items;
    }

    $retstr .= " entr" . ( @items > 1  ? "ies" : "y" )
        .  " elsewhere in this document ";

    return $retstr;

}

1;
