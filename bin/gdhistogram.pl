#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use GD;
# use Graphics::GnuplotIF qw(GnuplotIF);
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
  my $x_axis_label = undef;
  
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

  gdplot_the_plot($histogram_obj, $vline_at_x, $x_axis_label);

}				# end of main
###########

sub gdplot_the_plot{
  my $histogram_obj = shift;
  my $vline_position = shift // undef;
  my $x_axis_label = shift // undef;
  my $filecol_hdata = $histogram_obj->filecol_hdata();
  open my $fhout, ">", "histogram.png";
  my $width = 1200;
  my $height = 900;
  my $margin = 20; # margin width (in pixels)
  my $space_for_axis_labels = 80;
  my $frame_L_pix = $margin + $space_for_axis_labels;
  my $frame_B_pix = $height - ($margin + $space_for_axis_labels);
  my $tick_length_pix = 6;
  my $frame_line_thickness = 3;
  my $histogram_line_thickness = 2;

  my $image = GD::Image->new($width, $height);
  my $black = $image->colorAllocate(0, 0, 0);
  my $white = $image->colorAllocate(255, 255, 255);
  my $gray = $image->colorAllocate(80, 80, 80);
  $image->filledRectangle(0, 0, $width-1, $height-1, $white);
  $image->setThickness($frame_line_thickness);
  my $frame = GD::Polygon->new();
  $frame->addPt($frame_L_pix, $frame_B_pix);
  $frame->addPt($frame_L_pix, $margin);
  $frame->addPt($width-1-$margin, $margin);
  $frame->addPt($width-1-$margin, $frame_B_pix);
  $image->openPolygon($frame, $black);

  $image->setThickness($histogram_line_thickness);
  my $xmin = $histogram_obj->lo_limit();
  my $xmax = $histogram_obj->hi_limit();
  my $ymin = 0;
  my $ymax = $histogram_obj->max_bin_y()*1.08;
  my $bin_width = $histogram_obj->binwidth();

  # add tick marks.
  #    on x axis:
  my $char_width = 8;
  my $char_height = 16;
  my $tick_x = 0;
  my $tick_spacing_x = 10*$bin_width;
  for(my $i=0; 1; $i++){
    next if($tick_x < $xmin);
    last if($tick_x > $xmax);
    my $xpix = pix_pos($tick_x, $xmin, $xmax, $frame_L_pix, $width-$margin);
    if($i%5 == 0){
      $image->line($xpix, $frame_B_pix, $xpix, $frame_B_pix + 2*$tick_length_pix, $black);
      $image->string(gdLargeFont, $xpix - 0.5*(length $tick_x)*$char_width, $frame_B_pix + 3*$tick_length_pix, $tick_x, $black);
    }else{
      $image->line($xpix, $frame_B_pix, $xpix, $frame_B_pix + $tick_length_pix, $black);
    }
    $tick_x += $tick_spacing_x;
  }
  # add a label to the x axis:
  if(defined $x_axis_label){
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
 # print STDERR "$ymin $ymax $max_bin_count  $tick_y $tick_spacing_y \n";
  for(my $i=0; 1; $i++){
    next if($tick_y < $ymin);
    last if($tick_y > $ymax);
   # print STDERR "tick_y $tick_y\n";
    my $ypix = pix_pos($tick_y, $ymin, $ymax, $frame_B_pix, $margin);
    if($i%5 == 0){
      $image->line($frame_L_pix, $ypix, $frame_L_pix - 2*$tick_length_pix, $ypix, $black);
      $image->string(gdLargeFont, $frame_L_pix - 3*$tick_length_pix - (length $tick_y)*$char_width, $ypix-0.5*$char_height, $tick_y, $black);
    }else{
      $image->line($frame_L_pix, $ypix, $frame_L_pix - $tick_length_pix, $ypix, $black);
    }
    $tick_y += $tick_spacing_y;
  }




  # draw the histogram
  
  my @ids = keys %$filecol_hdata;
  my $n_histograms = (scalar @ids) - 1; # subtract 1 to exclude the pooled histogram
  #  while (my ($id, $v) = each %$filecol_hdata) {
    my $xpix = $frame_L_pix;
    my $ypix = $frame_B_pix;
    for(my $i = 0; $i < $n_histograms; $i++){
      my $id = $ids[$i];
      my $v = $filecol_hdata->{$id};
    print "histogram i, id: $i  $id\n";
    my $hline = GD::Polygon->new(); # this will be the line outlining the histogram bars.
    my $bincenters = $v->bin_centers();
    my $counts = $v->bin_counts();
  
  #  print "xpix: $xpix, ypix: $ypix\n";
    $hline->addPt($xpix, $ypix);
    while (my($i, $bcx) = each @$bincenters) {
      next if($bcx < $xmin  or  $bcx > $xmax); # exclude underflow, overflow
      my $bincount = $counts->[$i];
      $ypix = pix_pos($bincount, $ymin, $ymax, $frame_B_pix, $margin);
      $xpix = pix_pos($bcx-0.5*$bin_width, $xmin, $xmax, $frame_L_pix, $width-$margin);
     # print "xpix: $xpix, ypix: $ypix\n";
      $hline->addPt($xpix, $ypix);
      $xpix = pix_pos($bcx+0.5*$bin_width, $xmin, $xmax, $frame_L_pix, $width-$margin);
    #  print "xpix: $xpix, ypix: $ypix\n";
      $hline->addPt($xpix, $ypix);
    } # end loop over histogram bins.
    $xpix = $width-$margin;
    $ypix = $frame_B_pix;
  #  print "xpix: $xpix, ypix: $ypix\n";
    $hline->addPt($xpix, $ypix);
    $image->unclosedPolygon($hline, $black);
   # last;
    } # end loop over histograms
  if(defined $vline_position){
    $image->setStyle(
		     $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, 
		     #$gray, $gray, $gray, $gray, $gray, $gray, $gray, $gray, $gray, $gray, $gray, $gray,
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

sub plot_the_plot{
  my $histogram_obj = shift;
  my $plot_obj = shift;

  $plot_obj->gnuplot_set_xrange($histogram_obj->lo_limit(), $histogram_obj->hi_limit());
  my $bin_centers = $histogram_obj->filecol_hdata()->{pooled}->bin_centers();
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
  $plot_obj->gnuplot_set_plot_titles(@plot_titles);
  $plot_obj->gnuplot_plot_xy($bin_centers, @histo_bin_counts); # , $bin_counts);
  #  $plot_obj->gnuplot_plot_xy_style($bin_centers, @histo_bin_counts_w_styles);
  
}

sub tick_spacing{
  # put 20 tick marks or somewhat more
  my $max_data = shift;
  my @spacing_options = (1,2,4,5,10);
  my $int_log10_max_data = int( log($max_data)/log(10) );
  my $z = $max_data/(10**$int_log10_max_data); # should be in range 1 <= $z < 10
#  print STDERR "$max_data  $int_log10_max_data  $z\n";
  for my $sopt (@spacing_options){
    if($sopt > $z){
      my $ts = $sopt*(10**$int_log10_max_data)/20;
    #  print STDERR "## $sopt $z ", 10**$int_log10_max_data, "  $ts\n";
      return $ts;
    }
  }
  print STDERR "### $max_data  $int_log10_max_data \n";
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
