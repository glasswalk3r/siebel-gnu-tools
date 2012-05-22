#!/usr/bin/perl

#    COPYRIGHT AND LICENCE
#
#    This software is copyright (c) 2012 of Alceu Rodrigues de Freitas Junior, glasswalk3r@yahoo.com.br
#
#    This program is part of Siebel GNU Tools.
#
#    Siebel GNU Tools is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Siebel GNU Tools is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Siebel GNU Tools.  If not, see <http://www.gnu.org/licenses/>.
#
#    The "Onion Powered by Perl logo" is a trademark of the Perl Foundation (http://www.perl.org/)

use warnings;
use strict;
use GD::Graph::lines;
use Getopt::Std;
use File::Spec;

my %opts;
my $version = '0.1';
my $copyright =
'This software is copyright (c) 2012 of Alceu Rodrigues de Freitas Junior, glasswalk3r@yahoo.com.br, licensed under GPL v3';

getopt( 'd:', \%opts );

unless ( defined( $opts{d} ) ) {

    die <<BLOCK;
perl_txnrouter - version $version
perl_txnrouter is a Perl script to parse txnrouter log files with performance information
and produce graphic images about the values recovered
Usage: perf_txnrouter.pl -d PATH
Where:
	PATH = complete path to the directory were the txnrouter log files are available

$copyright
This program is part of Siebel GNU Tools.
BLOCK

}

opendir( my $dir, $opts{d} ) or die "Cannot read directory $opts{d}: $!\n";
my @files = readdir($dir);
close($dir);

my %rows;

my $perf_regex   = qr/^Performance\tPerformance\t\d/;
my $vis_regex    = qr/Vis\sCheck\sTime.*/;
my $header_regex = qr/Node\sName\|Total\sOpers.*/;

my $vis_check_time_regex = qr/Vis\sCheck\sTime\:\s/;
my $dx_file_regex        = qr/\sdx\sfile\sparsing\stime\:\s/;

foreach my $file (@files) {

    next unless ( $file =~ /^TxnRoute_\d+\.log$/ );

    my $path = File::Spec->catfile( $opts{d}, $file );

    open( my $in, '<', "$path" ) or die "Cannot read $path: $!\n";

    print "Reading $path\n";

    while (<$in>) {

        chomp();

        if ( $_ =~ $perf_regex ) {

            my @fields = split( /\t/, $_ );

            my ( $date, $timestamp ) = split( /\s/, $fields[3] );
            my $data = $fields[4];

            unless ( exists( $rows{$date}->{$timestamp} ) ) {

                $rows{$date}->{$timestamp} = {
                    visdx    => [],
                    nodes    => [],
                    greatest => {
                        vis_check_time => 0,
                        dx_parse_time  => 0,
                        total_opers    => 0,
                        total_time     => 0,
                        ts_time        => 0,
                        vis_events     => 0,
                        nonvis_events  => 0,
                        enterprise     => 0,
                        downloads      => 0,
                        removes        => 0

                    }
                };

            }

          CASE: {

                if ( $data =~ $vis_regex ) {

                    $data =~ s/Vis\sCheck\sTime\:\s//;

                    #$data =~ s/$vis_check_time_regex//;

                    $data =~ s/\sdx\sfile\sparsing\stime\:\s//;

                    #$data =~ s/$dx_file_regex//;
                    $data =~ tr/ //d;

                    my @fields = split( /\;/, $data );

                    push(
                        @{ $rows{$date}->{$timestamp}->{visdx} },
                        { vistime => $fields[0], dxtime => $fields[1] }
                    );

# :TODO:09/08/2011 15:51:07:: this should be refactored since is not general usage
                    $rows{$date}->{$timestamp}->{greatest}->{vis_check_time} =
                      $fields[0]
                      if ( $fields[0] > $rows{$date}->{$timestamp}->{greatest}
                        ->{vis_check_time} );

                    $rows{$date}->{$timestamp}->{greatest}->{dx_parse_time} =
                      $fields[1]
                      if ( $fields[1] > $rows{$date}->{$timestamp}->{greatest}
                        ->{dx_parse_time} );

                    last CASE;

                }

                if ( $data =~ $header_regex ) {

                    last CASE;

                }
                else {

                    my @fields = split( /\|/, $data );

                    my %node = (
                        node          => $fields[0],
                        total_opers   => $fields[1],
                        total_time    => $fields[2],
                        ts_time       => $fields[3],
                        vis_events    => $fields[4],
                        nonvis_events => $fields[5],
                        enterprise    => $fields[6],
                        downloads     => $fields[7],
                        removes       => $fields[8]
                    );

  #                    push( @{ $rows{$date}->{$timestamp}->{nodes} }, \%node );

                    foreach my $attrib (
                        qw(total_opers total_time ts_time vis_events nonvis_events enterprise downloads removes)
                      )
                    {

                        $rows{$date}->{$timestamp}->{greatest}->{$attrib} =
                          $node{$attrib}
                          if ( $node{$attrib} >
                            $rows{$date}->{$timestamp}->{greatest}->{$attrib} );

                    }

                    last CASE;

                }

            }

        }

    }

    close($in);

}

print "Finished reading log files\n";
print "Generating graphics\n";

