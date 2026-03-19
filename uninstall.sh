#!/bin/bash
# Git-Trello Uninstaller

echo "🗑️  Uninstalling Git-Trello Tool..."

# Remove local files
if [ -d ".git-trello" ]; then
    rm -rf .git-trello
    echo "✅ Removed .git-trello directory."
fi

# Unset Git configs
git config --unset core.hooksPath
git config --unset alias.ts
git config --unset alias.tc
git config --unset alias.tm
git config --unset alias.td
git config --unset alias.tt
git config --unset alias.tb
git config --unset alias.tl
echo "✅ Unset Git aliases and hooks."

# Clean up .gitignore
if [ -f ".gitignore" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/.git-trello\//d' .gitignore
    else
        sed -i '/.git-trello\//d' .gitignore
    fi
    echo "✅ Cleaned up .gitignore."
fi

echo -e "\033[0;32mDone! The tool has been removed from this repository.\033[0m"