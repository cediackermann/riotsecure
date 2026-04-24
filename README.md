# RIoT AI Setup Guide

> Step-by-step instructions for setting up a Mac Mini from scratch.

## Presentation Link

[Link](https://docs.google.com/presentation/d/12XRHySp_W6Mrh64nA_6Hi3s8XvliUoANP-p_ha0FHEA/edit?usp=sharing)

---

## Quick Start

### Single device (Ollama + Onyx on the same machine)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup.sh)
```

### Two devices (Ollama on one machine, Onyx on another)

**On the Ollama device** — installs Ollama and the RIoT models, no Docker needed:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_ollama.sh)
```

At the end the script prints the exact command to run on the Onyx device.

**On the Onyx device** — installs Docker and Onyx, auto-detects the Ollama device on the network:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_onyx.sh)
```

The script scans the local network for Ollama. If it can't find it automatically, it will ask for the IP address.

---

## Status & Maintenance

**Check everything is working:**

```bash
cd ~/riotsecure && ./check-status.sh
```

**Update Ollama models:**

```bash
cd ~/riotsecure && ./updateModels.sh modelfiles
```

**Uninstall:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/cleanup.sh)
```

---

## Manual Steps Reference

The scripts pause and prompt when manual action is required. Here is what to expect at each pause.

### Docker Desktop resources

Go to **Docker → Settings → Resources** and set:

| Setting          | Value                        |
| ---------------- | ---------------------------- |
| CPU limit        | MAX                          |
| Memory limit     | 20 GB (or MAX if less than 20 GB available) |
| Disk usage limit | MAX                          |

Hit **Apply & Restart**.

### Onyx installer prompts

1. Press **Enter** to acknowledge
2. Choose **2** for Standard
3. Press **Enter** for Edge

### Web interface configuration

1. Open `http://localhost:3000` and create an admin account.
2. Go to **Admin Panel → Language Models**:
   - Select **Ollama** as provider and give it a name
   - Set the API base URL to the address shown by the setup script
   - Refresh the model list, select at least the three RIoT models, and click **Connect**
3. Go to **Admin Panel → Chat Preferences → System Prompt → Modify Prompt**, delete the entire prompt, and save.

### RAG content upload

**Option A — File upload (recommended)**

```bash
cd ~/riotsecure && ./fetchContent.sh riot-sources.txt
```

Then in the web interface: **Admin Panel → Add Connector → File**, upload the files from `~/riotsecure/content`, and wait ~30 seconds for indexing.

**Option B — URL connector**

In the web interface: **Admin Panel → Add Connector → Web**, add each URL from `riot-sources.txt` as a separate connector using scrape method **Single**, and wait ~30 seconds for indexing.
