# Step 4 — Generate load

In a new terminal:

```bash
kubectl run -i --tty load --image=busybox --restart=Never -- /bin/sh -c \
  "while true; do wget -q -O- http://php-apache; done"
```

Watch:

```bash
kubectl get hpa -w
```

**Expected result:** within a minute `TARGETS` climbs well past `50%` (often several hundred
per cent, since one busy pod can use many times its 100m request), and `REPLICAS` rises
step by step toward `5`. Scale-**up** decisions are made about every 15 seconds.

```bash
kubectl get pods -l app=php-apache
kubectl top pods -l app=php-apache
```

**Expected result:** up to five pods. On a 1-CPU playground some may stay `Pending` for lack
of CPU — the HPA's *desired* count still rises, which is what you are observing. The load
generator competes for the same single CPU, so numbers swing; that is the environment, not
the HPA.
