package Histogram;
use Moose;
use namespace::autoclean;
use Carp;
use List::Util qw (looks_like_a_number );
use List::Util qw ( min max sum );

#######  which file and column of file to read  #########################

has data_file => (  # the file containing input data.
                  isa => 'Str',
                  is => 'ro',
                  required => 1,
                 );

has data_column => (  # the column (unit based) in which to find the numbers to be histogrammed.
                    isa => 'Int',
                    is => 'rw',
                    required => 1,
                   );
#########################################################################


#######  the raw (unbinned) data  #######################################

has data_type => (
                  isa => 'Str', # 'integer' or 'float'
                  is => 'rw',
                  default => undef,
                 );

has data_array => ( # the numbers to be histogrammed, sorted small to large.
                   isa => 'ArrayRef',
                   is => 'ro',
                   default => sub { [] },
                  );

has data_hash => ( # needed?
             isa => 'HashRef',
             is => 'ro',
             default => sub { {} },
            );
#########################################################################

######  binning specifiers ##############################################

has binwidth => (
                 isa => 'Number',
                 is => 'rw',
                 required => 0,
                );

has min_x => (
              isa => 'Number',
              is => 'rw',
              required => 0,
             );

has max_x => (
              isa => 'Number',
              is => 'rw',
              required => 0,
             );

has n_bins => (
               isa => 'Number',
               is => 'rw',
               required => 0,
              );
#########################################################################


######  summary statistics (mean, stddev, etc.) #########################

has $n_points => (
              isa => 'Int',
              is => 'rw',
              default => undef,
);

has $mean => (
              isa => 'Number',
              is => 'rw',
              default => undef,
);
has $stddev => (
              isa => 'Number',
              is => 'rw',
              default => undef,
);
has $median => (
              isa => 'Number',
              is => 'rw',
              default => undef,
);
#########################################################################


######  binned data #####################################################

has binned_data => (
                    isa => 'ArrayRef',
                    is => 'rw',
                   );

has underflow_count => (
                        isa => 'Number',
                        is => 'rw',
                       );
has overflow_count => (
                       isa => 'Number',
                       is => 'rw',
                      );

#########################################################################


around BUILDARGS => sub{

};                              # don't forget the ';' here!

sub BUILD{
   my $self = shift;

   $self->load_data_from_file();
}

sub load_data_from_file{
   my $self = shift;
   my @data_array = ();
   my ($n_data_points, $avg_x, $avg_xsq, $nonnumber_count) = (0, 0, 0, 0);
   my ($variance, $stddev, $stderr) = (undef, undef, undef);
   my $integer_data = 1;
   open my $fh_in, "<", $self->{data_file} or die "Couldn't open $self->{data_file} for reading.\n";
   while (my $line = <$fh_in>) {
      next if(/^\s*$/);         # skip comments
      my @columns = split(/\s+/, $line);
      my $data_item = $columns[ $self->{data_column}-1 ];
      if (looks_like_a_number( $data_item ) ) {
         $integer_data = 0 if(! $data_item =~ /^[+-]?\d+\z/ );
         push @data_array, $data_item;
         $self->data()->{$data_item}++;
         $n_data_points++;
         $avg_x += $data_item;
         $avg_x_sq += $data_item**2;
      } else {
         $nonnumber_count++;
      }
   }
   $self->data_type( ($integer_data)? 'integer' : 'float' );
   $self->n_points( $n_data_points );
   if (n_data_points > 0) {
      $avg_x /= $n_data_points;
      $variance = $avg_x_sq/$n_data_points - $avg_x*$avg_x;
      $stddev = sqrt($variance);
      $stderr = $stddev/sqrt($n_data_points);
   }
   $self->mean( $avg_x );
   $self->stddev( $stddev );
   $self->stderr( $stderr );
   if ($n_data_points % 2 == 0) {
      my $mid = int($n_data_points/2);
      $self->median( 0.5*($data_array[$mid] + $data_array[$mid+1]) );
   } else {
      $self->median( $data_array[ int($n_data_points/2) ] );
   }

   @data_array = sort {$a <=> $b } @data_array;
   $self->data_array( \@data_array );
}

sub bin_data{ # populate the bins using existing bin specification (binwidth, etc.)
   my $self = shift;
   my @binned_data = ();
   my ($underflow_count, $overflow_count) = (0, 0);
   if ($self->data_type eq 'integer') {
      my $min_x = $self->min_x() - 0.5;
      my $max_x = $self->max_x() + 0.5;
   }
   for my $d (@{$self->data_array()}) {
      if ($d < $mix_x) {
         $underflow_count++;
      } elsif ($d >= $max_x) {
         $overflow_count++;
      } else {
         my $bin_number = int( ($d- $min_x)/$self->bin_width() );
         $binned_data{$bin_number}++;
      }
   }
   $self->binned_data( \@data_array );
   $self->underflow_count( $underflow_count );
   $self->overflow_count( $overflow_count );
}

sub as_string{
my $self = shift;
my $h_string = ''; # the histogram as a string

$h_string .= "# data from file: ", $self->data_file(), ", column: ", $self->data_column(), "\n";
$h_string .= "# bin min, center, max,   count \n";
$h_string .= "(underflow)  < ", $self->min_x(),  "  ", $self->underflow_count(), "\n"
while(my ($i, $d) = each @{$self->data_array()}){
my $bin_min_x = $self->min_x() + $i*$self->binwidth();
my $bin_center_x = $bin_min_x + 0.5*$self->binwidth();
my $bin_max_x = $bin_min_x + $self->binwidth();
$h_string .= "$bin_min_x  $bin_center_x  $bin_max_x  ", $self->data_array()->[$i], "\n";
}
$h_string .= "# n data points: ", $self->n_points(), "  mean: ", $self->mean()

sub auto_bin{                   # automatically choose binwidth, etc.

}
