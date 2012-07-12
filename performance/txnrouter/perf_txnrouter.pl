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
use Getopt::Long qw(:config auto_version auto_help);
use File::Spec;
use Pod::Usage;

our $VERSION = 0.2;

my $input_dir = '';
my $max_high  = 70;
my $export    = 0;

GetOptions(
    "input=s" => \$input_dir,
    'max:i'   => \$max_high,
    'export'  => \$export
) or pod2usage(2);

pod2usage(2) if ( $input_dir eq '' );

opendir( my $dir, $input_dir ) or die "Cannot read directory $input_dir: $!\n";
my @files = readdir($dir);
close($dir);

my %rows;

# pre-compiled regexes to improve performance
my $perf_regex           = qr/^Performance\tPerformance\t\d/;
my $header_regex         = qr/Node\sName\|Total\sOpers.*/;
my $vis_check_time_regex = qr/Vis\sCheck\sTime\:\s/;
my $dx_file_regex        = qr/\sdx\sfile\sparsing\stime\:\s/;

# I/O references for exporting data
my $opers_out;
my $times_out;

if ($export) {

	print "Exporting data is enabled\n";

    my $opers_file = 'operations.csv';
    my $times_file = 'times.csv';

    open( $times_out, '>', $times_file )
      or die "Cannot created $times_file: $!\n";
    print $times_out
      "Date,Time,VisCheckTime,DXFileParsingTime,TotalTime,TSTime\n";

    open( $opers_out, '>', $opers_file )
      or die "Cannot created $opers_file: $!\n";
    print $opers_out
"Date,Time,NodeName,TotalOpers,VisEvents,NonVisEvents,Enterprise,Downloads,Removes\n";

}

