package DBOD::Job;

use Moose;
with 'MooseX::Log::Log4perl';
with 'MooseX::Getopt';

use Data::Dumper;
use DBOD::Config;
use DBOD::Api qw( load_cache get_entity_metadata );

# Input
has 'entity' => ( is => 'ro', isa => 'Str', required => 1);

# Variables
has 'md_cache' => (is => 'rw', isa =>'HashRef');
has 'config' => (is => 'rw', isa => 'HashRef');
has 'metadata' => (is => 'rw', isa => 'HashRef');

# output
has '_output' => ( is => 'rw', isa => 'Str', );
has '_result' => ( is => 'rw', isa => 'Num', );

after 'new_with_options' => sub {
    my $self = shift;
};

sub run {
    my ($self, $body, $params) = @_;
    $self->config(DBOD::Config::load());
    my %cache = load_cache($self->config);
    $self->md_cache(\%cache);
    $self->metadata(
        get_entity_metadata($self->entity, $self->md_cache, $self->config));
    $self->log->debug(Dumper $self->metadata);
    my $result = $body->($self->entity, $params);
    $self->_result($result);
}


1;
