# 🔄 Rotating Secrets the Chezmoi Way

Chezmoi supports **secret management with Age** directly in your dotfiles. You can:

1. Keep a **template file** (like `.env.tmpl`) with placeholders for secrets.
2. Use **encrypted variables** in the repo. Chezmoi handles decryption automatically using your Age key.
3. When a secret changes, you can update it locally in the **un-encrypted environment** and let Chezmoi re-encrypt it.

---

## 1️⃣ Store Secrets as Templates

Instead of editing `.chezmoidata.yaml.age` directly:

```yaml
# .env.tmpl
OPENAI_API_KEY: {{ .chezmoi.secret "OPENAI_API_KEY" }}
```

* The `{{ .chezmoi.secret "KEY_NAME" }}` function tells Chezmoi to **look up the secret**, decrypt it if needed, and inject it.

---

## 2️⃣ Edit Secrets Locally Using `chezmoi secret edit`

Chezmoi has a **built-in secret editor**:

```bash
chezmoi secret edit OPENAI_API_KEY
```

* Chezmoi will:

  1. Decrypt the current value using your Age key.
  2. Open it in your editor (e.g., `vim`, `nano`).
  3. Re-encrypt it automatically when you save and exit.

> ✅ No manual `age --encrypt` needed.

* You can also specify the editor explicitly:

```bash
EDITOR=vim chezmoi secret edit OPENAI_API_KEY
```

---

## 3️⃣ Propagate Changes Back to GitHub

Once the secret is updated:

```bash
cd ~/path/to/chezmoi/repo
git add .
git commit -m "Rotate OPENAI_API_KEY"
git push origin main
```

* Chezmoi already handled the encryption. The repo only stores the **encrypted secret**, never plaintext.

---

## 4️⃣ Apply Changes Locally

On your own system:

```bash
chezmoi apply
```

* The decrypted secret is automatically written into your local environment (e.g., `~/.env`), replacing the old value.
* Any apps that use `OPENAI_API_KEY` immediately see the rotated value.

---

### ✅ Advantages

1. **No manual decryption/re-encryption.**
2. **Secrets never touch disk in plaintext**, except temporarily in memory/editor.
3. Works **with multiple secrets** at once.
4. Integrates directly with your existing `justfile` workflow — just make sure the Age key is present before running `chezmoi apply`.

---

So instead of the old workflow:

```
age --decrypt → edit → age --encrypt → git commit
```

You now just do:

```
chezmoi secret edit OPENAI_API_KEY → git commit → chezmoi apply
```

Chezmoi handles the encryption automatically.

---

If you want, I can **rewrite your tutorial for secret rotation** to use `chezmoi secret edit`, so a new user can rotate keys safely without touching `.age` files manually. It would completely replace the previous manual rotation instructions.

Do you want me to do that?
