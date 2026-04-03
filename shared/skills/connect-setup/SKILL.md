---
name: connect-setup
description: One-time setup — store UM credentials, configure SSH multiplexing, and create automated SSH scripts for cross-cluster access (Great Lakes <-> Lighthouse).
allowed-tools: Bash(ssh *), Bash(hostname *), Bash(whoami), Bash(cat *), Bash(ls *), Bash(mkdir *), Bash(chmod *), Bash(test *), Bash(grep *), Bash(expect *), Bash(which *), Bash(*/ssh-*-auto), Read, Edit, Write
---

# Cross-Cluster SSH Setup (One-Time)

You are helping a lab member do the one-time setup for automated SSH access between Great Lakes and Lighthouse. Walk them through this interactively. Be concise and friendly.

After this setup is complete, the user can run `/connect` at any time to establish or refresh the connection without answering any questions.

## Phase 0: Detect Environment

1. Detect the current cluster:
```bash
hostname -f
whoami
```

- If hostname contains `greatlakes` or `gl-login` → local=**Great Lakes**, remote=**Lighthouse**
  - SSH Host alias: `lighthouse`
  - Remote hostname: `lighthouse.arc-ts.umich.edu`
  - Expect script: `~/.local/bin/ssh-lh-auto`
- If hostname contains `lighthouse` or `lh-login` → local=**Lighthouse**, remote=**Great Lakes**
  - SSH Host alias: `greatlakes`
  - Remote hostname: `greatlakes.arc-ts.umich.edu`
  - Expect script: `~/.local/bin/ssh-gl-auto`
- If neither: tell the user this skill is designed for the U-M Great Lakes and Lighthouse clusters and exit.

2. Check if `expect` is available:
```bash
which expect
```
If missing, suggest `module load expect` or installing it. Do not proceed without `expect`.

3. Present what the skill will do:
   - **(a)** Store your UM password locally for automated SSH
   - **(b)** Configure SSH multiplexing in `~/.ssh/config`
   - **(c)** Create an expect script to connect to the other cluster automatically
   - **(d)** Establish the connection and test it

Ask if they want to proceed.

## Phase 1: Credential Setup

### 1.1 Check existing credentials

```bash
test -f ~/.env && grep -c '^SSH_UMICH_PASS=' ~/.env 2>/dev/null
```

If `SSH_UMICH_PASS` is already set, tell the user:
> Your UM password is already stored in `~/.env`. Want to update it or keep the current one?

If they want to keep it, skip to Phase 2.

### 1.2 Store the password

Ask the user for their UM (UMICH) password. Explain:
> I'll store your UM password in `~/.env` so the SSH automation script can read it. This file is in your home directory with restricted permissions (readable only by you). Since `~/` is shared via NFS, this works from both clusters.

**Important**: Ask the user to type or paste their password. Do NOT echo it back or display it in any output.

If `~/.env` already contains `SSH_UMICH_PASS`, **replace** the existing line (do not append a duplicate). Use the Edit tool to swap the old line for the new one. If the file doesn't exist or doesn't contain the variable, append:

```
SSH_UMICH_PASS="<password>"
```

Then set permissions:
```bash
chmod 600 ~/.env
```

Verify there is exactly one entry:
```bash
ls -la ~/.env
grep -c '^SSH_UMICH_PASS=' ~/.env
```

If the count is not `1`, fix the file so there is exactly one `SSH_UMICH_PASS` line.

Confirm to the user that the password is stored and the file permissions are restricted.

**Security note**: Tell the user this is a plaintext password protected only by file permissions (`-rw-------`). To remove it later, delete the `SSH_UMICH_PASS` line from `~/.env`. Never loosen permissions on this file.

## Phase 2: SSH Config

### 2.1 Ensure directories exist

```bash
mkdir -p ~/.local/bin ~/.ssh && chmod 700 ~/.ssh
```

### 2.2 Configure SSH multiplexing

Check if the remote cluster Host entry already exists in `~/.ssh/config`:
```bash
grep -A5 -i "<remote-alias>" ~/.ssh/config 2>/dev/null
```

If the Host entry **does not exist**, append it to `~/.ssh/config`:

**If remote is Great Lakes:**
```
Host greatlakes
    HostName greatlakes.arc-ts.umich.edu
    User <username>
    ControlMaster auto
    ControlPath ~/.ssh/%r@%h:%p
    ControlPersist 86400
```