foreach my $day ( keys(%rows) ) {

    my $times_img = "times_$day.png";
    my $opers_img = "opers_$day.png";

    my @times = sort( keys( %{ $rows{$day} } ) );
    my $total = ( scalar(@times) ) - 1;

    #time spent in activities
    my @dx_parse_time;
    my @ts_time;
    my @vis_check_time;

    #number of operations
    my @downloads;
    my @enterprise;
    my @nonvis_events;
    my @removes;
    my @vis_events;

    my $data_ref;

# :WORKAROUND:10/08/2011 15:58:11:: had to put a limit to the amount of registries considered or the graph would become too hard to read
    if ( $total > 70 ) {

        my $skipped = $total - 70;
        warn
"Too many data, taking only first 70 highest values. Skipping $skipped entries\n";

  #        my @data = ( \@times, \@dx_parse_time, \@ts_time, \@vis_check_time );
        $data_ref =
          first_high( $day, \%rows, \@times, 70,
            [qw(dx_parse_time ts_time vis_check_time)] );

    }
    else {

        foreach my $time (@times) {

            if ( exists( $rows{$day}->{$time} ) ) {

                push( @dx_parse_time,
                    $rows{$day}->{$time}->{greatest}->{dx_parse_time} );
                push( @ts_time, $rows{$day}->{$time}->{greatest}->{ts_time} );
                push( @vis_check_time,
                    $rows{$day}->{$time}->{greatest}->{vis_check_time} );

                push( @downloads,
                    $rows{$day}->{$time}->{greatest}->{downloads} );
                push( @enterprise,
                    $rows{$day}->{$time}->{greatest}->{enterprise} );
                push( @nonvis_events,
                    $rows{$day}->{$time}->{greatest}->{nonvis_events} );
                push( @removes, $rows{$day}->{$time}->{greatest}->{removes} );
                push( @vis_events,
                    $rows{$day}->{$time}->{greatest}->{vis_events} );

            }
            else {

                warn "$time does not exists at $day\n";

            }

        }

    }

    my $graph_times = GD::Graph::lines->new( 1440, 900 );

    $graph_times->set(
        x_label           => 'Time of day (hh:mm:ss)',
        y_label           => 'Time spend (ms)',
        title             => 'Time spent on operations by timestamp',
        x_labels_vertical => 1,
        transparent       => 0,
        bgclr             => 'white',
        logo              => 'perlpowered.png',
        logo_position     => 'UR'

          #        y_max_value       => 800
    ) or die $graph_times->error();

    $graph_times->set_legend( 'DX Parse Time',
        'TS Time', 'Visibility Check Time' );

    my $gd = $graph_times->plot($data_ref) or die $graph_times->error();

    my $path = File::Spec->catfile( $opts{d}, $times_img );

    open( my $img, '>', $path ) or die "Cannot create $path: $!\n";
    binmode($img);
    print $img $gd->png();
    close($img);

    exit(0);

    my $graph_opers = GD::Graph::lines->new( 1440, 900 );

    #    @data = (
    #        \@partial,       \@downloads, \@enterprise,
    #        \@nonvis_events, \@removes,   \@vis_events
    #    );

    $graph_opers->set(
        x_label           => 'Time of day (hh:mm:ss)',
        y_label           => 'Total of operations',
        title             => 'Total of operations by timestamp',
        x_labels_vertical => 1,
        transparent       => 0,
        bgclr             => 'white',
        logo              => 'perlpowered.png',
        logo_position     => 'UR'

          #        y_max_value       => 1200
    ) or die $graph_opers->error();

    $graph_opers->set_legend(
        'Downloads',             'Enterprise',
        'Non Visibility Events', 'Removes',
        'Visibility Events'
    );

    my $gd2 = $graph_opers->plot($data_ref) or die $graph_opers->error();

    $path = File::Spec->catfile( $opts{d}, $opers_img );

    open( my $img2, '>', $path ) or die "Cannot create $path: $!\n";
    binmode($img2);
    print $img2 $gd2->png();
    close($img2);

}

print "Finished\n";

# subs

# this sub will get the first N highest values
sub first_high {

    my $day       = shift;    #string
    my $rows_ref  = shift;    #hash ref
    my $times_ref = shift;    #array ref with ordered times
    my $first     = shift;    #integer
    my $items_ref = shift;

    my %data;

    foreach my $time ( @{$times_ref} ) {

        if ( exists( $rows_ref->{$day}->{$time} ) ) {

            foreach my $item ( @{$items_ref} ) {

                my $value = $rows_ref->{$day}->{$time}->{greatest}->{$item};

                $data{$item}->{$time} = $value;

            }

        }
        else {

            warn "$time does not exists at $day\n";

        }

    }

    my $last = $first - 1;

    my %new_times;

    foreach my $item ( @{$items_ref} ) {

        my @high;
        my $counter = 0;

        foreach my $time (
            sort { $data{$item}->{$b} <=> $data{$item}->{$a} }
            keys( %{ $data{$item} } )
          )
        {

            push( @high, $time );
            $counter++;

            last if ( $counter == $last );

        }

        foreach my $time (@high) {

            #            print $time, "\t", $data{$item}->{$time}, "\n";
            $new_times{$time} = 0;    #removes duplicated timestamp

        }

    }

    my @sorted_new_times = sort( keys(%new_times) );

    my %new_data = ( dx_parse_time => [], ts_time => [], vis_check_time => [] );

    my @dx_parse_time;
    my @ts_time;
    my @vis_check_time;

    foreach my $timestamp (@sorted_new_times) {

        foreach my $item ( @{$items_ref} ) {

            if ( exists( $data{$item}->{$timestamp} ) ) {

                push(
                    @{ $new_data{$item} },
                    $data{$item}->{$timestamp}
                );

            }
            else {

                push( @{ $new_data{$item} }, 0 );

            }

        }

    }

    return [
        \@sorted_new_times,
        $new_data{dx_parse_time},
        $new_data{ts_time},
        $new_data{vis_check_time}
    ];

  #        my @data = ( \@times, \@dx_parse_time, \@ts_time, \@vis_check_time );

}
