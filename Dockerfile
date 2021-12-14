# The purpose of this file is to serve as a quick remediation of the elasticsearch image
# used by terra to remediate the log4j vulnerability discovered 12/21. The jenkins job that is 
# supposed to build this image has not succeeded or run since 2021. Adding this docker file
# as a quick fix just so the updated image is reproducible.

FROM docker.io/broadinstitute/elasticsearch:5.4.0_6

USER root
RUN yum -y install zip && \
    zip -q -d lib/log4j-core-*.jar \
      org/apache/logging/log4j/core/lookup/JndiLookup.class

USER elasticsearch
