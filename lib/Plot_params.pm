package Plot_params;
use strict;
use warnings;
use Moose;
# use Mouse;
use namespace::autoclean;
use Carp;
use Scalar::Util qw (looks_like_number );
use List::Util qw ( min max sum );
use POSIX qw ( floor ceil );
#use Hdata;

# store various numbers that will be used both gnuplot and gd

has log_y => (
	       isa => 'Bool',
	       is => 'rw',
	       required => 1,
	      );

has ymin => ( # value of y coord at bottom of graph (linear scale)
                  isa => 'Num', # e.g. '0v1:2,3,4; 0v2:4,7,10' -> histogram cols 2,3,4 of file 0v1, and cols 4,7,10 of file 0v2
                  is => 'rw',
                  required => 1,
	     );

has ymax => ( # value of y coord at top of graph (linear scale)
                  isa => 'Num', # e.g. '0v1:2,3,4; 0v2:4,7,10' -> histogram cols 2,3,4 of file 0v1, and cols 4,7,10 of file 0v2
                  is => 'rw',
                  required => 1,
	     );
has ymin_log => ( # value of y coord at bottom of graph (log scale)
                  isa => 'Num', # e.g. '0v1:2,3,4; 0v2:4,7,10' -> histogram cols 2,3,4 of file 0v1, and cols 4,7,10 of file 0v2
                  is => 'rw',
                  required => 1,
	     );
has ymax_log => ( # value of y coord at top of graph (log scale)
                  isa => 'Num', # e.g. '0v1:2,3,4; 0v2:4,7,10' -> histogram cols 2,3,4 of file 0v1, and cols 4,7,10 of file 0v2
                  is => 'rw',
                  required => 1,
		);

has vline_position => (
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

1;
