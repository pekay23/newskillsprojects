# Contributing to Raymond Gray IFM

> **⚠️ MANDATORY READING FOR ALL AGENTS AND DEVELOPERS**
>
> Every agent (AI or human) that makes commits to this repository **MUST read and follow** these rules. These rules govern the **branch strategy**, **commit workflow**, and **promotion gates** from `dev` → `staging` → `prod`.

---

## 1. Branch Strategy

```
main (production)          ← ONLY approved, tested code lives here
  └── staging              ← QA/testing happens here
       └── dev             ← development happens here
            └── feature/*  ← feature branches (short-lived)
```

| Branch | Purpose | Who can push | Auto-builds |
|--------|---------|--------------|-------------|
| `feature/*` | Isolated development work | Any developer | No (manual) |
| `dev` | Integration of features | Developers via PR | ✅ `rg-*-dev` |
| `staging` | QA / pre-production testing | Maintainers via PR | ✅ `rg-*-staging` |
| `main` | Production | Maintainers via PR + approval | ✅ `rg-*-prod` |

---

## 2. Commit Rules (ALL Agents MUST Follow)

### 2.1 Before committing
- [ ] **Never commit secrets** — no API keys, tokens, passwords, or connection strings with real credentials. Use `infrastructure/.env` (gitignored) or placeholders.
- [ ] **Never commit compiled binaries** (`.exe`, `.dll`, `.pdb`) — they are gitignored.
- [ ] **Never commit local config** — `.env`, `node_modules/`, `target/`, `dist/`, `venv/` are gitignored.
- [ ] **Run the build/tests locally** for the service you changed before committing.

### 2.2 Commit message format
Use **Conventional Commits**:
```
<type>(<scope>): <description>

[optional body]
```

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding/updating tests |
| `chore` | Maintenance (deps, tooling, CI) |
| `security` | Security fix or credential rotation |

**Examples:**
```
feat(workorder): add SLA escalation timer
fix(cmms): correct Npgsql connection string parsing
docs: add contributing guidelines
security: rotate exposed API keys
```

### 2.3 Commit hygiene
- **One logical change per commit** — don't mix unrelated changes.
- **Keep commits small and reviewable** — prefer several focused commits over one giant one.
- **Write clear commit messages** — the body should explain *why*, not just *what*.
- **Never force-push** to `dev`, `staging`, or `main`.

---

## 3. The Promotion Workflow (dev → staging → prod)

### 3.1 Development (feature → dev)

```
1. Create a feature branch from dev:
   git checkout dev
   git pull
   git checkout -b feature/my-change

2. Make changes, commit (see Section 2).

3. Push the feature branch:
   git push origin feature/my-change

4. Open a Pull Request (PR) into `dev`.
   - Title: conventional commit style
   - Description: what/why/how
   - Reference any related issue

5. PR must pass:
   - ✅ Code review (at least 1 approval)
   - ✅ `rg-*-dev` TeamCity builds pass (if triggered)
   - ✅ No merge conflicts

6. Merge the PR into `dev`.
```

**Gate:** A PR into `dev` requires **1 approving review** and **passing dev builds**.

---

### 3.2 Staging (dev → staging)

```
1. Open a Pull Request from `dev` into `staging`.

2. PR must pass:
   - ✅ Code review (at least 1 approval)
   - ✅ `rg-*-staging` TeamCity builds pass
   - ✅ QA verification on the staging environment

3. Merge the PR into `staging`.
```

**Gate:** A PR into `staging` requires **1 approving review**, **passing staging builds**, and **QA sign-off**.

---

### 3.3 Production (staging → main)

```
1. Open a Pull Request from `staging` into `main`.

2. PR must pass:
   - ✅ Code review (at least 1 approval)
   - ✅ `rg-*-prod` TeamCity builds pass
   - ✅ All staging tests passed
   - ✅ Explicit maintainer approval (release manager)

3. Merge the PR into `main`.

4. Tag the release:
   git tag v1.x.x
   git push origin v1.x.x
```

**Gate:** A PR into `main` requires **1 approving review**, **passing prod builds**, and **explicit release approval**. The version tag triggers the desktop app release pipeline (GitHub Actions).

---

## 4. Branch Protection (enforced by GitHub)

| Branch | Require PR | Require 1 approval | Require status checks | Enforce admins | Force push |
|--------|-----------|--------------------|----------------------|----------------|------------|
| `main` | ✅ | ✅ | ✅ | ✅ | ❌ |
| `staging` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `dev` | ✅ | ✅ | ✅ | ❌ | ❌ |

**No one (including admins) may push directly to `dev`, `staging`, or `main`.** All changes must go through a reviewed Pull Request.

---

## 5. Auto-Cancel Outdated Builds

All 18 TeamCity build configs have **auto-cancel** enabled:
- Stale queued builds are cancelled when a newer commit triggers a build.
- Running builds older than 3 minutes are cancelled if a newer build starts.

This ensures the agent always builds the **latest** commit, not a backlog.

---

## 6. Security Rules (ALL Agents MUST Follow)

1. **Never commit real credentials.** Use `infrastructure/.env` (gitignored) for secrets.
2. **If a secret is accidentally committed**, immediately:
   - Rotate/revoke the secret (it's compromised).
   - Remove it from the file.
   - Commit the fix.
3. **Never commit compiled binaries** — they may embed secrets.
4. **Never commit `.env` files** — they are gitignored.
5. **Review diffs for secrets** before every commit.

---

## 7. Definition of Done (DoD)

A change is **done** only when:
- [ ] Code is committed with a clear conventional message
- [ ] Build passes locally
- [ ] Tests pass (where applicable)
- [ ] PR reviewed and approved
- [ ] Merged to `dev` (and promoted through `staging` → `main` as appropriate)
- [ ] No secrets or binaries committed
- [ ] Documentation updated if behavior changed

---

## 8. Quick Reference — Common Commands

```bash
# Start a feature
git checkout dev && git pull
git checkout -b feature/my-change

# Commit
git add <files>
git commit -m "feat(scope): description"

# Push feature
git push origin feature/my-change

# Promote dev → staging (via PR)
# Promote staging → main (via PR)

# Tag a release
git tag v1.2.0 && git push origin v1.2.0
```

---

*This document is the authoritative source for the contribution workflow. If any agent is unsure, re-read this file before committing.*