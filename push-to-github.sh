#!/bin/bash
# Quick push script for xray-multiprofile

echo "GitHub Push Helper"
echo "=================="
echo ""
echo "Repository: https://github.com/kaccang/xray-multiprofile"
echo ""
echo "To push, you need a GitHub Personal Access Token:"
echo ""
echo "1. Go to: https://github.com/settings/tokens/new"
echo "2. Token name: xray-multiprofile-upload"
echo "3. Expiration: 90 days"
echo "4. Select scopes: [x] repo (full control)"
echo "5. Click 'Generate token'"
echo "6. Copy the token (starts with ghp_...)"
echo ""
read -p "Paste your GitHub token here: " GITHUB_TOKEN
echo ""

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: Token is empty"
    exit 1
fi

echo "Setting remote URL with token..."
cd /root/work
git remote set-url origin "https://${GITHUB_TOKEN}@github.com/kaccang/xray-multiprofile.git"

echo "Pushing to GitHub..."
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Repository uploaded to:"
    echo "   https://github.com/kaccang/xray-multiprofile"
    echo ""
    echo "Files uploaded:"
    git ls-files
else
    echo ""
    echo "❌ Push failed. Please check your token."
fi
