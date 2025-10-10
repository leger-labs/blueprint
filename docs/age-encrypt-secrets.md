# Blueprint Homeserver Secrets Tutorial

This guide explains how to safely write and manage secrets for the Blueprint homeserver, using Age encryption and your USB key. It assumes:

* All necessary keys (Tailscale OAuth, GitHub token, etc.) have already been created elsewhere.
* You are running the preconfigured Fedora ISO with all required packages and the `justfile` already installed.

> ⚠️ This tutorial **does not cover key creation**, only secret management and workflow.

---

## 1️⃣ Generate Your Age Key

1. Create an Age identity key:

```bash
age-keygen -o ~/.config/chezmoi/key.txt
```

2. Take note of the **public key** displayed, for example:

```
# public key: <YOUR_KEY>
```

* Keep your secret key in `~/.config/chezmoi/key.txt`.

---

## 2️⃣ Prepare Your USB Key

1. Plug in your USB drive.
2. Identify the device name:

```bash
lsblk
```

3. **Backup any existing data** on the USB before formatting.
4. Format the USB (example for `ext4`, adjust device as needed):

```bash
sudo mkfs.ext4 /dev/sdX
```

5. Label the USB as `SECRET-KEY`:

```bash
sudo fatlabel /dev/sdX SECRET-KEY   # or use mkfs options if needed
```

6. Copy the Age secret key to the USB:

```bash
mkdir -p /run/media/$USER/SECRET-KEY
cp ~/.config/chezmoi/key.txt /run/media/$USER/SECRET-KEY/age-key.txt
chmod 600 /run/media/$USER/SECRET-KEY/age-key.txt
```

> ✅ The **USB file name must be `age-key.txt`**, and your `justfile` expects it exactly there.

---

## 3️⃣ Encrypt Your Secrets File

1. Suppose your secrets live in `secret.yml`. Encrypt it using your Age public key:

```bash
age --encrypt -r "<YOUR_KEY>" secret.yml > .chezmoidata.yaml.age
```

2. Move the encrypted file to the **root of your chezmoi repo**:

```bash
mv .chezmoidata.yaml.age ~/path/to/chezmoi/repo/
```

---

## 4️⃣ Configure `.chezmoi.yaml.tmpl`

Update the **first few lines** of `.chezmoi.yaml.tmpl` to use Age encryption and point to your secret key:

```yaml
encryption: age
age:
  identity: "{{ .chezmoi.homeDir }}/.config/chezmoi/key.txt"
  recipient: "<YOUR_KEY>"
```

> 🔑 Make sure:
>
> * `identity` points to the location of `key.txt` (your secret key).
> * `recipient` is the Age **public key** corresponding to that secret key.

---

## 5️⃣ Workflow on First Boot

Once the Fedora ISO boots:

1. **Plug in your USB key** (`SECRET-KEY`).
2. Run the post-install setup using `just`:

```bash
just setup-all
```

This performs:

1. Copies `age-key.txt` from the USB to `~/.config/chezmoi/`.
2. Applies your dotfiles using `chezmoi apply` (decrypting secrets using the Age key).
3. Sets up Tailscale with OAuth credentials.
4. Configures GitHub CLI with `GH_TOKEN`.

> ✅ All steps are automated; you don’t need to manually source secrets.

---

## 6️⃣ Important Notes

* File names must match exactly:

  * USB key file: `age-key.txt`
  * Chezmoi secret key path: `~/.config/chezmoi/key.txt`
  * Encrypted secrets: `.chezmoidata.yaml.age`

* The `.chezmoi.yaml.tmpl` must contain **your Age public key** as `<YOUR_KEY>`.

* Always **backup your USB key**; losing it means you cannot decrypt secrets.

* If you need to rotate secrets, encrypt new `.chezmoidata.yaml.age` and commit it to the repo — the workflow remains the same.
