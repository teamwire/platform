#!/bin/bash -e

WORKDIR=${0%/*}

PASSWORD=""
BACKEND_RELEASE=""
DOCKERHUB_USERNAME=""
DOCKERHUB_PASSWORD=""
OFFLINE_INSTALLATION=""

help() {
  echo "Build Teamwire Server VMWare VM images"
  echo
  echo "Command line options:"
  echo "  --password <password>            Define the password of the 'teamwire' user (mandantory)"
  echo "  --offline-installation           Prepare an image for offline installation"
  echo "                                   Requires the following three parameters"
  echo "  --backend-release <TAG>          Backend release to integrate into the offline installation VM"
  echo "  --dashboard-release <TAG>        Dashboard release to integrate into the offline installation VM"
  echo "  --dockerhub-username <username>  Docker Hub user name"
  echo "  --dockerhub-password <password>  Docker Hub password"
}

while [[ $# -gt 0 ]] ; do
  case "$1" in
    --help|-h)
      help
      exit
      ;;
    --password)
      PASSWORD="$2"
      shift
      ;;
    --backend-release)
      BACKEND_RELEASE="$2"
      shift
      ;;
    --dashboard-release)
      DASHBOARD_RELEASE="$2"
      shift
      ;;
    --dockerhub-username)
      DOCKERHUB_USERNAME="$2"
      shift
      ;;
    --dockerhub-password)
      DOCKERHUB_PASSWORD="$2"
      shift
      ;;
    --offline-installation)
      OFFLINE_INSTALLATION=true
      ;;
  esac
  shift
done

if [ -z "${PASSWORD}" ] ; then
  echo "Please supply the password for the teamwire user on the command line."
  echo
  help
  exit 1
fi

if [ -n "${OFFLINE_INSTALLATION}" ] && [ -z "${DOCKERHUB_USERNAME}" ] && [ -z "${DOCKERHUB_PASSWORD}" ] ; then
  echo "Please specify Docker Hub credentials for offline installations."
  echo
  help
  exit 1
fi

if [ -n "${OFFLINE_INSTALLATION}" ] && [ -z "${BACKEND_RELEASE}" ] ; then
  echo "Please specify a backend release when packaging for offline installation."
  echo
  help
  exit 1
fi

if [ -n "${OFFLINE_INSTALLATION}" ] && [ -z "${DASHBOARD_RELEASE}" ] ; then
  echo "Please specify a dashboard release when packaging for offline installation."
  echo
  help
  exit 1
fi

if [ -f ../ansible/group_vars/all ] ; then
  echo "Please remove the Ansible config before building!"
  exit 1
fi

# Run packer to create the VM
pushd "${WORKDIR}" > /dev/null
packer build \
  -var "http_directory=." \
  -var "ssh_password=${PASSWORD}" \
  -var "offline_installation=${OFFLINE_INSTALLATION}" \
  -var "dashboard_release=${DASHBOARD_RELEASE}" \
  -var "backend_release=${BACKEND_RELEASE}" \
  -var "dockerhub_password=${DOCKERHUB_PASSWORD}" \
  -var "dockerhub_username=${DOCKERHUB_USERNAME}" \
  -only teamwire-server-vmware \
  "teamwire-server.json"
popd > /dev/null

# Convert the VM and create a compressed archive of the result
pushd "${WORKDIR}"/output-teamwire-server-vmware > /dev/null
ovftool localhost.vmx teamwire-server.ovf
rm disk-s0* disk.vmdk localhost.vmx
# The order of files is significant, see the OVF spec: http://www.dmtf.org/sites/default/files/standards/documents/DSP0243_1.0.0.pdf
tar cfv ../teamwire-server.ova teamwire-server.ovf teamwire-server.mf teamwire-server-disk1.vmdk localhost.nvram localhost.vmsd localhost.vmxf
popd > /dev/null

# Remove build artefacts
rm -rf "${WORKDIR}"/output-teamwire-server-vmware
