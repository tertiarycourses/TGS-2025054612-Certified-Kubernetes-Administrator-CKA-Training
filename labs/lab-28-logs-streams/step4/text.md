# Step 4 — Logs from the host

```bash
ls /var/log/pods/
ls /var/log/pods/default_multi_*/writer/
sudo tail /var/log/pods/default_multi_*/writer/0.log
```

**Expected result:** a directory per pod named `<namespace>_<pod>_<uid>`, a subdirectory
per container, and `0.log` inside it. Each line begins with an RFC3339 timestamp, then
`stdout` or `stderr`, then the raw output — the CRI log format that `kubectl logs` parses.

```bash
sudo ls /var/log/pods/default_crashy_*/crashy/
```

**Expected result:** **several** numbered files (`0.log`, `1.log`, …) — one per container
restart. `kubectl logs --previous` reads the second-newest, and files beyond that are what
you lose when a pod restarts enough times. Node-level log rotation
(`containerLogMaxFiles`) is the limit.
