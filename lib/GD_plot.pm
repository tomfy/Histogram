package GD_plot;
use strict;
use warnings;
use Moose;
# use Mouse;
use namespace::autoclean;
use Carp;
use Scalar::Util qw (looks_like_number );
use List::Util qw ( min max sum );
use POSIX qw ( floor ceil );
use GD;

has histograms => (
		   isa => 'Object',
		   is => 'rw',
		   required => 1,
		  );

has image => (
	      isa => 'Maybe[Object]',
	      is => 'rw',
	      required => 0,
	      default => undef,
	     );

has width => (
	      isa => 'Int',
	      is => 'rw',
	      required => 0,
	      default => 640,
	     );

has height => (
	       isa => 'Int',
	       is => 'rw',
	       required => 0,
	       default => 480,
	      );

has frame_L_pix => (
		    isa => 'Maybe[Num]',
		    is => 'rw',
		    required => 0,
		    default => undef,
		   );

has frame_R_pix => (
		    isa => 'Maybe[Num]',
		    is => 'rw',
		    required => 0,
		    default => undef,
		   );

has frame_B_pix => (
		    isa => 'Maybe[Num]',
		    is => 'rw',
		    required => 0,
		    default => undef,
		   );

has frame_T_pix => (
		    isa => 'Maybe[Num]',
		    is => 'rw',
		    required => 0,
		    default => undef,
		   );

has key_horiz_position => (
			   isa => 'Str',
			   is => 'rw',
			   required => 0,
			   default => 'center',
			  );

has key_vert_position => (
			   isa => 'Str',
			   is => 'rw',
			   required => 0,
			   default => 'top',
			  );

# has xmin => (
# 	     isa => 'Maybe[Num]',
# 	     is => 'rw',
# 	     required => 0,
# 	     default => undef,
# 	    );

# has xmax => (
# 	     isa => 'Maybe[Num]',
# 	     is => 'rw',
# 	     required => 0,
# 	     default => undef,
# 	    );

has ymin => (
	     isa => 'Maybe[Num]',
	     is => 'rw',
	     required => 0,
	     default => undef,
	    );

has ymax => (
	     isa => 'Maybe[Num]',
	     is => 'rw',
	     required => 0,
	     default => undef,
	    );

has line_width => (
		   isa => 'Num',
		   is => 'rw',
		   required => 0,
		   default => 1,
		  );

has relative_frame_thickness => ( # thickness of line framing the plot relative to histogram linewidth
				 isa => 'Num',
				 is => 'rw',
				 required => 0,
				 default => 1.5,
				);

has char_width => (
		   isa => 'Num',
		   is => 'ro',
		   default => 8,
		  );

has char_height => (
		    isa => 'Num',
		    is => 'ro',
		    default => 16,
		   );

has x_axis_label => (
		     isa => 'Maybe[Str]',
		     is => 'rw',
		     required => 0,
		     default => undef,
		    );

has y_axis_label => (
		     isa => 'Maybe[Str]',
		     is => 'rw',
		     required => 0,
		     default => undef,
		    );

has color => (
	      isa => 'Maybe[Str]',
	      is => 'rw',
	      required => 0,
	      default => undef,
	     );

has colors => (
	       isa => 'Maybe[HashRef]',
	       is => 'rw',
	       required => 0,
	       default => undef,
	       # sub {
	       # 	 { 'black' => [0,0,0], 'white' => [255,255,255],
	       # 	   'blue' => [50,80,255], 'green' => [20,130,20], 'red' => [150,20,20] }
	       # },
	      );

has output_filename => (
			isa => 'Str',
			is => 'rw',
			required => 0,
			default => 'histogram.png',
		       );

