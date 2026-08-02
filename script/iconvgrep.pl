#! /usr/bin/env perl
use 5.014004;
use strict;
use warnings;
use Carp;
use Encode;
use English '-no_match_vars';
use Getopt::Std;

## The version of the script.
our $VERSION = '0.0.1';

## Help message for the script.
my $HELP = <<"_END_OF_HELP_";
usage: $PROGRAM_NAME [OPTION ..] REGEX [FILE ..]
OPTION:
    --help           Display this help message.
    --version        Display version information.
    -f FROM_ENCODING Specify the source encoding. (default: utf8)
    -t TO_ENCODING   Specify the target encoding. (default: utf8)
    -i               Ignore case in regex matching.
    -b BEHAVIOR      Specify the behavior for encoding errors.
                     (default: FB_DEFAULT)
BEHAVIOR:
    FB_DEFAULT  Replace any malformed character with a substitution
                character.  When you encode, sub char is used.
                When you decode, the Unicode REPLACEMENT CHARACTER,
                code point U+FFFD, is used.
                If the data is supposed to be UTF-8,
                an optional lexical warning of warning category "utf8"
                is given.
    FB_CROAK    Croak on encoding errors.
    FB_QUIET    Do nothing on encoding errors.
    FB_WARN     Warn on encoding errors.
    FB_PERLQQ   Use Perl-style \\xHH escapes for malformed characters.
    FB_HTMLCREF Use HTML character references for malformed characters.
    FB_XMLCREF  Use XML character references for malformed characters.
For more details run
    perldoc -F $PROGRAM_NAME
_END_OF_HELP_

##
# Print the help message when the user requests it or when an error occurs.
# @return 1 on success, otherwise croak with an error message.
sub HELP_MESSAGE {
    print "$HELP"
        or croak 'failed to print help message: ' . $OS_ERROR . "\n" . $HELP;
    return 1;
}

##
# Compile the provided regex string into a regex object.
# @param[in] $regex_string The regex string to compile.
# @param[in] $ignore_case
#   A boolean indicating whether to ignore case in regex matching.
# @return
#   The compiled regex object,
#   or croak with an error message if the regex is invalid.
sub compile_regex {
    my ( $regex_string, $ignore_case ) = @_;
    my $regex = eval {
        $ignore_case ? qr/$regex_string/xmsui : qr/$regex_string/xmsu;
    }
        or croak 'invalid regex: '
        . $regex_string . "\n"
        . $EVAL_ERROR . "\n";
    return $regex;
}

##
# Specify the behavior for encoding errors.
# Specify the behavior for encoding errors based
# on the provided behavior string.
# @param[in] $behavior_string The behavior string to specify the behavior.
# @return
#   The corresponding behavior constant from the Encode module,
#   or croak with an error message if the behavior string is invalid.
sub specify_behavior {
    my ($behavior_string) = @_;
    my $behavior = {
        FB_DEFAULT  => Encode::FB_DEFAULT,
        FB_CROAK    => Encode::FB_CROAK,
        FB_QUIET    => Encode::FB_QUIET,
        FB_WARN     => Encode::FB_WARN,
        FB_PERLQQ   => Encode::FB_PERLQQ,
        FB_HTMLCREF => Encode::FB_HTMLCREF,
        FB_XMLCREF  => Encode::FB_XMLCREF,
    }->{$behavior_string};
    defined $behavior
        or croak 'invalid behavior: ' . $behavior_string . "\n" . $HELP;
    return $behavior;
}

##
# Parse the command-line arguments.
# Parse the command-line arguments and return a hash reference containing
# the parsed values.
# @return
#   A hash reference containing the parsed values:
#   - from: The source encoding (default: utf8)
#   - to: The target encoding (default: utf8)
#   - regex: The compiled regex object
#   - behavior: The specified behavior for encoding errors
sub parse_arguments {
    $Getopt::Std::STANDARD_HELP_VERSION = 1;
    getopts( 'ib:f:t:', \my %opts ) or croak $HELP;

    my $from_encoding = $opts{f} // 'utf8';
    my $to_encoding   = $opts{t} // 'utf8';

    my $behavior_string = $opts{b} // 'FB_DEFAULT';
    my $behavior        = specify_behavior($behavior_string);

    my $ignore_case  = $opts{i};
    my $regex_string = shift @ARGV or croak "no regex provided\n" . $HELP;
    my $regex        = compile_regex( $regex_string, $ignore_case );

    return {
        from     => $from_encoding,
        to       => $to_encoding,
        regex    => $regex,
        behavior => $behavior,
    };
}

