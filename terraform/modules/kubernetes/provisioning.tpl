#!/bin/bash +x
exec > >(tee -i /var/log/ansible-bootstrap.log)

SCRIPT=$(readlink -f $0)
echo "Running bootstrap script from here $SCRIPT"
cp $SCRIPT /tmp/bootstrap.sh

# TODO: Propagate as a variable
ANSIBLE_TAG=0.1.4



## Metadata Discovery :
export METADATA_VARS="$(curl  -H "Accept: application/json" -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/?recursive=true")"

###echo  "sslverify=0" >> /etc/yum.conf
# Deprecated proxied approach in favor of internal repos

mkdir /opt/ansible
cd /opt/ansible

# The beauty of using public resources is that we can download the artifact straight from github

yum install -y unzip
unzip adtech-ansible-$LATEST_ARTIFACT_STR.zip
cd ansible

# Deprecated proxied approach in favor of internal repos
# if [ -n "$MY_PROXY" ] ; then
#     export http_proxy=$MY_PROXY
#     export https_proxy=$MY_PROXY
# fi

yum install -y ansible jq

ansible-playbook -i $(hostname),  --connection=local -v roles/gcp-repos.yml

# Deprecated proxied approach in favor of internal repos
# After GCP repos are deployed, we don't need a proxy anymore :
# sed 's/proxy=.*//g' -i /etc/yum.conf
# export http_proxy=""
# export https_proxy=""

yum makecache -y

echo $METADATA_VARS > /tmp/metadata.json
export PROFILE="$(cat /tmp/metadata.json | jq -r .profile)"

echo "RUNNING PROFILE $PROFILE"
ansible-playbook -i $(hostname), --extra-vars @/tmp/metadata.json --connection=local -v roles/$PROFILE.yml

