package Histograms;
use strict;
use warnings;
use Moose;
#use Mouse;
use namespace::autoclean;
use Carp;
use Scalar::Util qw (looks_like_number );
use List::Util qw ( min max sum );
use POSIX qw ( floor ceil );
use Hdata;

# use constant  BINWIDTHS => {
# 		      1.0 => [0.8, 1.25],
# 		      1.25 => [1.0, 2.0],
# 		      2.0 =>[1.25, 2.5],
# 		      2.5 => [2.0, 4.0],
# 		      4.0 => [2.5, 5.0],
# 		      5.0 => [4.0, 8.0],
# 		      8.0 => [5.0, 10.0]
# 			   };

use constant  BINWIDTHS => {
			    100 => [80, 125],
			    125 => [100, 200],
			    200 =>[125, 250],
			    250 => [200, 400],
			    400 => [250, 500],
			    500 => [400, 800],
			    800 => [500, 1000]
			   };

#######  which file and column of file to read  #########################


has data_fcol => ( # strings representing files and column(s) (unit based) in which to find the numbers to be histogrammed.
                  isa => 'Str', # e.g. '0v1:2,3,4; 0v2:4,7,10' -> histogram cols 2,3,4 of file 0v1, and cols 4,7,10 of file 0v2
                  is => 'rw',
                  required => 1,
                 );

has filecol_specifiers => ( # one entry specifying file and column (e.g. 'x.out:3' for each histogram.
                           isa => 'ArrayRef',
                           is => 'rw',
                           required => 0,
                        );

  # has data_files_and_columns => ( # Hashref. keys are files, values strings specifying cols to be histogrammed.
  #                                isa => 'HashRef',
  #                                is => 'rw',
  #                                required => 0,
  #                               );

#########################################################################


#######  the raw (unbinned) data  #######################################

has data_type => (
                  isa => 'Maybe[Str]', # 'integer' or 'float'
                  is => 'rw',
                  default => undef,
                 );

has filecol_hdata => (
                      # a hashref of Hdata objects, one for each histogram,
                      # keys are strings typically with filenames and column numbers, e.g. 'x.out:1' 
                      # but potentially something like 'x.out:3+5' (histogram of the sum of col 3 and col 5 values)
                      # plus one for all of them pooled, with key 'pooled'
                      isa => 'HashRef',
                      is => 'rw',
                      default => sub { {} },
                     );

# has data_hash => ( # needed?
#              isa => 'HashRef',
#              is => 'ro',
#              default => sub { {} },
#             );
#########################################################################

######  binning specifiers ##############################################

has binwidth => (
                 isa => 'Maybe[Num]',
                 is => 'rw',
                 required => 0,
                );

has lo_limit => (               # low edge of lowest bin
                 isa => 'Maybe[Num]',
                 is => 'rw',
                 required => 0,
                );

has hi_limit => (               # high edge of highest bin
                 isa => 'Maybe[Num]',
                 is => 'rw',
                 required => 0,
                );

has n_bins => (
               isa => 'Maybe[Num]',
               is => 'rw',
               required => 0,
              );
#########################################################################







#########################################################################

# around BUILDARGS => sub{

# };
# don't forget the ';' here!

sub BUILD{
   my $self = shift;

   $self->set_filecol_specs(); # construct filecol_specifiers (e.g. ['x.out:3', 'x.out:5'] from 'x.out:3,5'
   $self->load_data_from_file();
   #  print $self->lo_limit(), " ", $self->binwidth(), " ", $self->hi_limit(), "\n";

   if (!(defined $self->lo_limit()  and  defined $self->hi_limit()  and  defined  $self->binwidth())) {
      $self->auto_bin();
   }

   my $n_bins = int( ($self->hi_limit() - $self->lo_limit())/$self->binwidth() ) + 1;
   $self->n_bins($n_bins);

   print "In BUILD: ", $self->lo_limit(), "  ", $self->hi_limit(), "  ", $self->binwidth(), "  ", $self->n_bins(), "\n";

}

