#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use List::Util qw (min max sum);

my $y_plot_factor = 1.08;
my $y_plot_factor_log = 1.5;
my $relative_frame_thickness = 1.5; # the thickness of frame lines rel to histogram itself

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
#use Plot_params;
#use GD_plot;

{				      # main
  unlink glob ".gnuplot*.stderr.log"; # to avoid accumulation of log files.
  my $lo_limit = 'auto';	      # 0;
  my $hi_limit = undef;
  my $binwidth = undef;
  my $persist = 0;
  my $do_plot = 1;
  my $log_y = 0;
  my $key_horiz_position = 'center'; # 'right';
  #  print "#### $key_horiz_position \n"; sleep(1);
  my $key_vert_position = 'top';
  my $data = undef;
  my $gnuplot_command = undef;
  my $line_width = 2;
  my $terminal = 'x11';	   # (for gnuplot case) qt also works. Others?
  my $ymin = 0;
  my $ymax = "*";
  my $ymax_log = "*";
  my $ymin_log = 0.8;
  my $output_filename = 'histogram.png'; # default is to just send to screen.
  my $show_on_screen = 1;
  my $write_to_png = 0;
  my $interactive = undef;
  my $enhanced = 0;
  my $vline_position = undef;
  my $plot_title = undef;
  my $x_axis_label = undef;
  my $y_axis_label = undef;
  my $tight = 1;     # choose x range so as to include all data points
  my $plot_width = 640;		# pixels
  my $plot_height = 480;	# pixels
  my $histogram_color = undef;
  # other options for plot range: 'strict', 'loose_positive', 'loose'
  my $graphics = 'gnuplot';	# alternative is 'gd' 

  GetOptions(
	     'data_input|input=s' => \$data,
	     'output_filename=s' => \$output_filename, # to send output to a (png) file, specify a filename

	     # control of binning, x and y ranges:
	     'low_limit|xmin=f' => \$lo_limit,
	     'hi_limit|xmax=f' => \$hi_limit,
	     'bw|binwidth|width=f' => \$binwidth,
	     'logy!' => \$log_y,
	     'ymax=f' => \$ymax,
	     'log_ymax=f' => \$ymax_log,
	     'tight!' => \$tight,
	     # how to plot (gnuplot or GD, and plot parameters)
	     'graphics=s' => \$graphics,
	     # whether to plot, and where (screen or file)
	     'plot!' => \$do_plot, # -noplot to suppress plot - just see histogram as text.
	     'screen!' => \$show_on_screen,
	     'png!' => \$write_to_png,
	     'interactive!' => \$interactive, # if true, plot and wait for further commands, else plot and exit

	     'width=f' => \$plot_width,
	     'height=f' => \$plot_height,

	     'linewidth|line_width|lw=f' => \$line_width, # line thickness for histogram
	     'color=s' => \$histogram_color,

	     'title=s' => \$plot_title,
	     'x_axis_label|x_label|xlabel=s' => \$x_axis_label,
	     'y_axis_label|y_label|ylabel=s' => \$y_axis_label,
	     'h_key|key_horiz_position=s' => \$key_horiz_position,
	     'v_key|key_vert_position=s' => \$key_vert_position,

	     'vline_position=f' => \$vline_position,

	     # relevant to gnuplot
	     'terminal=s' => \$terminal, # x11, qt, etc.
	     'command=s' => \$gnuplot_command,
	     'enhanced!' => \$enhanced,
	    );

  if (lc $graphics eq 'gd') {
    print STDERR "GD graphics; setting terminal to only supported options: png \n" if(lc $terminal ne 'png');
    $terminal = 'png';
  } elsif (lc $graphics eq 'gnuplot') {
  } else {
    die "Graphics option $graphics is unknown. Allowed options are 'gnuplot' and 'gd'.\n";
  }

  $lo_limit = undef if($lo_limit eq 'auto'); # now default is 0.

  if (!defined $interactive) {
    $interactive = ($write_to_png)? 0 : 1;
  }

  $enhanced = ($enhanced)? 'enhanced' : 'noenhanced';

  print "files&columns to histogram: [$data] \n";

  my $histograms_obj = Histograms->new({
					data_fcol => $data,
					lo_limit => $lo_limit,
					hi_limit => $hi_limit,
					binwidth => $binwidth,
					tight => $tight,
				       });
  $histograms_obj->bin_data();
  print "Max bin y: ", $histograms_obj->max_bin_y(), "\n";
  my $histogram_as_string = $histograms_obj->as_string();
  print "$histogram_as_string \n";

  print "graphics will use: ", lc $graphics, "\n";

  $ymax_log = $y_plot_factor_log*$histograms_obj->max_bin_y();
  $ymax = $y_plot_factor*$histograms_obj->max_bin_y();
  # my $plot_params = Plot_params->new(
  # 				     output_filename => $output_filename,
  # 				     persist => $persist,
  # 				     terminal => $terminal,
  # 				     width => $plot_width,
  # 				     height => $plot_height,
  # 				     line_width => $line_width,
  # 				     histogram_color => $histogram_color,
  # 				     plot_title => $plot_title,
  # 				     x_axis_label => $x_axis_label,
  # 				     y_axis_label => $y_axis_label,
  # 				     key_horiz_position => $key_horiz_position,
  # 				     key_vert_position => $key_vert_position,

  # 				     xmin => $histograms_obj->lo_limit(),
  # 				     xmax => $histograms_obj->hi_limit(),

  # 				     log_y => $log_y,
  # 				     ymin => $ymin, ymax => $ymax,
  # 				     ymin_log => $ymin_log, ymax_log => $ymax_log,

  # 				     max_yaxis_chars => length int($histograms_obj->max_bin_y()),

  # 				     vline_position => $vline_position,
  # 				    );
  #print "# line width: ", $plot_params->line_width(), "\n"; # sleep(4);

  # $key_horiz_position = 'center' if($key_horiz_position eq 'middle');
  # $key_vert_position = 'center' if($key_vert_position eq 'middle');
  if (lc $graphics eq 'gnuplot') { # Use gnuplot
    # if (0) {			   # old way
    #   use Graphics::GnuplotIF qw(GnuplotIF);
    #   my $gnuplot_plot = create_gnuplot_plot($plot_params);
    #   if ($write_to_png) {
    # 	$gnuplot_plot->gnuplot_hardcopy($output_filename, " png $enhanced linewidth $line_width");
    # 	$gnuplot_plot->gnuplot_cmd("set out $output_filename");
    # 	plot_the_plot_gnuplot($histograms_obj, $gnuplot_plot, $vline_position);
    # 	$gnuplot_plot->gnuplot_restore_terminal();
    #   }
    #   print "[$show_on_screen] [$terminal] [$do_plot]\n";
    #   if ($show_on_screen) {
    # 	plot_the_plot_gnuplot($histograms_obj, $gnuplot_plot, $vline_position) if($do_plot);
    #   }
    #   if ($interactive) {
    # 	#####  modify plot in response to keyboard commands: #####
    # 	while (1) {		# loop to handle interactive commands.
    # 	  my $commands_string = <STDIN>; # command and optionally a parameter, e.g. 'x:0.8'
    # 	  last if(handle_interactive_command($histograms_obj, $plot_params,  $gnuplot_plot, $commands_string));
    # 	}
    #   }
    # } else {			# new way, using Gnuplot_plot module
      use Gnuplot_plot;
      my $gnuplot_plot = Gnuplot_plot->new({
					    persist => $persist,
					    width => $plot_width, height => $plot_height,
					    xmin => $histograms_obj->lo_limit, xmax => $histograms_obj->hi_limit,
					    ymin => $ymin, ymax => $ymax,
					    ymin_log => $ymin_log, ymax_log => $ymax_log,
					    x_axis_label => $x_axis_label,
					    y_axis_label => $y_axis_label,
					    line_width => $line_width,
					    color => $histogram_color,
					    relative_frame_thickness => $relative_frame_thickness,
					    key_horiz_position => $key_horiz_position,
					    key_vert_position => $key_vert_position,
					    histograms => $histograms_obj,
					    vline_position => $vline_position,
					    output_filename => $output_filename,
					   });
      $gnuplot_plot->draw_histograms();

        if ($interactive) {
	#####  modify plot in response to keyboard commands: #####
	while (1) {		# loop to handle interactive commands.
	  my $commands_string = <STDIN>; # command and optionally a parameter, e.g. 'x:0.8'
	  my $done = $gnuplot_plot->handle_interactive_command($commands_string);
	  #print "done with interactive commands? $done \n";
	  last if($done);
	}
      }
    #}
  } elsif (lc $graphics eq 'gd') { # Use GD
    use GD_plot;
    my $plot_gd = GD_plot->new({
				persist => $persist,
				width => $plot_width, height => $plot_height,
				xmin => $histograms_obj->lo_limit, xmax => $histograms_obj->hi_limit,
				ymin => $ymin, ymax => $ymax,
				x_axis_label => $x_axis_label,
				y_axis_label => $y_axis_label,
				line_width => $line_width,
				color => $histogram_color,
				relative_frame_thickness => $relative_frame_thickness,
				key_horiz_position => $key_horiz_position,
				key_vert_position => $key_vert_position,
				histograms => $histograms_obj,
				vline_position => $vline_position,
				output_filename => $output_filename,
			       });
    $plot_gd->draw_histograms();
    $plot_gd->draw_vline($vline_position, 'black');

    open my $fhout, ">", $plot_gd->output_filename;
    binmode $fhout;
    print $fhout $plot_gd->image->png;
    close $fhout;
  } else {
    die "Graphics option $graphics is unknown. Accepted options are 'gnuplot' and 'gd'\n";
  }
  print "Exiting histogram.pl\n";
}				# end of main
###########


