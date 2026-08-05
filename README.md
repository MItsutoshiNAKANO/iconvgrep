# NAME

iconvgrep.pl - grep with encoding conversion

# SYNOPSIS

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

# USAGE

    iconvgrep.pl -f euc-jp -t cp932 -i -b FB_WARN 'REGEX' file1.txt

# REQUIRED ARGUMENTS

- REGEX

    The regular expression to match against each line of the input files.
    The regex is applied after decoding the line from the source encoding,
    so it matches per character, not per byte.
    The regex is specified in Perl syntax and is compiled with the
    /m (multi-line), /s (single-line), and /u (Unicode) modifiers.
    The -i option adds the /i (case-insensitive) modifier.
    The /x (extended syntax) modifier is intentionally not applied,
    so whitespace and "#" in the pattern are matched literally.

# OPTIONS

- `-f` FROM\_ENCODING

    Specifies the source encoding of the input files.
    If not specified, the default is 'utf8'.

- `-t` TO\_ENCODING

    Specifies the target encoding for the output.
    If not specified, the default is 'utf8'.

- `-i`

    Ignore case in regex matching.
    This option makes the regex matching case-insensitive.
    This option is equivalent to using the /i modifier in the regex.

- `-b` BEHAVIOR

    Specifies the behavior for handling encoding errors during conversion.

    The possible values are:

    - `FB_DEFAULT`

        Replace any malformed character with a substitution character.
        When you encode, sub char is used.
        When you decode, the Unicode REPLACEMENT CHARACTER,
        code point U+FFFD, is used.
        If the data is supposed to be UTF-8,
        an optional lexical warning of warning category "utf8" is given.
        This is the default behavior if the -b option is not specified.

    - `FB_CROAK` Croak on encoding errors.
    - `FB_QUIET` Do nothing on encoding errors.
    - `FB_WARN` Warn on encoding errors.
    - `FB_PERLQQ`

        Use Perl-style \\xHH escapes for malformed characters.

    - `FB_HTMLCREF`

        Use HTML character references for malformed characters.

    - `FB_XMLCREF`

        Use XML character references for malformed characters.

# DESCRIPTION

This script is a simple implementation of grep with encoding
conversion.
It reads lines from the specified files (or standard input if no files
are specified),
decodes each line from the specified source encoding,
and then applies the specified regular expression to the decoded line.
If a match is found, it encodes the line into the specified target
encoding and prints it.
The script supports various behaviors for handling encoding errors,
which can be specified using the -b option.
The default behavior is to replace any malformed character with a
substitution character.
The script also supports ignoring case in regex matching with the -i
option.
The script is implemented in Perl and uses the Encode module for
encoding conversion and the [Getopt::Std](https://metacpan.org/pod/Getopt%3A%3AStd) module for command-line
option parsing.
The script is designed to be used in a command-line environment
and can be combined with other command-line tools for text processing.
The script is intended for users who need to search for patterns in
text files with different encodings and want to handle encoding errors
in a customizable way.
Regular expressions are specified in Perl syntax and are compiled
with the /m (multi-line), /s (single-line), and /u (Unicode)
modifiers; the -i option adds the /i (case-insensitive) modifier.
The /x (extended syntax) modifier is intentionally not applied,
so whitespace and "#" in the pattern are matched literally.
The script is open-source and can be modified and redistributed under
the terms of the Apache License 2.0.
Refer to the LICENSE AND COPYRIGHT section for more details.

# DIAGNOSTICS

- `no regex provided`

    No regular expression was provided on the command line.

- `invalid regex: `

    The provided regular expression is invalid and could not be compiled.

- `invalid behavior: `

    The specified behavior for encoding errors is invalid
    and not recognized.

- `failed to print help message: `

    The script failed to print the help message to standard output.

# EXIT STATUS

The script exits with one of the following status codes:

- `0`

    The script executed successfully

- `1`-`255`

    The script encountered an error, such as an invalid regex
    or encoding error.

# CONFIGURATION

The script does not require any special configuration files
or environment variables.
The script can be run directly from the command line with the
appropriate options and arguments.

# DEPENDENCIES

- \*[perl](https://metacpan.org/pod/perl) version 5.14.4 or higher
- \*[Carp](https://metacpan.org/pod/Carp)
- \*[Encode](https://metacpan.org/pod/Encode)
- \*[English](https://metacpan.org/pod/English)
- \*[Getopt::Std](https://metacpan.org/pod/Getopt%3A%3AStd)
- \*[strict](https://metacpan.org/pod/strict)
- \*[warnings](https://metacpan.org/pod/warnings)

# INCOMPATIBILITIES

There are no known incompatibilities with other modules or scripts.

# BUGS AND LIMITATIONS

There are no known bugs or limitations in this script.

# AUTHOR

Mitsutoshi NAKANO <ItSANgo@gmail.com>

# LICENSE AND COPYRIGHT

Copyright 2026 Mitsutoshi NAKANO

SPDX-License-Identifier: Apache-2.0
