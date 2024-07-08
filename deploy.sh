#!/bin/bash

set -eux

cm_file=$(mktemp)
cat <<EOF > $cm_file
kind: ConfigMap
apiVersion: v1
metadata:
  name: env-overrides
  namespace: openshift-ovn-kubernetes
data:
  _master: |
    # This sets the log level for the ovn-kubernetes master process as well as the ovn-dbchecker:
    OVN_KUBE_LOG_LEVEL=5
EOF
nodes=$(oc get nodes | tail -n+2 | awk '{print $1}')
for node in $nodes; do
  cat <<EOF >> $cm_file
  $node: | 
    OVN_KUBE_LOG_LEVEL=5
EOF
done
oc apply -f $cm_file

oc patch network.operator/cluster --type merge -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"routingViaHost":true}}}}}'
sleep 120
oc rollout status daemonset -n openshift-ovn-kubernetes ovnkube-node
oc rollout status daemonset -n openshift-ovn-kubernetes ovnkube-master

oc new-project network-check
oc create serviceaccount network-check
oc adm policy add-scc-to-user privileged -z network-check
oc apply -f role.yaml
oc apply -f ds.yaml
oc expose svc network-check

sleep 60

oc patch mcp/worker --type merge --patch '{"spec":{"paused":true}}'
oc adm upgrade channel stable-4.14
sleep 5
oc adm upgrade --to-latest=true
sleep 5
oc -n openshift-config patch cm admin-acks --patch '{"data":{"ack-4.13-kube-1.27-api-removals-in-4.14":"true"}}' --type=merge
