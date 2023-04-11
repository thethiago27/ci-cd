#!/bin/sh

# Adiciona a chave SSH ao agente
eval "$(ssh-agent -s)"
ssh-add <(echo "$SSH_PRIVATE_KEY")

# Configura o host SSH para o GitHub
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "StrictHostKeyChecking no" >> ~/.ssh/config
ssh-keyscan github.com >> ~/.ssh/known_hosts

# Obtem as informações do pull request
pull_request=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PULL_REQUEST_NUMBER})
title=$(echo "$pull_request" | jq -r '.title')
body=$(echo "$pull_request" | jq -r '.body')
url=$(echo "$pull_request" | jq -r '.html_url')
user=$(echo "$pull_request" | jq -r '.user.login')
assignees=$(echo "$pull_request" | jq -r '.assignees[].login')
reviewers=$(echo "$pull_request" | jq -r '.requested_reviewers[].login')
labels=$(echo "$pull_request" | jq -r '.labels[].name')

# Cria o issue no Linear
issue="{\"title\":\"${title}\",\"description\":\"${body}\",\"priority\":\"high\",\"assigneeIds\":[\"${user}\"]}"
if [ -n "$reviewers" ]; then
  issue="$issue,\"userIds\":[\"${reviewers// /\",\"}\"]"
fi
response=$(curl -s -H "Authorization: Bearer $LINEAR_API_KEY" -H "Content-Type: application/json" -X POST -d "$issue" https://api.linear.app/v1/issues)

# Obtem o id do issue criado
issue_id=$(echo "$response" | jq -r '.id')

# Marca os revisores do pull request no issue do Linear
if [ -n "$reviewers" ]; then
  message="Revisores: @$reviewers"
  curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" $SLACK_WEBHOOK_URL
  curl -s -H "Authorization: Bearer $LINEAR_API_KEY" -H "Content-Type: application/json" -X POST -d "{\"note\":\"${message}\"}" https://api.linear.app/v1/issues/${issue_id}/comments
fi

# Envia uma notificação no Slack
message="Novo pull request: <$url|${title}>"
if [ -n "$assignees" ]; then
  message="$message (para @$assignees)"
fi
if [ -n "$labels" ]; then
  message="$message [${labels}]"
fi
curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" $SLACK_WEBHOOK_URL