package DBOD::Job;
use Moose;
with 'MooseX::Log::Log4perl';
with 'MooseX::Getopt';

# Check https://metacpan.org/pod/MooseX::Getopt

has 'input' => (
    is => 'rw',
    isa => 'Str',
    );

has 'output' => (
    is => 'rw',
    isa => 'Str',
    );

has 'result' => (
    is => 'rw',
    isa => 'Num',
);

sub help {

}

sub run {
    my $self = shift;
    $self->output("ran with (" . $self->input() . ") as parameters");
    $self->log->debug( "ran with (" . $self->input() . ") as parameters");
    $self->result(0);
}


1;