foreach my $file (@files) {

    next unless ( $file =~ /^TxnRoute_\d+\.log$/ );

    my $path = File::Spec->catfile( $input_dir, $file );

    open( my $in, '<', "$path" ) or die "Cannot read $path: $!\n";

    print "Reading $path\n";

    my $no_perf_data = 1;

    my %last_time;

    while (<$in>) {

        chomp();

        if ( $_ =~ $perf_regex ) {

            $no_perf_data = 0;

            my ( $current_time, $data ) = ( split( /\t/, $_ ) )[ 3, 4 ];
            my ( $date, $timestamp ) = split( /\s/, $current_time );

            if ($export) {

                unless ( exists( $last_time{$current_time} ) ) {

                    $last_time{$current_time} = {
                        vis_check_time => 0,
                        dx_parse_time  => 0,
                        total_time     => 0,
                        ts_time        => 0
                    };

                }

            }

            unless ( exists( $rows{$date}->{$timestamp} ) ) {

# TODO the greatest key is not necessary anymore, remove it and use a simple hash
                $rows{$date}->{$timestamp} = {
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

                if ( $data =~ $vis_check_time_regex ) {

                    $data =~ s/$vis_check_time_regex//;

                    $data =~ s/$dx_file_regex//;

                    $data =~ tr/ //d;

                    my @fields = split( /\;/, $data );

# :TODO:09/08/2011 15:51:07:: this should be refactored since is not general usage
                    $rows{$date}->{$timestamp}->{greatest}->{vis_check_time} =
                      $fields[0]
                      if ( $fields[0] > $rows{$date}->{$timestamp}->{greatest}
                        ->{vis_check_time} );

                    $rows{$date}->{$timestamp}->{greatest}->{dx_parse_time} =
                      $fields[1]
                      if ( $fields[1] > $rows{$date}->{$timestamp}->{greatest}
                        ->{dx_parse_time} );

                    if ($export) {

                        if ( exists( $last_time{$current_time} ) ) {

                            $last_time{$current_time}->{vis_check_time} =
                              $fields[0];
                            $last_time{$current_time}->{dx_parse_time} =
                              $fields[1];

                        }

                    }

                    last CASE;

                }

                if ( $data =~ $header_regex ) {

                    last CASE;

                }
                else {

                    my @fields = split( /\|/, $data );

# fields have the following sequence of data
# Node Name|Total Opers|Time|TS Time|VisEvents|NonVisEvents|Enterprise|Downloads|Removes

                    my @attribs =
                      qw(total_opers total_time ts_time vis_events nonvis_events enterprise downloads removes);
                    my $counter = 1;

                    foreach my $attrib (@attribs) {

                        $rows{$date}->{$timestamp}->{greatest}->{$attrib} =
                          $fields[$counter]
                          if ( $fields[$counter] >
                            $rows{$date}->{$timestamp}->{greatest}->{$attrib} );

                        $counter++;

                    }

                    if ($export) {

                        if ( exists( $last_time{$current_time} ) ) {

                            $last_time{$current_time}->{total_time} =
                              $fields[2];
                            $last_time{$current_time}->{ts_time} = $fields[3];

                            my ( $date, $timestamp ) =
                              split( /\s/, $current_time );

                            print $times_out join( ",",
                                $date,
                                $timestamp,
                                $last_time{$current_time}->{vis_check_time},
                                $last_time{$current_time}->{dx_parse_time},
                                $last_time{$current_time}->{total_time},
                                $last_time{$current_time}->{ts_time} ),
                              "\n";

                            delete( $last_time{$current_time} );

                        }
                        else {

                            warn "could not find matching of timestamp\n";

                        }

                        my ( $date, $timestamp ) = split( /\s/, $current_time );

                        # removing time data from the fields
                        splice( @fields, 2, 1 );
                        splice( @fields, 2, 1 )
                          ;    #array was reduced in number of items

                        print $opers_out
                          join( ',', $date, $timestamp, @fields ), "\n";

                    }

                    last CASE;

                }

            }

        }

    }

    close($in);

    print "File $file has no performance data\n" if ($no_perf_data);

}

print "Finished reading log files\n";

if ($export) {

    close($opers_out);
    close($times_out);

}

if ( keys(%rows) ) {

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

        my $times_data_ref;
        my $opers_data_ref;

# :WORKAROUND:10/08/2011 15:58:11:: had to put a limit to the amount of registries considered or the graph would become too hard to read
        if ( $total > $max_high ) {

            my $skipped = $total - $max_high;
            warn
"Too much data at $day, taking only first $max_high highest values. Skipping $skipped entries\n";

            $times_data_ref =
              first_high( $day, \%rows, \@times, $max_high,
                [qw(dx_parse_time ts_time vis_check_time)] );

            $opers_data_ref =
              first_high( $day, \%rows, \@times, $max_high,
                [qw(downloads enterprise nonvis_events removes vis_events)] );

        }
        else {

            foreach my $time (@times) {

                if ( exists( $rows{$day}->{$time} ) ) {

                    push( @dx_parse_time,
                        $rows{$day}->{$time}->{greatest}->{dx_parse_time} );
                    push( @ts_time,
                        $rows{$day}->{$time}->{greatest}->{ts_time} );
                    push( @vis_check_time,
                        $rows{$day}->{$time}->{greatest}->{vis_check_time} );

                    push( @downloads,
                        $rows{$day}->{$time}->{greatest}->{downloads} );
                    push( @enterprise,
                        $rows{$day}->{$time}->{greatest}->{enterprise} );
                    push( @nonvis_events,
                        $rows{$day}->{$time}->{greatest}->{nonvis_events} );
                    push( @removes,
                        $rows{$day}->{$time}->{greatest}->{removes} );
                    push( @vis_events,
                        $rows{$day}->{$time}->{greatest}->{vis_events} );

                }
                else {

                    warn "$time does not exists at $day\n";

                }

                $times_data_ref =
                  [ \@times, \@dx_parse_time, \@ts_time, \@vis_check_time ];
                $opers_data_ref = [
                    \@times,         \@downloads, \@enterprise,
                    \@nonvis_events, \@removes,   \@vis_events
                ];

            }

        }

        gen_times_graph( $times_data_ref, $times_img, $input_dir, $day );
        gen_opers_graph( $opers_data_ref, $opers_img, $input_dir, $day );

    }

}
else {

    print "Cannot generate charts without performance data\n";

}

print "Finished\n";

##############################
# subs

# this sub will get the first N highest values
sub first_high {

    my $day       = shift;    #string
    my $rows_ref  = shift;    #hash ref
    my $times_ref = shift;    #array ref with ordered times
    my $first     = shift;    #integer
    my $items_ref =
      shift;    #array ref with performance items name to be evaluated

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

            $new_times{$time} = 0;    #removes duplicated timestamp

        }

    }

    my @sorted_new_times = sort( keys(%new_times) );

    my %new_data;

    foreach my $item ( @{$items_ref} ) {

        $new_data{$item} = [];

    }

    foreach my $timestamp (@sorted_new_times) {

        foreach my $item ( @{$items_ref} ) {

            if ( exists( $data{$item}->{$timestamp} ) ) {

                push( @{ $new_data{$item} }, $data{$item}->{$timestamp} );

            }
            else {

                push( @{ $new_data{$item} }, 0 );

            }

        }

    }

    my @return_data = ( \@sorted_new_times );

    foreach my $item ( @{$items_ref} ) {

        push( @return_data, $new_data{$item} );

    }

    return \@return_data;

}

