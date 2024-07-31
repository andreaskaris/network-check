#!/bin/bash

oc project default

sosreport_location=sosreports
mkdir -p ${sosreport_location}

gather_sosreport() {
    local node=$1
    local f=$(mktemp)
    for i in {1..5}; do
        echo "Gathering sosreport for $n"
        oc debug ${node} -- chroot /host /bin/bash -c "sudo podman rm -f 'toolbox-root' || true; echo y | toolbox sosreport --batch -k crio.all=on -k crio.logs=on  -k podman.all=on -k podman.logs=on --all-logs" 2>&1 | tee ${f}
        if [ $? == 0 ]; then
            break
        else
            echo "Collection attempt $i of sosreport for $node failed"
        fi
    done
    local sos_report_file=$(grep "/host/var/tmp" ${f} | tail -1 | tr -d '\r' | awk '{$1=$1;print}')
    local dst="${sosreport_location}/sosreport.${node/node\//}.$(date +%s).tar.gz"
    for i in {1..5}; do
        echo "Copying file ${sos_report_file} from $n to ${dst}"
        oc debug ${node} -- cat ${sos_report_file} > "${dst}"
        if [ -s "${dst}" ]; then
            break
        else
            echo "Downloading attempt $i of file ${sos_report_file} from $n to ${dst} failed"
        fi
    done
}

for n in $(oc get nodes -o name); do
    gather_sosreport $n &
done
echo "Waiting for all sosreports to finish"
wait