sub BUILD{
  my $self = shift;
  #  my $params = shift;
  #  $self->parameters($params);
  #  my $histograms_obj = shift;
  #my $params = $self->parameters;
  # my $ymin = $self>ymin;
  # my $ymax = $self->ymax;

  my $bin_width = $self->histograms->binwidth;
  my $xmin = $self->histograms->lo_limit;
  my $xmax = $self->histograms->hi_limit;

  # $self->xmin($xmin);
  # $self->xmax($xmax);
  # $self->ymin($ymin);
  # $self->ymax($ymax);

  my $char_width = 8;
  my $char_height = 16;

  # my $width = $params->width;
  # my $height = $params->height;
  my $margin = 28;		# margin width (in pixels)
  my $tick_length_pix = 6;
  my $max_y_axis_chars = length int($self->histograms->max_bin_y);
  my $x_axis_label_space = 3*$tick_length_pix + 2.5*$char_height;
  my $y_axis_label_space = 3*$tick_length_pix + (0.5 + $max_y_axis_chars)*$char_width + ((defined $self->y_axis_label)? 2*$char_height : 0);

  
  my $frame_L_pix = $margin + $y_axis_label_space;
  my $frame_R_pix = $self->width() - $margin;
  my $frame_T_pix = $margin;
  my $frame_B_pix = $self->height - ($margin + $x_axis_label_space);
  $self->frame_L_pix($frame_L_pix);
  $self->frame_R_pix($frame_R_pix);
  $self->frame_B_pix($frame_B_pix);
  $self->frame_T_pix($frame_T_pix);

  #####  construct the image
  my $image = GD::Image->new($self->width(), $self->height());
  $self->colors({black => $image->colorAllocate(0, 0, 0),
		 white => $image->colorAllocate(255, 255, 255),
		 blue => $image->colorAllocate(50, 80, 255),
		 green => $image->colorAllocate(20,130,20),
		 red => $image->colorAllocate(150,20,20)}
	       );
  my $black = $self->colors->{black};
  my @histogram_colors = ('black', 'blue', 'green', 'red');

  my $white = $self->colors->{white};
  $image->filledRectangle(0, 0, $self->width-1, $self->height-1, $white);

  #my $black = $image->colorAllocate(0, 0, 0);

  # my $frame_line_thickness = $relative_frame_thickness*$line_width;
  my $frame_line_thickness = $self->relative_frame_thickness()*$self->line_width;
  $image->setThickness($frame_line_thickness);
  my $frame = GD::Polygon->new();
  $frame->addPt($frame_L_pix, $frame_B_pix);
  $frame->addPt($frame_L_pix, $frame_T_pix);
  $frame->addPt($frame_R_pix, $frame_T_pix);
  $frame->addPt($frame_R_pix, $frame_B_pix);
  $image->openPolygon($frame, $black);

  # add tick marks #

  # add tick marks.
  #    on x axis:
  my $tick_x = 0;
  my $tick_spacing_x = 10*$bin_width;
  for (my $i=0; 1; $i++) {
    next if($tick_x < $xmin);
    last if($tick_x > $xmax);
    my $xpix = $self->x_pix($tick_x);
    # pix_pos($tick_x, $xmin, $xmax, $frame_L_pix, $frame_R_pix);
    if ($i%5 == 0) {
      $image->line($xpix, $frame_B_pix, $xpix, $frame_B_pix + 2*$tick_length_pix, $black);
      $image->string(gdLargeFont, $xpix - 0.5*(length $tick_x)*$char_width, $frame_B_pix + 3*$tick_length_pix, $tick_x, $black);
      $image->line($xpix, $frame_T_pix, $xpix, $frame_T_pix - 2*$tick_length_pix, $black);
    } else {
      $image->line($xpix, $frame_B_pix, $xpix, $frame_B_pix + $tick_length_pix, $black);
      $image->line($xpix, $frame_T_pix, $xpix, $frame_T_pix - $tick_length_pix, $black);
    }
    $tick_x += $tick_spacing_x;
  }
  # add a label to the x axis:
  if (defined $self->x_axis_label) {
    my $label_length = length $self->x_axis_label;
    my $xpix = $self->x_pix(0.5*($xmin + $xmax));
    # pix_pos(0.5*($xmin + $xmax), $xmin, $xmax, $frame_L_pix, $frame_R_pix);
    $image->string(gdLargeFont,
		   $xpix - 0.5*$label_length*$char_width,
		   $frame_B_pix + 3*$tick_length_pix + $char_height,
		   $self->x_axis_label, $black);
  }

  # tick marks on y axis
  my $max_bin_count = $self->histograms->max_bin_y();
  my $tick_y = 0;
  my $tick_spacing_y = tick_spacing($max_bin_count);
  my $max_tick_chars = 0;  # max number of chars in the tick_y numbers
  for (my $i=0; 1; $i++) {
    next if($tick_y < $self->ymin);
    last if($tick_y > $self->ymax);
    my $ypix = $self->y_pix($tick_y);
    # pix_pos($tick_y, $ymin, $ymax, $frame_B_pix, $frame_T_pix);
    if ($i%5 == 0) {
      $image->line($frame_L_pix, $ypix, $frame_L_pix - 2*$tick_length_pix, $ypix, $black);
      $image->string(gdLargeFont, $frame_L_pix - 3*$tick_length_pix - (length $tick_y)*$char_width, $ypix-0.5*$char_height, $tick_y, $black);
      $image->line($frame_R_pix, $ypix, $frame_R_pix + 2*$tick_length_pix, $ypix, $black);
      $max_tick_chars = max($max_tick_chars, length $tick_y);
    } else {
      $image->line($frame_L_pix, $ypix, $frame_L_pix - $tick_length_pix, $ypix, $black);
      $image->line($frame_R_pix, $ypix, $frame_R_pix + $tick_length_pix, $ypix, $black);
    }
    $tick_y += $tick_spacing_y;
  }

  # add a label to the y axis:
  if (defined $self->y_axis_label) {
    my $label_length = length $self->y_axis_label;
    my $ypix = $self->y_pix(0.5*($self->ymin() + $self->ymax()));
    #  pix_pos(0.5*($ymin + $ymax), $ymin, $ymax, $frame_B_pix, $frame_T_pix);
    $image->stringUp(gdLargeFont, $frame_L_pix - (3*$tick_length_pix + ($max_tick_chars)*$char_width + 1.5*$char_height),
		     $ypix + 0.5*$label_length*$char_width,
		     $self->y_axis_label, $black);
  }
  $self->image($image);
}

