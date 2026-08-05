#! /usr/bin/env perl
use 5.014004;
use strict;
use warnings;
use utf8;
use Carp;
use Encode;
use English '-no_match_vars';
use File::Temp;
use FindBin;
use POSIX qw(WEXITSTATUS);
use Test::Fatal;
use Test::More;

our $VERSION = '0.0.1';

my $SCRIPT = "$FindBin::Bin/../script/iconvgrep.pl";

require $SCRIPT;

## no critic (InputOutput::RequireBriefOpen)
## The pipe filehandle is intentionally handed back to the caller instead
## of being closed here; see the "return the filehandle" exception in
## InputOutput::RequireBriefOpen's documentation.
sub open_pipe_with_stdin {
    my ( $stdin_path, @command ) = @_;

    open my $saved_stdin, '<&', \*STDIN
        or croak 'failed to save STDIN: ' . $OS_ERROR;
    open STDIN, '<', $stdin_path
        or croak 'failed to redirect STDIN: ' . $OS_ERROR;

    my $pipe_mode = '-|';    ## no critic (ValuesAndExpressions::ProhibitNoisyQuotes)
    open my $pipe, $pipe_mode, @command
        or croak 'failed to run '
        . join( q{ }, @command ) . q{: }
        . $OS_ERROR;

    open STDIN, '<&', $saved_stdin
        or croak 'failed to restore STDIN: ' . $OS_ERROR;
    close $saved_stdin
        or croak 'failed to close saved STDIN: ' . $OS_ERROR;

    return $pipe;
}
## use critic

