#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

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
use Plot;

{				      # main
  unlink glob ".gnuplot*.stderr.log"; # to avoid accumulation of log files.
  my $lo_limit = 'auto';	      # 0;
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
  my $x_axis_label = undef;
  my $y_axis_label = undef;
  my $tight = 1;
  # other options for plot range: 'strict', 'loose_positive', 'loose'
  my $graphics = 'gnuplot';	# alternative is 'gd' 
  
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
	     'x_axis_label|x_label=s' => \$x_axis_label,
	     'y_axis_label|y_label=s' => \$y_axis_label,
	     'tight!' => \$tight,
	     'graphics=s' => \$graphics,
	    );

  $lo_limit = undef if($lo_limit eq 'auto'); # now default is 0.

  if (!defined $interactive) {
    $interactive = ($write_to_png)? 0 : 1;
  }

  $enhanced = ($enhanced)? 'enhanced' : 'noenhanced';

  print "files&columns to histogram: [$data] \n";

  my $histogram_obj = Histograms->new({
				       data_fcol => $data,
				       lo_limit => $lo_limit,
				       hi_limit => $hi_limit,
				       binwidth => $binwidth,
				       tight => $tight,
				      });
  $histogram_obj->bin_data();
  print "Max bin y: ", $histogram_obj->max_bin_y(), "\n";
  my $histogram_as_string = $histogram_obj->as_string();
  print "$histogram_as_string \n";

  print "graphics will use: ", lc $graphics, "\n";

    $ymax_log = $y_plot_factor_log*$histogram_obj->max_bin_y();
    $ymax = $y_plot_factor*$histogram_obj->max_bin_y();
  my $the_plot = Plot->new( log_y => $log_y, ymin => $ymin, ymax => $ymax, ymin_log => $ymin_log, ymax_log => $ymax_log);

  if (lc $graphics eq 'gnuplot') {	# $plot defined within this block
    use Graphics::GnuplotIF qw(GnuplotIF);
    my $plot = Graphics::GnuplotIF->new( persist => $persist, style => 'histeps',
					 xlabel => "$x_axis_label", ylabel => "$y_axis_label");

    $plot->gnuplot_cmd("set terminal $terminal noenhanced linewidth $linewidth");

  
    if ($log_y) {
      $plot->gnuplot_cmd('set log y');
      $plot->gnuplot_set_yrange(0.8, (defined $ymax_log)? $ymax_log : '*');
      set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
    } else {
      if (defined $vline_at_x) {
	set_arrow($plot, $vline_at_x, $ymin, $ymax);
      }
      $plot->gnuplot_set_yrange(0, (defined $ymax)? $ymax : '*');
    }

    my $key_pos_cmd = 'set key ' . "$key_horiz_position  $key_vert_position";
    $plot->gnuplot_cmd($key_pos_cmd);
    $plot->gnuplot_cmd('set border lw 1.25'); # apparently this width is relative to that for the histogram lines.
    $plot->gnuplot_cmd('set mxtics');
    $plot->gnuplot_cmd('set tics out');
 #   $plot->gnuplot_cmd('set tics front');
    $plot->gnuplot_cmd('set tics scale 2,1');
    $plot->gnuplot_cmd($gnuplot_command) if(defined $gnuplot_command);
 

    if ($write_to_png) {
      $plot->gnuplot_hardcopy($output_filename . '.png', "png $enhanced linewidth $linewidth");
      $plot->gnuplot_cmd("set out $output_filename");
      plot_the_plot($histogram_obj, $plot);
      $plot->gnuplot_restore_terminal();
    }
    print "[$show_on_screen] [$terminal] [$do_plot]\n";
    if ($show_on_screen) {
      plot_the_plot($histogram_obj, $plot) if($do_plot);
    }
    if ($interactive) {
      #####  modify plot in response to keyboard commands: #####
      while (1) {		# loop to handle interactive commands.
	my $commands_string = <STDIN>; # command and optionally a parameter, e.g. 'x:0.8'
	if(1){
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

	  if (defined $cmd) {
	    $commands_string =~ s/\s+//g if($cmd ne 'xlabel');
	      if ($cmd eq 'g') {
	      $plot->gnuplot_cmd('set grid');
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
	    } elsif ($cmd eq 'bw') { # set the bin width
	      $histogram_obj->set_binwidth($param);
	      $histogram_obj->bin_data();
	    } elsif ($cmd eq 'lo' or $cmd eq 'low' or $cmd eq 'xmin') { # change low x-scale limit
	      $histogram_obj->change_range($param, undef);
	      $histogram_obj->bin_data();
	    } elsif ($cmd eq 'hi' or $cmd eq 'xmax') { # change high x-scale limit
	      $histogram_obj->change_range(undef, $param);
	      $histogram_obj->bin_data();
	    } elsif ($cmd eq 'c') { # coarsen bins
	      $histogram_obj->change_binwidth($param);
	      $histogram_obj->bin_data();
	      $ymax = $histogram_obj->max_bin_y()*$y_plot_factor;
	      $ymax_log = $histogram_obj->max_bin_y()*$y_plot_factor_log;
	      if ($log_y) {
		$plot->gnuplot_set_yrange($ymin_log, $ymax_log);
		set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
	      } else {
		$plot->gnuplot_set_yrange($ymin, $ymax);
		set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
	      }
	    } elsif ($cmd eq 'r') { # refine bins
	      $histogram_obj->change_binwidth($param? -1*$param : -1);
	      $histogram_obj->bin_data();
	      $ymax = $histogram_obj->max_bin_y()*$y_plot_factor;
	      $ymax_log = $histogram_obj->max_bin_y()*$y_plot_factor_log;
	      if ($log_y) {
		$plot->gnuplot_set_yrange($ymin_log, $ymax_log);
		set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
	      } else {
		$plot->gnuplot_set_yrange($ymin, $ymax);
		set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
	      }
	    } elsif ($cmd eq 'key') { # move the key (options are left, right, top, bottom)
	      my $new_key_position = $param // 'left'; #
	      $new_key_position =~ s/,/ /; # so can use e.g. left,bottom to move both horiz. vert. at once
	      $plot->gnuplot_cmd("set key $new_key_position");
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
	      if ($param =~ /^\s*['](.+)[']\s*$/) { # remove surrounding single quotes if present
		$param = $1;
	      }
	      $plot->gnuplot_cmd("$param");
	    }
	    print STDERR "max_bin_y: ", $histogram_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
	    plot_the_plot($histogram_obj, $plot);
	  }
	}
      }else{
	last if(handle_interactive_command($histogram_obj, $plot, $commands_string));
      }
      }
    }
  }elsif (lc $graphics eq 'gd') {
      use GD;
      gdplot_the_plot($histogram_obj, $vline_at_x, $x_axis_label);
    }
  else{
    die "Graphics option $graphics is unknown. Accepted options are 'gnuplot' and 'gd'\n";
  }
} # end of main
###########


