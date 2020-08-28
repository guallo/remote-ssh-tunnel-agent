# remote-ssh-tunnel-agent

## Installation

### Manual

1.  Create the user that will run the *agent service*:

    ```bash
    sudo adduser --system --group rssht-agent
    ```

2.  Generate the public/private rsa key pair the *agent* will use to connect to the *intermediate SSH server*, replace `<AGENT-ID>` accordingly:

    ```bash
    sudo -H -u rssht-agent bash -c 'ssh-keygen -C "<AGENT-ID>" -N "" -f "$HOME/.ssh/id_rsa"'
    ```

3.  Copy the public key to the *intermediate SSH server*, replace `<INTERMEDIATE-SSH-USER>`, `<INTERMEDIATE-SSH-SERVER>` and `<INTERMEDIATE-SSH-PORT>` accordingly (see [the configuration of the intermediate SSH server](#manual-1)):

    ```bash
    sudo -H -u rssht-agent bash -c 'ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" <INTERMEDIATE-SSH-USER>@<INTERMEDIATE-SSH-SERVER> -p <INTERMEDIATE-SSH-PORT>'
    ```

4.  Download the source code:

    ```bash
    cd /opt
    sudo git clone https://github.com/guallo/remote-ssh-tunnel-agent.git
    cd remote-ssh-tunnel-agent
    ```

5.  Configure the *agent* with the corresponding `<INTERMEDIATE-OPTION>`'s (see [the configuration of the intermediate SSH server](#manual-1)):

    ```bash
    sudo sed -i 's/^\(SSH_USER=\).*$/\1<INTERMEDIATE-SSH-USER>/' rssht-agent.sh
    sudo sed -i 's/^\(SSH_SERVER=\).*$/\1<INTERMEDIATE-SSH-SERVER>/' rssht-agent.sh
    sudo sed -i 's/^\(SSH_PORT=\).*$/\1<INTERMEDIATE-SSH-PORT>/' rssht-agent.sh
    sudo sed -i 's!^\(SWAP_DIRECTORY=\).*$!\1"<INTERMEDIATE-SWAP-DIRECTORY>"!' rssht-agent.sh
    ```

6.  Give execution permission to the *agent*'s group:

    ```bash
    sudo chown :rssht-agent rssht-agent.sh
    sudo chmod g+x rssht-agent.sh
    ```

7.  Install, enable and start the *systemd unit*:

    ```bash
    sudo cp rssht-agent.service /lib/systemd/system/
    sudo systemctl enable rssht-agent.service
    sudo systemctl start rssht-agent.service
    ```

## Installation upgrade

### Manually

**NOTICE:** This method currently do not deploy (if upgraded) the *systemd unit* file [`rssht-agent.service`](https://github.com/guallo/remote-ssh-tunnel-agent/blob/master/rssht-agent.service).

1.  Change to the installation directory:

```bash
cd /opt/remote-ssh-tunnel-agent
```

2.  Configure temporary identification:

```bash
sudo git config user.name temp
sudo git config user.email temp
```

3.  Temporarily save the local changes:

```bash
sudo git add -A
sudo git commit -m 'temp'
```

4.  Apply last remote changes:

```bash
sudo git pull --rebase
```

5.  Resolve any conflicts (if any) that could arise from previous step.

6.  Restore the local changes:

```bash
sudo git reset HEAD~1
sudo chown :rssht-agent rssht-agent.sh
sudo chmod g+x rssht-agent.sh
```

7.  Discard temporary identification:

```bash
sudo git config --unset user.name
sudo git config --unset user.email
```

8.  Restart the *agent service*:

```bash
sudo systemctl restart rssht-agent.service
```

# Intermediate SSH Server

## Configuration

### Manual

1.  Create the `<INTERMEDIATE-SSH-USER>` that the *agents* will use to fetch commands from and notify status to the `<INTERMEDIATE-SSH-SERVER>`, **IT IS WORTH TO METION THE IMPORTANCE OF ASSIGNING A VERY STRONG PASSWORD TO THIS USER**:

    ```bash
    sudo adduser --home /home/rssht-server --shell /bin/bash rssht-server
    ```

2.  It is convenient to set the `<INTERMEDIATE-SSH-PORT>` to `443` (commonly used for the *https* protocol) to avoid as much as possible the *agents* get blocked by their *ISP*'s. To do that configure `Port 443` into the `/etc/ssh/sshd_config` file.

3.  Override the following settings for the `<INTERMEDIATE-SSH-USER>` and restart the *ssh* service:

    ```bash
    sudo bash -c 'echo "
    Match User rssht-server
        PasswordAuthentication yes
        PubkeyAuthentication yes
        AllowTcpForwarding yes
        GatewayPorts yes
    " >> /etc/ssh/sshd_config'
    sudo systemctl restart ssh
    ```

4.  Create the `<INTERMEDIATE-SWAP-DIRECTORY>` used by the *agents* to fetch commands from the `<INTERMEDIATE-SWAP-DIRECTORY>/<AGENT-ID>.in` file and notify status to the `<INTERMEDIATE-SWAP-DIRECTORY>/<AGENT-ID>.out` file:

    ```bash
    sudo -H -u rssht-server bash -c 'mkdir /home/rssht-server/rssht-swap-dir'
    ```

5.  Protect the `<INTERMEDIATE-SWAP-DIRECTORY>`:

    ```bash
    sudo chmod 700 /home/rssht-server/rssht-swap-dir
    ```

## Monitor

To watch *sshd*'s processes tree every second:

```bash
watch -n 1.0 "pstree -acglnp $(ps -C sshd -o pid,cmd --no-headers | grep /usr/sbin/sshd | grep -Po '\d+' | head -n 1)"
```
