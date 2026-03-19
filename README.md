# 🚀 Git-Trello Tooling (Community Edition)

A professional command-line automation suite designed to bridge the gap between Git (Bitbucket) development workflows and Trello project management. Licensed under GPL-v2.

This tool handles the "boring stuff"—Trello card creation, strict branch naming, automatic commit tagging, card list movement, and API integrations—so you can stay in your terminal and focus on writing code.

## ✨ Key Features

* **Instant Workflows (`git ts` & `git tb`)**: Create a new Trello card or link to an existing one. Automatically assigns it to you, extracts the 24-character internal ID, and generates a perfectly formatted Git branch (`type/ID-description`).
* **Seamless Communication (`git tc` & `git tm`)**: Fetch assigned members or post comments directly to your active Trello card without leaving the command line. Comments automatically include a link back to your Bitbucket branch.
* **Instant Transitions (`git td` & `git tt`)**: Move your active card between "To Do" and "Doing" lists instantly, leaving an automated audit trail comment behind.
* **Smart Language Detection**: Automatically scans your repository for files like `package.json`, `requirements.txt`, or `Gemfile` and tags your Trello cards with the detected primary language.
* **Local, Non-Destructive Installation**: Installs silently into a hidden `.git-trello/` directory specific to your current repository, ensuring it never conflicts with your global Git configuration or other team members' setups.
* **Automated Git Hooks**:
    * **`prepare-commit-msg`**: Automatically injects your Trello Card ID into the bottom of every commit message.
    * **`pre-push`**: Acts as a local bouncer, blocking pushes to Bitbucket if your feature branch does not contain a valid 24-character Trello ID.
* **CI/CD Readiness**: Generates standard branch names and commit metadata, making it trivial to configure automatic Trello list movement in Bitbucket Pipelines.

---

## 📋 Prerequisites

Before installing, ensure your system has the following dependencies:

* `git`
* `curl`
* `jq` (Command-line JSON processor)

You will also need your **Trello API Key and Token**, which you can generate here: [https://trello.com/app-key](https://trello.com/app-key)

---

## 📦 Installation

This tool is designed to be installed **per-repository**. Navigate to the root folder of the project you are working on and run the web installer:

```bash
curl -s https://raw.githubusercontent.com/osuarez1/git-trello-tool/main/install.sh | bash
```

### What the installer does:

1. Creates a hidden `.git-trello/` directory in your project.
2. Downloads the latest executables and Git hooks.
3. Automatically adds `.git-trello/` to your `.gitignore` to prevent accidental commits.
4. Maps local Git aliases (`ts`, `tb`, `tc`, `tm`, `td`, `tt`) specifically for this repository.
5. Prompts you to configure your `~/.trello_secrets` file if it doesn't exist.

---

## ⚙️ Configuration

The installer will generate a secure `~/.trello_secrets` file in your home directory (with `chmod 600` permissions so only you can read it). Open this file in your favorite text editor and add your credentials:

```bash
# ~/.trello_secrets
export API_KEY="your_trello_api_key_here"
export TOKEN="your_trello_api_token_here"
export TARGET_BOARD_ID="your_board_id"
export TARGET_LIST_ID="your_to_do_list_id"
export TARGET_DOING_LIST_ID="your_doing_list_id"
```

*(Because this file lives in your home directory, you only have to configure it once, and all your local repository installations will share it!)*

### Finding Your Trello IDs via Terminal
Instead of hunting through the Trello UI, you can find your Board and List IDs directly from the command line once your `API_KEY` and `TOKEN` are saved in your secrets file.

**1. Find your Board ID:**
```bash
source ~/.trello_secrets && curl -s "https://api.trello.com/1/members/me/boards?fields=name,id&key=$API_KEY&token=$TOKEN" | jq -r '.[] | "Board: \(.name) \nID: \(.id)\n---"'
```
*(Copy the ID of your target board and paste it into `TARGET_BOARD_ID`)*

**2. Find your List IDs:**
```bash
source ~/.trello_secrets && curl -s "https://api.trello.com/1/boards/$TARGET_BOARD_ID/lists?fields=name,id&key=$API_KEY&token=$TOKEN" | jq -r '.[] | "List Name: \(.name) \nList ID:   \(.id)\n---"'
```
*(Copy the IDs for your "To Do" and "Doing" lists and add them to your secrets file)*

---

## 🛠️ Usage Guide

Once installed, use these custom Git aliases anywhere inside your repository:

### `git ts` (Trello Start)
Initiates a new piece of work. It will prompt you for the task type, title, and description, then automatically create the Trello card and check out your new branch.

### `git tb [card_id]` (Trello Branch)
Creates a new standardized branch linked to an *existing* Trello card. It fetches the card title automatically to format the branch name.

### `git tc [message]` (Trello Comment)
Posts a comment to the Trello card associated with your current branch. It automatically appends a Bitbucket link to your branch.
* *Example:* `git tc "Just pushed the initial database migrations."`

### `git tm` (Trello Members)
Fetches and displays the names and `@usernames` of everyone currently assigned to the Trello card linked to your active branch.

### `git td` (Trello Doing)
Moves the Trello card linked to your current branch to the "Doing" list and posts a comment noting who moved it.

### `git tt` (Trello To Do)
Moves the Trello card linked to your current branch back to the "To Do" list and posts a comment noting who moved it.

### `git tl` (Trello List)
Fetches and displays all cards currently sitting in your configured "To Do" list. It prints the 24-character Card IDs in yellow so you can easily copy them to use with the `git tb` command.
---

## 🤝 Contributing & License

This project is licensed under the GNU General Public License v2.0 (GPL-v2). Feel free to fork, modify, and submit pull requests!

---
