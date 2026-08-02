#! /usr/bin/env perl
use 5.014004;
use strict;
use warnings;

use Test::More;
use File::Spec;
use File::Temp qw(tempfile);
use FindBin qw($Bin);
use Encode qw(encode);

my $script = File::Spec->catfile( $Bin, '..', 'script', 'iconvgrep.pl' );
$script = File::Spec->rel2abs($script);

sub run_script {
    my ( $regex, $content, @extra_args ) = @_;

    my ( $fh, $path ) = tempfile( UNLINK => 1 );
    binmode $fh, ':raw';
    print {$fh} encode( 'UTF-8', $content );
    close $fh;

    open my $pipe, '-|', $^X, $script, @extra_args, $regex, $path
        or die "failed to run $script: $!";

    my $output = do { local $/; <$pipe> };
    my $close_status = close $pipe;
    my $exit_code = $? >> 8;

    return ( $output, $exit_code, $close_status );
}

my ( $output, $exit_code, $close_status ) = run_script( 'alpha', "alpha\n", );

ok( !$close_status || $close_status == 1, 'script exits with a status code for a matching line' );
is( $exit_code, 1, 'script returns 1 when a match is found' );
like( $output, qr/:1: alpha\n\z/, 'prints the matching line with filename and line number' );

my ( $output2, $exit_code2, $close_status2 ) = run_script( 'hello', "Hello\n", '-i' );

ok( !$close_status2 || $close_status2 == 1, 'script exits with a status code for case-insensitive matching' );
is( $exit_code2, 1, 'case-insensitive matching returns 1' );
like( $output2, qr/Hello\n\z/, 'case-insensitive match finds the line' );

my ( $output3, $exit_code3, $close_status3 ) = run_script( 'zzz', "alpha\n", );

ok( $close_status3, 'script exits cleanly when no match is found' );
is( $exit_code3, 0, 'script returns 0 when no match is found' );
is( $output3, q{}, 'no output is produced when no match is found' );

done_testing();
