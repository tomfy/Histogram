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
   my $plot = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
   $histogram_obj->bin_data();
   my $histogram_as_string = plot_the_plot($histogram_obj, $plot);
   print "$histogram_as_string \n";

   # $histogram_obj->bin_data();
   # print $histogram_obj->as_string, "\n";

   # my $plot = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
   # $plot->gnuplot_set_xrange($histogram_obj->min_x(), $histogram_obj->max_x());
   # my $bin_centers = $histogram_obj->column_hdata()->{pooled}->bin_centers();
   # #my $bin_counts = $histogram_obj->column_hdata()->{pooled}->bin_counts();

   # my @plot_titles = map("col $_", @{$histogram_obj->get_column_specs()} );
   # $plot->gnuplot_set_plot_titles(@plot_titles);

   # my @histo_bin_counts = map($histogram_obj->column_hdata()->{$_}->bin_counts(), @{$histogram_obj->get_column_specs()});
   # $plot->gnuplot_plot_xy($bin_centers, @histo_bin_counts); # , $bin_counts);
   # # $plot->gnuplot_pause();

   while (1) {
      my $cmd_param = <>; # command and optionally a parameter, e.g. 'x 0.8'
      chomp $cmd_param;
      print "[$cmd_param]\n";
      if ($cmd_param =~ s/^\s*(\S+)\s*//) {
         my $cmd = $1;
         my $param = ($cmd_param =~ (/\s*(\S+)\s*/))? $1 : undef;
        print "[$cmd] [", $param // 'undef', "]\n";
         if ($cmd eq 'g') {
            $plot->gnuplot_cmd('set grid');
            $plot->gnuplot_cmd('refresh');
         } elsif ($cmd eq 'q') {
            last;
         } elsif ($cmd eq 'logy'){ #doesn't work.
            $plot->gnuplot_cmd('set log y');
            $plot->gnuplot_cmd('refresh');
}elsif($cmd eq 'r') {
            $plot->gnuplot_cmd('refresh');
         } elsif ($cmd eq 'x') {
            $histogram_obj->expand_range($param);
            $histogram_obj->bin_data();
            my $new_h_string = plot_the_plot($histogram_obj, $plot);
         }
      }

   }
}                               # end of main
###########


sub plot_the_plot{
   my $histogram_obj = shift;
   my $plot_obj = shift;
#   my $persist = shift;

 
#   my $plot_obj = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
   $plot_obj->gnuplot_set_xrange($histogram_obj->min_x(), $histogram_obj->max_x());
   my $bin_centers = $histogram_obj->column_hdata()->{pooled}->bin_centers();
   #my $bin_counts = $histogram_obj->column_hdata()->{pooled}->bin_counts();

   my @plot_titles = map("col $_", @{$histogram_obj->get_column_specs()} );
   $plot_obj->gnuplot_set_plot_titles(@plot_titles);

   my @histo_bin_counts = map($histogram_obj->column_hdata()->{$_}->bin_counts(), @{$histogram_obj->get_column_specs()});
   $plot_obj->gnuplot_plot_xy($bin_centers, @histo_bin_counts); # , $bin_counts);
   return $histogram_obj->as_string();
}