**If remote is Lighthouse:**
```
Host lighthouse
    HostName lighthouse.arc-ts.umich.edu
    User <username>
    ControlMaster auto
    ControlPath ~/.ssh/%r@%h:%p
    ControlPersist 86400
```

Where `<username>` is the output of `whoami`.

If the Host entry **already exists**, check that it has `ControlMaster`, `ControlPath`, and `ControlPersist`. If any are missing, tell the user and suggest adding them. Do not modify existing entries without asking.

`ControlPersist 86400` keeps the socket alive for 24 hours. `ControlMaster auto` enables multiplexing so subsequent SSH commands reuse the connection.

## Phase 3: Create Expect Script

### 3.1 Write the expect script

Based on the detected cluster (Phase 0), write the appropriate script.

**If on Great Lakes** (connecting to Lighthouse), write `~/.local/bin/ssh-lh-auto`:

```expect
#!/usr/bin/expect -f
if {[catch {open "$env(HOME)/.env" r} fp]} {
    puts stderr "Error: unable to read $env(HOME)/.env"
    exit 1
}
set envdata [read $fp]
close $fp
if {![regexp {SSH_UMICH_PASS="([^"]+)"} $envdata -> password] || $password eq ""} {
    puts stderr "Error: SSH_UMICH_PASS not found in $env(HOME)/.env"
    exit 1
}

set timeout 60
spawn ssh -fN lighthouse

expect {
    "yes/no" { send "yes\r"; exp_continue }
    -nocase "*assword:" { send -- "$password\r" }
}

expect "Passcode or option*"
send "1\r"

# SSH forks to background after successful Duo auth, closing the pty.
catch {expect eof}
```

**If on Lighthouse** (connecting to Great Lakes), write `~/.local/bin/ssh-gl-auto`:

```expect
#!/usr/bin/expect -f
if {[catch {open "$env(HOME)/.env" r} fp]} {
    puts stderr "Error: unable to read $env(HOME)/.env"
    exit 1
}
set envdata [read $fp]
close $fp
if {![regexp {SSH_UMICH_PASS="([^"]+)"} $envdata -> password] || $password eq ""} {
    puts stderr "Error: SSH_UMICH_PASS not found in $env(HOME)/.env"
    exit 1
}

set timeout 60
spawn ssh -fN greatlakes

expect {
    "yes/no" { send "yes\r"; exp_continue }
    -nocase "*assword:" { send -- "$password\r" }
}

expect "Passcode or option*"
send "1\r"

# SSH forks to background after successful Duo auth, closing the pty.
catch {expect eof}
```

The scripts use `ssh -fN <alias>` which forks SSH to background (`-f`) with no remote command (`-N`). The SSH config's `ControlMaster auto` handles multiplexing automatically.

Then make it executable:
```bash
chmod +x ~/.local/bin/ssh-<remote-short>-auto
```

Tell the user what was created and what it does.

## Phase 4: Establish Connection and Test

### 4.1 Check for existing connection

```bash
ssh -O check <remote-alias> 2>&1
```

If already connected, skip to 4.3.

### 4.2 Run the expect script

Tell the user:
> I'm establishing the SSH connection now. You'll need to approve the Duo push notification on your phone.

```bash
~/.local/bin/ssh-<remote-short>-auto
```

**Note**: After Duo approval, the command may appear to hang. This is normal — the user may need to cancel the running command (Ctrl+C or escape) once they see the Duo approval go through. The SSH process will already be forked to the background.

### 4.3 Verify and test

```bash
ssh -O check <remote-alias> 2>&1
```

If the socket is alive, run quick connectivity checks:
```bash
ssh <remote-alias> "hostname -f && whoami && sinfo --version 2>&1"
ssh <remote-alias> "ls -d /nfs/turbo/si-qmei 2>&1"
```

Present a quick pass/fail summary.

If it fails, troubleshoot:
- Check if Duo was approved
- Check if the password is correct (suggest updating `~/.env`)
- Check `~/.ssh/config` for the Host entry
- Suggest running `ssh <remote-alias>` manually to diagnose

### 4.4 Wrap up

Tell the user:
- Setup is complete. The connection lasts 24 hours.
- To reconnect anytime without setup questions, just run **`/connect`**
- They can also run the script directly: `~/.local/bin/ssh-<remote-short>-auto`
- Add `~/.local/bin` to their `PATH` in `~/.bashrc` if not already there
- `/slurm-status` can now check both clusters (if the combined module is set up)
