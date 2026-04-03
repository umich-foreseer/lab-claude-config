---
name: connect
description: Establish (or refresh) the cross-cluster SSH connection. No questions asked — just connects and verifies.
allowed-tools: Bash(ssh *), Bash(hostname *), Bash(whoami), Bash(test *), Bash(ls *), Bash(expect *), Bash(*/ssh-*-auto), Bash(sinfo *), Bash(grep *)
---

# Cross-Cluster SSH Connect

Establish or refresh the persistent SSH connection to the other cluster. This is the quick, no-questions version — it assumes `/connect-setup` has already been run.

## Step 1: Detect environment

```bash
hostname -f
whoami
```

- If hostname contains `greatlakes` or `gl-login` → remote=**Lighthouse**
  - SSH Host alias: `lighthouse`
  - Expect script: `~/.local/bin/ssh-lh-auto`
- If hostname contains `lighthouse` or `lh-login` → remote=**Great Lakes**
  - SSH Host alias: `greatlakes`
  - Expect script: `~/.local/bin/ssh-gl-auto`
- If neither: tell the user this skill is for U-M Great Lakes / Lighthouse clusters and exit.

## Step 2: Pre-flight checks

Check if the expect script, credentials, and SSH config exist:
```bash
test -x ~/.local/bin/ssh-<remote-short>-auto && echo "script OK" || echo "script MISSING"
test -f ~/.env && grep -q 'SSH_UMICH_PASS' ~/.env && echo "credentials OK" || echo "credentials MISSING"
grep -q "^Host.*<remote-alias>" ~/.ssh/config 2>/dev/null && echo "ssh config OK" || echo "ssh config MISSING"
```

If any are missing, tell the user to run `/connect-setup` first and stop.

## Step 3: Check existing connection

```bash
ssh -O check <remote-alias> 2>&1
```

If the socket is already alive, report:
> Connection to `<remote>` is already active.

Then skip to Step 5 (connectivity test). Do NOT re-establish.

## Step 4: Establish connection

Run the expect script:
```bash
~/.local/bin/ssh-<remote-short>-auto
```

**Note**: After Duo approval, the command may appear to hang. This is normal — the user may need to cancel the running command once they see the Duo approval go through. The SSH process will already be forked to the background.

Verify:
```bash
ssh -O check <remote-alias> 2>&1
```

If it fails, briefly suggest:
- Approve Duo push and retry
- Check password in `~/.env` (run `/connect-setup` to update)
- Try `ssh <remote-alias>` manually

## Step 5: Quick connectivity test

Run all checks and report:

```bash
ssh <remote-alias> "hostname -f && whoami"
ssh <remote-alias> "sinfo --version 2>&1"
ssh <remote-alias> "ls -d /nfs/turbo/si-qmei 2>&1"
```

Present as a brief checklist:

```
## <local> -> <remote>: Connected

- [x] SSH socket: active (24h)
- [x] Remote shell: OK
- [x] Remote Slurm: available
- [x] Shared storage: accessible
```

For any failures, provide one-line remediation.

Done. No further prompts needed.
