## Commands to build & serve ostree commit

### assumes running in an environment similar to [this](../rheledge-imagebuilder/README.md)

SSH into the **ostree builder machine** (updates will be served from this machine)

```bash
vim rhde.toml 
# edit the blueprint toml to add or modify as necessary

composer-cli blueprints push rhde.toml
composer-cli compose start-ostree rhde rhel-edge-container
composer-cli compose status # wait until status is FINISHED

# from the output above, find the container id as it is here ca772544...
composer-cli compose image ca772544-795c-41bf-b819-80b78708d5de

# might need to run `podman system migrate` if the following command fails with `not enough uid...something like that`
skopeo copy oci-archive:ca772544-795c-41bf-b819-80b78708d5de-container.tar containers-storage:localhost/rhde:latest

podman run --name edge-stage --rm -d -p 8000:8080 localhost/rhde:latest
# confirm that http://ipaddress:8000/repo/refs/heads/rhel/9/x86_64/edge is serving a new commit
# this must be running in order for the edge device to upgrade
```

## Trigger upgrade in edge device

Refer to the
[RHEL9 documentation for composing rhel edge images](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/composing_installing_and_managing_rhel_for_edge_images/managing-rhel-for-edge-images_composing-installing-managing-rhel-for-edge-images) for more information about setting up
ostree repositories. The below workflow is an example.

### Pull initial remotes

This step must be completed whenever a new remote ostree commit server is added.

Run as the root user.
Confirm the URL for the edge server is set correctly. This might have been configured in the kickstart.

```bash
cat /etc/ostree/remotes.d/edge.conf
[remote "edge"]
url=ip-address-of-builder-vm:8000/repo/
gpg-verify=false
```

```bash
ostree remote show-url edge
```

If the above command fails with the below message,
this means the new repository must be added. 

```
Error: Remote refs not available; server has no summary file
```

To add the repository

```bash
ostree remote add --no-gpg-verify edge http://ip-address-of-builder:8000/repo/
ostree remote show-url edge # confirm the correct url is returned
ostree remote list # confirm the new remote has been added
```

Rebase the system to the new RHEL ostree commit server

```bash
rpm-ostree rebase edge:rhel/9/x86_64/edge
```

With subsequent updates, the following commands will pick up new commits, provided they are currently being served.

```bash
rpm-ostree upgrade --check
rpm-ostree upgrade
```
Reboot into the new ostree commit.

Confirm the currently running deployment

```bash
sudo rpm-ostree status
```
