package DBOD::Job;

use Moose;
with 'MooseX::Log::Log4perl';
with 'MooseX::Getopt';

use Data::Dumper;
use DBOD::Config qw( $config );

# Input
has 'entity' => ( is => 'ro', isa => 'Str', required => 1);

# output
has '_output' => ( is => 'rw', isa => 'Str', );
has '_result' => ( is => 'rw', isa => 'Num', );

sub run {
    my $self = shift;
    $self->_output("ran with (" . $self->entity() . ") as parameters");
    $self->log->debug( "ran with (" . $self->entity() . ") as parameters");
    $self->log->debug( "ran with config:\n" . Dumper $config  );
    $self->log->debug( "Parameter access: " . Dumper $config->{'parameter'}  );
    $self->_result(0);
}


1;
