<div align="center">

# 🚨 WTF, EVERYTHING BROKE DOWN. HELP. 🚨

**Something is on fire. You are not stupid. Let's fix it.**

</div>

> *"It worked five minutes ago." — every developer, right before opening this file.*

This is the file you open when the Hydra is down, the logs are screaming, and you have no idea where to start. It is deliberately boring: find the problem, undo the last change, bring it back. No magic.

---

## 🧭 Start Here

- **A container is down or unhealthy** → Scenario 1.
- **The last deploy broke everything** → Scenario 2.
- **`api.localhost` / `agent.localhost` do not answer** → Scenario 3.
- **The model does not answer, but the stack looks fine** → Scenario 4.
- **The data looks wrong or is missing** → Scenario 5.

If you do not know which one, run the 60-second triage below.

---

## 🧯 The First Rule: Do Not Make It Worse

Before you touch anything, repeat after me:

- **Do not delete `~/hydr4-data`.** That is the database, the keys, and your chat history.
- **Do not run `docker system prune -a --volumes`.** It can nuke unrelated Docker data.
- **Do not force-push `main`.** Fix forward, or roll back locally.
- **Do not edit `.env` and restart "just to see".** Write down what you change.
- **Do not run random commands from the internet.** Especially the ones with `sudo`.

A broken stack is recoverable. Deleted data is not.

---

## 🩺 Triage in 60 Seconds

Run these three, in this order:

```bash
./hydra status
./hydra check
./hydra logs
```

### `status` tells you where you are

It shows what state each container is in, which commit is deployed, and whether the working tree is clean.

If the commit is not the one you expected, stop and check Git first.

### `check` tells you what is broken

`check` is read-only. It does not call models, spend tokens, or change anything.

```text
[OK]   compose config
[OK]   gateway: running, healthy
[OK]   agent: running, healthy
[OK]   gateway /healthz -> 200
[OK]   gateway /v1/models -> 200
[OK]   agent -> gateway DNS
[OK]   api.localhost -> 200
[OK]   agent.localhost -> 200
```

- `[OK]` — fine.
- `[FAIL]` — something obvious is broken. Keep reading.
- `[WAIT]` — still starting. Wait a bit, rerun `check`.

### `logs` tells you why

```bash
./hydra logs            # all services
./hydra logs gateway    # just the gateway
./hydra logs agent      # just the agent
```

Read the last 100 lines. The answer is usually there.

---

## 🧭 Scenario 1: A Container Is Down

```bash
./hydra start
```

If it was already running but misbehaving:

```bash
./hydra restart
```

If the image itself is suspect, or `restart` did not help:

```bash
./hydra rebuild
```

`rebuild` builds the agent from scratch (`--no-cache`), pulls the pinned gateway image, and recreates everything. It is slow. It is also the closest thing to "turn it off and on again" that actually works.

---

## 🧨 Scenario 2: The Last Deploy Broke Everything

This is the important one. **Git is the source of truth.** Roll back the code, not the Docker images.

### Step 1 — Find the last commit that worked

```bash
git log --oneline -10
```

Pick a commit you trust. The one before the bad merge is usually right.

### Step 2 — Run that commit (without touching `main`)

```bash
git switch --detach <good-sha>
./hydra rebuild
./hydra check
```

`--detach` means "look at this commit, but do not move `main`." Your branch is safe.

### Step 3 — Go back to `main` when you are done

```bash
git switch main
```

That is it. No reset, no force-push, no lost work.

### Step 4 — Fix forward

Start from a clean tree. If `./hydra status` says it is dirty, commit or `git stash` your changes first.

```bash
git switch main
git pull --ff-only
git revert --no-commit <bad-sha>   # if <bad-sha> is a merge commit, add: -m 1
git reset                          # unstage, keep the changes in your files
# edit the files
git add .
git commit -m "fix: ..."
git push
./hydra rebuild
./hydra check
```

`git reset` here does **not** delete your changes. It only unstages them so you can edit freely.

---

## 🌐 Scenario 3: `api.localhost` / `agent.localhost` Do Not Answer

Traefik is **not** part of this repository. It lives in `l3rn4-nix`. `hydr4-agent` only declares labels and joins `traefik-net`.

So if `./hydra check` says:

```text
[FAIL] api.localhost -> 502
```

...the containers are probably fine. The ingress is not.

Check, in order:

1. `./hydra check` — are the containers healthy?
2. `docker ps` — is Traefik running?
3. `l3rn4-nix` — does the router still point at `hydr4-gateway:3001` and `hydr4-agent:4096`?

This is exactly the class of breakage that happened when the container was renamed from `hydr4-aggregator` to `hydr4-gateway`. The fix lives in the Traefik config, not here.

---

## 🔌 Scenario 4: The Providers Are Down

Sometimes it is not you. NVIDIA NIM, DeepSeek, or Google can be unavailable. `check` deliberately does **not** test them, so a provider outage will not show up as a failed check.

If the model does not answer, but `check` is green:

1. Open the gateway dashboard: `http://localhost:3001`
2. Look at the provider status.
3. Try another model.
4. Wait. Providers come back.

Do **not** rebuild the stack because a provider is down. You will just lose time.

---

## 💾 Scenario 5: The Data Looks Wrong

The gateway data lives at:

```text
~/hydr4-data/gateway/
```

It contains `freeapi.db` and its WAL files. If that directory is missing or the database is tiny, stop immediately:

```bash
./hydra stop
```

Then restore the backup:

```bash
# Move the broken directory aside first (do not delete it yet).
mv ~/hydr4-data/gateway ~/hydr4-data/gateway.broken-$(date +%F-%H%M%S)

# Then restore the backup.
cp -a ~/hydr4-data/gateway.bak-YYYY-MM-DD ~/hydr4-data/gateway

./hydra start
./hydra check
```

To make a fresh backup before risky work:

```bash
cp -a ~/hydr4-data ~/hydr4-data.bak-$(date +%F-%H%M%S)
```

Never "clean up" `~/hydr4-data` to save space. It is not cache. It is the Hydra's memory.

---

## ☢️ The Nuclear Options (In Order)

Use these only after the gentle options failed.

1. `./hydra restart` — recreate containers, keep images.
2. `./hydra rebuild` — rebuild the agent image, pull the gateway image.
3. `docker compose --profile opencode down --remove-orphans` then `./hydra start`.
4. Restore the data backup from above.
5. Roll back to a known-good commit and rebuild.

If you are about to do something not on this list, stop and ask. That is not weakness. That is cheaper than spending three hours rebuilding a database you could have restored in two minutes.

---

## 🆘 Still Stuck?

Collect the evidence:

```bash
./hydra status
./hydra check
./hydra logs
git log --oneline -5
```

Paste the output somewhere. Do not paste `.env` — it contains secrets.

---

## 🌱 The Final Step: Touch Grass

Maybe it's time to implement a different kind of fix. A life-decision one.

Go outside. Touch grass. Talk to someone. Fall in love. Marry them. Get a mortgage. Have children. By the time they are teenagers, the `hydr4-agent` outage will be the least of your problems.

---

<div align="center">

**"Have you tried turning it off and on again?"**

*Built by humans. Debugged by caffeine. Powered by spite.*

</div>
