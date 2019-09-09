package Histogram;
#use Moose;
use Mouse;
use namespace::autoclean;
use Carp;
use Scalar::Util qw (looks_like_number );
use List::Util qw ( min max sum );

#######  which file and column of file to read  #########################

has data_file => (              # the file containing input data.
                  isa => 'Str',
                  is => 'ro',
                  required => 1,
                 );

has data_column => ( # the column (unit based) in which to find the numbers to be histogrammed.
                    isa => 'Int',
                    is => 'rw',
                    required => 1,
                   );
#########################################################################


#######  the raw (unbinned) data  #######################################

has data_type => (
                  isa => 'Maybe[Str]', # 'integer' or 'float'
                  is => 'rw',
                  default => undef,
                 );

has data_array => ( # the numbers to be histogrammed, sorted small to large.
                   isa => 'ArrayRef',
                   is => 'rw',
                   default => sub { [] },
                  );

# has data_hash => ( # needed?
#              isa => 'HashRef',
#              is => 'ro',
#              default => sub { {} },
#             );
#########################################################################

######  binning specifiers ##############################################

has binwidth => (
                 isa => 'Num',
                 is => 'rw',
                 required => 0,
                );

has min_x => (
              isa => 'Num',
              is => 'rw',
              required => 0,
             );

has max_x => (
              isa => 'Num',
              is => 'rw',
              required => 0,
             );

has n_bins => (
               isa => 'Num',
               is => 'rw',
               required => 0,
              );
#########################################################################


######  summary statistics (mean, stddev, etc.) #########################

has n_points => (
                 isa => 'Maybe[Int]',
                 is => 'rw',
                 default => undef,
                );

has range => (                  # min and max numbers in
              isa => 'ArrayRef[Maybe[Num]]',
              is => 'rw',
              default => sub { [undef, undef] },
             );

has mean => (
             isa => 'Maybe[Num]',
             is => 'rw',
             default => undef,
            );
has stddev => (
               isa => 'Maybe[Num]',
               is => 'rw',
               default => undef,
              );
has stderr => (
               isa => 'Maybe[Num]',
               is => 'rw',
               default => undef,
              );
has median => (
               isa => 'Maybe[Num]',
               is => 'rw',
               default => undef,
              );
#########################################################################


######  binned data #####################################################

has bin_counts => (
                   isa => 'ArrayRef',
                   is => 'rw',
                  );

has bin_centers => (
                    isa => 'ArrayRef',
                    is => 'rw',
                   );

has underflow_count => (
                        isa => 'Num',
                        is => 'rw',
                       );
has overflow_count => (
                       isa => 'Num',
                       is => 'rw',
                      );

#########################################################################

# around BUILDARGS => sub{

# };
# don't forget the ';' here!

sub BUILD{
   my $self = shift;

   $self->load_data_from_file();
   #  print $self->min_x(), " ", $self->binwidth(), " ", $self->max_x(), "\n";
}

