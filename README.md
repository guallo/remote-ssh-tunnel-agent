# remote-ssh-tunnel-agent

## Installation

### Manual

1.  Create the user that will run the *agent service*:

```bash
sudo useradd --system --create-home --user-group --shell "$(which nologin)" rssht-agent
```

2.  Change to user `rssht-agent` and its `HOME` directory:

```bash
sudo -H -u rssht-agent bash
cd
```

3.  Generate the public/private rsa key pair the *agent* will use to connect to the *intermediate SSH server*, replace `<AGENT-ID>` accordingly:

```bash
ssh-keygen -C "<AGENT-ID>" -N "" -f ".ssh/id_rsa"
```

4.  Copy the public key to the *intermediate SSH server*, replace `<SSH-USER>`, `<SSH-SERVER>` and `<SSH-PORT>` accordingly (see [the configuration of the intermediate SSH server](#manual-1)):

```bash
ssh-copy-id -i ".ssh/id_rsa.pub" <SSH-USER>@<SSH-SERVER> -p <SSH-PORT>
```

5.  Download and change to the source code directory:

```bash
git clone https://github.com/guallo/remote-ssh-tunnel-agent.git
cd remote-ssh-tunnel-agent
```

6.  Configure the *agent* with the corresponding `<OPTION>`'s (see [the configuration of the intermediate SSH server](#manual-1)):

```bash
sed -i 's/^\(SSH_USER=\).*$/\1<SSH-USER>/' rssht-agent.sh
sed -i 's/^\(SSH_SERVER=\).*$/\1<SSH-SERVER>/' rssht-agent.sh
sed -i 's/^\(SSH_PORT=\).*$/\1<SSH-PORT>/' rssht-agent.sh
sed -i 's!^\(SWAP_DIRECTORY=\).*$!\1"<SWAP-DIRECTORY>"!' rssht-agent.sh
```

7.  Give execution permission to the *agent*'s user:

```bash
chmod u+x rssht-agent.sh
```

8.  Come back to original user and directory:

```bash
exit
```

9.  Install, enable and start the *systemd unit*:

```bash
sudo cp /home/rssht-agent/remote-ssh-tunnel-agent/rssht-agent.service /lib/systemd/system/
sudo systemctl enable rssht-agent.service
sudo systemctl start rssht-agent.service
```

## Installation upgrade

### Manually

**NOTICE:** This method currently do not deploy (if upgraded) the *systemd unit* file [`rssht-agent.service`](https://github.com/guallo/remote-ssh-tunnel-agent/blob/master/rssht-agent.service).

1.  Change to the *agent*'s user and installation directory:

```bash
sudo -H -u rssht-agent bash
cd $HOME/remote-ssh-tunnel-agent
```

2.  Configure temporary identification:

```bash
git config user.name temp
git config user.email temp
```

3.  Temporarily save the local changes:

```bash
git add -A
git commit -m 'temp'
```

4.  Apply last remote changes:

```bash
git pull --rebase
```

5.  Resolve any conflicts (if any) that could arise from previous step.

6.  Restore the local changes:

```bash
git reset HEAD~1
chmod u+x rssht-agent.sh
```

7.  Discard temporary identification:

```bash
git config --unset user.name
git config --unset user.email
```

8.  Come back to original user and directory:

```bash
exit
```

9.  Restart the *agent service*:

```bash
sudo systemctl restart rssht-agent.service
```

# Intermediate SSH Server

## Configuration

### Manual

1.  Create the `<SSH-USER>` that the *agents* will use to fetch commands from and notify status to the `<SSH-SERVER>`:

```bash
sudo useradd --create-home --home-dir /home/rssht-server --shell /bin/bash rssht-server
```

2.  Assign **A VERY STRONG** password to the `<SSH-USER>`:

```bash
sudo passwd rssht-server
```

3.  It is convenient to set the `<SSH-PORT>` to `443` (commonly used for the *https* protocol) to avoid as much as possible the *agents* get blocked by their *ISP*'s. To do that configure `Port 443` into the `/etc/ssh/sshd_config` file.

4.  Override the following settings for the `<SSH-USER>` and restart the *ssh* service:

```bash
sudo tee -a /etc/ssh/sshd_config >/dev/null <<EOF

Match User rssht-server
    PasswordAuthentication yes
    PubkeyAuthentication yes
    AllowTcpForwarding yes
    GatewayPorts yes
EOF

sudo systemctl restart sshd
```

5.  Create the `<SWAP-DIRECTORY>` used by the *agents* to fetch commands from the `<SWAP-DIRECTORY>/<AGENT-ID>.in` file and notify status to the `<SWAP-DIRECTORY>/<AGENT-ID>.out` file:

```bash
sudo -H -u rssht-server bash -c 'mkdir /home/rssht-server/rssht-swap-dir'
```

6.  Protect the `<SWAP-DIRECTORY>`:

```bash
sudo chmod 700 /home/rssht-server/rssht-swap-dir
```

## Monitor

To watch *sshd*'s processes tree every second:

```bash
watch -n 1.0 "pstree -acglnp $(ps -C sshd -o pid,cmd --no-headers | grep /usr/sbin/sshd | grep -Po '\d+' | head -n 1)"
```
