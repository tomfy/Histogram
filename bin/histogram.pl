#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Graphics::GnuplotIF qw(GnuplotIF);
use Math::GSL::SF  qw( :all );



use File::Basename 'dirname';
use Cwd 'abs_path';
my ( $bindir, $libdir );
BEGIN {     # this has to go in Begin block so happens at compile time
   $bindir =
     dirname( abs_path(__FILE__) ) ; # the directory containing this script
   $libdir = $bindir . '/../lib';
   $libdir = abs_path($libdir);	# collapses the bin/../lib to just lib
}
use lib $libdir;

use Histograms;

{                               # main
   my $input_filename = undef;
   my $columns = undef;
   my $min_x = undef;
   my $max_x = undef;
   my $binwidth = undef;
my $persist = 0;

   GetOptions(
              'input_filename=s' => \$input_filename,
              'columns=s' => \$columns, # unit based, i.e. left-most column is 1
              'min_x=f' => \$min_x,
              'max_x=f' => \$max_x,
              'binwidth|width=f' => \$binwidth,
             );


print "columns [$columns] \n";
   my $histogram_obj = Histograms->new({
                                       data_file => $input_filename, data_columns => $columns, 
                                       min_x => $min_x, max_x => $max_x, binwidth => $binwidth
                                      });
#print $histogram_obj->min_x(), "  ", $histogram_obj->max_x(), "\n";

   $histogram_obj->bin_data();
   my $histogram_as_string = $histogram_obj->as_string;
print "$histogram_as_string\n";

my $plot = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
$plot->gnuplot_set_xrange($histogram_obj->min_x(), $histogram_obj->max_x());
my $bin_centers = $histogram_obj->column_hdata()->{pooled}->bin_centers();
my $bin_counts = $histogram_obj->column_hdata()->{pooled}->bin_counts();
#print join(", ", @$bin_centers);
#print join(", ", @$bin_counts);
$plot->gnuplot_plot_xy($bin_centers, $bin_counts);
$plot->gnuplot_pause();

}                               # end of main
###########
