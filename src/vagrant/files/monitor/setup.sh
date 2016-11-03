#!/bin/bash

curl -u admin:admin -H 'Content-Type: application/xml' -d @OpenNMS-Requisition.xml http://192.168.205.150:8980/opennms/rest/requisitions   2>/dev/null
curl -u admin:admin -H 'Content-Type: application/xml' -d @OpenNMS-Definition.xml  http://192.168.205.150:8980/opennms/rest/foreignSources 2>/dev/null
curl -u admin:admin -X PUT http://192.168.205.150:8980/opennms/rest/requisitions/OpenNMS/import 2>/dev/null