sub run_script {
    my ( $args_ref, $stdin_content ) = @_;

    my $stdin_file = File::Temp->new();
    print {$stdin_file} $stdin_content // q{}
        or croak 'failed to write temporary stdin file: ' . $OS_ERROR;
    close $stdin_file
        or croak 'failed to close temporary stdin file: ' . $OS_ERROR;

    my @command = ( $EXECUTABLE_NAME, $SCRIPT, @{$args_ref} );
    my $pipe    = open_pipe_with_stdin( $stdin_file->filename, @command );
    binmode $pipe;

    local $RS = undef;
    my $stdout    = <$pipe>;
    my $closed_ok = close $pipe;
    my $exit_code = WEXITSTATUS($CHILD_ERROR);
    if ( !$closed_ok && $exit_code == 0 ) {
        croak 'failed to close pipe for '
            . join( q{ }, @command ) . q{: }
            . $OS_ERROR;
    }

    return ( $stdout // q{}, $exit_code );
}

sub test_compile_regex {
    my $regex = compile_regex( 'ba+r', 0 );
    ok( 'bar' =~ $regex, 'compile_regex: matches literal pattern' );
    ok( 'BAR' !~ $regex, 'compile_regex: case sensitive by default' );

    my $ci_regex = compile_regex( 'ba+r', 1 );
    ok( 'BAR' =~ $ci_regex, 'compile_regex: -i makes it case insensitive' );

    my $space_regex = compile_regex( 'foo bar', 0 );
    ok( 'foo bar' =~ $space_regex,
        'compile_regex: whitespace in the pattern is matched literally' );
    ok( 'foobar' !~ $space_regex,
        'compile_regex: whitespace in the pattern is not ignored' );

    like(
        exception { compile_regex( '(unclosed', 0 ) },
        qr/invalid [ ] regex/xms,
        'compile_regex: invalid regex croaks',
    );
    return;
}

sub test_specify_behavior {
    my %expected = (
        FB_DEFAULT  => Encode::FB_DEFAULT,
        FB_CROAK    => Encode::FB_CROAK,
        FB_QUIET    => Encode::FB_QUIET,
        FB_WARN     => Encode::FB_WARN,
        FB_PERLQQ   => Encode::FB_PERLQQ,
        FB_HTMLCREF => Encode::FB_HTMLCREF,
        FB_XMLCREF  => Encode::FB_XMLCREF,
    );

    for my $name ( sort keys %expected ) {
        is( specify_behavior($name), $expected{$name},
            "specify_behavior: $name maps to the expected constant" );
    }

    like(
        exception { specify_behavior('FB_BOGUS') },
        qr/invalid [ ] behavior/xms,
        'specify_behavior: unknown behavior name croaks',
    );
    return;
}

sub test_parse_arguments {
    {
        local @ARGV = ('pattern');
        my $parsed = parse_arguments();
        is( $parsed->{from}, 'utf8',
            'parse_arguments: default from encoding' );
        is( $parsed->{to}, 'utf8', 'parse_arguments: default to encoding' );
        is( $parsed->{behavior}, Encode::FB_DEFAULT,
            'parse_arguments: default behavior' );
        ok( 'pattern' =~ $parsed->{regex},
            'parse_arguments: regex compiled from the last argument' );
    }

    {
        local @ARGV = qw(-f euc-jp -t cp932 -i -b FB_CROAK PATTERN);
        my $parsed = parse_arguments();
        is( $parsed->{from}, 'euc-jp',
            'parse_arguments: -f sets from encoding' );
        is( $parsed->{to}, 'cp932', 'parse_arguments: -t sets to encoding' );
        is( $parsed->{behavior}, Encode::FB_CROAK,
            'parse_arguments: -b sets the behavior' );
        ok( 'pattern' =~ $parsed->{regex},
            'parse_arguments: -i makes the regex case insensitive' );
    }

    {
        local @ARGV = ();
        like(
            exception { parse_arguments() },
            qr/no [ ] regex [ ] provided/xms,
            'parse_arguments: missing regex croaks',
        );
    }
    return;
}

sub test_grep_from_file {
    my $input_file = File::Temp->new();
    print {$input_file} "dog\ncat\nbird\n"
        or croak 'failed to write temporary input file: ' . $OS_ERROR;
    close $input_file
        or croak 'failed to close temporary input file: ' . $OS_ERROR;
    my $path = $input_file->filename;

    my ( $stdout, $exit_code ) = run_script( [ 'cat', $path ] );
    is( $exit_code, 0, 'grep from file: exits successfully' );
    is( $stdout,
        "$path:2: cat\n",
        'grep from file: prints "file:line: match"'
    );
    return;
}

sub test_grep_from_stdin {
    my ( $stdout, $exit_code ) = run_script( ['cat'], "dog\ncat\nbird\n" );
    is( $exit_code, 0,         'grep from stdin: exits successfully' );
    is( $stdout, "-:2: cat\n", 'grep from stdin: uses "-" as the filename' );
    return;
}

sub test_grep_case_insensitive {
    my ( $stdout, $exit_code )
        = run_script( [ '-i', 'CAT' ], "dog\ncat\nbird\n" );
    is( $exit_code, 0,            'grep -i: exits successfully' );
    is( $stdout,    "-:2: cat\n", 'grep -i: matches regardless of case' );
    return;
}

sub test_grep_no_match {
    my ( $stdout, $exit_code )
        = run_script( ['no such word'], "dog\ncat\nbird\n" );
    is( $exit_code, 0,   'grep with no match: still exits successfully' );
    is( $stdout,    q{}, 'grep with no match: prints nothing' );
    return;
}

## Regression test: the UTF-8 encoding of the first character of each
## test word below contains the byte 0x85 (NEL).  When the undecoded
## pattern was compiled with /x, that byte was silently dropped as
## ignorable whitespace and the pattern never matched.
## UTF-8 hex codes of the affected characters:
##   光 (U+5149) = E5 85 89, 元 (U+5143) = E5 85 83,
##   先 (U+5148) = E5 85 88, 兄 (U+5144) = E5 85 84,
##   克 (U+514B) = E5 85 8B, 免 (U+514D) = E5 85 8D,
##   児 (U+5150) = E5 85 90
sub test_grep_multibyte_pattern {
    foreach my $word (qw(光子 元素 先生 兄弟 克服 免許 児童)) {
        my $label = sprintf 'U+%04X', ord $word;
        my ( $stdout, $exit_code ) = run_script(
            [ encode( 'utf8', $word ) ],
            encode( 'utf8', "$word\n電圧\n" )
        );
        is( $exit_code, 0, "multibyte pattern $label: exits successfully" );
        is( $stdout,
            encode( 'utf8', "-:1: $word\n" ),
            "multibyte pattern $label: matches a word whose UTF-8 form"
                . ' contains the 0x85 byte'
        );
    }
    return;
}

sub test_grep_encoding_conversion {
    my $text         = "犬\n猫\n";
    my $euc_jp_bytes = encode( 'euc-jp', $text );

    my $input_file = File::Temp->new();
    binmode $input_file;
    print {$input_file} $euc_jp_bytes
        or croak 'failed to write temporary input file: ' . $OS_ERROR;
    close $input_file
        or croak 'failed to close temporary input file: ' . $OS_ERROR;
    my $path = $input_file->filename;

    my ( $stdout, $exit_code )
        = run_script( [ '-f', 'euc-jp', '-t', 'cp932', '猫', $path ] );
    is( $exit_code, 0, 'grep with encoding conversion: exits successfully' );

    my $expected = encode( 'cp932', "$path:2: 猫\n" );
    is( $stdout, $expected,
        'grep with encoding conversion: output is converted to cp932' );
    return;
}

sub test_invalid_regex_exits_nonzero {
    my ( undef, $exit_code ) = run_script( ['(unclosed'], q{} );
    isnt( $exit_code, 0, 'invalid regex: exits with a non-zero status' );
    return;
}

sub test_missing_regex_exits_nonzero {
    my ( undef, $exit_code ) = run_script( [], q{} );
    isnt( $exit_code, 0, 'missing regex: exits with a non-zero status' );
    return;
}

test_compile_regex();
test_specify_behavior();
test_parse_arguments();
test_grep_from_file();
test_grep_from_stdin();
test_grep_multibyte_pattern();
test_grep_case_insensitive();
test_grep_no_match();
test_grep_encoding_conversion();
test_invalid_regex_exits_nonzero();
test_missing_regex_exits_nonzero();

done_testing();
