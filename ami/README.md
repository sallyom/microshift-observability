## Create RHEL4Edge AMI (AWS machine image) from qcow2

Assumes

0. RHEL4Edge machine created similar to [Red Hat Device Edge with MicroShift](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift)
0. For RHEL Device Edge with necessary Performanc CoPilot packages, see [rhde-microshift.toml](./PCP/rhde-microshift.toml)
1. RHEL4Edge machine is currently created & stopped, with a QCOW2 image at /var/lib/libvirt/images/rheledge.qcow2
2. The following roles are created in an AWS account. View trust-policy.json, role-policy.json files in this directory.
3. Access to an s3 bucket in AWS

_image conversion commands heavily borrowed from [rapidsdb.com](https://docs.rapidsdb.com/development/import-qcow2.html)_ 

```bash
aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://role-policy.json
```

### Check image file on system

```bash
qemu-img info /var/lib/libvirt/images/rheledge.qcow2
```

### Convert to raw format and update to s3

```bash
sudo qemu-img convert /var/lib/libvirt/images/rheledge.qcow2 rheledge.raw
aws s3 cp rheledge.raw s3:/yourbucketname
```

### Import snapshot

Update the contents of `container.json` to match your image name

```bash
aws ec2 import-snapshot --description "rheledge.qcow2" --disk-container file://container.json

# check status
aws ec2 describe-import-snapshot-tasks

# if stuck you may want to delete the snapshot
aws ec2 cancel-import-task --import-task-id import-snap-xxxxx
```

You can now create an AMI from the snapshot in the AWS console.