# #####  gnuplot specific subroutines  #####

# sub create_gnuplot_plot{
#   my $plot_params = shift;
#   my $other_gnuplot_command = shift // undef;

#   # construct Graphics::GnuplotIF object and set various parameters;
#   # terminal, linewidth, plot size, x, y, labels, yrange,
#   # frame thickness, tick marks
  
#   my $gnuplot_plot = Graphics::GnuplotIF->new( persist => $plot_params->persist(), style => 'histeps');
#   my $terminal_command = "set terminal " . $plot_params->terminal() . " noenhanced " .
#     " linewidth " . $plot_params->line_width() .
#     " size " . $plot_params->width() . ", " .  $plot_params->height();
#   $gnuplot_plot->gnuplot_cmd($terminal_command);
#   my ($x_axis_label, $y_axis_label) = ($plot_params->x_axis_label(), $plot_params->y_axis_label());
#   $gnuplot_plot->gnuplot_set_xlabel($x_axis_label) if(defined $x_axis_label);
#   $gnuplot_plot->gnuplot_set_ylabel($y_axis_label) if(defined $y_axis_label);

#   if ($plot_params->log_y()) {
#     $gnuplot_plot->gnuplot_cmd('set log y');
#     my $ymax_log = $plot_params->ymax_log();
#     $gnuplot_plot->gnuplot_set_yrange($plot_params->ymin_log(), $ymax_log // '*');
#   } else {
#     my $ymax = $plot_params->ymax();
#     $gnuplot_plot->gnuplot_set_yrange($plot_params->ymin(), $ymax // '*');
#   }

