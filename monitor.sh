#!/bin/bash

while true; do
    sleep 1
    echo ====================
    date
    echo ====================
    oc get clusterversion
    oc get nodes
    oc get pods -o wide
    oc get pods -n openshift-ovn-kubernetes -o wide
    for p in $(oc get pods -o name); do
        bash -c "oc logs $p | grep lost | tail -10 | while read l; do echo \"$p: \$l\"; done" &
        read -t 0.1
    done
    wait
 done
