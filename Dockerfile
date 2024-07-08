FROM registry.fedoraproject.org/fedora
RUN yum install iputils -y
RUN curl -L -O https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.14.31/openshift-client-linux.tar.gz && \
      tar -xzf openshift-client-linux.tar.gz -C /usr/bin/ && \
      rm -v openshift-client-linux.tar.gz