#   my $key_pos_cmd = 'set key ' . $plot_params->key_horiz_position() . " " .  $plot_params->key_vert_position();
#   $gnuplot_plot->gnuplot_cmd($key_pos_cmd);
#   $gnuplot_plot->gnuplot_cmd("set border lw " . $plot_params->relative_frame_thickness());
#   $gnuplot_plot->gnuplot_cmd('set mxtics');
#   $gnuplot_plot->gnuplot_cmd('set tics out');
#   $gnuplot_plot->gnuplot_cmd('set tics scale 2,1');
#   $gnuplot_plot->gnuplot_cmd($other_gnuplot_command) if(defined $other_gnuplot_command);

#   return $gnuplot_plot;
# }

# sub plot_the_plot_gnuplot{
#   my $histograms_obj = shift;
#   my $gnuplot_plot_obj = shift;
#   my $vline_position = shift;
#   # print STDERR "vline pos: $vline_position \n"; sleep(2);

#   $gnuplot_plot_obj->gnuplot_set_xrange($histograms_obj->lo_limit(), $histograms_obj->hi_limit());
#   my $bin_centers = $histograms_obj->filecol_hdata()->{pooled}->bin_centers();
#   my @plot_titles = ();

#   my @histo_bin_counts = ();
#   while (my ($i_histogram, $plt) = each @{$histograms_obj->histograms_to_plot()} ) {
#     if ($plt == 1) {
#       print STDERR "adding histogram w index $i_histogram.\n";
#       my $fcspec = $histograms_obj->filecol_specifiers()->[$i_histogram];
#       my $hdata_obj = $histograms_obj->filecol_hdata()->{$fcspec};
#       my $bincounts = $hdata_obj->bin_counts();
#       push @plot_titles, $hdata_obj->label();
#       push @histo_bin_counts, $bincounts; # push an array ref holding the bin counts ...
#     }
#   }
#   if (defined $vline_position) {
#     draw_vline_gnuplot($gnuplot_plot_obj, $vline_position); #, $ymin, $ymax);
#   }
#   $gnuplot_plot_obj->gnuplot_set_plot_titles(@plot_titles);
#   $gnuplot_plot_obj->gnuplot_plot_xy($bin_centers, @histo_bin_counts);
# }

