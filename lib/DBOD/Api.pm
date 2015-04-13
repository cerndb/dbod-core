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

our ($VERSION, @ISA, @EXPORT_OK);

$VERSION     = 0.1;
@ISA         = qw(Exporter);
@EXPORT_OK   = qw( load_cache get_entity_metadata );

# Loads entity/host entities metadata from cache file
sub load_cache {
    my $config = shift;
    my $filename = $config->{'api'}->{'cachefile'};
    my $json_text = do { 
        local $/ = undef;
        open(my $json_fh, "<:encoding(UTF-8)", $filename)
            or return ();
        <$json_fh>
    };
    my $nested_array = decode_json $json_text;
    my @flat_array = map{@$_} @$nested_array;

    return @flat_array;
}


sub _api_client {
    my ($config, $auth) = @_;
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
    my ($entity, $config) = @_;
    my $client = _api_client($config);
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
    my ($entity, $cache, $config) = @_;
    my $result = _api_get_entity_metadata($entity, $config);
    if ($result->{'code'} eq '200') {
        return $result->{'response'};
    } elsif ($result->{'code'} eq '500') {
        return $cache->{$entity} // {};
    } else {
        return {};
    }
}

1;
