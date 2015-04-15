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

sub BUILD {
    my $self = shift;
    # Load General Configuration from file
    $self->config(DBOD::Config::load());
    # Load cache file
    my %cache = load_cache($self->config);
    $self->md_cache(\%cache);
    # Load entity metadata
    $self->metadata(
        get_entity_metadata($self->entity, $self->md_cache, $self->config));
};

sub run {
    my ($self, $body, $params) = @_;
    my $result = $body->($params);
    $self->_result($result);
}


1;
