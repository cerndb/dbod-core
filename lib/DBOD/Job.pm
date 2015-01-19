package DBOD::Job;

use Moose;
with 'MooseX::Log::Log4perl';
with 'MooseX::Getopt';

# Check https://metacpan.org/pod/MooseX::Getopt

# Input
has 'entity' => ( is => 'ro', isa => 'Str', required => 1);

# output
has '_output' => ( is => 'rw', isa => 'Str', );
has '_result' => ( is => 'rw', isa => 'Num', );


sub run {
    my $self = shift;
    $self->output("ran with (" . $self->entity() . ") as parameters");
    $self->log->debug( "ran with (" . $self->entity() . ") as parameters");
    $self->result(0);
}


1;
