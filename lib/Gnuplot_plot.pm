package Gnuplot_plot;
use strict;
use warnings;
use Moose;
# use Mouse;
use namespace::autoclean;
use Carp;
use Scalar::Util qw (looks_like_number );
use List::Util qw ( min max sum );
use POSIX qw ( floor ceil );
use Graphics::GnuplotIF qw(GnuplotIF);

my $y_plot_factor = 1.08;
my $y_plot_factor_log = 1.5;

has histograms => (
		   isa => 'Object',
		   is => 'rw',
		   required => 1,
		  );

has gnuplotIF => ( # this is the object constructed with Graphics::GnuplotIF->new(...
	      isa => 'Maybe[Object]',
	      is => 'rw',
	      required => 0,
	      default => undef,
		);

has persist => (
		isa => 'Bool',
		is => 'rw',
		required => 0,
		default => 1,
	       );

has terminal => (
		 isa => 'Str',
		 is => 'rw',
		 required => 0,
		 default => 'x11',
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

# has frame_L_pix => (
# 		    isa => 'Maybe[Num]',
# 		    is => 'rw',
# 		    required => 0,
# 		    default => undef,
# 		   );

# has frame_R_pix => (
# 		    isa => 'Maybe[Num]',
# 		    is => 'rw',
# 		    required => 0,
# 		    default => undef,
# 		   );

# has frame_B_pix => (
# 		    isa => 'Maybe[Num]',
# 		    is => 'rw',
# 		    required => 0,
# 		    default => undef,
# 		   );

# has frame_T_pix => (
# 		    isa => 'Maybe[Num]',
# 		    is => 'rw',
# 		    required => 0,
# 		    default => undef,
# 		   );

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

has xmin => (
	     isa => 'Maybe[Num]',
	     is => 'rw',
	     required => 0,
	     default => undef,
	    );

has xmax => (
	     isa => 'Maybe[Num]',
	     is => 'rw',
	     required => 0,
	     default => undef,
	    );

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

has log_y => (
		isa => 'Bool',
		is => 'rw',
		required => 0,
		default => 0,
	     );

has vline_position => (
		       isa => 'Maybe[Num]',
		       is => 'rw',
		       required => 0,
		       default => undef,
		       );

# has color => (
# 	      isa => 'Maybe[Str]',
# 	      is => 'rw',
# 	      required => 0,
# 	      default => undef,
# 	     );

# has colors => (
# 	       isa => 'Maybe[HashRef]',
# 	       is => 'rw',
# 	       required => 0,
# 	       default => undef,
# 	       # sub {
# 	       # 	 { 'black' => [0,0,0], 'white' => [255,255,255],
# 	       # 	   'blue' => [50,80,255], 'green' => [20,130,20], 'red' => [150,20,20] }
# 	       # },
# 	      );


sub BUILD{
  my $self = shift;

  my $bin_width = $self->histograms->binwidth;
  my $xmin = $self->xmin;
  my $xmax = $self->xmax;

  my $gnuplotIF = Graphics::GnuplotIF->new(persist => $self->persist, style => 'histeps');
  $self->gnuplotIF($gnuplotIF);
  my $terminal_command = "set terminal " . $self->terminal . " noenhanced " .
    " linewidth " . $self->line_width . " size " . $self->width . ", " . $self->height;
  $gnuplotIF->gnuplot_cmd($terminal_command);

  $gnuplotIF->gnuplot_set_xlabel($self->x_axis_label) if(defined $self->x_axis_label);
  $gnuplotIF->gnuplot_set_ylabel($self->y_axis_label) if(defined $self->y_axis_label);

 if ($self->log_y()) {
      $gnuplotIF->gnuplot_cmd('set log y');
      my $ymax_log = $self->ymax_log();
      $gnuplotIF->gnuplot_set_yrange($self->ymin_log(), $ymax_log // '*');
    } else {
      my $ymax = $self->ymax();
      $gnuplotIF->gnuplot_set_yrange($self->ymin(), $ymax // '*');
    }

     my $key_pos_cmd = 'set key ' . $self->key_horiz_position . " " .  $self->key_vert_position;
    $gnuplotIF->gnuplot_cmd($key_pos_cmd);
    $gnuplotIF->gnuplot_cmd("set border lw " . $self->relative_frame_thickness());
    $gnuplotIF->gnuplot_cmd('set mxtics');
    $gnuplotIF->gnuplot_cmd('set tics out');
    $gnuplotIF->gnuplot_cmd('set tics scale 2,1');
  #  $gnuplotIF->gnuplot_cmd($other_gnuplot_command) if(defined $other_gnuplot_command);

}

sub draw_histograms{
  my $self = shift;

  my $histograms_obj = $self->histograms;
  my $gnuplotIF = $self->gnuplotIF;

  my ($xmin, $xmax) = ($self->xmin, $self->xmax);
  my ($ymin, $ymax) = ($self->ymin, $self->ymax);

  $gnuplotIF->gnuplot_set_xrange($xmin, $xmax);
  my $bin_centers = $histograms_obj->filecol_hdata()->{pooled}->bin_centers();
  my @plot_titles = ();

  my @histo_bin_counts = ();
  while (my ($i_histogram, $plt) = each @{$histograms_obj->histograms_to_plot()} ) {
    if ($plt == 1) {
      print STDERR "adding histogram w index $i_histogram.\n";
      my $fcspec = $histograms_obj->filecol_specifiers()->[$i_histogram];
      my $hdata_obj = $histograms_obj->filecol_hdata()->{$fcspec};
      my $bincounts = $hdata_obj->bin_counts();
      push @plot_titles, $hdata_obj->label();
      push @histo_bin_counts, $bincounts; # push an array ref holding the bin counts ...
    }
  }
      #
  $gnuplotIF->gnuplot_set_plot_titles(@plot_titles);
  $gnuplotIF->gnuplot_plot_xy($bin_centers, @histo_bin_counts);
  print "bottom of draw_histograms (gnuplot).\n";
  # sleep(3);
}


sub draw_vline{
  my $self = shift;
  my $gnuplotIF = $self->gnuplotIF;
  my $vline_x = $self->vline_position;

  if (defined $vline_x) {
    $gnuplotIF->gnuplot_cmd("unset arrow");
    $gnuplotIF->gnuplot_cmd("set arrow nohead from $vline_x, graph 0 to $vline_x, graph 1 lw 1 dt 2");
    print "Drew vline at x = ", $vline_x, "\n";
  }
}

sub handle_interactive_command{ # handle 1 line of interactive command, e.g. r:4 or xmax:0.2;ymax:2000q
 my $self = shift;
  my $histograms_obj = $self->histograms;
  # my $the_plot_params = shift;	# instance of Plot_params
  # my $plot_params = shift; # Plot_params->new( log_y => $log_y, ymin => $ymin, ymax => $ymax, ymin_log => $ymin_log, ymax_log => $ymax_log,
  # 			    vline_position => $vline_position, line_width => $line_width);
  my $gnuplotIF = $self->gnuplotIF; # $gnuplot_plot instance of Graphics::GnuplotIF
  my $commands_string = shift;
  #  my $plot = $the_plot_params->plot_obj();
  my $log_y = $self->log_y();
  my $ymin = $self->ymin();
  my $ymax = $self->ymax();
  my $ymin_log = $self->ymin_log();
  my $ymax_log = $self->ymax_log();
 # my $vline_position = $self->vline_position(); # 
  my $line_width = $self->line_width();

  $commands_string =~ s/\s+$//g; # delete whitespace
  return 1 if($commands_string eq 'q');
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
	$gnuplotIF->gnuplot_cmd('set grid');
      } elsif ($cmd eq 'll') {
	if ($log_y) {
	  $self->log_y(0);
	  $gnuplotIF->gnuplot_cmd('unset log');
	  $gnuplotIF->gnuplot_set_yrange($ymin, $ymax);
	} else {
	  $self->log_y(1);
	  $gnuplotIF->gnuplot_cmd('set log y');
	  print STDERR "ll max_bin_y: ", $histograms_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
	  print STDERR "ll $ymin $ymax\n";
	  print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
	  $gnuplotIF->gnuplot_set_yrange($ymin_log, $ymax_log);
	}
      } elsif ($cmd eq 'ymax') {
	if (!$log_y) {
	  $ymax = $param;
	  $gnuplotIF->gnuplot_set_yrange($ymin, $ymax);
	} else {
	  $ymax_log = $param;
	  $gnuplotIF->gnuplot_set_yrange($ymin_log, $ymax_log);
	}
      } elsif ($cmd eq 'ymin') {
	if (!$log_y) {
	  $ymin = $param;
	  print "ymin,ymax,yminlog,ymaxlog: $ymin $ymax $ymin_log $ymax_log\n";
	  $gnuplotIF->gnuplot_set_yrange($ymin, $ymax);
	  # $self->ymin($ymin);
	} else {
	  $ymin_log = $param;
	  $gnuplotIF->gnuplot_set_yrange($ymin_log, $ymax_log);
	  # $self->ymin_log($ymin_log);
	}
      } elsif ($cmd eq 'x') {	# expand (or contract) x range.
	$histograms_obj->expand_range($param);
	$histograms_obj->bin_data();
      } elsif ($cmd eq 'bw') {	# set the bin width
	$histograms_obj->set_binwidth($param);
	$histograms_obj->bin_data();
      } elsif ($cmd eq 'lo' or $cmd eq 'low' or $cmd eq 'xmin') { # change low x-scale limit
	$histograms_obj->change_range($param, undef);
	$histograms_obj->bin_data();
      } elsif ($cmd eq 'hi' or $cmd eq 'xmax') { # change high x-scale limit
	$histograms_obj->change_range(undef, $param);
	$histograms_obj->bin_data();
      } elsif ($cmd eq 'c') {	# coarsen bins
	$histograms_obj->change_binwidth($param);
	$histograms_obj->bin_data();
	$ymax = $histograms_obj->max_bin_y()*$y_plot_factor;
	# $self->ymax($ymax);
	$ymax_log = $histograms_obj->max_bin_y()*$y_plot_factor_log;
	# $self->ymax_log($ymax_log);
	if ($log_y) {
	  $gnuplotIF->gnuplot_set_yrange($ymin_log, $ymax_log);
	} else {
	  $gnuplotIF->gnuplot_set_yrange($ymin, $ymax);
	}
      } elsif ($cmd eq 'r') {	# refine bins
	$histograms_obj->change_binwidth($param? -1*$param : -1);
	$histograms_obj->bin_data();
	$ymax = $histograms_obj->max_bin_y()*$y_plot_factor;
	# $self->ymax($ymax);
	$ymax_log = $histograms_obj->max_bin_y()*$y_plot_factor_log;
	# $self->ymax_log($ymax_log);
	if ($log_y) {
	  $gnuplotIF->gnuplot_set_yrange($ymin_log, $ymax_log);
	} else {
	  $gnuplotIF->gnuplot_set_yrange($ymin, $ymax);
	}
      } elsif ($cmd eq 'key') { # move the key (options are left, right, top, bottom)
	my $new_key_position = $param // 'left'; #
	$new_key_position =~ s/,/ /; # so can use e.g. left,bottom to move both horiz. vert. at once
	$gnuplotIF->gnuplot_cmd("set key $new_key_position");
      } elsif ($cmd eq 'xlabel') {
	$param =~ s/^\s+//;
	$param =~ s/\s+$//;
	$param =~ s/^([^'])/'$1/;
	$param =~ s/([^']\s*)$/$1'/;
	print STDERR "param: $param \n";
	$gnuplotIF->gnuplot_cmd("set xlabel $param");
      } elsif ($cmd eq 'export') {
	$param =~ s/'//g; # the name of the file to export to; the format will be png, and '.png' will be added to filename

	$gnuplotIF->gnuplot_hardcopy($param, " png linewidth $line_width");
	# plot_the_plot_gnuplot($histograms_obj, $gnuplotIF, $vline_position);
	$self->draw_histogram();
	$self->draw_vline();
	$gnuplotIF->gnuplot_restore_terminal();
      } elsif ($cmd eq 'off') {
	$histograms_obj->histograms_to_plot()->[$param-1] = 0;
      } elsif ($cmd eq 'on') {
	$histograms_obj->histograms_to_plot()->[$param-1] = 1;
      } elsif ($cmd eq 'cmd') {
	if ($param =~ /^\s*['](.+)[']\s*$/) { # remove surrounding single quotes if present
	  $param = $1;
	}
	$gnuplotIF->gnuplot_cmd("$param");
      }
      print STDERR "max_bin_y: ", $histograms_obj->max_bin_y(), " y_plot_factor: $y_plot_factor \n";
      #plot_the_plot_gnuplot($histograms_obj, $gnuplotIF, $vline_position);
      $self->draw_histogram();
      $self->draw_vline();

      $self->ymin($ymin);
      $self->ymin_log($ymin_log);
      $self->ymax($ymax);
      $self->ymax_log($ymax_log);
    }
  }
  return 0;
}

# sub x_pix{
#   my $self = shift;
#   my $x = shift;
#   my $x_pix = $self->frame_L_pix + ($x-$self->xmin())/($self->xmax() - $self->xmin()) * ($self->frame_R_pix() - $self->frame_L_pix());
#   return $x_pix;
# }

# sub y_pix{
#   my $self = shift;
#   my $y = shift;
#   my $y_pix = $self->frame_B_pix + ($y-$self->ymin())/($self->ymax() - $self->ymin()) * ($self->frame_T_pix() - $self->frame_B_pix());
#   return $y_pix;
# }

# sub tick_spacing{
#   # put approx. 20 tick marks
#   my $max_data = shift;
#   my @spacing_options = (1,2,4,5,10);
#   my $int_log10_max_data = int( log($max_data)/log(10) );
#   my $z = $max_data/(10**$int_log10_max_data); # should be in range 1 <= $z < 10
#   for my $sopt (@spacing_options) {
#     if ($sopt > $z) {
#       my $ts = $sopt*(10**$int_log10_max_data)/20;
#       return $ts;
#     }
#   }
#   print STDERR "### $max_data  $int_log10_max_data \n";
# }

__PACKAGE__->meta->make_immutable;

1;
