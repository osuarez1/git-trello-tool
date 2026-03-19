#!/bin/bash

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SECRETS_FILE="$HOME/.trello_secrets"
REPO_URL="https://raw.githubusercontent.com/osuarez1/git-trello-tool/main"

echo -e "${BLUE}🚀 Starting Git-Trello Installation...${NC}"

# --- 1. CREDENTIALS SETUP ---
if [ -f "$SECRETS_FILE" ]; then
    echo -e "${YELLOW}⚠️  Found existing credentials at $SECRETS_FILE${NC}"
    read -p "Do you want to overwrite it with a new template? (y/N): " OVERWRITE
    if [[ "$OVERWRITE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        curl -s "$REPO_URL/credentials.example" -o "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
        echo -e "${GREEN}✅ New template created. Please edit it with your keys.${NC}"
    else
        echo "Keeping existing credentials."
    fi
else
    echo -e "${BLUE}Creating new credentials file...${NC}"
    curl -s "$REPO_URL/credentials.example" -o "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    echo -e "${GREEN}✅ Created $SECRETS_FILE. Please add your Trello keys after this install.${NC}"
fi

# --- 2. DOWNLOAD & FOLDER SETUP ---
echo -e "\n${BLUE}Downloading latest scripts...${NC}"
mkdir -p .git-trello/hooks
mkdir -p .git-trello/bin

curl -s "$REPO_URL/bin/git-trello" -o .git-trello/bin/git-trello
curl -s "$REPO_URL/hooks/post-commit" -o .git-trello/hooks/post-commit
curl -s "$REPO_URL/hooks/pre-push" -o .git-trello/hooks/pre-push
curl -s "$REPO_URL/hooks/prepare-commit-msg" -o .git-trello/hooks/prepare-commit-msg

chmod +x .git-trello/bin/git-trello
chmod +x .git-trello/hooks/*
echo -e "${GREEN}✅ Download complete.${NC}"

# --- 3. GIT CONFIGURATION ---
echo -e "\n${BLUE}Configuring local Git repository...${NC}"
git config core.hooksPath .git-trello/hooks
git config alias.trello "!$(pwd)/.git-trello/bin/git-trello"
git config alias.ts "!$(pwd)/.git-trello/bin/git-trello start"
git config alias.tc "!$(pwd)/.git-trello/bin/git-trello comment"
git config alias.tm "!$(pwd)/.git-trello/bin/git-trello members"
git config alias.td "!$(pwd)/.git-trello/bin/git-trello doing"
git config alias.tt "!$(pwd)/.git-trello/bin/git-trello todo"
git config alias.tb "!$(pwd)/.git-trello/bin/git-trello branch"
git config alias.tl "!$(pwd)/.git-trello/bin/git-trello list"
echo -e "${GREEN}✅ Aliases and hooks configured.${NC}"

# --- 4. GITIGNORE SETUP ---
echo -e "\n${BLUE}Securing .gitignore...${NC}"
GITIGNORE_FILE=".gitignore"
IGNORE_ENTRY=".git-trello/"

if grep -qs "^$IGNORE_ENTRY" "$GITIGNORE_FILE"; then
    echo -e "${YELLOW}⚠️  $IGNORE_ENTRY is already in $GITIGNORE_FILE${NC}"
else
    echo "$IGNORE_ENTRY" >> "$GITIGNORE_FILE"
    echo -e "${GREEN}✅ Added $IGNORE_ENTRY to $GITIGNORE_FILE to prevent accidental commits.${NC}"
fi

echo -e "\n${GREEN}✅ Installation Complete for this repository!${NC}"
echo "Remember to visit https://trello.com/app-key to get your credentials."