sub load_data_from_file{
   my $self = shift;

   my %filecol_hdata = ('pooled' => Hdata->new());

   my $integer_data = 1;

   for my $histogram_id (@{$self->filecol_specifiers()}) { #
      $filecol_hdata{$histogram_id} = Hdata->new();
      if ($histogram_id =~ /^([^:]+)[:](\S+)/) {
         my ($datafile, $cth) = ($1, $2);

         open my $fh_in, "<", $datafile or die "Couldn't open $datafile for reading.\n";
         while (my $line = <$fh_in>) {
            next if($line =~ /^\s*#/); # skip comments
            $line =~ s/^\s+//;
         #   $line =~ s/\s+$//;
            my @columns = split(/\s+/, $line);
            #  for my $the_column (@columns_to_histogram) {
            my $data_item = $columns[ $cth - 1 ];
            if (looks_like_number( $data_item ) ) {

               $integer_data = 0 if(! ($data_item =~ /^[+-]?\d+\z/) );
               #    print "$data_item $integer_data \n";
               $filecol_hdata{$histogram_id}->add_value( $data_item );
               $filecol_hdata{'pooled'}->add_value( $data_item );
            } else {
               #  $nonnumber_count++;
            }
         }
         close $fh_in;
      }
   }

   $self->data_type( ($integer_data)? 'integer' : 'float' );
   for my $hdata (values %filecol_hdata) {
      $hdata->sort_etc();
   }
   $self->filecol_hdata( \%filecol_hdata );
}

######## defining the binning #########

sub auto_bin{                   # automatically choose binwidth, etc.
   my $self = shift;

   my $pooled_hdata = $self->filecol_hdata()->{'pooled'};
   my @bws = sort( keys %{ BINWIDTHS() } );
   # (1.0, 1.25, 2.0, 2.5, 4.0, 5.0, 8.0);
   my ($x_lo, $x_hi) = ($pooled_hdata->min(), $pooled_hdata->max()); 
   my $n_points = $pooled_hdata->n_points();

   my $i5 = int(0.05*$n_points);
   my $i95 = -1*($i5+1);
   #   print "i5 i95: $i5  $i95 \n";
   #my ($v5, $v95) = ($pooled_hdata->data_array()->[$i5], $pooled_hdata->data_array()->[$i95]);
   my $v5 = $pooled_hdata->data_array()->[$i5];
   my $v95 = $pooled_hdata->data_array()->[$i95];
   my $iq1 = int(0.25*$n_points);
   my $iq3 = $n_points - $iq1 - 1;
   my $iqr = $pooled_hdata->data_array()->[$iq3] - $pooled_hdata->data_array()->[$iq1];
   my $FD_bw = 2*$iqr/$n_points**0.3333;
   my $mid = 0.5*($v5 + $v95);
   my $v90range = $v95-$v5;
   my $half_range = 0.5*($v90range * 2);
   #   print STDERR "v5 etc.: $v5 $v95
   my ($lo_limit, $hi_limit) = ($mid - $half_range, $mid + $half_range);
   $lo_limit = 0 if($x_lo >= 0  and  $lo_limit < 0);
   $self->lo_limit($lo_limit);
   $self->hi_limit($hi_limit);
   
   # print "hr npts: $half_range  $n_points\n";
   my $binwidth = $FD_bw;	# 4*$half_range/sqrt($n_points);
   my $bwf = 0.01;

   print STDERR "in auto bin. data type: ", $self->data_type(), "\n";
   if (0) {
      # put into range: [100,1000)
      while ($binwidth >= 1000) {
         $binwidth /= 10;
         $bwf *= 10;
      }
      while ($binwidth < 100) {
         $binwidth *= 10;
         $bwf /= 10;
      }
   } else {
      ($binwidth, $bwf) = xyz($binwidth);
   }

   # round binwidth down to nearest 
   for (my $i = @bws-1; $i >= 0; $i--) {
      my $bw = $bws[$i];
      if ($bw <= $binwidth) {
         $binwidth = $bw;
         last;
      }
   }

   $binwidth *= $bwf;

   if ($self->data_type() eq 'integer') {
      $binwidth = 1 if ($binwidth < 1);
      $binwidth = int($binwidth + 0.5);
   }

   $self->set_binwidth($binwidth);
   # $lo_limit = $binwidth * floor( $lo_limit / $binwidth );
   # $hi_limit = $binwidth * ceil( $hi_limit / $binwidth );
   # if ($self->data_type() eq 'integer') {
   #    $lo_limit -= 0.5;
   #    $hi_limit += 0.5;
   # }
   # print STDERR "in auto bin: $lo_limit  $hi_limit  $binwidth \n";

   # $self->lo_limit($lo_limit);
   # $self->hi_limit($hi_limit);
   # $self->binwidth($binwidth);
}

sub change_range{
   my $self = shift;
   my $new_lo = shift // undef;
   my $new_hi = shift // undef;
   #   print STDERR "new_lo, new_hi:  ", $new_lo // 'undef', "  ", $new_hi // 'undef', "\n";
   $self->lo_limit($new_lo) if(defined $new_lo);
   $self->hi_limit($new_hi) if(defined $new_hi);
   $self->set_binwidth($self->binwidth());
}

sub expand_range{
   my $self = shift;
   my $factor = shift // 1.2;

   my $mid_x = 0.5*($self->lo_limit() + $self->hi_limit());
   my $hrange = $self->hi_limit() - $mid_x;
   my $lo_limit = $mid_x - $factor*$hrange;
   my $hi_limit = $mid_x + $factor*$hrange;
   $lo_limit = max($lo_limit, 0) if($self->filecol_hdata()->{'pooled'}->min() >= 0); # $self->pooled_hdata()->min
   my $binwidth = $self->binwidth();
   $lo_limit = $binwidth * floor( $lo_limit / $binwidth );
   $hi_limit = $binwidth * ceil( $hi_limit / $binwidth );
   $self->lo_limit( $lo_limit );
   $self->hi_limit( $hi_limit );
   $self->n_bins( int( ($self->hi_limit() - $self->lo_limit())/$self->binwidth() ) + 1 );
   print "after:  ", $self->lo_limit(), '  ', $self->hi_limit(), '  ', $self->binwidth(), '  ', $self->n_bins(), "\n";
}

sub change_binwidth{
   my $self = shift;
   my $n_notches = shift // 1; # 1 -> go to next coarser binning, -1 -> go to next finer binning, etc.
   return if($n_notches == 0);
   my $bw = $self->binwidth();
   if ($n_notches > 0) {
      for (1..$n_notches) {
         my ($bw100, $pow10) = xyz($bw);
         $bw = (BINWIDTHS->{ int($bw100+0.5) }->[1])*$pow10;
      }
      $self->set_binwidth($bw);
   } else {			#  ($n_notches == -1) {
      $n_notches *= -1;
      for (1..$n_notches) {
         my ($bw100, $pow10) = xyz($bw);
         $bw = (BINWIDTHS->{ int($bw100+0.5) }->[0])*$pow10;
      }
      $self->set_binwidth($bw);
   }
}

sub set_binwidth{ # set the binwidth and adjust the lo and hi limits to be multiples of binwidth; set n_bins accordingly.
   my $self = shift;
   my $new_bw = shift;
   my ($lo_limit, $hi_limit) = ($self->lo_limit(), $self->hi_limit());
   $lo_limit = $new_bw * floor( $lo_limit / $new_bw );
   $hi_limit = $new_bw * ceil( $hi_limit / $new_bw );
   if ($self->data_type() eq 'integer') {
      $lo_limit -= 0.5;
      $hi_limit += 0.5;
   }
   my $n_bins =  int( ($self->hi_limit() - $self->lo_limit())/$new_bw ) + 1;
   #  print STDERR "in set binwidth: $lo_limit  $hi_limit  $new_bw $n_bins\n";

   $self->lo_limit($lo_limit);
   $self->hi_limit($hi_limit);
   $self->binwidth($new_bw);
   $self->n_bins($n_bins);
}

sub bin_data{ # populate the bins using existing bin specification (binwidth, etc.)
   my $self = shift;

   while (my ($col, $hdata) = each %{$self->filecol_hdata}) {

      my @bin_counts = (0) x $self->n_bins();
      my @bin_centers = map( $self->lo_limit() + ($_ + 0.5)*$self->binwidth(), (0 .. $self->n_bins() ) );
      #     print STDERR 'lo_limit: ', $self->lo_limit(), "   bin centers: ", join('  ', @bin_centers), "\n";
      my ($underflow_count, $overflow_count) = (0, 0);
      my ($lo_limit, $hi_limit) = ($self->lo_limit(), $self->hi_limit());
      #print "datat type: ", $self->data_type(), "\n";
      # if ($self->data_type eq 'integer') {
      #    $lo_limit -= 0.5;
      #    $hi_limit += 0.5;
      # }
      for my $d (@{$hdata->data_array()}) {
         if ($d < $lo_limit) {
            $underflow_count++;
         } elsif ($d >= $hi_limit) {
            $overflow_count++;
         } else {
            my $bin_number = int( ($d - $lo_limit)/$self->binwidth() );
            #print "$lo_limit  ", $self->binwidth(), "  $d  $bin_number \n";
            $bin_counts[$bin_number]++;
            # $bin_centers[$bin_number] = ($bin_number+0.5)*$self->binwidth()
         }
      }
      $self->filecol_hdata()->{$col}->bin_counts( \@bin_counts );
      $self->filecol_hdata()->{$col}->bin_centers( \@bin_centers );
      $self->filecol_hdata()->{$col}->underflow_count( $underflow_count );
      $self->filecol_hdata()->{$col}->overflow_count( $overflow_count );
   }
}

sub binned_data{
   my $self = shift;
   return ($self->bin_centers(), $self->underflow_counts(), $self->bin_counts(), $self->overflow_counts());
}

sub as_string{
   my $self = shift;
   my $h_string = '';           # the histogram as a string

#   my @filecol_specs = @{$self->get_filecol_specs()};
   my @filecol_specs = @{$self->filecol_specifiers};
# print STDERR "filecolspecs: ", join("; ", @filecol_specs), "\n";
   my $horiz_line_string .= sprintf("#----------------------------------------------");
   for (@filecol_specs) {
      $horiz_line_string .= "----------";
   }
   $horiz_line_string .= "\n";

   $h_string .= sprintf("# data from file:column             " . "%9s " x (@filecol_specs+1) . "\n", @filecol_specs, '  pooled' );
   $h_string .= $horiz_line_string;
   $h_string .= sprintf("     < %6.4g  (underflow)          ", $self->lo_limit());

   for my $fcspec (@filecol_specs) {
         $h_string .= sprintf("%9.4g ", $self->filecol_hdata()->{$fcspec}->underflow_count() // 0);
   }
   $h_string .= sprintf("%9.4g \n", $self->filecol_hdata()->{pooled}->underflow_count() );

   $h_string .= $horiz_line_string;
   $h_string .= sprintf("# bin     min    center       max     count \n");

   while (my ($i, $bin_center_x) = each @{$self->filecol_hdata()->{pooled}->bin_centers()} ) {
      my $bin_lo_limit = $bin_center_x - 0.5*$self->binwidth();
      my $bin_hi_limit = $bin_center_x + 0.5*$self->binwidth();
      $h_string .= sprintf("    %9.4g %9.4g %9.4g   ",
                           $bin_lo_limit, $bin_center_x,
                           $bin_hi_limit);

      for my $fcspec (@filecol_specs) {
            $h_string .= sprintf("%9.4g ", $self->filecol_hdata()->{$fcspec}->bin_counts()->[$i] // 0);
      }

      $h_string .= sprintf("%9d\n", ($self->filecol_hdata()->{pooled}->bin_counts()->[$i] // 0));
   }
   $h_string .= $horiz_line_string;
   $h_string .= sprintf("     > %6.4g   (overflow)          ", $self->hi_limit());

   for my $fcspec (@filecol_specs) {
         $h_string .= sprintf("%9.4g ", $self->filecol_hdata()->{$fcspec}->overflow_count() // 0);
   }
   $h_string .= sprintf("%9.4g \n", $self->filecol_hdata()->{pooled}->overflow_count() );
   $h_string .= $horiz_line_string;
   
   #  $h_string .= sprintf("# range: [%9.4g,%9.4g]   median: %9.4g\n", @{$self->range()},  $self->median());
   #  for (@col_specs) {
   for my $fcspec (@filecol_specs) {
      my ($f, $cspec) = split(':', $fcspec);
      my @colspecs = split(',', $cspec);
      for my $csp (@colspecs) {
         my $fc = $f . ':' . $csp;
         $h_string .= sprintf("# file:col %10s  n points: %5d   ", $fc, $self->filecol_hdata()->{$fc}->n_points());
         $h_string .= sprintf("mean: %9.4g   stddev: %9.4g   stderr: %9.4g\n",
                              $self->filecol_hdata()->{$fc}->mean(),
                              $self->filecol_hdata()->{$fc}->stddev(),
                              $self->filecol_hdata()->{$fc}->stderr);
      }
   }
   $h_string .= sprintf("# pooled               n points: %5d   ", $self->filecol_hdata()->{pooled}->n_points());
   $h_string .= sprintf("mean: %9.4g   stddev: %9.4g   stderr: %9.4g\n",
                        $self->filecol_hdata()->{pooled}->mean(),
                        $self->filecol_hdata()->{pooled}->stddev(),
                        $self->filecol_hdata()->{pooled}->stderr);
   return $h_string;
}



sub set_filecol_specs{
   my $self = shift;
   my @filecol_specs = ();

   #  my @filecol_specifiers = split(/;/, $self->data_fcol() ); # e.g. '0v1:3,4,5; 0v2:1,5,9' -> ('0v1:3,4,5', '0v2:1,5,9')
   for my $fcs (split(/;/, $self->data_fcol() )) {
  #   $fcs =~ s/\s+//g; # remove whitespace
      print STDERR "fcs: ", $fcs, "\n";
      my ($f, $cols) = split(':', $fcs);
  #   my @colspecs = split(',', $cols);
     my @colspecs = split(/[, ]+/, $cols);
      for (@colspecs) {
         push @filecol_specs, $f . ':' . $_;
      }
   }
   $self->filecol_specifiers( \@filecol_specs );
   #  return \@filecol_specs;
}

#### ordinary subroutines ########

sub xyz{ # express the input number as prod. of 2 factors, one in range [100,1000)
   # the other an int power of 10.
   my $x = shift;
   my $f = 1;
   while ($x >= 1000) {
      $x /= 10;
      $f *= 10;
   }
   while ($x < 100) {
      $x *= 10;
      $f /= 10;
   }
   return ($x, $f);
}

1;
