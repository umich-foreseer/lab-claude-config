---
name: connect
description: Set up cross-cluster SSH (Great Lakes <-> Lighthouse) and establish the connection. Handles first-time setup automatically.
allowed-tools: Bash(ssh *), Bash(hostname *), Bash(whoami), Bash(cat *), Bash(ls *), Bash(mkdir *), Bash(chmod *), Bash(test *), Bash(grep *), Bash(which *), Bash(sinfo *), Bash(~/.local/bin/ssh-*), Read, Edit, Write
---

# Cross-Cluster SSH Connect

Set up and establish a persistent SSH connection to the other cluster. Automatically detects whether first-time setup is needed.

## Step 1: Detect environment

```bash
hostname -f
whoami
```

- If hostname contains `greatlakes` or `gl-login` → remote=**Lighthouse**
  - SSH Host alias: `lighthouse`
  - Remote hostname: `lighthouse.arc-ts.umich.edu`
  - Expect script: `~/.local/bin/ssh-lh-auto`
- If hostname contains `lighthouse` or `lh-login` → remote=**Great Lakes**
  - SSH Host alias: `greatlakes`
  - Remote hostname: `greatlakes.arc-ts.umich.edu`
  - Expect script: `~/.local/bin/ssh-gl-auto`
- If neither: tell the user this skill is for U-M Great Lakes / Lighthouse clusters and exit.

## Step 2: Check prerequisites

```bash
test -x ~/.local/bin/ssh-<remote-short>-auto && grep -q 'Okta passcode' ~/.local/bin/ssh-<remote-short>-auto && grep -q 'Press enter to continue' ~/.local/bin/ssh-<remote-short>-auto && echo "script OK" || echo "script MISSING_OR_STALE"
test -f ~/.env && grep -q '^SSH_UMICH_PASS=' ~/.env && [ "$(stat -c '%a' ~/.env 2>/dev/null)" = "600" ] && echo "credentials OK" || echo "credentials MISSING"
grep -q "^Host.*<remote-alias>" ~/.ssh/config 2>/dev/null && echo "ssh config OK" || echo "ssh config MISSING"
which expect 2>/dev/null && echo "expect OK" || echo "expect MISSING"
```

- If **all present** → skip to Step 4 (establish connection)
- If **any missing** → proceed to Step 3 (first-time setup)

## Step 3: First-time setup (only if prerequisites missing)

Walk the user through each missing piece interactively. Skip any sub-step where the prerequisite already exists.

### 3.1 Check expect

If `expect` is missing, suggest `module load expect` or installing it. Do not proceed without it.

### 3.2 Store UM credentials

If `~/.env` is missing `SSH_UMICH_PASS` or correct `600` permissions:

**Do NOT ask the user to type their password into the chat or write it yourself.** Instead, tell the user to create the file themselves.

Tell the user:

