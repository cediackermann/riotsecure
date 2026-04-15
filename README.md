# RIoT AI setup

This is an instruction on how to set up a mac from scratch.

## Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

```bash
echo >> /Users/riot/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> /Users/riot/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
```

## Install Ollama

`curl -fsSL https://ollama.com/install.sh | sh`

## Install Docker

`brew install --cask docker-desktop`

`open -a Docker`

Click through the install menu and if prompted, install software update.

### Adjust resources

Docker -> Settings -> Resources:

- CPU limit: MAX
- Memory limi 20GB
- Disk usage limit: MAX

Then hit Apply & restart

## Install Onyx

`curl -fsSL https://onyx.app/install_onyx.sh | bash`

1. To acknowledge press Enter
2. Choose 2 for standard
3. Press Enter for edge

Onyx created a directory (~/onyx_data) in which you can find the docker compose to manually stop it or modify the images if needed. There is also a `.env` but we don't touch that since it is not necessary.

Disable sleeping for the mac mini `sudo pmset -a sleep 0 disksleep 0`

## Set up ollama models

1. Clone this repo into home

   ```bash
   cd ~
   git clone https://github.com/cediackermann/riotsecure.git
   cd ~/riotsecure
   ```

2. Create models from modelfiles

   ```bash
   ./updateModels.sh modelfiles
   ```

   The needed model is pulled automatically, you just need to wait until it's done.

3. Navigate to the web-interface located on port `3000`.
4. Make yourself an admin account
5. Go to Admin Panel -> Language Models
6. Select Ollama as a provider and give the provider a name.
7. Set the API base URL to `http://host.docker.internal:11434`
8. Refresh the models and select at least the three riot models and hit connect.
9. Go to Admin Panel -> Chat Preferences -> System prompt -> Modify Prompt. Delete the whole prompt and Save.

## Upload RAG files

### Upload as file

1. If needed, adjust the urls in `riot-sources.txt`
2. Run bash script to get json files

   ```bash
   cd ~/riotsecure
   ./fetchContent.sh riot-sources.txt
   ```

3. Go to the web-interface -> Admine Panel -> Add Connector -> File
4. Give the connector a name and upload the files from `~/riotsecure/content`
5. Give it a few seconds ~30 until it finished indexing.

### Upload as URL

1. Go to the web-interface -> Admine Panel -> Add Connector -> Web
2. Add every single needed URL as a connector
3. For each URL choose the scrape method `single`
4. Give it a few seconds ~30 until it finished indexing.
