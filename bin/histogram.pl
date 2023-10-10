#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Graphics::GnuplotIF qw(GnuplotIF);
# use Math::GSL::SF  qw( :all );
my $y_plot_factor = 1.08;
my $y_plot_factor_log = 1.5;

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
  unlink glob ".gnuplot*.stderr.log"; # to avoid accumulation of log files.
  my $lo_limit = 0;
  my $hi_limit = undef;
  my $binwidth = undef;
  my $persist = 0;
  my $do_plot = 1;
  my $log_y = 0;
  my $key_horiz_position = 'right';
  my $key_vert_position = 'top';
  my $data = undef;
  my $gnuplot_command = undef;
  my $linewidth = 1.5;
  my $terminal = 'x11';
  my $ymin = 0;
  my $ymax = "*";
  my $ymax_log = "*";
  my $ymin_log = 0.8;
  my $output_filename = 'histogram'; # default is to just send to screen.
  my $show_on_screen = 1;
  my $write_to_png = 0;
  my $interactive = undef;
  my $enhanced = 0;
  my $vline_at_x = undef;
  
  GetOptions(
	     'data_input|input=s' => \$data,
	     #             'input_filename=s' => \$input_filename,
	     #             'columns=s' => \$columns, # unit based, i.e. left-most column is 1
	     'output_filename=s' => \$output_filename, # to send output to a (png) file, specify a filename
	     'low_limit|xmin=f' => \$lo_limit,
	     'hi_limit|xmax=f' => \$hi_limit,
	     'bw|binwidth|width=f' => \$binwidth,
	     'plot!' => \$do_plot, # -noplot to suppress plot - just see histogram as text.
	     'logy!' => \$log_y,
	     'h_key|key_horiz_position=s' => \$key_horiz_position,
	     'v_key|key_vert_positioqn=s' => \$key_vert_position,
	     'command=s' => \$gnuplot_command,
	     'linewidth|lw=f' => \$linewidth,
	     'terminal=s' => \$terminal,
	     'screen!' => \$show_on_screen,
	     'png!' => \$write_to_png,
	     'interactive!' => \$interactive, # if true, plot and wait for further commands, else plot and exit
	     'enhanced!' => \$enhanced,
	     'ymax=f' => \$ymax,
	     'log_ymax=f' => \$ymax_log,
	     'vline_at_x=f' => \$vline_at_x,
	    );

  $lo_limit = undef if($lo_limit eq 'auto'); # now default is 0.

  if (!defined $interactive) {
    $interactive = ($write_to_png)? 0 : 1;
  }

  $enhanced = ($enhanced)? 'enhanced' : 'noenhanced';

  print "files&columns to histogram: [$data] \n";
  #my @plot_titles = ($data =~ /\"([^"]+)\"/g); # assumes all have a title in "", otherwise misdistributes them -- improve this!
  # print "plot_titles:  ", join("  ", @plot_titles), "\n";
  #  $data =~ s/\"([^"]+)\"//g;
  
  my $histogram_obj = Histograms->new({
				       data_fcol => $data,
				       lo_limit => $lo_limit,
				       hi_limit => $hi_limit, 
				       binwidth => $binwidth
				      });
  $histogram_obj->bin_data();
  print "Max bin y: ", $histogram_obj->max_bin_y(), "\n";
  my $histogram_as_string = $histogram_obj->as_string();
  print "$histogram_as_string \n";

  {				# $plot defined within this block
    my $plot = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
    #, plot_titles => \@plot_titles); #, xlabel => 'lxable');

    $plot->gnuplot_cmd("set terminal $terminal noenhanced linewidth $linewidth");
    $plot->gnuplot_cmd('set tics out');

    $ymax_log = $y_plot_factor_log*$histogram_obj->max_bin_y();
    $ymax = $y_plot_factor*$histogram_obj->max_bin_y();
    if ($log_y) {
      $plot->gnuplot_cmd('set log y');
      $plot->gnuplot_set_yrange(0.8, (defined $ymax_log)? $ymax_log : '*');
      set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
    } else {
      if (defined $vline_at_x) {
	#  $plot->gnuplot_cmd("set arrow nohead from $vline_at_x,0 to $vline_at_x,$ymax lw 0.75 dt '-'");
	set_arrow($plot, $vline_at_x, $ymin, $ymax);
      }
      $plot->gnuplot_set_yrange(0, (defined $ymax)? $ymax : '*');
    }

    #if($left_key) {
    my $key_pos_cmd = 'set key ' . "$key_horiz_position  $key_vert_position";
    $plot->gnuplot_cmd($key_pos_cmd);
    #}
    $plot->gnuplot_cmd('set border lw 1.25'); # apparently this width is relative to that for the histogram lines.
    $plot->gnuplot_cmd('set mxtics');
    $plot->gnuplot_cmd('set tics front');
    $plot->gnuplot_cmd('set tics scale 2,1');
    $plot->gnuplot_cmd($gnuplot_command) if(defined $gnuplot_command);
    #  $plot->gnuplot_cmd('set tics out');
    # $plot->gnuplot_set_plot_titles(@plot_titles);

    if ($write_to_png) {
      $plot->gnuplot_hardcopy($output_filename . '.png', "png $enhanced linewidth $linewidth");
      #  $plot->gnuplot_cmd("set terminal png $enhanced  linewidth $linewidth");
      #  $output_filename .= '.png';
      $plot->gnuplot_cmd("set out $output_filename");
      plot_the_plot($histogram_obj, $plot);
      $plot->gnuplot_restore_terminal();
    }
    print "[$show_on_screen] [$terminal] [$do_plot]\n";
    if ($show_on_screen) {
      print "XXX\n";
      plot_the_plot($histogram_obj, $plot) if($do_plot);
    }
    if ($interactive) {
      #####  modify plot in response to keyboard commands: #####
      while (1) {		# loop to handle interactive commands.
	my $commands_string = <STDIN>; # command and optionally a parameter, e.g. 'x:0.8'
	$commands_string =~ s/\s+$//g; # delete whitespace
	last if($commands_string eq 'q');
	my @cmds = split(';', $commands_string);
	my ($cmd, $param) = (undef, undef);

	for my $cmd_param (@cmds) {
	  if ($cmd_param =~ /^([^:]+):(.+)/) {
	    ($cmd, $param) = ($1, $2);
	    $param =~ s/\s+//g if(! $cmd =~ /^\s*xlabel\s*$/);
	    print STDERR "cmd: [$cmd]  param: [$param]\n";
	  } elsif ($cmd_param =~ /^(\S+)/) {
	    $cmd = $1;
	  }
	  $cmd =~ s/\s+//g;
	  #    print "[$cmd_param]\n";
	  #   if ($cmd_param =~ s/^\s*(\S+)\s*//) {
	  if (defined $cmd) {
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
	      if ($log_y) {
		$log_y = 0;
		$plot->gnuplot_cmd('unset log');
		
	
		set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
		$plot->gnuplot_set_yrange($ymin, $ymax);
	      } else {
		$log_y = 1;
		$plot->gnuplot_cmd('set log y');
			print STDERR "ll max_bin_y: ", $histogram_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
		print STDERR "ll $ymin $ymax\n";
		print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
		set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
		$plot->gnuplot_set_yrange($ymin_log, $ymax_log);
	      }
	    } elsif ($cmd eq 'ymax') {
	      if (!$log_y) {
		$ymax = $param;
		set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
		print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
		$plot->gnuplot_set_yrange($ymin, $ymax);
	      } else {
		$ymax_log = $param;
		set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
		$plot->gnuplot_set_yrange($ymin_log, $ymax_log);
	      }
	    } elsif ($cmd eq 'ymin') {
	      if (!$log_y) {
		$ymin = $param;
		print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
		$plot->gnuplot_set_yrange($ymin, $ymax);
	      } else {
		$ymin_log = $param;
		$plot->gnuplot_set_yrange($ymin_log, $ymax_log);
	      }
	    } elsif ($cmd eq 'x') { # expand (or contract) x range.
	      $histogram_obj->expand_range($param);
	      $histogram_obj->bin_data();
	      #   plot_the_plot($histogram_obj, $plot);
	    } elsif ($cmd eq 'bw') { # set the bin width
	      $histogram_obj->set_binwidth($param);
	      $histogram_obj->bin_data();
	      #   plot_the_plot($histogram_obj, $plot);
	    } elsif ($cmd eq 'lo' or $cmd eq 'low' or $cmd eq 'xmin') { # change low x-scale limit
	      $histogram_obj->change_range($param, undef);
	      $histogram_obj->bin_data();
	      #  plot_the_plot($histogram_obj, $plot);
	    } elsif ($cmd eq 'hi' or $cmd eq 'xmax') { # change high x-scale limit
	      $histogram_obj->change_range(undef, $param);
	      $histogram_obj->bin_data();
	      #   plot_the_plot($histogram_obj, $plot);
	    } elsif ($cmd eq 'c') { # coarsen bins
	      $histogram_obj->change_binwidth($param);
	      $histogram_obj->bin_data();
	      $ymax = $histogram_obj->max_bin_y()*$y_plot_factor;
	      $ymax_log = $histogram_obj->max_bin_y()*$y_plot_factor_log;
	      if($log_y){
		$plot->gnuplot_set_yrange($ymin_log, $ymax_log);
		set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
	      }else{
		$plot->gnuplot_set_yrange($ymin, $ymax);
		set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
	      }
	      #   plot_the_plot($histogram_obj, $plot);
	    } elsif ($cmd eq 'r') { # refine bins
	      $histogram_obj->change_binwidth($param? -1*$param : -1);
	      $histogram_obj->bin_data();
	      $ymax = $histogram_obj->max_bin_y()*$y_plot_factor;
	      $ymax_log = $histogram_obj->max_bin_y()*$y_plot_factor_log;
	      if($log_y){
		$plot->gnuplot_set_yrange($ymin_log, $ymax_log);
		set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
	      }else{
		$plot->gnuplot_set_yrange($ymin, $ymax);
		set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
	      }
	      #   plot_the_plot($histogram_obj, $plot);
	    } elsif ($cmd eq 'key') { # move the key (options are left, right, top, bottom)
	      my $new_key_position = $param // 'left'; #
	      $new_key_position =~ s/,/ /; # so can use e.g. left,bottom to move both horiz. vert. at once
	      $plot->gnuplot_cmd("set key $new_key_position");
	      #   plot_the_plot($histogram_obj, $plot);
	    } elsif ($cmd eq 'xlabel') {
	      $param =~ s/^\s+//;
	      $param =~ s/\s+$//;
	      $param =~ s/^([^'])/'$1/;
	      $param =~ s/([^']\s*)$/$1'/;
	      print STDERR "param: $param \n";
	      $plot->gnuplot_cmd("set xlabel $param");
	    } elsif ($cmd eq 'export') {
	      $param =~ s/'//g; # the name of the file to export to; the format will be png, and '.png' will be added to filename

	      $plot->gnuplot_hardcopy($param . '.png', "png linewidth $linewidth");
	      plot_the_plot($histogram_obj, $plot);
	      $plot->gnuplot_restore_terminal();
	    } elsif ($cmd eq 'off') {
	      $histogram_obj->histograms_to_plot()->[$param-1] = 0;
	    } elsif ($cmd eq 'on') {
	      $histogram_obj->histograms_to_plot()->[$param-1] = 1;
	    } elsif ($cmd eq 'cmd') {
	      print STDERR "xxcmd: $cmd param: $param\n";
	      if ($param =~ /^\s*['](.+)[']\s*$/) { # remove surrounding single quotes if present
		$param = $1;
	      }
	      print STDERR "xxxcmd: $cmd  param: $param\n";
	      $plot->gnuplot_cmd("$param");
	    }
	    print STDERR "about to plot_the_plot\n";
	    print STDERR "max_bin_y: ", $histogram_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
	    plot_the_plot($histogram_obj, $plot);
	  }
	}
      }
    #  print "after interactive commands loop.\n";
    }
   # print "XXXXXXX\n";
  }
 
  # print "About to exit histogram.pl, but first sleep, perchance to dream (for 1 second).\n";
  # sleep(1);
  # print "Ok, wake up and exit.\n";
}				# end of main
###########


sub plot_the_plot{
  my $histogram_obj = shift;
  my $plot_obj = shift;
  #   my $persist = shift;

 
  #   my $plot_obj = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
  $plot_obj->gnuplot_set_xrange($histogram_obj->lo_limit(), $histogram_obj->hi_limit());
  my $bin_centers = $histogram_obj->filecol_hdata()->{pooled}->bin_centers();
  #print STDERR "Bin_centers  ", join(" ", @$bin_centers), "\n";
  #my $bin_counts = $histogram_obj->column_hdata()->{pooled}->bin_counts();
  # # =======
  #   my $histogram_obj = shift;
  #   my $plot_obj = shift;
  #   #   my $persist = shift;

 
  #   #   my $plot_obj = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps');
  #   $plot_obj->gnuplot_set_xrange($histogram_obj->lo_limit(), $histogram_obj->hi_limit());
  #   my $bin_centers = $histogram_obj->filecol_hdata()->{pooled}->bin_centers();
  #   #my $bin_counts = $histogram_obj->column_hdata()->{pooled}->bin_counts();
  # # >>>>>>>  989dd3ac8f8ad24edab82d9ce779e996bea2b741

  # my @plot_titles = map("$_", @{$histogram_obj->filecol_specifiers()} );
  # print STDERR "plot titles:  ", join("  ", @plot_titles), "\n";
  # $plot_obj->gnuplot_set_plot_titles(@plot_titles);
  my @plot_titles = ();


  my @histo_bin_counts = ();
  #  my @histo_bin_counts_w_styles = (); # array of hashrefs
  # map($histogram_obj->filecol_hdata()->{$_}->bin_counts(), @{$histogram_obj->filecol_specifiers()});
  while (my ($hi, $plt) = each @{$histogram_obj->histograms_to_plot()} ) {
    #  print STDERR "histograms to plot:  ", join(" ", @{$histogram_obj->histograms_to_plot()} ), "\n";
    if ($plt == 1) {
      print STDERR "adding histogram w index $hi.\n";
      my $fcspec = $histogram_obj->filecol_specifiers()->[$hi];
      my $hdata_obj = $histogram_obj->filecol_hdata()->{$fcspec};
      my $bincounts = $hdata_obj->bin_counts();
      push @plot_titles, $hdata_obj->label();
      #   print STDERR "Bincounts: $hi  ", "n bins: ", scalar @$bincounts, "  ", join(" ", @$bincounts), "\n";
      push @histo_bin_counts, $bincounts; # push an array ref holding the bin counts ...
      #     push @histo_bin_counts_w_styles, {y_values => $bincounts, style_spec => "t'description'"};
    }
  }
  #  print STDERR "n histograms: ", scalar @histo_bin_counts, "\n";
  # for my $hbc (@histo_bin_counts){
  #   print STDERR "bincounts: [", join("|", @$hbc), "]\n";
  # }
  #print STDERR "Bin_centers  ", scalar @$bin_centers, "  ", join(" ", @$bin_centers), "\n";
  $plot_obj->gnuplot_set_plot_titles(@plot_titles);
  $plot_obj->gnuplot_plot_xy($bin_centers, @histo_bin_counts); # , $bin_counts);
  #  $plot_obj->gnuplot_plot_xy_style($bin_centers, @histo_bin_counts_w_styles);
  
}

sub set_arrow{
  my $the_plot = shift;
  my $x_pos = shift;
  my $y_min = shift;
  my $y_max = shift;
  print "arrow top: $y_max\n";
  $the_plot->gnuplot_cmd("unset arrow");
  $the_plot->gnuplot_cmd("set arrow nohead from $x_pos,$y_min to $x_pos,$y_max lw 0.75 dt '-'");
}
