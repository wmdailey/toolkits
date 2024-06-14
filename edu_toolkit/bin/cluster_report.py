#!/usr/bin/python

# Copyright 2024 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Disclaimer
# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.


# Title: cluster_report.pyh
# Author: WKD
# Date: 15JAN24
# Version: 22MAR24
# Purpose: Use CM REST API to run a cluster report

import ConfigParser
import cm_client
from cm_api.api_client import ApiResource
from cm_client.rest import ApiException
from cm_api.endpoints.services import ApiService
from pprint import pprint

# Read in the config file
config = ConfigParser.ConfigParser()
config.read("/home/training/conf/cluster.ini")

# Assign account info
cm_host = config.get("CM", "cm.host")
cluster_name = config.get("CM", "cluster.name")
admin_user = config.get("CM", "admin.name")
admin_password = config.get("CM", "admin.password")
truststore = config.get("CM", "truststore.pem")

# Assign Clustername
cdh_version = "CDH7"

# Assign HTTPS authentication
cm_client.configuration.username = admin_user
cm_client.configuration.password = admin_password
cm_client.configuration.verify_ssl = True
# Path of truststore file
cm_client.configuration.ssl_ca_cert = truststore

# Create an instance of the API class
api_host = 'https://' + cm_host
port = '7183'
api_version = 'v45'
# Construct base URL for API
# https://cmhost:7183/api/v45
api_url = api_host + ':' + port + '/api/' + api_version
api_client = cm_client.ApiClient(api_url)
try:
    # Set session cookie
    # Any valid api call shall return a Set-Cookie HTTP response header
    api_instance = cm_client.ClouderaManagerResourceApi(api_client)
    api_instance.get_version()
    api_client.cookie = api_client.last_response.getheader('Set-Cookie')
except ApiException as e:
    print("Failed to set session cookies. Exception occurred when calling "
        "ClouderaManagerResourceApi->get_version: %s\n" % e)

# Main Function
def main():
    cluster_api_instance = cm_client.ClustersResourceApi(api_client)

    # Lists all known clusters.
    api_response = cluster_api_instance.read_clusters(view='SUMMARY')

    print "List all known clusters"
    for cluster in api_response.items:
        print cluster.name, "-", cluster.full_version
    print

    # Look for cluster versions
        #services = services_api_instance.read_services(cluster.name, view='FULL')
    print "List cluster versions:"

    if cluster.full_version.startswith("7."):
            services_api_instance = cm_client.ServicesResourceApi(api_client)
            services = services_api_instance.read_services("Cluster1", view='FULL')
            for service in services.items:
                print service.display_name, "-", service.type
            if service.type == 'HDFS':
                hdfs = service
    print

    print "Service status:"
    print hdfs.name, hdfs.service_state, hdfs.health_summary
    print
    ## -- Output --
    # HDFS-1 STARTED GOOD

    print "Service URL:"
    print hdfs.service_url
    print
    ## -- Output --
    # http://cm-host:7180/cmf/serviceRedirect/HDFS-1
   print "Health check:"
    for health_check in hdfs.health_checks:
        print health_check.name, "---", health_check.summary
    print

# Main Function
def main():
    cluster_api_instance = cm_client.ClustersResourceApi(api_client)

    # Lists all known clusters.
    api_response = cluster_api_instance.read_clusters(view='SUMMARY')

    print "List all known clusters"
    for cluster in api_response.items:
        print cluster.name, "-", cluster.full_version
    print

    # Look for cluster versions
        #services = services_api_instance.read_services(cluster.name, view='FULL')
    print "List cluster versions:"

    if cluster.full_version.startswith("7."):
            services_api_instance = cm_client.ServicesResourceApi(api_client)
            services = services_api_instance.read_services("Cluster1", view='FULL')
            for service in services.items:
                print service.display_name, "-", service.type
                if service.type.upper() == 'HDFS':
                    hdfs = service
                    print "========================="
                    print "Service status:"
                    print hdfs.name, hdfs.service_state, hdfs.health_summary
                    print
                    print "Service URL:"
                    print hdfs.service_url
                    print
                    print "Health check:"
                    for health_check in hdfs.health_checks:
                        print health_check.name, "---", health_check.summary
                    print "========================="

if __name__ == "__main__":
    main()