sub plot_the_plot{
  my $histogram_obj = shift;
  my $plot_obj = shift;

  $plot_obj->gnuplot_set_xrange($histogram_obj->lo_limit(), $histogram_obj->hi_limit());
  my $bin_centers = $histogram_obj->filecol_hdata()->{pooled}->bin_centers();
  my @plot_titles = ();

  my @histo_bin_counts = ();
  while (my ($hi, $plt) = each @{$histogram_obj->histograms_to_plot()} ) {
    if ($plt == 1) {
      print STDERR "adding histogram w index $hi.\n";
      my $fcspec = $histogram_obj->filecol_specifiers()->[$hi];
      my $hdata_obj = $histogram_obj->filecol_hdata()->{$fcspec};
      my $bincounts = $hdata_obj->bin_counts();
      push @plot_titles, $hdata_obj->label();
      push @histo_bin_counts, $bincounts; # push an array ref holding the bin counts ...
    }
  }

  $plot_obj->gnuplot_set_plot_titles(@plot_titles);
  $plot_obj->gnuplot_plot_xy($bin_centers, @histo_bin_counts); # , $bin_counts);
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


### GD plotting:
sub gdplot_the_plot{
  my $histogram_obj = shift;
  my $vline_position = shift // undef;
  my $x_axis_label = shift // undef;
  my $filecol_hdata = $histogram_obj->filecol_hdata();
  open my $fhout, ">", "histogram.png";

  my $width = 1200;
  my $height = 900;
  my $image = GD::Image->new($width, $height);
  my $black = $image->colorAllocate(0, 0, 0);
  my $white = $image->colorAllocate(255, 255, 255);
  $image->filledRectangle(0, 0, $width-1, $height-1, $white);

  my $margin = 20;		# margin width (in pixels)
  my $space_for_axis_labels = 80;
  my $frame_L_pix = $margin + $space_for_axis_labels;
  my $frame_B_pix = $height - ($margin + $space_for_axis_labels);
  my $frame_line_thickness = 3;
  $image->setThickness($frame_line_thickness);
  my $frame = GD::Polygon->new();
  $frame->addPt($frame_L_pix, $frame_B_pix);
  $frame->addPt($frame_L_pix, $margin);
  $frame->addPt($width-1-$margin, $margin);
  $frame->addPt($width-1-$margin, $frame_B_pix);
  $image->openPolygon($frame, $black);

  my $char_width = 8;
  my $char_height = 16;
  my $xmin = $histogram_obj->lo_limit();
  my $xmax = $histogram_obj->hi_limit();
  my $ymin = 0;
  my $ymax = $histogram_obj->max_bin_y()*1.08;
  my $bin_width = $histogram_obj->binwidth();

  # add tick marks.
  my $tick_length_pix = 6;
  #    on x axis:
  my $tick_x = 0;
  my $tick_spacing_x = 10*$bin_width;
  for (my $i=0; 1; $i++) {
    next if($tick_x < $xmin);
    last if($tick_x > $xmax);
    my $xpix = pix_pos($tick_x, $xmin, $xmax, $frame_L_pix, $width-$margin);
    if ($i%5 == 0) {
      $image->line($xpix, $frame_B_pix, $xpix, $frame_B_pix + 2*$tick_length_pix, $black);
      $image->string(gdLargeFont, $xpix - 0.5*(length $tick_x)*$char_width, $frame_B_pix + 3*$tick_length_pix, $tick_x, $black);
    } else {
      $image->line($xpix, $frame_B_pix, $xpix, $frame_B_pix + $tick_length_pix, $black);
    }
    $tick_x += $tick_spacing_x;
  }
  # add a label to the x axis:
  if (defined $x_axis_label) {
    my $label_length = length $x_axis_label;
    my $xpix = pix_pos(0.5*($xmin + $xmax), $xmin, $xmax, $frame_L_pix, $width-$margin);
    $image->string(gdLargeFont,
		   $xpix - 0.5*$label_length*$char_width,
		   $frame_B_pix + 3*$tick_length_pix + 1.5*$char_height,
		   $x_axis_label, $black);
  }
  
  # tick marks on y axis
  my $max_bin_count = $histogram_obj->max_bin_y();
  my $tick_y = 0;
  my $tick_spacing_y = tick_spacing($max_bin_count);
  for (my $i=0; 1; $i++) {
    next if($tick_y < $ymin);
    last if($tick_y > $ymax);
    my $ypix = pix_pos($tick_y, $ymin, $ymax, $frame_B_pix, $margin);
    if ($i%5 == 0) {
      $image->line($frame_L_pix, $ypix, $frame_L_pix - 2*$tick_length_pix, $ypix, $black);
      $image->string(gdLargeFont, $frame_L_pix - 3*$tick_length_pix - (length $tick_y)*$char_width, $ypix-0.5*$char_height, $tick_y, $black);
    } else {
      $image->line($frame_L_pix, $ypix, $frame_L_pix - $tick_length_pix, $ypix, $black);
    }
    $tick_y += $tick_spacing_y;
  }

  # draw the histogram
  my $histogram_line_thickness = 2;
  $image->setThickness($histogram_line_thickness);
  my @ids = keys %$filecol_hdata;
  my $n_histograms = (scalar @ids) - 1; # subtract 1 to exclude the pooled histogram
  my $xpix = $frame_L_pix;
  my $ypix = $frame_B_pix;
  for (my $i = 0; $i < $n_histograms; $i++) {
    my $id = $ids[$i];
    my $v = $filecol_hdata->{$id};
    print "histogram i, id: $i  $id\n";
    my $hline = GD::Polygon->new(); # this will be the line outlining the histogram bars.
    my $bincenters = $v->bin_centers();
    my $counts = $v->bin_counts();

    $hline->addPt($xpix, $ypix);
    while (my($i, $bcx) = each @$bincenters) {
      next if($bcx < $xmin  or  $bcx > $xmax); # exclude underflow, overflow
      my $bincount = $counts->[$i];
      $ypix = pix_pos($bincount, $ymin, $ymax, $frame_B_pix, $margin);
      $xpix = pix_pos($bcx-0.5*$bin_width, $xmin, $xmax, $frame_L_pix, $width-$margin);
      $hline->addPt($xpix, $ypix);
      $xpix = pix_pos($bcx+0.5*$bin_width, $xmin, $xmax, $frame_L_pix, $width-$margin);
      $hline->addPt($xpix, $ypix);
    }				# end loop over histogram bins.
    $xpix = $width-$margin;
    $ypix = $frame_B_pix;
    $hline->addPt($xpix, $ypix);
    $image->unclosedPolygon($hline, $black);
  } # end loop over histograms
  if (defined $vline_position) {
    $image->setStyle(
		     $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, 
		     gdTransparent, gdTransparent, gdTransparent, gdTransparent, gdTransparent, gdTransparent,
		     gdTransparent, gdTransparent, gdTransparent, gdTransparent);
    $xpix = pix_pos($vline_position, $xmin, $xmax, $frame_L_pix, $width-$margin);
    $image->line($xpix, $frame_B_pix, $xpix, $margin, gdStyled);
  }
  binmode $fhout;
  print $fhout $image->png;
}

sub pix_pos{
  my $x = shift;
  my $xmin = shift;
  my $xmax = shift;
  my $low_edge = shift;		# the pixels corresponding to 
  my $hi_edge = shift;
  return $low_edge + ($x-$xmin)/($xmax-$xmin) * ($hi_edge-$low_edge);
}

sub tick_spacing{
  # put approx. 20 tick marks
  my $max_data = shift;
  my @spacing_options = (1,2,4,5,10);
  my $int_log10_max_data = int( log($max_data)/log(10) );
  my $z = $max_data/(10**$int_log10_max_data); # should be in range 1 <= $z < 10
  for my $sopt (@spacing_options) {
    if ($sopt > $z) {
      my $ts = $sopt*(10**$int_log10_max_data)/20;
      return $ts;
    }
  }
  print STDERR "### $max_data  $int_log10_max_data \n";
}


# sub handle_interactive_command{
#   my $histogram_obj = shift;
#   my $plot = shift;
#   my $commands_string = shift;
#   my $ymin = shift;
#   my $ymax = shift;
#   my $ymin_log = shift;
#   my $y

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
#       $commands_string =~ s/\s+//g if($cmd ne 'xlabel');
#       if ($cmd eq 'g') {
# 	$plot->gnuplot_cmd('set grid');
#       } elsif ($cmd eq 'll') {
# 	if ($log_y) {
# 	  $log_y = 0;
# 	  $plot->gnuplot_cmd('unset log');
# 	  set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
# 	  $plot->gnuplot_set_yrange($ymin, $ymax);
# 	} else {
# 	  $log_y = 1;
# 	  $plot->gnuplot_cmd('set log y');
# 	  print STDERR "ll max_bin_y: ", $histogram_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
# 	  print STDERR "ll $ymin $ymax\n";
# 	  print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
# 	  set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
# 	  $plot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	}
#       } elsif ($cmd eq 'ymax') {
# 	if (!$log_y) {
# 	  $ymax = $param;
# 	  set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
# 	  print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
# 	  $plot->gnuplot_set_yrange($ymin, $ymax);
# 	} else {
# 	  $ymax_log = $param;
# 	  set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
# 	  $plot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	}
#       } elsif ($cmd eq 'ymin') {
# 	if (!$log_y) {
# 	  $ymin = $param;
# 	  print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
# 	  $plot->gnuplot_set_yrange($ymin, $ymax);
# 	} else {
# 	  $ymin_log = $param;
# 	  $plot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	}
#       } elsif ($cmd eq 'x') {	# expand (or contract) x range.
# 	$histogram_obj->expand_range($param);
# 	$histogram_obj->bin_data();
#       } elsif ($cmd eq 'bw') {	# set the bin width
# 	$histogram_obj->set_binwidth($param);
# 	$histogram_obj->bin_data();
#       } elsif ($cmd eq 'lo' or $cmd eq 'low' or $cmd eq 'xmin') { # change low x-scale limit
# 	$histogram_obj->change_range($param, undef);
# 	$histogram_obj->bin_data();
#       } elsif ($cmd eq 'hi' or $cmd eq 'xmax') { # change high x-scale limit
# 	$histogram_obj->change_range(undef, $param);
# 	$histogram_obj->bin_data();
#       } elsif ($cmd eq 'c') {	# coarsen bins
# 	$histogram_obj->change_binwidth($param);
# 	$histogram_obj->bin_data();
# 	$ymax = $histogram_obj->max_bin_y()*$y_plot_factor;
# 	$ymax_log = $histogram_obj->max_bin_y()*$y_plot_factor_log;
# 	if ($log_y) {
# 	  $plot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	  set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
# 	} else {
# 	  $plot->gnuplot_set_yrange($ymin, $ymax);
# 	  set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
# 	}
#       } elsif ($cmd eq 'r') {	# refine bins
# 	$histogram_obj->change_binwidth($param? -1*$param : -1);
# 	$histogram_obj->bin_data();
# 	$ymax = $histogram_obj->max_bin_y()*$y_plot_factor;
# 	$ymax_log = $histogram_obj->max_bin_y()*$y_plot_factor_log;
# 	if ($log_y) {
# 	  $plot->gnuplot_set_yrange($ymin_log, $ymax_log);
# 	  set_arrow($plot, $vline_at_x, $ymin_log, $ymax_log) if(defined $vline_at_x);
# 	} else {
# 	  $plot->gnuplot_set_yrange($ymin, $ymax);
# 	  set_arrow($plot, $vline_at_x, $ymin, $ymax) if(defined $vline_at_x);
# 	}
#       } elsif ($cmd eq 'key') { # move the key (options are left, right, top, bottom)
# 	my $new_key_position = $param // 'left'; #
# 	$new_key_position =~ s/,/ /; # so can use e.g. left,bottom to move both horiz. vert. at once
# 	$plot->gnuplot_cmd("set key $new_key_position");
#       } elsif ($cmd eq 'xlabel') {
# 	$param =~ s/^\s+//;
# 	$param =~ s/\s+$//;
# 	$param =~ s/^([^'])/'$1/;
# 	$param =~ s/([^']\s*)$/$1'/;
# 	print STDERR "param: $param \n";
# 	$plot->gnuplot_cmd("set xlabel $param");
#       } elsif ($cmd eq 'export') {
# 	$param =~ s/'//g; # the name of the file to export to; the format will be png, and '.png' will be added to filename

# 	$plot->gnuplot_hardcopy($param . '.png', "png linewidth $linewidth");
# 	plot_the_plot($histogram_obj, $plot);
# 	$plot->gnuplot_restore_terminal();
#       } elsif ($cmd eq 'off') {
# 	$histogram_obj->histograms_to_plot()->[$param-1] = 0;
#       } elsif ($cmd eq 'on') {
# 	$histogram_obj->histograms_to_plot()->[$param-1] = 1;
#       } elsif ($cmd eq 'cmd') {
# 	if ($param =~ /^\s*['](.+)[']\s*$/) { # remove surrounding single quotes if present
# 	  $param = $1;
# 	}
# 	$plot->gnuplot_cmd("$param");
#       }
#       print STDERR "max_bin_y: ", $histogram_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
#       plot_the_plot($histogram_obj, $plot);
#     }
#   }
#   return 0;
# }
