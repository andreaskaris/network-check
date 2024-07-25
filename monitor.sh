#!/bin/bash

#stty -echoctl # hide ^C
#
#exit_trap() {
#    echo ""
#    echo ""
#    echo ====================
#    echo "Overview:"
#    echo ====================
#    oc logs -n openshift-network-operator -l name=network-operator --tail=-1 --timestamps=true | grep -i interconnect
#    for p in $(oc get pods -o name); do
#        bash -c "oc logs $p --timestamps=true | grep lost | while read l; do echo \"$p: \$l\"; done" &
#        read -t 0.1
#    done
#    wait
#    exit 0
#}

ovnk_inspect() {
    mkdir -p ovnk-inspects
    while true; do
        oc adm inspect ns/openshift-ovn-kubernetes --dest-dir=ovnk-inspects/$(date +%Y%m%d%H%M) --since=5m
        sleep 120
    done
}

# trap 'exit_trap' SIGINT

echo ====================
echo "Running ovnk inspects every 3 minutes and storing them in ovnk-inspects"
echo ====================
ovnk_inspect &

echo ====================
echo "Monitoring components in a loop"
echo ====================
echo
echo
echo

while true; do
    sleep 1
    echo ====================
    date
    echo ====================
    oc get clusterversion
    oc get co | grep -E "PROGRESSING|network"
    oc get nodes
    oc get pods -o wide
    oc get pods -n openshift-ovn-kubernetes -o wide
    oc get cm -n openshift-ovn-kubernetes ovn-interconnect-configuration -o yaml
    oc logs -n openshift-network-operator -l name=network-operator --tail=-1 --since=60s --timestamps=true | grep -i interconnect
    pids=""
    for p in $(oc get pods -o name); do
        # bash -c "oc logs $p | tail -10 | while read l; do echo \"$p: \$l\"; done" &
        bash -c "oc logs $p --since=60s --timestamps=true | grep lost | while read l; do echo \"$p: \$l\"; done" &
        pid=$!
        pids="${pids} ${pid}"
        read -t 0.1
    done
    wait ${pids}
 done