# sub draw_vline_gnuplot{
#   my $the_plot = shift;
#   my $x_pos = shift;
#   $the_plot->gnuplot_cmd("unset arrow");
#   $the_plot->gnuplot_cmd("set arrow nohead from $x_pos, graph 0 to $x_pos, graph 1 lw 1 dt 2") if(defined $x_pos);
# }

# sub handle_interactive_command{ # handle 1 line of interactive command, e.g. r:4 or xmax:0.2;ymax:2000q
#   my $histograms_obj = shift;
#   my $the_plot_params = shift;	# instance of Plot_params
#   # my $plot_params = shift; # Plot_params->new( log_y => $log_y, ymin => $ymin, ymax => $ymax, ymin_log => $ymin_log, ymax_log => $ymax_log,
#   # 			    vline_position => $vline_position, line_width => $line_width);
#   my $the_gnuplot = shift; # $gnuplot_plot instance of Graphics::GnuplotIF
#   my $commands_string = shift;
#   #  my $plot = $the_plot_params->plot_obj();
#   my $log_y = $the_plot_params->log_y();
#   my $ymin = $the_plot_params->ymin();
#   my $ymax = $the_plot_params->ymax();
#   my $ymin_log = $the_plot_params->ymin_log();
#   my $ymax_log = $the_plot_params->ymax_log();
#   my $vline_position = $the_plot_params->vline_position(); # 
#   my $line_width = $the_plot_params->line_width();

#   $commands_string =~ s/\s+$//g; # delete whitespace
#   return 1 if($commands_string eq 'q');
#   my @cmds = split(';', $commands_string);
#   my ($cmd, $param) = (undef, undef);

#   for my $cmd_param (@cmds) {
#     if ($cmd_param =~ /^([^:]+):(.+)/) {
#       ($cmd, $param) = ($1, $2);
#       $param =~ s/\s+//g if(! $cmd =~ /^\s*xlabel\s*$/);
#       print STDERR "cmd: [$cmd]  param: [$param]\n";
#     } elsif ($cmd_param =~ /^(\S+)/) {
#       $cmd = $1;
#     }
#     $cmd =~ s/\s+//g;