sub gen_img {

    my $graph    = shift;
    my $img_path = shift;

    open( my $img, '>', $img_path ) or die "Cannot create $img_path: $!\n";
    binmode($img);
    print $img $graph->png();
    close($img);

}

sub gen_times_graph {

    # [ \@times, \@dx_parse_time, \@ts_time, \@vis_check_time ];
    my $data_ref  = shift;
    my $times_img = shift;
    my $input_dir = shift;
    my $day       = shift;

    my $graph_times = GD::Graph::lines->new( 1440, 900 );

    $graph_times->set(
        x_label           => 'Time of day (hh:mm:ss)',
        y_label           => 'Time spend (ms)',
        title             => "Time spent on operations by timestamp at $day",
        x_labels_vertical => 1,
        transparent       => 0,
        bgclr             => 'white',
        logo              => 'perlpowered.png',
        logo_position     => 'UR'
    ) or die $graph_times->error();

    $graph_times->set_legend( 'DX Parse Time',
        'TS Time', 'Visibility Check Time' );

    my $gd = $graph_times->plot($data_ref) or die $graph_times->error();

    gen_img( $gd, File::Spec->catfile( $input_dir, $times_img ) );

}

sub gen_opers_graph {

    my $data_ref  = shift;
    my $opers_img = shift;
    my $input_dir = shift;
    my $day       = shift;

    my $graph_opers = GD::Graph::lines->new( 1440, 900 );

    $graph_opers->set(
        x_label           => 'Time of day (hh:mm:ss)',
        y_label           => 'Total of operations',
        title             => "Total of operations by timestamp at $day",
        x_labels_vertical => 1,
        transparent       => 0,
        bgclr             => 'white',
        logo              => 'perlpowered.png',
        logo_position     => 'UR'
    ) or die $graph_opers->error();

    $graph_opers->set_legend(
        'Downloads',             'Enterprise',
        'Non Visibility Events', 'Removes',
        'Visibility Events'
    );

    my $gd = $graph_opers->plot($data_ref) or die $graph_opers->error();

    gen_img( $gd, File::Spec->catfile( $input_dir, $opers_img ) );

}

__END__

 =head1 NAME

perf_txnrouter - Parses Txnrouter log files and generate graphics from their performance data

=head1 SYNOPSIS

perf_txnrouter [options]

Parses Txnrouter log files and generate performance graphics from their data

Options:

	--input: input directory (required)
	--max: maximum highest value
	--export: if enabled, will create text files with the performance data parsed
	--help: brief help message
	--version: version information about the program

By using "perldoc perf_txnrouter" you can have more detailed information about using the program.

=head1 OPTIONS

=over 3 

=item --help

Print a brief help message and exits.

=item --input
 
Input directory from where to read the Transaction Router log files. This parameter is obligatory.

=item --max

Maximum highest value to consider to generate the graphics. This parameter is optional and the default value is 70.

=back

=head1 DESCRIPTION

perl_txnrouter is a Perl script to parse Siebel Transaction Router log files with performance information and produce graphic images about the values recovered.

When trying to identify performance issues with Siebel Transaction Router, it is possible to change the log levels of the component to generate performance information. 
This information can lead to huge log files (measured in Mb or even Gb) that are just too hard to have information checked with a common text editor.

This program was created to parse those log files, looking for performance information and generating two line charts:

=over

=item *

one with information about time taken to execute tasks in a given timestamp

=item *

one with information about the number of operations in a given timestamp

=back

Each point in those charts mean the highest value found in that timestamp (not all values will be show in the chart).

When the amount of information is too large to fit in a chart, the program can accept a parameter to show only N highest values found in the log files. 
Please check the command line help for more information.

If desired, the parsed data can be exported to CSV files, which can be latter easily imported into programs as Microsoft Excel or R for statistics analysis. This is useful, 
for example, when is desired to have more information that the one generated automatically by the program (as charts).

With this information, the user can have a hint of when the component started taking too much time to route information and/or have too much operations 
to execute and compare with measures taken from the servers (like CPU, memory and network usage by time).

This program is part of Siebel GNU Tools.

=head1 COPYRIGHT

This software is copyright (c) 2012 of Alceu Rodrigues de Freitas Junior, glasswalk3r@yahoo.com.br, licensed under GPL v3

=cut
