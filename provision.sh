#!/bin/bash

. functions.sh

validate_config count "the number of instances to create"
validate_config AMI "the AWS AMI image id to use, default is $AMI"
validate_config KEYNAME "the AWS keyname used to provision instances, default $KEYNAME"
validate_config SECGROUP "the AWS security group, default $SECGROUP"
validate_config SUBNET "the AWS subnet, default $SUBNET"
optional_config add_drive "if 'yes' will add a second block device"
optional_config add_public_ip "if 'yes' will associate a public IP"
optional_config runname "if provided will override default runname"
optional_config purpose "used in instance name, default is 'inst'"

# generate an ignore list
ignore=$(aws ec2 describe-instances | grep InstanceId | awk '{print $2}' | cut -d '"' -f2)

options="--image-id $AMI --key-name $KEYNAME 
   --security-group-ids $SECGROUP --instance-type m4.large 
   --subnet-id $SUBNET --ebs-optimized 
   --count $count"

pubip=
if [[ "$add_public_ip" == "yes" ]]; then
   pubip="--associate-public-ip-address"
fi

blkdev=
if [[ "$add_drive" == "yes" ]]; then
   blkdev="--block-device-mappings '[{\"DeviceName\":\"/dev/sdh\",\"Ebs\":{\"DeleteOnTermination\":\"true\",\"VolumeSize\":20,\"VolumeType\":\"gp2\"}}]' "
fi

if [[ "$runname" == "" ]]; then
   tag=$(date +"%Y%d%m-%H%M")
else
   tag="$runname"
fi

if [[ "$purpose" == "" ]]; then
   purpose="inst"
fi

echo "*** Provisioning Instances.........
using the following command:
aws ec2 run-instances $options $pubip $blkdev

once the instances have been requested, they will be tagged:
- Name=$purpose-<number>
- RunName=$tag
"
read -p "Press a key to continue, or CTRL-C to abort"

aws ec2 run-instances $options $pubip $blkdev

id=1

echo "--------------------------

"
echo "INSTANCE NAME,INSTANCE TAG"
# dump out a new list of instances creating using the above start command
aws ec2 describe-instances | grep InstanceId | awk '{print $2}' | cut -d '"' -f2 | while read instanceID
do

   if [[ ${ignore} != *"${instanceID}"* ]]; then

      echo "${instanceID},${tag}"  
      aws ec2 create-tags --resources ${instanceID} --tags Key=Name,Value="${purpose}-${id}" Key=RunName,Value="${tag}" > /dev/null
      id=$((id+1))

   fi 

done


