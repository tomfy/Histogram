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
   my $lo_limit = undef;
   my $hi_limit = undef;
   my $binwidth = undef;
   my $persist = 0;
   my $do_plot = 1;
   my $log_y = 0;

   GetOptions(
              'input_filename=s' => \$input_filename,
              'columns=s' => \$columns, # unit based, i.e. left-most column is 1
              'low_limit=f' => \$lo_limit,
              'hi_limit=f' => \$hi_limit,
              'bw|binwidth|width=f' => \$binwidth,
	      'plot!' => \$do_plot, # -noplot to suppress plot - just see histogram as text.
              'logy!' => \$log_y,
	     );


   print "columns [$columns] \n";
   my $histogram_obj = Histograms->new({
                                        data_file => $input_filename, data_columns => $columns, 
                                        lo_limit => $lo_limit, hi_limit => $hi_limit, binwidth => $binwidth
                                       });
   #print $histogram_obj->lo_limit(), "  ", $histogram_obj->hi_limit(), "\n";
   my $plot = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
   $histogram_obj->bin_data();
   my $histogram_as_string = $histogram_obj->as_string();
   print "$histogram_as_string \n";
   if ($log_y) {
     $plot->gnuplot_cmd('set log y');
     $plot->gnuplot_set_yrange(0.8, '*');
   }
   plot_the_plot($histogram_obj, $plot) if($do_plot);

   #####  modify plot in response to keyboard commands: #####
   while (1) {
     my $cmd_param = <>; # command and optionally a parameter, e.g. 'x 0.8'
     chomp $cmd_param;
  #    print "[$cmd_param]\n";
      if ($cmd_param =~ s/^\s*(\S+)\s*//) {
         my $cmd = $1;
         my $param = ($cmd_param =~ (/\s*(\S+)\s*/))? $1 : undef;
#	 print "[$cmd] [", $param // 'undef', "]\n";
	 if ($cmd eq 'p') {
            plot_the_plot($histogram_obj, $plot);
	 } elsif ($cmd eq 'g') {
	   $plot->gnuplot_cmd('set grid');
	     plot_the_plot($histogram_obj, $plot);
       #     $plot->gnuplot_cmd('refresh');
         } elsif ($cmd eq 'q') {
            last;
	  } elsif ($cmd eq 'll') {
	    if($log_y){
	      $log_y = 0;
	      $plot->gnuplot_cmd('unset log');
	       $plot->gnuplot_set_yrange('*', '*');
	    }else{
	      $log_y = 1;
	      $plot->gnuplot_cmd('set log y');
	      $plot->gnuplot_set_yrange(0.8, '*');
	    }
            plot_the_plot($histogram_obj, $plot);
         #   $plot->gnuplot_cmd('refresh');
         } elsif ($cmd eq 'refresh') {
            $plot->gnuplot_cmd('refresh');
         } elsif ($cmd eq 'x') {
            $histogram_obj->expand_range($param);
            $histogram_obj->bin_data();
	    plot_the_plot($histogram_obj, $plot);
         } elsif ($cmd eq 'bw') {
            $histogram_obj->set_binwidth($param);
            $histogram_obj->bin_data();
	    plot_the_plot($histogram_obj, $plot);
         } elsif ($cmd eq 'lo') {
            $histogram_obj->change_range($param, undef);
            plot_the_plot($histogram_obj, $plot);
         } elsif ($cmd eq 'hi') {
            $histogram_obj->change_range(undef, $param);
            plot_the_plot($histogram_obj, $plot);
	  } elsif ($cmd eq 'c'){
	    $histogram_obj->change_binwidth($param);
	    $histogram_obj->bin_data();
	    plot_the_plot($histogram_obj, $plot);
	  } elsif ($cmd eq 'r'){
	    $histogram_obj->change_binwidth($param? -1*$param : -1);
	    $histogram_obj->bin_data();
	    plot_the_plot($histogram_obj, $plot);
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
   $plot_obj->gnuplot_set_xrange($histogram_obj->lo_limit(), $histogram_obj->hi_limit());
   my $bin_centers = $histogram_obj->column_hdata()->{pooled}->bin_centers();
   #my $bin_counts = $histogram_obj->column_hdata()->{pooled}->bin_counts();

   my @plot_titles = map("col $_", @{$histogram_obj->get_column_specs()} );
   $plot_obj->gnuplot_set_plot_titles(@plot_titles);

   my @histo_bin_counts = map($histogram_obj->column_hdata()->{$_}->bin_counts(), @{$histogram_obj->get_column_specs()});
   $plot_obj->gnuplot_plot_xy($bin_centers, @histo_bin_counts); # , $bin_counts);
  
}
