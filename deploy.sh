#!/bin/bash

set -eux

# Increase log level and convert to routingViaHost: true
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

# Scale nodes to 50
for ms in $(oc get machineset -n openshift-machine-api -o name); do oc scale $ms -n openshift-machine-api --replicas=50; done
for ms in $(oc get machineset -n openshift-machine-api -o name); do echo "Waiting for $ms"; oc wait $ms --timeout=20m --for=jsonpath='{.status.readyReplicas}'=50 -n openshift-machine-api; done

# Start monitoring
oc new-project network-check
oc create serviceaccount network-check
oc adm policy add-scc-to-user privileged -z network-check
oc apply -f role.yaml
oc apply -f ds.yaml
oc expose svc network-check

sleep 60

# Force single-zone
# cat <<'EOF' | oc apply -f -
# apiVersion: v1
# data:
#   zone-mode: singlezone
# kind: ConfigMap
# metadata:
#   name: ovn-interconnect-configuration
#   namespace: openshift-ovn-kubernetes
# EOF
# Force single-zone
# cat <<'EOF' | oc apply -f -
# apiVersion: v1
# data:
#   fast-forward-to-multizone: "true"
# kind: ConfigMap
# metadata:
#   name: ovn-interconnect-configuration
#   namespace: openshift-ovn-kubernetes
# EOF

# Start upgrade
oc patch mcp/worker --type merge --patch '{"spec":{"paused":true}}'
oc adm upgrade channel stable-4.14
sleep 5
# oc adm upgrade --to-latest=true
# oc adm upgrade --to=4.14.31
oc adm upgrade --to=4.14.33
sleep 5
oc -n openshift-config patch cm admin-acks --patch '{"data":{"ack-4.13-kube-1.27-api-removals-in-4.14":"true"}}' --type=merge