> I need your UM password stored in `~/.env` so the SSH automation script can use it. Okta push is initiated by submitting a blank passcode, so no separate MFA option needs to be stored. **Please create this file yourself** — I won't handle your password directly.
>
> **Option A** (recommended — doesn't leave your password in shell history):
> ```
> ! vim ~/.env
> ```
> Add these lines:
> ```
> SSH_UMICH_PASS="your_password_here"
> ```
> Then save and run: `! chmod 600 ~/.env`
>
> **Option B** (quick, but the command will appear in shell history):
> ```
> ! printf 'SSH_UMICH_PASS="YOUR_PASSWORD"\n' > ~/.env && chmod 600 ~/.env
> ```
>
> **Security note**: This is a plaintext password protected only by file permissions (`-rw-------`). Since `~/` is shared via NFS, it works from both clusters. To remove it later, delete the file.

The `!` prefix runs the command in the current terminal session so Claude Code doesn't capture the password.

After the user confirms they've done it, verify:
```bash
test -f ~/.env && grep -c '^SSH_UMICH_PASS=' ~/.env
ls -la ~/.env
```

If the count is not `1` or permissions are not `-rw-------`, help the user fix it.

### 3.3 Configure SSH multiplexing

Ensure directories exist:
```bash
mkdir -p ~/.local/bin ~/.ssh && chmod 700 ~/.ssh
```

If `~/.ssh/config` does not have a Host entry for the remote cluster, append it and set permissions:

After writing, always ensure correct permissions:
```bash
chmod 600 ~/.ssh/config
```

Append this Host block:

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

If the Host entry already exists, check it has `ControlMaster`, `ControlPath`, and `ControlPersist`. If any are missing, tell the user and suggest adding them. Do not modify existing entries without asking.

### 3.4 Create or replace expect script

Create the expect script when it is missing or stale. A stale script is any existing `~/.local/bin/ssh-<remote-short>-auto` that still expects `Passcode or option*`, reads `SSH_DUO_OPTION`, or lacks the `Okta passcode*` / `Press enter to continue:` handling below.

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

expect {
    "Okta passcode*" {
        send "\r"
    }
    eof {
        puts stderr "SSH exited before Okta prompt."
        exit 1
    }
    timeout {
        puts stderr "Timed out waiting for Okta prompt."
        exit 1
    }
}

# Okta may show a number challenge on the phone and then ask for one final Enter.
# ssh -fN forks to background after auth, closing the pty.
expect {
    "Press enter to continue:" {
        send "\r"
        exp_continue
    }
    eof {}
    timeout {
        puts stderr "Timed out waiting for SSH to finish after Okta push."
        exit 1
    }
}
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

expect {
    "Okta passcode*" {
        send "\r"
    }
    eof {
        puts stderr "SSH exited before Okta prompt."
        exit 1
    }
    timeout {
        puts stderr "Timed out waiting for Okta prompt."
        exit 1
    }
}

# Okta may show a number challenge on the phone and then ask for one final Enter.
# ssh -fN forks to background after auth, closing the pty.
expect {
    "Press enter to continue:" {
        send "\r"
        exp_continue
    }
    eof {}
    timeout {
        puts stderr "Timed out waiting for SSH to finish after Okta push."
        exit 1
    }
}
```

Make it executable:
```bash
chmod +x ~/.local/bin/ssh-<remote-short>-auto
```

Tell the user what was created.

## Step 4: Establish connection

### 4.1 Check existing connection

```bash
ssh -O check <remote-alias> 2>&1
```

If already alive, report it and skip to Step 5.

### 4.2 Run the expect script

Run the expect script yourself via the Bash tool. Use a 90-second timeout so it doesn't block forever — the script will handle password entry and initiate Okta push automatically. Before running, tell the user:

> Connecting now — **approve the Okta push on your phone** when you receive it.
>
> Okta may show a number challenge. If it does, choose the number displayed in the terminal on your phone.
>
> Once you've approved, press **Esc** to return here and let me know so I can verify the connection.

```bash
~/.local/bin/ssh-<remote-short>-auto
```

Use a 90s timeout on the Bash call. The command should exit after Okta approval once SSH forks to the background. If it times out, verify whether the user approved the push and selected the displayed number challenge.

After the script finishes (or the user returns after approving Okta), verify:
```bash
ssh -O check <remote-alias> 2>&1
```

If it fails:
- Check if Okta was approved and the number challenge was answered correctly
- Check password in `~/.env`
- Try `! ssh <remote-alias>` manually

## Step 5: Connectivity test

```bash
ssh <remote-alias> "hostname -f && whoami"
ssh <remote-alias> "sinfo --version 2>&1"
```

Present as a checklist:

```
## <local> -> <remote>: Connected

- [x] SSH socket: active (24h)
- [x] Remote shell: OK
- [x] Remote Slurm: available
```

For any failures, provide one-line remediation.

## Wrap up

- The connection lasts 24 hours. Run `/connect` again to reconnect.
- Direct script: `~/.local/bin/ssh-<remote-short>-auto`
- Add `~/.local/bin` to `PATH` in `~/.bashrc` if not already there
- `/slurm-status` can now check both clusters (if the combined module is set up)
