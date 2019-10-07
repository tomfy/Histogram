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
#   my $input_filename = undef;
#   my $columns = undef;
   my $lo_limit = undef;
   my $hi_limit = undef;
   my $binwidth = undef;
   my $persist = 0;
   my $do_plot = 1;
   my $log_y = 0;
   my $data = undef;

   GetOptions(
              'data|input=s' => \$data,
 #             'input_filename=s' => \$input_filename,
 #             'columns=s' => \$columns, # unit based, i.e. left-most column is 1
              'low_limit=f' => \$lo_limit,
              'hi_limit=f' => \$hi_limit,
              'bw|binwidth|width=f' => \$binwidth,
	      'plot!' => \$do_plot, # -noplot to suppress plot - just see histogram as text.
              'logy!' => \$log_y,
	     );




   print "files&columns to histogram: [$data] \n";
   my $histogram_obj = Histograms->new({
                                        data_fcol => $data,
                                        lo_limit => $lo_limit, hi_limit => $hi_limit, binwidth => $binwidth
                                       });

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
     my $commands_string = <STDIN>; # command and optionally a parameter, e.g. 'x 0.8'
       $commands_string =~ s/\s+$//g; # delete whitespace
     last if($commands_string eq 'q');
     my @cmds = split(';', $commands_string);
     my ($cmd, $param) = (undef, undef);

     for my $cmd_param (@cmds){
        if($cmd_param =~ /^([^:]+):(.+)/){
           ($cmd, $param) = ($1, $2);
           $param =~ s/\s+//g if(! $cmd =~ /xlabel/);
        }elsif($cmd_param =~ /^(\S+)/){
           $cmd = $1;
        }
        $cmd =~ s/\s+//g;
  #    print "[$cmd_param]\n";
   #   if ($cmd_param =~ s/^\s*(\S+)\s*//) {
        if(defined $cmd){
           $commands_string =~ s/\s+//g if($cmd ne 'xlabel');
	 if ($cmd eq 'p') {
        #    plot_the_plot($histogram_obj, $plot);
	 } elsif ($cmd eq 'g') {
	   $plot->gnuplot_cmd('set grid');
	 #    plot_the_plot($histogram_obj, $plot);
       #     $plot->gnuplot_cmd('refresh');
         # } elsif ($cmd eq 'q') {
         #    last;
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
         #   plot_the_plot($histogram_obj, $plot);
         #   $plot->gnuplot_cmd('refresh');
         # } elsif ($cmd eq 'refresh') {
         #    $plot->gnuplot_cmd('refresh');
         } elsif ($cmd eq 'x') { # expand (or contract) x range.
            $histogram_obj->expand_range($param);
            $histogram_obj->bin_data();
	 #   plot_the_plot($histogram_obj, $plot);
         } elsif ($cmd eq 'bw') { # change bin width
            $histogram_obj->set_binwidth($param);
            $histogram_obj->bin_data();
	 #   plot_the_plot($histogram_obj, $plot);
         } elsif ($cmd eq 'lo') { # change low x-scale limit
            $histogram_obj->change_range($param, undef);
          #  plot_the_plot($histogram_obj, $plot);
         } elsif ($cmd eq 'hi') { # change high x-scale limit
            $histogram_obj->change_range(undef, $param);
         #   plot_the_plot($histogram_obj, $plot);
	  } elsif ($cmd eq 'c'){ # coarsen bins
	    $histogram_obj->change_binwidth($param);
	    $histogram_obj->bin_data();
	 #   plot_the_plot($histogram_obj, $plot);
	  } elsif ($cmd eq 'r'){ # refine bins
	    $histogram_obj->change_binwidth($param? -1*$param : -1);
	    $histogram_obj->bin_data();
	 #   plot_the_plot($histogram_obj, $plot);
         } elsif ($cmd eq 'key'){ # move the key (options are left, right, top, bottom)
            my $new_key_position = $param // 'left'; #
            $new_key_position =~ s/,/ /; # so can use e.g. left,bottom to move both horiz. vert. at once
              $plot->gnuplot_cmd("set key $new_key_position");
         #   plot_the_plot($histogram_obj, $plot);
         } elsif($cmd eq 'xlabel'){
$param =~ s/^\s+//;
$param =~ s/\s+$//;
$param =~ s/^([^'])/'$1/;
$param =~ s/([^']\s*)$/$1'/;
print STDERR "param: $param \n";
            $plot->gnuplot_cmd("set xlabel $param");
} elsif ($cmd eq 'export'){
   $param =~ s/'//g;
   $plot->gnuplot_hardcopy($param . '.png', 'png');
   plot_the_plot($histogram_obj, $plot);
   $plot->gnuplot_restore_terminal();
}
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
   my $bin_centers = $histogram_obj->filecol_hdata()->{pooled}->bin_centers();
   #my $bin_counts = $histogram_obj->column_hdata()->{pooled}->bin_counts();

   my @plot_titles = map("$_", @{$histogram_obj->filecol_specifiers()} );
   $plot_obj->gnuplot_set_plot_titles(@plot_titles);

   my @histo_bin_counts = map($histogram_obj->filecol_hdata()->{$_}->bin_counts(), @{$histogram_obj->filecol_specifiers()});
   $plot_obj->gnuplot_plot_xy($bin_centers, @histo_bin_counts); # , $bin_counts);
  
}