sub load_data_from_file{
   my $self = shift;
   my @data_array = ();
   my ($n_data_points, $avg_x, $avg_xsq, $nonnumber_count) = (0, 0, 0, 0);
   my ($variance, $stddev, $stderr) = (undef, undef, undef);
   my $integer_data = 1;
   open my $fh_in, "<", $self->{data_file} or die "Couldn't open $self->{data_file} for reading.\n";
   while (my $line = <$fh_in>) {
      next if($line =~ /^\s*#$/); # skip comments
      my @columns = split(/\s+/, $line);
      my $data_item = $columns[ $self->{data_column}-1 ];
      if (looks_like_number( $data_item ) ) {
         
         $integer_data = 0 if(! ($data_item =~ /^[+-]?\d+\z/) );
         #    print "$data_item $integer_data \n";
         push @data_array, $data_item;
         #        $self->data_hash()->{$data_item}++;
         $n_data_points++;
         $avg_x += $data_item;
         $avg_xsq += $data_item**2;
         
      } else {
         $nonnumber_count++;
      }
   }
   $self->data_type( ($integer_data)? 'integer' : 'float' );
   $self->n_points( $n_data_points );
   if ($n_data_points > 0) {
      $avg_x /= $n_data_points;
      $variance = $avg_xsq/$n_data_points - $avg_x*$avg_x;
      $stddev = sqrt($variance);
      $stderr = $stddev/sqrt($n_data_points);
   }

   $self->mean( $avg_x );
   $self->stddev( $stddev );
   $self->stderr( $stderr );
   @data_array = sort {$a <=> $b } @data_array;
   print STDERR join(' ', @data_array), "\n";
   $self->range( [$data_array[0], $data_array[-1]] );
   if ($n_data_points % 2 == 0) {
      my $mid = int($n_data_points/2);
      $self->median( 0.5*($data_array[$mid] + $data_array[$mid+1]) );
   } else {
      $self->median( $data_array[ int($n_data_points/2) ] );
   }

   
   $self->data_array( \@data_array );
}

sub bin_data{ # populate the bins using existing bin specification (binwidth, etc.)
   my $self = shift;
   my @bin_counts = ();
   my @bin_centers = ();
   my ($underflow_count, $overflow_count) = (0, 0);
   my ($min_x, $max_x) = ($self->min_x(), $self->max_x());
   #print "datat type: ", $self->data_type(), "\n";
   if ($self->data_type eq 'integer') {
      $min_x -= 0.5;
      $max_x += 0.5;
   }
   for my $d (@{$self->data_array()}) {
      if ($d < $min_x) {
         $underflow_count++;
      } elsif ($d >= $max_x) {
         $overflow_count++;
      } else {
         my $bin_number = int( ($d - $min_x)/$self->binwidth() );
         #print "$min_x  ", $self->binwidth(), "  $d  $bin_number \n";
         $bin_counts[$bin_number]++;
         $bin_centers[$bin_number] = ($bin_number+0.5)*$self->binwidth()
      }
   }
   $self->bin_counts( \@bin_counts );
   $self->bin_centers( \@bin_centers );
   $self->underflow_count( $underflow_count );
   $self->overflow_count( $overflow_count );
}

sub binned_data{
   my $self = shift;
   return ($self->bin_centers(), $self->underflow_counts(), $self->bin_counts(), $self->overflow_counts());
}

sub as_string{
   my $self = shift;
   my $h_string = '';           # the histogram as a string

   $h_string .= sprintf("# data from file: %s, column: %3d \n", $self->data_file(), $self->data_column() );
   $h_string .= sprintf("#-----------------------------------------------\n");
   $h_string .= sprintf("     < %6.4g  (underflow)         %8d \n", $self->min_x(), $self->underflow_count() );
   $h_string .= sprintf("#-----------------------------------------------\n");
   $h_string .= sprintf("# bin     min    center       max     count \n");

   for (my ($i, $bin_min_x) = (0, $self->min_x()); $bin_min_x < $self->max_x; $i++, $bin_min_x += $self->binwidth()) {
      my $bin_center_x = $bin_min_x + 0.5*$self->binwidth();
      my $bin_max_x = $bin_min_x + $self->binwidth();
      $h_string .= sprintf("    %9.4g %9.4g %9.4g  %8d\n",
                           $bin_min_x, $bin_center_x, $bin_max_x, ($self->bin_counts()->[$i] // 0));
   }
   $h_string .= sprintf("#-----------------------------------------------\n");
   $h_string .= sprintf("     > %6.4g  (overflow)          %8d \n", $self->max_x(), $self->overflow_count() );
   $h_string .= sprintf("#-----------------------------------------------\n");
   $h_string .= sprintf("# n data points: %5d\n", $self->n_points());
   $h_string .= sprintf("# range: [%9.4g,%9.4g]   median: %9.4g\n", @{$self->range()},  $self->median());
   $h_string .= sprintf("# mean: %9.4g   stddev: %9.4g   stderr: %9.4g\n",
                        $self->mean(), $self->stddev(), $self->stderr);
   return $h_string;
}



sub auto_bin{                   # automatically choose binwidth, etc.

}

1;
