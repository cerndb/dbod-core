package DBOD::Api;

use strict;
use warnings;
use Exporter;

use YAML::Syck;
use File::ShareDir;
use Log::Log4perl;
use REST::Client;
use MIME::Base64;
use JSON;

use DBOD::Config qw($config $metadata);

our ($VERSION, @ISA, @EXPORT_OK);

$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT_OK   = qw( get_entity_metadata );

sub _api_client {
    my $auth = shift;
    my $client = REST::Client->new(
        host => $config->{'api'}->{'host'},
        timeout => $config->{'api'}->{'timeout'},
    );
    $client->addHeader('Content-Type', 'application/json');
    $client->addHeader('Accept', 'application/json');
    # Disable SSL host verification
    $client->getUseragent()->ssl_opts( SSL_verify_mode => 0 ); 
    if (defined $auth) {
        my $api_user = $config->{'api'}->{'user'};
        my $api_pass = $config->{'api'}->{'password'};
        $client->addHeader("Authorization", "Basic " . 
            encode_base64("$api_user:$api_pass", "")); 
    }
    return $client; 
}

sub _api_get_entity_metadata {
    my $entity = shift;
    my $client = _api_client();
    $client->GET(join '/', 
        $config->{'api'}->{'entity_metadata_endpoint'}, $entity);
    my %result;
    $result{'code'} = $client->responseCode();
    if ($result{'code'} eq '200') {
        $result{'response'} = decode_json $client->responseContent();
    } else {
        $result{'response'} = ''; 
    }
    return \%result;
}

sub get_entity_metadata {
    my $entity = shift;
    my $result = _api_get_entity_metadata($entity);
    if ($result->{'code'} eq '200') {
        return $result->{'response'};
    } elsif ($result->{'code'} eq '500') {
        return $metadata->{$entity} // {};
    } else {
        return {};
    }
}

1;
