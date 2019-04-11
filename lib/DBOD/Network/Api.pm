# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

package DBOD::Network::Api;

use strict;
use warnings;
use Exporter;

use Log::Log4perl qw(:easy);
use REST::Client;
use MIME::Base64;
use JSON;
use Data::Dumper;
use DBOD::Templates;
use DBOD;

our ($VERSION, @EXPORT_OK);

use base qw(Exporter);
@EXPORT_OK   = qw( load_cache get_entity_metadata );

# Loads entity/host entities metadata from cache file. Returns empty if the cache does not exists.
sub load_cache {
    my ($filename)=@_;
    DEBUG 'Loading cache from ' . $filename;
    local $/ = undef;
    open(my $json_fh, "<:encoding(UTF-8)", $filename) or do {
        WARN 'File does not exist or cannot be open';
        return ();
    };

    # The metadata cache is stored as an array of hashes
    my $json_text = <$json_fh>;
    close($json_fh);
    my $array = decode_json $json_text;
    my %md_cache;
    for my $instance (@{$array}) {
        $md_cache{$instance->{db_name}} = $instance;
    }
    return \%md_cache;
}


sub _api_client {
    my ($config, $auth) = @_;
    DEBUG 'Api client connecting to '.$config->{'api'}->{'host'};
    my $client = REST::Client->new(
        host    => $config->{'api'}->{'host'},
        timeout => $config->{'api'}->{'timeout'},
    );
    $client->addHeader( 'Content-Type', 'application/json' );
    $client->addHeader( 'Accept', 'application/json' );
    if ($config->{api}->{ssl_enable}) {
        # X509 Auth
        $client->setCa( $config->{api}->{ssl_ca_certfile} );
        # This seems to be needed because of an issue with the underlying LWP library
        # not being able to verify the host certificate although the whole chain
        # and hostname is correct
        $client->getUseragent()->ssl_opts( verify_hostname => 0 );
    }
    if (defined $auth) {
        my $api_user = $config->{'api'}->{'user'};
        my $api_pass = $config->{'api'}->{'password'};
        DEBUG 'Using basic authentication for user: ' . $api_user;
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
        WARN 'Failed to contact API server';
        $result{'response'} = ''; 
    }
    return \%result;
}

sub _api_get_host_metadata {
    my ($host, $config) = @_;
    my $client = _api_client($config);
    $client->GET(join '/', 
        $config->{'api'}->{'host_metadata_endpoint'}, $host);
    my %result;
    $result{'code'} = $client->responseCode();
    if ($result{'code'} eq '200') {
        $result{'response'} = decode_json $client->responseContent();
    } else {
        WARN 'Failed to contact API server';
        $result{'response'} = ''; 
    }
    return \%result;
}

sub host_metadata {
    my ($host, $config) = @_;
    my $result = _api_get_host_metadata($host, $config);
    if ($result->{'code'} eq '200') {
        return $result->{response}->{response};
    } else {
        ERROR 'Metadata not available for entity ' . $host;
        return;
    }
}

sub get_entity_metadata {
    my ($entity, $cache, $config) = @_;
    my $result = _api_get_entity_metadata($entity, $config);
    if ($result->{'code'} eq '200') {
        return shift @{$result->{response}->{response}};
    } elsif ($result->{'code'} eq '500') {
        WARN 'Returning metadata info from cache';
        return $cache->{$entity} // {};
    } else {
        ERROR 'Metadata not available for entity ' . $entity;
        return {};
    }
}

sub set_ip_alias {
    my ($entity, $ipalias, $config) = @_;
    my $client = _api_client($config, 1);
    my $params = $client->buildQuery([ alias => $ipalias ]);
    $client->POST(
        join('/', $config->{'api'}->{'entity_ipalias_endpoint'}, $entity) .
        $params
    );
    if ($client->responseCode() eq '201') {
        INFO 'IP Alias succesfully created for ' . $entity;
        return $OK;
    } else {
        ERROR 'Resource not available. IP alias creation failed for ' . $entity;
        return $ERROR;
    }
}

sub get_ip_alias {
    my ($entity, $config) = @_;
    my $client = _api_client($config);
    $client->GET(join '/', 
        $config->{'api'}->{'entity_ipalias_endpoint'}, $entity);
	DEBUG "API call returns " . $client->responseCode();
    DEBUG "API call returns " . $client->responseContent();
    if ($client->responseCode() eq '200') {
        INFO 'IP Alias fetched for ' . $entity;
        my $result = decode_json $client->responseContent();
        return shift @{$result->{response}};
    } else {
        WARN 'IP alias does not exist for ' . $entity;
		return;
    }
}

sub remove_ip_alias {
    my ($entity, $config) = @_;
    my $client = _api_client($config, 1);
    $client->DELETE(join '/', 
        $config->{'api'}->{'entity_ipalias_endpoint'}, $entity);
    DEBUG "API call returns " . $client->responseCode();
    DEBUG "API call returns " . $client->responseContent();
    if ($client->responseCode() eq '204') {
        INFO 'IP Alias removed for ' . $entity;
		return $OK;
    } else {
        ERROR 'IP alias could not be removed for ' . $entity;
		return $ERROR;
    }
}

sub set_metadata { 
    my ($entity, $metadata, $config) = @_;
    my $client = _api_client($config, 1);
    my $metadata_json = encode_json $metadata;
	
    $client->PUT(
        join('/', $config->{'api'}->{'entity_metadata_endpoint'}, $entity),
        "metadata=$metadata_json",
        {
            Content_Type => 'application/x-www-form-urlencoded',
        }
    );
    my %result;
    $result{'code'} = $client->responseCode();
    if ($result{'code'} eq '201') {
        INFO 'Entity created: ' . $entity;
    } else { 
        ERROR 'Error creating entity: ' . $entity; 
    }
    return \%result;
}

sub create_entity { 
    my ($input, $config) = @_;
    my $entity = $input->{dbname};
    my $metadata = DBOD::Templates::create_metadata($input, $config);
    if (defined $metadata) { 
        my $client = _api_client($config, 1);
        $client->PUT(
            join('/', $config->{'api'}->{'entity_endpoint'}, $entity),
            $metadata,
            {
            Content_Type => 'application/json',
            }
        );
        my %result;
        $result{'code'} = $client->responseCode();
		DEBUG "result: ", Dumper \%result;
        if ($result{'code'} eq '201') {
            INFO 'Entity created: ' . $entity;
        } elsif ($result{code} eq '200') {
			INFO 'Entity already present in database';
        } elsif ($result{code} eq '204') {
            INFO 'Entity updated';
        } else {
            ERROR 'Error creating entity: ' . $entity; 
			return $ERROR;
		}
        return $OK;
    } else {
        ERROR "Entity metadata not valid. Aborting operation";
        return $ERROR;
    }
}

sub delete_entity {
    my ($entity, $config) = @_;
    my $client = _api_client($config,1);
    $client->DELETE(join '/', 
        $config->{'api'}->{'entity_endpoint'}, $entity);
    my %result;
    $result{'code'} = $client->responseCode();
    if ($result{'code'} eq '204') {
         INFO 'Entity deleted: ' . $entity;
         return $OK;
    } else {
        ERROR 'Failed to contact API server';
	DEBUG Dumper $client;
	return $ERROR;
    }
}

1;
