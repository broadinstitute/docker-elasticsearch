FROM elasticsearch:2.4
RUN /usr/share/elasticsearch/bin/plugin install --batch cloud-gce
LABEL JAVA_VERSION=8u102
LABEL ELASTICSEARCH_VERSION=2.4.0