sub draw_histograms{
  my $self = shift;

  my $histograms_obj = $self->histograms;
  my $image = $self->image();

  my ($xmin, $xmax) = ($histograms_obj->lo_limit, $histograms_obj->hi_limit);
  my ($ymin, $ymax) = ($self->ymin, $self->ymax);
  my $frame_L_pix = $self->frame_L_pix;
  my $frame_R_pix = $self->frame_R_pix;
  my $frame_B_pix = $self->frame_B_pix;
  my $frame_T_pix = $self->frame_T_pix;

  my $bin_width = $histograms_obj->binwidth;

  my $color_name = $self->color;
  print "Color name: $color_name \n";
  my @histogram_colors = ('black', 'blue', 'green', 'red');

  my $h_label_x_fraction = 0.1; # default histogram label horiz position is 'left'
  if ($self->key_horiz_position eq 'center') {
    $h_label_x_fraction = 0.35;
  } elsif ($self->key_horiz_position eq 'right') {
    $h_label_x_fraction = 0.6;
  }
  my $label_x_pix = (1.0 - $h_label_x_fraction)*$frame_L_pix + $h_label_x_fraction*$frame_R_pix;
  my $label_y_pix = 0.94*$frame_T_pix + 0.06*$frame_B_pix;
  ##########################
  ##  draw the histogram  ##
  ##########################
  my $histogram_line_thickness = $self->line_width();
  $image->setThickness($histogram_line_thickness);
  my $filecol_hdata = $histograms_obj->filecol_hdata();
  my @ids = keys %$filecol_hdata;
  my $n_histograms = (scalar @ids); # - 1; # subtract 1 to exclude the pooled histogram

  #  for (my $i = 0; $i < $n_histograms; $i++) {
  while (my ($histogram_index, $plt) = each @{$histograms_obj->histograms_to_plot()} ) {
    if ($plt == 1) {
      print STDERR "adding histogram w index $histogram_index.\n";
      my $fcspec = $histograms_obj->filecol_specifiers()->[$histogram_index];
      my $hdata_obj = $histograms_obj->filecol_hdata()->{$fcspec};
      my $bincounts = $hdata_obj->bin_counts();
      # my $id = $ids[$i];
      # my $v = $filecol_hdata->{$id};
      # print "histogram i, id: $i  $id\n";
      my $hline = GD::Polygon->new(); # this will be the line outlining the histogram shape.
      my $bincenters = $hdata_obj->bin_centers();
      #   my $counts = $v->bin_counts();
      my $xpix = $frame_L_pix;
      my $ypix = $frame_B_pix;
      $hline->addPt($xpix, $ypix);
      while (my($i, $bcx) = each @$bincenters) {
	next if($bcx < $xmin  or  $bcx > $xmax); # exclude underflow, overflow
	my $bincount = $bincounts->[$i];
	$ypix = $self->y_pix($bincount); # pix_pos($bincount, $ymin, $ymax, $frame_B_pix, $frame_T_pix);
	$xpix = $self->x_pix($bcx-0.5*$bin_width); #, $xmin, $xmax, $frame_L_pix, $frame_R_pix);
	$hline->addPt($xpix, $ypix);
	$xpix = $self->x_pix($bcx+0.5*$bin_width); # pix_pos($bcx+0.5*$bin_width, $xmin, $xmax, $frame_L_pix, $frame_R_pix);
	$hline->addPt($xpix, $ypix);
      }				# end loop over histogram bins.
      $xpix = $frame_R_pix;
      $ypix = $frame_B_pix;
      $hline->addPt($xpix, $ypix);
      $color_name = $histogram_colors[$histogram_index % 4] if($histogram_index > 0  or  !defined $color_name);
      print "[$histogram_index]  [$color_name]\n";
      $image->unclosedPolygon($hline, $self->colors->{$color_name});
      # my $label = $hdata_obj->label();
      if (defined $hdata_obj->label()  and  length $hdata_obj->label() > 0) {
	$image->line($label_x_pix - 25, $label_y_pix + 0.5*$self->char_height, $label_x_pix - 5, $label_y_pix + 0.5*$self->char_height, $ self->colors->{$color_name});
	$image->string(gdLargeFont, $label_x_pix, $label_y_pix, $hdata_obj->label(), $self->colors->{black});
	 $label_y_pix += $self->char_height;
       }
    }
  }				# end loop over histograms
  return $self;
}

