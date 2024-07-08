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
    oc get pods -o name | while read p; do
        echo === $p ===
        oc logs $p | grep lost | tail -n 10
    done
 done