##
# Convert a line from the specified source encoding to UTF-8.
# @param[in] $from_encoding The source encoding of the line.
# @param[in] $line The line to convert.
# @param[in] $behavior The specified behavior for encoding errors.
# @return The line converted to UTF-8.
sub encode_to_utf8 {
    my ( $from_encoding, $line, $behavior ) = @_;
    my $decoded_line = decode( $from_encoding, $line, $behavior );
    return encode( 'utf8', $decoded_line, $behavior );
}

##
# Convert a line from UTF-8 to the specified target encoding.
# @param[in] $to_encoding The target encoding of the line.
# @param[in] $line The line to convert.
# @param[in] $behavior The specified behavior for encoding errors.
# @return The line converted to the target encoding.
sub decode_from_utf8 {
    my ( $to_encoding, $line, $behavior ) = @_;
    my $decoded_line = decode( 'utf8', $line, $behavior );
    return encode( $to_encoding, $decoded_line, $behavior );
}

##
# Match a line against the specified regex and print it if it matches.
# @param[in] $parsed A hash reference containing the parsed values.
# @param[in] $utf8_line The line to match against the regex.
# @return 1 if the line matches the regex and is printed, otherwise 0.
sub match_and_print {
    my ( $parsed, $utf8_line ) = @_;
    my $to_encoding = $parsed->{to};
    my $regex       = $parsed->{regex};
    my $behavior    = $parsed->{behavior};

    if ( $utf8_line =~ $regex ) {
        my $encoded_line
            = decode_from_utf8( $to_encoding, $utf8_line, $behavior );
        print "$ARGV" . ': ' . $encoded_line
            or croak 'failed to print matched line: ' . $OS_ERROR;
        return 1;
    }
    return 0;
}

##
# Match a line against the specified regex and print it if it matches.
# @param[in] $parsed A hash reference containing the parsed values.
# @param[in] $line The line to match against the regex.
# @return 1 if the line matches the regex and is printed, otherwise 0.
sub print_matched_line {
    my ( $parsed, $line ) = @_;
    my $from_encoding = $parsed->{from};
    my $to_encoding   = $parsed->{to};
    my $regex         = $parsed->{regex};
    my $behavior      = $parsed->{behavior};

    my $utf8_line = encode_to_utf8( $from_encoding, $line, $behavior );
    if ( $utf8_line =~ $regex ) {
        my $encoded_line
            = decode_from_utf8( $to_encoding, $utf8_line, $behavior );
        print "$ARGV" . q{:} . $NR . q{: } . $encoded_line
            or croak 'failed to print matched line: ' . $OS_ERROR;
        return 1;
    }
    return 0;
}

##
# Read lines and print matched lines from the input files.
# Read lines from the input files, match them against the specified regex,
# and print the matched lines.
# @param[in] $parsed
#   A hash reference containing the parsed values.
#   - from: The source encoding (default: utf8)
#   - to: The target encoding (default: utf8)
#   - regex: The compiled regex object
#   - behavior: The specified behavior for encoding errors
#     (default: FB_DEFAULT)
# @return The number of matched lines printed.
sub print_matched_lines {
    my ($parsed)      = @_;
    my $from_encoding = $parsed->{from};
    my $behavior      = $parsed->{behavior};

    my $matched = 0;
    while (<>) {
        if ( print_matched_line( $parsed, $_ ) ) { ++$matched }
    }
    continue {
        if (eof) {
            close ARGV
                or croak q{failed to close } . $ARGV . q{: } . $OS_ERROR;
        }
    }
    return $matched;
}

##
# The main function of the script.
# Parse the command-line arguments
# and print matched lines from the input files.
# @return The number of matched lines printed.
sub main {
    my $parsed = parse_arguments();
    return print_matched_lines($parsed);
}

# Run the main function if the script is executed directly.
if ( !caller ) { main() }

1;
__END__

=encoding utf8

=head1 NAME

iconvgrep.pl - grep with encoding conversion

=head1 SYNOPSIS

    iconvgrep.pl [OPTION ..] REGEX [FILE ..]
    OPTION:
        --help           Display this help message
        --version        Display version information
        -f FROM_ENCODING Specify the source encoding
                         (default: utf8)
        -t TO_ENCODING   Specify the target encoding
                         (default: utf8)
        -i               Ignore case in regex matching
        -b BEHAVIOR      Specify the behavior for encoding errors
                         (default: FB_DEFAULT)
    BEHAVIOR:
        FB_DEFAULT  replace any malformed character with a
                    substitution character.  When you encode,
                    sub char is used.
                    When you decode, the Unicode REPLACEMENT
                    CHARACTER, code point U+FFFD, is used.
                    If the data is supposed to be UTF-8,
                    an optional lexical warning of warning category
                    "utf8" is given.
        FB_CROAK    croak on encoding errors
        FB_QUIET    do nothing on encoding errors
        FB_WARN     warn on encoding errors
        FB_PERLQQ   use Perl-style \xHH escapes for malformed
                    characters
        FB_HTMLCREF use HTML character references for malformed
                    characters
        FB_XMLCREF  use XML character references for malformed
                    characters

