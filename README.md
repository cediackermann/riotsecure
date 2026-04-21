# RIoT AI Setup Guide

> Step-by-step instructions for setting up a Mac Mini from scratch.

## Presentation Link

[Link](https://docs.google.com/presentation/d/12XRHySp_W6Mrh64nA_6Hi3s8XvliUoANP-p_ha0FHEA/edit?usp=sharing)

## Quick Start

**One-line installation** (recommended):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup.sh)
```

Or clone and run locally:

```bash
git clone https://github.com/cediackermann/riotsecure.git
cd riotsecure
./setup.sh
```

The script automates most steps and pauses for manual configuration when needed (Docker settings, web interface setup, etc.). 

**After installation**, verify everything is working:

```bash
cd ~/riotsecure
./check-status.sh
```

**To uninstall** (one-line command):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/cleanup.sh)
```

Or run locally:

```bash
cd ~/riotsecure
./cleanup.sh
```

For detailed manual instructions, continue reading below.

---

## 1. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Add Homebrew to your shell profile:

```bash
echo >> /Users/riot/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> /Users/riot/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
```

---

## 2. Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

---

## 3. Docker Desktop

```bash
brew install --cask docker-desktop
open -a Docker
```

Click through the installer and install any prompted software updates.

### Adjust Resources

Go to **Docker → Settings → Resources** and set:

| Setting          | Value |
| ---------------- | ----- |
| CPU limit        | MAX   |
| Memory limit     | 20 GB |
| Disk usage limit | MAX   |

Hit **Apply & Restart**.

---

## 4. Onyx

```bash
curl -fsSL https://onyx.app/install_onyx.sh | bash
```

When prompted:

1. Press **Enter** to acknowledge
2. Choose **2** for Standard
3. Press **Enter** for Edge

Onyx creates `~/riotsecure/onyx_data/`, which contains the Docker Compose file (useful for manually stopping or modifying images). There is also a `.env` file — leave it untouched.

### Prevent Sleep

```bash
sudo pmset -a sleep 0 disksleep 0
```

---

## 5. Ollama Models

1. Clone the repo:

   ```bash
   cd ~
   git clone https://github.com/cediackermann/riotsecure.git
   cd ~/riotsecure
   ```

2. Create models from modelfiles:

   ```bash
   ./updateModels.sh modelfiles
   ```

   The required base model is pulled automatically — just wait for it to finish.

3. Open the web interface on port **3000** and create an admin account.
4. Go to **Admin Panel → Language Models**:
   - Select **Ollama** as provider and give it a name
   - Set the API base URL to `http://host.docker.internal:11434`
   - Refresh the model list, select at least the three RIoT models, and click **Connect**
5. Go to **Admin Panel → Chat Preferences → System Prompt → Modify Prompt**, delete the entire prompt, and save.

---

## 6. RAG Content Upload

### Option A — Upload as File

1. If needed, edit the URLs in `riot-sources.txt`.

2. Fetch content:

   ```bash
   cd ~/riotsecure
   ./fetchContent.sh riot-sources.txt
   ```

3. In the web interface, go to **Admin Panel → Add Connector → File**.
4. Give the connector a name and upload the files from `~/riotsecure/content`.
5. Wait ~30 seconds for indexing to complete.

### Option B — Upload as URL

1. In the web interface, go to **Admin Panel → Add Connector → Web**.
2. Add each URL as a separate connector, using scrape method **Single**.
3. Wait ~30 seconds for indexing to complete.
