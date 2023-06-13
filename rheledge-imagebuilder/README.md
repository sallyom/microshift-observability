## Create RH Device Edge ISO Builder and Server using OSBuild

[OSBuild](https://www.osbuild.org/guides/introduction.html) is comprised of many individual projects which work together
to provide a wide range of features to build and assemble OS artifacts.
The GUI for OSBuild is known as `Image Builder` and provides access to the osbuild machinery. 

This documemt describes how to create a RH Device Edge ISO builder and server, to enable over the air updates for your RH Device Edge machines.
For detailed information about building a Device Edge ISO, refer to the excellent post by Ben Schmaus,
[Red Hat Device Edge with MicroShift](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift). 
The steps from that post are condensed here and also updated to use RHEL 9.2 instead of RHEL 8.7.

### Step 0: Launch a RHEL 9 system to use an an Edge ISO Builder

This assumes you have a Red Hat customer account.
With [RH ImageBuilder](https://console.redhat.com/insights/image-builder) you can create RHEL 9.2 (.iso) images for Bare Metal installs
or various cloud vendors. For this, I created an AWS RHEL 9.2 AMI. This image will be associated with the Amazon account you provide to Image Builder.
I then went to AWS console and launched a `RHEL 9.2 t3.xlarge` instance using this AMI, although there is also an option to launch this AMI directly
from the RH Hybrid Cloud Console Image Builder.

*The rest of this document assumes you have a `RHEL 9.2` machine running somewhere and you are SSH'd into this machine.*

#### Register system if necessary

```bash
sudo subscription-manager register
# enter RH credentials
```

#### Enable MicroShift repositories if embedding MicroShift into RH Device Edge

Enable the MicroShift repositories, if you plan on running MicroShift on Device Edge. This is not a requirement. Depending on your edge workloads
you might choose to run podman containers, RPMs, or MicroShift. If not running Kubernetes based deployments, you might skip this step.

```bash
sudo subscription-manager repos \
    --enable rhocp-4.13-for-rhel-9-$(uname -i)-rpms \
    --enable fast-datapath-for-rhel-9-$(uname -i)-rpms
```

#### Prerequisites

Install packages required for ISO building and enable osbuild-composer service.

```bash
sudo dnf -y install createrepo yum-utils lorax skopeo composer-cli cockpit-composer podman genisoimage syslinux isomd5sum
sudo systemctl enable --now cockpit.socket
sudo systemctl enable --now osbuild-composer.socket
```

### Sync DNF packages from OpenShift repositories to local filesystem/local repository

If not installing MicroShift at the edge, you may skip this step.

```bash
sudo mkdir -p /var/repos/microshift-local
sudo reposync --arch=$(uname -i) --arch=noarch --gpgcheck --download-path /var/repos/microshift-local --repo=rhocp-4.12-for-rhel-8-x86_64-rpms --repo=fast-datapath-for-rhel-8-x86_64-rpms

# Remove CoreOS packages that might cause conflicts
sudo find /var/repos/microshift-local -name \*coreos\* -print -exec rm -f {} \;
sudo createrepo /var/repos/microshift-local
```

#### Add user to weldr group to run non-root composer-cli

```bash
sudo usermod -a -G weldr your-user
sudo systemctl restart osbuild-composer
```

#### Add a source for composer-cli from the created repository

If not installing MicroShift at the edge, you may skip this step.

```
sudo curl -o /var/repos/microshift-local/microshift.toml https://raw.githubusercontent.com/sallyom/microshift-observability/main/rheledge-imagebuilder/microshift.toml
composer-cli sources add /var/repos/microshift-local/microshift.toml
```

With `$ composer-cli sources list` you should now see the following:

```bash
appstream
baseos
microshift-local # if installing MicroShift
```

### Create a blueprint and push to `osbuild-composer`

The tool used by OSBuild, `osbuild-composer`, allows customizations for the images it builds. These customizations are defined in a blueprint file in
[TOML format](https://toml.io/en/). For more information,
refer to the [OSBuild blueprint reference](https://www.osbuild.org/guides/blueprint-reference/blueprint-reference.html).

You will update this blueprint file whenever you wish to add, remove, or update packages or configurations on your edge devices. 

#### Create a blueprint file that lists packages to include in the RH Device Edge image

```bash
curl -o ~/rhde.toml https://raw.githubusercontent.com/sallyom/microshift-observability/main/rheledge-imagebuilder/rhde.toml
```

Open `~/rhde.toml` and add whatever is required on your edge devices. The example downloaded above assumes MicroShift will be installed, as well as
Performance Co-Pilot rpms for system monitoring.

Now use `composer-cli` to push the blueprint to `osbuild-composer`

```bash
composer-cli blueprints push ~/rhde.toml
```

### Compose RH Device Edge image

`composer-cli compose` will use the `rhde` blueprint and will build a `rhel-edge-container`.
The `composer-cli compose` command that creates the build container can take several minutes depending on the system it runs on.
After the container is composed, an _image (.tar file)_ will be downloaded from that container, copied to local container-storage using `skopeo`,
and finally `podman` will be used to generate the ISO.

#### compose a build container

```bash
composer-cli compose start-ostree rhde rhel-edge-container
```

You can watch the progress with the status command. Wait until the compose is finished to move on.

```bash
composer-cli compose status
ID                                     Status     Time                       Blueprint         Version   Type               Size
6993c01c-ea04-4347-8f2a-35a35443799c   FINISHED   Mon Jun 12 21:34:59 2023   rhde              1.0.0     edge-container
```

#### compose a local image

After the rhel-edge-container is created (~20 minutes), create a local image using `composer-cli` and `skopeo`

First, create the .tar file

```bash
composer-cli compose image 6993c01c-ea04-4347-8f2a-35a35443799c
6993c01c-ea04-4347-8f2a-35a35443799c-container.tar
```

Next, copy the image to local container storage

```bash
# may need to run `podman system migrate`
skopeo copy oci-archive:6993c01c-ea04-4347-8f2a-35a35443799c-container.tar containers-storage:localhost/rhde:latest
```

Confirm that you now have a rhde image in local storage

```bash
podman images
REPOSITORY      TAG         IMAGE ID      CREATED        SIZE
localhost/rhde  latest      06ca183f790d  7 minutes ago  1.44 GB
```

#### Run the image in order to extract its contents for the ISO

```bash
podman run --rm -p 8000:8080 rhde &

podman ps  # check that container is running
CONTAINER ID  IMAGE                  COMMAND               CREATED         STATUS         PORTS                   NAMES
ba8f7fbaace3  localhost/rhde:latest  nginx -c /etc/ngi...  31 minutes ago  Up 31 minutes  0.0.0.0:8000->8080/tcp  beautiful_margulis
```

### Create ISO for Red Hat Device Edge

This section creates the file structure necessary to hold the artifacts for a zero touch RH Device Edge bootable iso image.
The steps here have been copied from [Ben Schmaus's excellent post](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift).

```bash
mkdir -p ~/generate-iso/ostree
podman cp ba8f7fbaace3:/usr/share/nginx/html/repo ~/generate-iso/ostree
podman stop ba8f7fbaace3

# check that the following structure now exists
ls -al ~/generate-iso/ostree/repo
total 16
drwxr-xr-x.   7 root     root      102 Jun 12 21:32 .
drwxr-xr-x.   3 ec2-user ec2-user   18 Jun 13 13:37 ..
-rw-r--r--.   1 root     root       38 Jun 12 21:32 config
drwxr-xr-x.   2 root     root        6 Jun 12 21:32 extensions
-rw-r-----.   1 root     root        0 Jun 12 21:32 .lock
drwxr-xr-x. 258 root     root     8192 Jun 12 21:32 objects
drwxr-xr-x.   5 root     root       49 Jun 12 21:32 refs
drwxr-xr-x.   2 root     root        6 Jun 12 21:32 state
drwxr-xr-x.   3 root     root       19 Jun 12 21:32 tmp
```

A few additional files are necessary in `~/generate-iso` to reference a custom kickstart and boot screen.

#### Download `isolinux.cfg` and `grub.cfg`

```bash
sudo curl -o ~/generate-iso/isolinux.cfg https://raw.githubusercontent.com/sallyom/microshift-observability/main/rheledge-imagebuilder/isolinux.cfg
sudo curl -o ~/generate-iso/grub.cfg https://raw.githubusercontent.com/sallyom/microshift-observability/main/rheledge-imagebuilder/grub.cfg
```

#### Create a kickstart file

[Ben Schmaus's post, RH Device Edge with MicroShift,](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift) provides a complete
explanation for items in the example [ks.cfg](./ks.cfg).
If running MicroShift, a pull secret for downloading MicroShift images is necessary, a place holder is in the example ks.cfg.
You can download a pull secret from the [Red Hat console](https://console.redhat.com/openshift/downloads#tool-pull-secret).
Here's a summary:

1. Defines the ostreesetup to consume the image that will be built into the iso image
2. Updates /etc/ostree/remotes.d/edge.conf to point to a remote locations for ostree updates
3. Enables the MicroShift firewall rules needed for access (edit these out if not running MicroShift)
4. Defines a pull-secret for MicroShift images (edit this out if not running MicroShift)
5. Sets a volume group for partitions that will also be used with MicroShift

#### Download a RHEL 9.2 boot iso from the RH Developer console

You'll need to exit out of the builder VM for this.
Download to your local system from the console [here](https://developers.redhat.com/products/rhel/download)
Then, use `scp` to copy this boot iso to the builder VM:

```bash
scp -i ~/.ssh/your.pem ~/Downloads/rhel-9.2-x86_64-dvd.iso you@builder-vm-ip-address:/home/your-vm-user/generate-iso
```

#### Download the `recook.sh` script

SSH back into the builder VM where you'll build the Device Edge iso.
[This script](./recook.sh) is copied from
[Ben Schmaus's RH Device Edge with MicroShift blog](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift).
Copy this to the `~/generate-iso` directory.

```bash
curl -o ~/generate-iso/recook.sh https://raw.githubusercontent.com/sallyom/microshift-observability/main/rheledge-imagebuilder/recook.sh
chmod 755 ~/generate-iso/recook.sh
```

#### Run the script!

First, `cd` into `~/generate-iso` directory and ensure you have the necessary files

```bash
cd ~/generate-iso
ls -al
total 885784
drwxr-xr-x. 3 ec2-user ec2-user       119 Jun 13 14:50 .
drwx------. 7 ec2-user ec2-user      4096 Jun 13 14:46 ..
-rw-r--r--. 1 ec2-user ec2-user      1520 Jun 13 14:06 grub.cfg
-rw-r--r--. 1 ec2-user ec2-user      3258 Jun 13 14:05 isolinux.cfg
-rw-r--r--. 1 ec2-user ec2-user      4722 Jun 13 14:08 ks.cfg
drwxr-xr-x. 3 ec2-user ec2-user        18 Jun 13 13:37 ostree
-rwxr-xr-x. 1 ec2-user ec2-user      1267 Jun 13 14:46 recook.sh
-rw-r--r--. 1 ec2-user ec2-user 907018240 Jun 13 14:50 rhel-9.2-x86_64-boot.iso
```

Now, run the `recook.sh` with `sudo`

```bash
sudo ./recook.sh
```

If all goes well, you should now have a `~/generate-iso/rhde-ztp.iso` 

Here's the final command to copy this over to your local system.

```bash
scp -i ~/.ssh/your.pem build-vm-user@build-vm-ipaddress:/home/your-build-machine-user/generate-iso/rhde-ztp.iso ~/Downloads

ls ~/Downloads/rhde-ztp.iso
-rw-r--r--. 1 somalley somalley 2314207232 Jun 13 11:46 /home/somalley/Downloads/rhde-ztp.iso
```

You can write this iso to a usb drive to boot your physical edge device or use it to create a virtual machine.
If you wish to create a virtual machine with a local hypervisor [watch this brief tutorial](https://youtu.be/1gTEpBuZV4o).
With the example kickstart file from this repository, a user is created in the VM `username: redhat, password: redhat`. 

From a virtual machine's `*.qcow2` file, you can follow the [AMI documentation](../ami/README.md) to create an Amazon Machine Image that can be
used to launch a RH Device Edge instance for testing in AWS.


### Serve RH Device Edge update commits and update edge machine

To point your edge devices to the builder, you can edit the remotes configuration file at `/etc/ostree/remotes.d/edge.conf`

```bash
cat /etc/ostree/remotes.d/rhel.conf

[remote "rhel"]
url=file:///run/install/repo/ostree/repo
gpg-verify=false

[remote "edge"]
gpg-verify=false
url=http://ip-address-of-build-machine:8000/repo
```

Whenever it is necessary to update your edge devices, you can point them to your Device Edge builder where you can serve ostree commits by
following [this workflow](../rpm-ostree-update/update.md).

