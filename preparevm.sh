#! /bin/bash
# Automatic VM preparation for PE code testing
# This script assumes that you will be working off of the newest PE builds.
# Thus, the tarball source dir should be kept up to date.
# Development packages and scripts must be placed into the staging directory 

# 1) Restore VM to clean state
# 1.5) Prepare root's SSH key
# 2) Prepare /etc/hosts
# 3) Copy the PE tarball to the VM and unpack it
# 4) If a development package(s) is provided, replace the old package
# 5) If a development installer/uninstaller/upgrader are provided, replace the old scripts

# -- VARIABLES -- #
PETARS="/Users/whopper/Packages/pe-packages/vm_staging"
DEVSCRIPTS="/Users/whopper/Packages/vm_staging/scripts"
DEVPKGS="/Users/whopper/Packages/vm_staging/packages"
VMIMGS="/Users/whopper/VMs"
DebianInst="${VMIMGS}/pe-debian6.vmwarevm/pe-debian6.vmx"
Centos6Inst="${VMIMGS}/pe-centos6.vmwarevm/pe-centos6.vmx"
Centos5Inst="${VMIMGS}/pe-centos5.vmwarevm/pe-centos5.vmx"
Sles11Inst="${VMIMGS}/pe-sles11.vmwarevm/pe-sles11.vmx"
LucidInst="${VMIMGS}/pe-ubuntu-lucid.vmwarevm/pe-ubuntu-lucid.vmx"
PreciseInst="/Users/whopper/Ubuntu.vmwarevm/Ubuntu.vmx"
SolarisInst="${VMIMGS}/pe-solaris10.vmwarevm/pe-solaris10.vmx"
HOSTSFILE="/Users/whopper/Packages/pe-packages/vm_staging/HOSTSFILE"
KEYFILE="/Users/whopper/.ssh/id_rsa.pub"
# -- ARGUMENTS -- #
OS=${1}

#       ---       #

if [ -z ${1} ]; then
  echo "Error: Must specify OS"
  exit 1
elif [ ${1} = "debian" ]; then
  TO_USE="${DebianInst}"
  STATE="Debian 6 Clean State"
  VMHOSTNAME="debian"
elif [ ${1} = "el-5" ]; then
  TO_USE=${Centos5Inst}
  STATE="Centos5 Clean State"
  VMHOSTNAME="centos5"
elif [ ${1} = "el-6" ]; then
  TO_USE=${Centos6Inst}
  STATE="Snapshot"
  VMHOSTNAME="centos6"
elif [ ${1} = "sles-11" ]; then
  TO_USE=${Sles11Inst}
  STATE="SLES11-SP2"
  VMHOSTNAME="sles11"
elif [ ${1} = "lucid" ]; then
  TO_USE=${LucidInst}
  STATE="Lucid Clean State"
  VMHOSTNAME="lucid"
elif [ ${1} = "precise" ]; then
  TO_USE=${PreciseInst}
  STATE="Clean Precise"
  VMHOSTNAME="precise"
elif [ ${1} = "solaris" ]; then
  TO_USE=${SolarisInst}
  STATE="Clean solaris"
  HOSTNAME="solaris10"
else
  echo "Error: Unrecognized OS..."
  echo "Options are: debian, lucid, precise, el-5, el-6, sles-11, solaris"
  exit 1
fi

# Restore to clean state
vmrun revertToSnapshot "${TO_USE}" "${STATE}"
vmrun start "${TO_USE}"

if ! ps -elf | grep ssh-agent > /dev/null; then
  eval `ssh-agent` && ssh-add ~/.ssh/id_rsa && exec
fi

# Prepare authorized_keys 
  scp "${KEYFILE}" root@"${VMHOSTNAME}":~root
  ssh root@"${VMHOSTNAME}" 'mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys > /dev/null'
  ssh root@"${VMHOSTNAME}" 'cat ~/id_rsa.pub >> .ssh/authorized_keys'

# Update the VM's /etc/hosts
  scp "${HOSTSFILE}" root@"${VMHOSTNAME}":~root
  ssh root@"${VMHOSTNAME}" 'cat ~/HOSTSFILE >> /etc/hosts'

# Copy latest tarball to the VM and extract it
if [ ${1} != 'lucid' -a ${1} != 'precise' ]; then
  TOCOPY=$(ls ${PETARS} | grep ${1})
else
  if [ ${1} = 'lucid' ]; then
    TOCOPY=$(ls ${PETARS} | grep '10.04')
  else
    TOCOPY=$(ls ${PETARS} | grep '12.04')
  fi
fi

scp "${PETARS}"/"${TOCOPY}" root@"${VMHOSTNAME}":~root
ssh root@"${VMHOSTNAME}" 'tar -zvxf puppet* > /dev/null 2>&1'
ssh root@"${VMHOSTNAME}" 'mkdir ~/tarball && mv *.tar.gz ~/tarball'

# Put dev packages and scripts in place
for each in $(ls ${DEVSCRIPTS}); do
  ssh root@"${VMHOSTNAME}" 'mkdir ~/scripts'
  scp ${DEVSCRIPTS}/${each} root@"${VMHOSTNAME}":~/scripts
  ssh root@"${VMHOSTNAME}" 'mv ~/scripts/* puppet-enterprise*'
done

REGEX=$(ls ${DEVPKGS} | grep -o --regexp='.*_[0-9]')

if [ -n ${REGEX} ]; then
  for each in $(ls ${DEVPKGS}); do
    ssh root@"${VMHOSTNAME}" 'mkdir ~/pkgs'
    scp ${DEVPKGS}/${each} root@"${VMHOSTNAME}":~/pkgs
    ssh root@"${VMHOSTNAME}" 'rm ~/HOSTSFILE ~/id_rsa.pub'
  done
fi
