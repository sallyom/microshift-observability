#!/bin/bash
#
# This script automates the VM configuration steps described in the "MicroShift Development Environment on RHEL 8" document.
# See https://github.com/openshift/microshift/blob/main/docs/devenv_rhel8.md
#
set -eo pipefail

function usage() {
    echo "Usage: $(basename $0) <openshift-pull-secret-file>"
    [ ! -z "$1" ] && echo -e "\nERROR: $1"
    exit 1
}

if [ $# -ne 1 ]; then
    usage "Wrong number of arguments"
fi

OCP_PULL_SECRET=$(realpath $1)
[ ! -f "${OCP_PULL_SECRET}" ] && usage "OpenShift pull secret ${OCP_PULL_SECRET} does not exist or is not a regular file."

if [ "$(whoami)" != "microshift" ] ; then
    echo "This script should be run from 'microshift' user account"
    exit 1
fi

# Check the subscription status and register if necessary
if ! sudo subscription-manager status >& /dev/null ; then
   sudo subscription-manager register
fi

# https://github.com/openshift/microshift/blob/main/docs/devenv_rhel8.md#runtime-prerequisites
sudo tee /etc/yum.repos.d/rhocp-4.12-el8-beta-$(uname -i)-rpms.repo >/dev/null <<EOF
[rhocp-4.12-el8-beta-$(uname -i)-rpms]
name=Beta rhocp-4.12 RPMs for RHEL8
baseurl=https://mirror.openshift.com/pub/openshift-v4/\$basearch/dependencies/rpms/4.12-el8-beta/
enabled=1
gpgcheck=0
skip_if_unavailable=1
EOF

sudo subscription-manager repos \
    --enable fast-datapath-for-rhel-8-$(uname -i)-rpms
#    --enable rhocp-4.12-for-rhel-8-$(uname -i)-rpms \

# Install MicroShift testing package
sudo dnf copr enable -y @redhat-et/microshift-testing
sudo dnf install -y microshift

# https://github.com/openshift/microshift/blob/main/docs/devenv_rhel8.md#configuring-vm
echo -e 'microshift\tALL=(ALL)\tNOPASSWD: ALL' | sudo tee /etc/sudoers.d/microshift
sudo dnf clean all -y
sudo dnf update -y
sudo dnf install -y git kernel-devel cockpit make golang selinux-policy-devel bash-completion \
    conmon conntrack-tools containernetworking-plugins containers-common container-selinux \
    criu jq NetworkManager-ovs python36 
# sudo systemctl enable --now cockpit.socket

# Run MicroShift Executable > Installing Clients
# https://github.com/openshift/microshift/blob/main/docs/devenv_rhel8.md#installing-clients
sudo dnf install -y openshift-clients

sudo cp -f ${OCP_PULL_SECRET} /etc/crio/openshift-pull-secret
sudo chmod 600                /etc/crio/openshift-pull-secret

# Run MicroShift Executable > Configuring MicroShift > Firewalld
# https://github.com/openshift/microshift/blob/main/docs/howto_firewall.md#firewalld
sudo dnf install -y firewalld
sudo systemctl enable firewalld --now
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=169.254.169.1
sudo firewall-cmd --reload

echo ""
echo "The configuration phase completed."
echo "Done"
