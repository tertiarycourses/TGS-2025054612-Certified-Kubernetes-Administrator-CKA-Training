# Lab 11 — Deployments: Rolling Update and Rollback

In this lab you create a Deployment, perform a rolling update by changing the image, watch the rollout, then roll back to the previous revision.

**Lab environment:** [Play with Kubernetes](https://killercoda.com/playgrounds/course/kubernetes-playgrounds/two-node)
---

## Step 1 — Create the Deployment

```bash
kubectl create deployment web --image=nginx:1.25 --replicas=4
kubectl rollout status deploy/web
kubectl get pods -l app=web -o wide
```

**Expected result:** `deployment "web" successfully rolled out` and four `Running` pods. On
a 1-CPU playground this takes a moment; the control-plane node is tainted, so all four land
on `node01`.

---

## Step 2 — Inspect the strategy

```bash
kubectl get deploy web -o yaml | grep -A5 strategy
```

**Expected result:**

```yaml
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
```

With four replicas that means at most 5 pods during the rollout (`+25%`) and at least 3
serving (`-25%`) — Kubernetes rounds surge up and unavailability down.

---

## Step 3 — Perform a rolling update

```bash
kubectl set image deploy/web nginx=nginx:1.26
kubectl annotate deploy/web kubernetes.io/change-cause="set image nginx:1.26" --overwrite
kubectl rollout status deploy/web
kubectl rollout history deploy/web
```

**Expected result:** the rollout completes and `history` lists revisions 1 and 2, with
revision 2's `CHANGE-CAUSE` reading `set image nginx:1.26`.

> **Why not `--record`?** That flag is deprecated upstream (`--record will be removed in the
> future`) and prints a warning. The annotation
> `kubernetes.io/change-cause` is what `--record` wrote anyway, and setting it yourself is
> the supported way to fill in `CHANGE-CAUSE`.

Watch in another shell:

```bash
kubectl get pods -l app=web -w
```

You'll see new pods come up while old ones are still serving — that's the surge.

---

## Step 4 — Cause a bad rollout

```bash
kubectl set image deploy/web nginx=nginx:doesnotexist
kubectl rollout status deploy/web --timeout=30s
kubectl get pods -l app=web
```

**Expected result:** `rollout status` gives up with
`error: timed out waiting for the condition`, and `get pods` shows one new pod in
`ImagePullBackOff` or `ErrImagePull` while **three old pods keep Running**.

That is `maxUnavailable: 25%` protecting you: the Deployment refuses to remove healthy
replicas until the new ones are ready, so a bad image degrades a rollout instead of taking
the app down.

```bash
kubectl rollout history deploy/web
kubectl describe deploy web | grep -A3 Conditions
```

**Expected result:** a third revision exists, and the conditions report
`ProgressDeadlineExceeded`.

---

## Step 5 — Roll back

```bash
kubectl rollout undo deploy/web
kubectl rollout status deploy/web
kubectl rollout history deploy/web
```

**Expected result:** `deployment.apps/web rolled back`, the bad pod disappears, and all
four pods run `nginx:1.26` again. `history` gains another revision — a rollback rolls
*forward* to a new revision with the old spec; it never rewrites history.

Go back to a specific revision:

```bash
kubectl rollout undo deploy/web --to-revision=1
kubectl get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Expected result:** `nginx:1.25` — revision 1's image.

---

## Step 6 — Pause and resume

```bash
kubectl rollout pause deploy/web
kubectl set image deploy/web nginx=nginx:1.27
kubectl set resources deploy/web --limits=cpu=200m,memory=256Mi
kubectl rollout resume deploy/web
kubectl rollout status deploy/web
```

**Expected result:** nothing happens while paused — no new ReplicaSet, no new pods. The
moment you `resume`, **one** rollout applies both the image and the resource change
together.

Check it only cost you one revision:

```bash
kubectl rollout history deploy/web | tail -3
kubectl get rs -l app=web
```

**Expected result:** a single new revision, and one ReplicaSet with non-zero replicas while
the older ones sit at `0` — kept for rollback.

---

## Step 7 — Cleanup

```bash
kubectl delete deploy web
```

---

## Verification

| Check | Expected |
|---|---|
| Step 1 — created | `successfully rolled out`, four pods Running |
| Step 2 — strategy | `RollingUpdate`, `maxSurge: 25%`, `maxUnavailable: 25%` |
| Step 3 — rolling update | revisions 1 and 2; revision 2 `CHANGE-CAUSE` = `set image nginx:1.26` |
| Step 4 — bad rollout | new pod `ImagePullBackOff`, three old pods still Running, `ProgressDeadlineExceeded` |
| Step 5 — rollback | `rolled back`; `--to-revision=1` returns the image to `nginx:1.25` |
| Step 6 — pause/resume | both changes ship in one rollout; old ReplicaSets remain at 0 |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `--record` prints a deprecation warning | Expected. Use `kubectl annotate … kubernetes.io/change-cause=…` instead. |
| `CHANGE-CAUSE` shows `<none>` | Nothing set the annotation. Add it as Step 3 does. |
| `rollout status` hangs after a bad image | Correct behaviour. Pass `--timeout=30s`, then `kubectl rollout undo`. |
| Rollback did not remove the bad revision | By design: undo creates a **new** revision with the old spec. |
| Pods stay `Pending`, not `ImagePullBackOff` | Not an image problem — insufficient CPU on a 1-CPU node: `kubectl describe pod` and lower `--replicas`. |
| `error: no rollout history found` | The Deployment was recreated; revisions live on its ReplicaSets, which were deleted with it. |

---

## What you learned
- `RollingUpdate` strategy, `maxSurge` and `maxUnavailable`.
- `rollout status`, `history`, `undo`, `pause`, `resume`.
- How a Deployment tracks each revision as a ReplicaSet.