=head1 USAGE

    iconvgrep.pl -f euc-jp -t cp932 -i -b FB_WARN 'REGEX' file1.txt

=head1 REQUIRED ARGUMENTS

=over

=item REGEX

The regular expression to match against each line of the input files.
The regex is applied after converting the line from the source encoding
to UTF-8.
The regex can be specified in Perl syntax, and supports various regex
modifiers such as /i for case-insensitive matching,
/x for extended syntax, /s for single-line mode,
/m for multi-line mode, and /u for Unicode mode.

=back

=head1 OPTIONS

=over

=item * C<-f> FROM_ENCODING

Specifies the source encoding of the input files.
If not specified, the default is 'utf8'.

=item * C<-t> TO_ENCODING

Specifies the target encoding for the output.
If not specified, the default is 'utf8'.

=item * C<-i>

Ignore case in regex matching.
This option makes the regex matching case-insensitive.
This option is equivalent to using the /i modifier in the regex.

=item * C<-b> BEHAVIOR

Specifies the behavior for handling encoding errors during conversion.

The possible values are:

=over

=item * C<FB_DEFAULT>

Replace any malformed character with a substitution character.
When you encode, sub char is used.
When you decode, the Unicode REPLACEMENT CHARACTER,
code point U+FFFD, is used.
If the data is supposed to be UTF-8,
an optional lexical warning of warning category "utf8" is given.
This is the default behavior if the -b option is not specified.

=item * C<FB_CROAK> Croak on encoding errors.

=item * C<FB_QUIET> Do nothing on encoding errors.

=item * C<FB_WARN> Warn on encoding errors.

=item * C<FB_PERLQQ>

Use Perl-style \xHH escapes for malformed characters.

=item * C<FB_HTMLCREF>

Use HTML character references for malformed characters.

=item * C<FB_XMLCREF>

Use XML character references for malformed characters.

=back

=back

=head1 DESCRIPTION

This script is a simple implementation of grep with encoding
conversion.
It reads lines from the specified files (or standard input if no files
are specified),
converts the encoding of each line from the specified source encoding
to UTF-8, and then applies the specified regular expression to the
UTF-8 encoded line.
If a match is found, it converts the line back to the specified target
encoding and prints it.
The script supports various behaviors for handling encoding errors,
which can be specified using the -b option.
The default behavior is to replace any malformed character with a
substitution character.
The script also supports ignoring case in regex matching with the -i
option.
The script is implemented in Perl and uses the Encode module for
encoding conversion and the L<Getopt::Std> module for command-line
option parsing.
The script is designed to be used in a command-line environment
and can be combined with other command-line tools for text processing.
The script is intended for users who need to search for patterns in
text files with different encodings and want to handle encoding errors
in a customizable way.
Regular expressions can be specified in Perl syntax, and the script
supports various regex modifiers such as /i for case-insensitive
matching.
Regular expressions can also be specified in the /xmsui mode,
which combines the extended, multi-line, single-line, Unicode,
and case-insensitive modifiers.
Regular expressions can also be specified in the /xmsu mode,
which combines the extended, multi-line, single-line,
and Unicode modifiers.
The script is open-source and can be modified and redistributed under
the terms of the Apache License 2.0.
Refer to the LICENSE AND COPYRIGHT section for more details.

=head1 DIAGNOSTICS

=over

=item * C<no regex provided>

No regular expression was provided on the command line.

=item * C<invalid regex: >

The provided regular expression is invalid and could not be compiled.

=item * C<invalid behavior: >

The specified behavior for encoding errors is invalid
and not recognized.

=item * C<failed to print help message: >

The script failed to print the help message to standard output.

=back

=head1 EXIT STATUS

The script exits with one of the following status codes:

=over

=item * C<0>

The script executed successfully

=item * C<1>-C<255>

The script encountered an error, such as an invalid regex
or encoding error.

=back

=head1 CONFIGURATION

The script does not require any special configuration files
or environment variables.
The script can be run directly from the command line with the
appropriate options and arguments.

=head1 DEPENDENCIES

=over

=item *L<perl> version 5.14.4 or higher

=item *L<Carp>

=item *L<Encode>

=item *L<English>

=item *L<Getopt::Std>

=item *L<strict>

=item *L<warnings>

=back

=head1 INCOMPATIBILITIES

There are no known incompatibilities with other modules or scripts.

=head1 BUGS AND LIMITATIONS

There are no known bugs or limitations in this script.

=head1 AUTHOR

Mitsutoshi NAKANO <ItSANgo@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2026 Mitsutoshi NAKANO

SPDX-License-Identifier: Apache-2.0
