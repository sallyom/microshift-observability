## Commands to build & serve ostree commit

### assumes running in an environment similar to [this](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift)

```bash
vim rhde-microshift.toml 
sudo su
composer-cli blueprints push ~/rhde-microshift.toml
composer-cli compose start-ostree rhde-microshift rhel-edge-container
composer-cli compose image ca772544-795c-41bf-b819-80b78708d5de
skopeo copy oci-archive:ca772544-795c-41bf-b819-80b78708d5de-container.tar containers-storage:localhost/rhde-microshift:latest
podman run --name edge-stage --rm -d -p 8000:8080 localhost/rhde-microshift:latest
exit
```

## In edge device

```bash
sudo su
# if necessary, update /etc/ostree/remotes.d/edge.conf
rpm-ostree upgrade --check
rpm-ostree upgrade
exit
```

