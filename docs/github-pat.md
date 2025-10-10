# 🧠 Goal

Create a **robust GitHub CLI authentication setup** that:

* Uses a **Personal Access Token (PAT)** you control.
* Stores it **encrypted with age** under chezmoi.
* Automatically sets up `gh` authentication on any new system.
* Never exposes the token in plain text.

---

# ⚙️ Step 1 — Create a New GitHub PAT (Fine-Grained or Classic)

You can use either:

* **Fine-grained tokens** (newer, more secure, repo-specific), or
* **Classic tokens** (broad, simpler for CLI automation).

Let’s go with **Fine-grained** (recommended).

## 🔗 Generate Token

1. Visit: **[https://github.com/settings/personal-access-tokens](https://github.com/settings/personal-access-tokens)**
2. Choose **“Tokens (Fine-grained)” → “Generate new token”**.
3. Set:

   * **Name:** `gh-cli`
   * **Expiration:** `90 days` or `No expiration` (your call)
   * **Resource owner:** your user (if prompted)
   * **Repository access:**
     → “All repositories” or select specific ones
   * **Permissions:**

     * ✅ Repository: *Read and write*
     * ✅ Metadata: *Read-only*
     * ✅ Gists: *Read and write*
4. Click **“Generate token”**, then **copy** the token (it starts with `github_pat_...` or `ghp_...`).

---

# 🧩 Step 2 — Authenticate GitHub CLI Using Your PAT

Now, authenticate manually once, to ensure it works:

```bash
echo "your-github-pat-here" | gh auth login --with-token
```

This logs you in **without a browser**, using your token.
Verify success:

```bash
gh auth status
```

You should see:

```
You are logged into github.com as mecattaf (token)
```

---

# 🛠 Step 3 — Export and Encrypt the Token with Age

Once confirmed working, let’s secure the token for future use with chezmoi.

1. Create an encrypted file in your chezmoi source directory:

   ```bash
   echo "your-github-pat-here" | age --encrypt --recipient "your-age-public-key" > ~/.local/share/chezmoi/encrypted_github-token.age
   ```

2. Optionally, tell chezmoi to track it:

   ```bash
   chezmoi add ~/.local/share/chezmoi/encrypted_github-token.age
   ```

---

# 🧩 Step 4 — Automate Decryption and GH Auth Setup

Create a chezmoi template script so that **on any new machine**, chezmoi will:

* Decrypt your encrypted PAT.
* Log you into GitHub CLI automatically.

Create this file:

```bash
~/.local/share/chezmoi/run_onchange_before_setup-gh-auth.sh.tmpl
```

Contents:

```bash
#!/bin/bash
# Setup GitHub CLI authentication with decrypted token

TOKEN="{{ include "encrypted_github-token.age" | decrypt }}"
export GH_TOKEN="$TOKEN"

# Authenticate gh non-interactively
echo "$GH_TOKEN" | gh auth login --with-token --hostname github.com --git-protocol https

# Verify login success silently
gh auth status >/dev/null 2>&1 && echo "✅ GitHub CLI authenticated for $(gh api user --jq '.login')"
```

Make it executable:

```bash
chmod +x ~/.local/share/chezmoi/run_onchange_before_setup-gh-auth.sh.tmpl
```

Now chezmoi will run it automatically whenever applied or changed.

---

# 🧱 Step 5 — Confirm on a Fresh Machine

When you clone your chezmoi setup on another device:

```bash
chezmoi init your-username
chezmoi apply
```

You’ll see:

```
✅ GitHub CLI authenticated for mecattaf
```

Now your CLI is authenticated and ready — no manual token entry, no plaintext secrets.

---

# 🧰 Step 6 — (Optional) Use GH_TOKEN in Shell Environment

If you want the token available to scripts or CI jobs:

Add this to `~/.bashrc.tmpl` or `~/.zshrc.tmpl`:

```bash
# GitHub CLI authentication
export GH_TOKEN="{{ include "encrypted_github-token.age" | decrypt }}"
```

Then in any script, you can use:

```bash
gh api user
gh repo list
```

---

# 🔒 Security Best Practices

* Protect your age private key (`chmod 600 ~/.config/chezmoi/key.txt`).
* Use minimal token scopes.
* Rotate your PAT periodically.
* Never `echo` decrypted tokens in plain logs.

---

✅ **End Result**

* You can bootstrap any new system with `chezmoi apply`.
* `gh` authenticates automatically using your encrypted PAT.
* No browser flow or manual copy/paste.
* Secure, repeatable, and version-controlled.

---

Would you like me to include an optional **systemd unit** that automatically refreshes your `gh` auth on startup (using your encrypted token)? It’s handy if you want this setup to persist without running `chezmoi apply` manually.
