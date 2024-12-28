#!/bin/bash

docker compose up -d wait_for_elasticsearch

docker compose logs -f wait_for_elasticsearch

export SERVICE_TOKEN=$(docker exec -it elasticsearch bin/elasticsearch-service-tokens create elastic/kibana kibana-token | grep SERVICE_TOKEN | awk '{print $NF}' | tr -d '\r' | tr -d '\n')

echo "${SERVICE_TOKEN}"

docker compose up -d logstash

LOOP=true

echo "Waiting for logstash to process input data..."

while ${LOOP}; do
    STATUS=$(docker compose exec -it logstash curl -XGET 'localhost:9600/_node/stats/events?pretty' 2> /dev/null)

    IN=$(echo ${STATUS} | grep -o "\"in\" : [0-9]*" | awk '{print $NF}')
    OUT=$(echo ${STATUS} | grep -o "\"out\" : [0-9]*" | awk '{print $NF}')

    if [ ! -z ${IN} ] && [ ${IN} -gt 0 ] && [ ${IN} -eq ${OUT} ]; then
        LOOP=false
    fi
    sleep 1
done

echo "DONE"

docker compose down logstash

docker compose up -d wait_for_kibana

docker compose logs -f wait_for_kibana

curl -X POST localhost:5601/api/saved_objects/_import?createNewCopies=true -H "kbn-xsrf: true" --user elastic:elastic --form file=@bunny.ndjson