#     if (defined $cmd) {
#       # $commands_string =~ s/\s+//g if($cmd ne 'xlabel');
#       if ($cmd eq 'g') {
# 	$the_gnuplot->gnuplot_cmd('set grid');
#       } elsif ($cmd eq 'll') {
# 	if ($log_y) {
# 	  $the_plot_params->log_y(0);
# 	  $the_gnuplot->gnuplot_cmd('unset log');
# 	  $the_gnuplot->gnuplot_set_yrange($ymin, $ymax);
# 	} else {
# 	  $the_plot_params->log_y(1);
# 	  $the_gnuplot->gnuplot_cmd('set log y');
# 	  print STDERR "ll max_bin_y: ", $histograms_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
# 	  print STDERR "ll $ymin $ymax\n";
# 	  print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
# 	  $the_gnuplot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	}
#       } elsif ($cmd eq 'ymax') {
# 	if (!$log_y) {
# 	  $ymax = $param;
# 	  $the_gnuplot->gnuplot_set_yrange($ymin, $ymax);
# 	} else {
# 	  $ymax_log = $param;
# 	  $the_gnuplot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	}
#       } elsif ($cmd eq 'ymin') {
# 	if (!$log_y) {
# 	  $ymin = $param;
# 	  print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
# 	  $the_gnuplot->gnuplot_set_yrange($ymin, $ymax);
# 	  # $the_plot_params->ymin($ymin);
# 	} else {
# 	  $ymin_log = $param;
# 	  $the_gnuplot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	  # $the_plot_params->ymin_log($ymin_log);
# 	}
#       } elsif ($cmd eq 'x') {	# expand (or contract) x range.
# 	$histograms_obj->expand_range($param);
# 	$histograms_obj->bin_data();
#       } elsif ($cmd eq 'bw') {	# set the bin width
# 	$histograms_obj->set_binwidth($param);
# 	$histograms_obj->bin_data();
#       } elsif ($cmd eq 'lo' or $cmd eq 'low' or $cmd eq 'xmin') { # change low x-scale limit
# 	$histograms_obj->change_range($param, undef);
# 	$histograms_obj->bin_data();
#       } elsif ($cmd eq 'hi' or $cmd eq 'xmax') { # change high x-scale limit
# 	$histograms_obj->change_range(undef, $param);
# 	$histograms_obj->bin_data();
#       } elsif ($cmd eq 'c') {	# coarsen bins
# 	$histograms_obj->change_binwidth($param);
# 	$histograms_obj->bin_data();
# 	$ymax = $histograms_obj->max_bin_y()*$y_plot_factor;
# 	# $the_plot_params->ymax($ymax);
# 	$ymax_log = $histograms_obj->max_bin_y()*$y_plot_factor_log;
# 	# $the_plot_params->ymax_log($ymax_log);
# 	if ($log_y) {
# 	  $the_gnuplot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	} else {
# 	  $the_gnuplot->gnuplot_set_yrange($ymin, $ymax);
# 	}
#       } elsif ($cmd eq 'r') {	# refine bins
# 	$histograms_obj->change_binwidth($param? -1*$param : -1);
# 	$histograms_obj->bin_data();
# 	$ymax = $histograms_obj->max_bin_y()*$y_plot_factor;
# 	# $the_plot_params->ymax($ymax);
# 	$ymax_log = $histograms_obj->max_bin_y()*$y_plot_factor_log;
# 	# $the_plot_params->ymax_log($ymax_log);
# 	if ($log_y) {
# 	  $the_gnuplot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	} else {
# 	  $the_gnuplot->gnuplot_set_yrange($ymin, $ymax);
# 	}
#       } elsif ($cmd eq 'key') { # move the key (options are left, right, top, bottom)
# 	my $new_key_position = $param // 'left'; #
# 	$new_key_position =~ s/,/ /; # so can use e.g. left,bottom to move both horiz. vert. at once
# 	$the_gnuplot->gnuplot_cmd("set key $new_key_position");
#       } elsif ($cmd eq 'xlabel') {
# 	$param =~ s/^\s+//;
# 	$param =~ s/\s+$//;
# 	$param =~ s/^([^'])/'$1/;
# 	$param =~ s/([^']\s*)$/$1'/;
# 	print STDERR "param: $param \n";
# 	$the_gnuplot->gnuplot_cmd("set xlabel $param");
#       } elsif ($cmd eq 'export') {
# 	$param =~ s/'//g; # the name of the file to export to; the format will be png, and '.png' will be added to filename

# 	$the_gnuplot->gnuplot_hardcopy($param, " png linewidth $line_width");
# 	plot_the_plot_gnuplot($histograms_obj, $the_gnuplot, $vline_position);
# 	$the_gnuplot->gnuplot_restore_terminal();
#       } elsif ($cmd eq 'off') {
# 	$histograms_obj->histograms_to_plot()->[$param-1] = 0;
#       } elsif ($cmd eq 'on') {
# 	$histograms_obj->histograms_to_plot()->[$param-1] = 1;
#       } elsif ($cmd eq 'cmd') {
# 	if ($param =~ /^\s*['](.+)[']\s*$/) { # remove surrounding single quotes if present
# 	  $param = $1;
# 	}
# 	$the_gnuplot->gnuplot_cmd("$param");
#       }
#       print STDERR "max_bin_y: ", $histograms_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
#       plot_the_plot_gnuplot($histograms_obj, $the_gnuplot, $vline_position);

#       $the_plot_params->ymin($ymin);
#       $the_plot_params->ymin_log($ymin_log);
#       $the_plot_params->ymax($ymax);
#       $the_plot_params->ymax_log($ymax_log);
#     }
#   }
#   return 0;
# }