sub draw_vline{
  my $self = shift;
  my $vline_position = shift;
  my $color_name = shift;
  my $image = $self->image();
  print STDERR $vline_position // 'undef', "\n";
  if (defined $vline_position) {
    $image->setThickness(1);
    my $color = $self->colors->{$color_name};
    $image->setStyle(
		     # $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, # $black, $black,
		     $color, $color, $color, $color, $color, $color, $color, $color, $color, $color, # $color, $color, 
		     # $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, $black, $black,
		     gdTransparent, gdTransparent, gdTransparent, gdTransparent, # gdTransparent, gdTransparent,
		     # gdTransparent, gdTransparent, gdTransparent, gdTransparent, gdTransparent, gdTransparent,
		     gdTransparent, gdTransparent, gdTransparent, gdTransparent);
    my $xpix = $self->x_pix($vline_position); #, $self->xmin, $self->xmax, $self->frame_L_pix, $self->frame_R_pix);
    $image->line($xpix, $self->frame_B_pix(), $xpix, $self->frame_T_pix(), gdStyled);
  }
}

sub x_pix{
  my $self = shift;
  my $x = shift;
  my ($xmin, $xmax) = ($self->histograms->lo_limit, $self->histograms->hi_limit);
  my $x_pix = $self->frame_L_pix + ($x-$xmin)/($xmax - $xmin) * ($self->frame_R_pix() - $self->frame_L_pix());
  return $x_pix;
}

sub y_pix{
  my $self = shift;
  my $y = shift;
  my $y_pix = $self->frame_B_pix + ($y-$self->ymin())/($self->ymax() - $self->ymin()) * ($self->frame_T_pix() - $self->frame_B_pix());
  return $y_pix;
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

__PACKAGE__->meta->make_immutable;

1;
