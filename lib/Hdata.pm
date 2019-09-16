package Hdata;
use strict;
use warnings;
use Moose;
#use Mouse;
use namespace::autoclean;
use Carp;
use Scalar::Util qw (looks_like_number );
use List::Util qw ( min max sum );
use POSIX qw ( floor ceil );

# to hold the data from (typically) one column, together with
# mean, stddev, etc.

# data values, sorted but not binned

has data_array => (
                  isa => 'ArrayRef',
                  is => 'rw',
                  default => sub { [] },
);

######  summary statistics (mean, stddev, etc.) #########################

has n_points => (
                 isa => 'Maybe[Int]',
                 is => 'rw',
                 default => undef,
                );

has min => (
             isa => 'Maybe[Num]',
             is => 'rw',
             default => undef,
            );

has max => (
             isa => 'Maybe[Num]',
             is => 'rw',
             default => undef,
            );

has range => (                  # min and max numbers in
              isa => 'ArrayRef[Maybe[Num]]',
              is => 'rw',
              default => sub { [undef, undef] },
             );

has sum => (
             isa => 'Maybe[Num]',
             is => 'rw',
             default => 0,
            );

has sumsqr => (
             isa => 'Maybe[Num]',
             is => 'rw',
             default => 0    ,
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

sub add_value{
   my $self = shift;
   my $value = shift;
   push @{$self->data_array()}, $value;
   $self->{sum} += $value;
   $self->{sumsqr} += $value*$value;
}

sub sort_etc{
   my $self = shift;

   my $n_points =  scalar @{ $self->data_array() };
   if ($n_points > 0) {
      $self->{data_array} = [sort {$a <=> $b} @{$self->{data_array}}];
      $self->min( $self->data_array()->[0] );
      $self->max( $self->data_array()->[-1] );
  
      $self->mean( $self->sum()/$n_points );
      my $mean = $self->sum()/$n_points;
      my $variance = $self->sumsqr()/$n_points - $mean*$mean;
      my $stddev = sqrt($variance);
      my $stderr = $stddev/sqrt($n_points);
      $self->n_points( $n_points );
      $self->mean( $mean );
      $self->stddev( $stddev );
      $self->stderr( $stderr );

      if ($n_points % 2 == 0) {
         my $mid = int($n_points/2);
         $self->median( 0.5*($self->{data_array}->[$mid] + $self->{data_array}->[$mid+1]) );
      } else {
         $self->median( $self->{data_array}->[ int($n_points/2) ] );
      }

   }
}


# sub bin_data{ # populate the bins using existing bin specification (binwidth, etc.)
#    my $self = shift;

#    while(my ($col, $data) = each %{$self->column_dataarray}){

#    my @bin_counts = (0) x $self->n_bins();
#    my @bin_centers = map( $self->min_x() + ($_ - 0.5)*$self->binwidth(), (0 .. $self->n_bins() ) );
#    my ($underflow_count, $overflow_count) = (0, 0);
#    my ($min_x, $max_x) = ($self->min_x(), $self->max_x());
#    #print "datat type: ", $self->data_type(), "\n";
#    if ($self->data_type eq 'integer') {
#       $min_x -= 0.5;
#       $max_x += 0.5;
#    }
#    for my $d (@{$data}) {
#       if ($d < $min_x) {
#          $underflow_count++;
#       } elsif ($d >= $max_x) {
#          $overflow_count++;
#       } else {
#          my $bin_number = int( ($d - $min_x)/$self->binwidth() );
#          #print "$min_x  ", $self->binwidth(), "  $d  $bin_number \n";
#          $bin_counts[$bin_number]++;
#         # $bin_centers[$bin_number] = ($bin_number+0.5)*$self->binwidth()
#       }
#    }
#    $self->column_hdata{$col}->bin_counts( \@bin_counts );
#    $self->bin_centers( \@bin_centers );
#    $self->underflow_count( $underflow_count );
#    $self->overflow_count( $overflow_count );
# }


1;
