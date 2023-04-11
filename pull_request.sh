#!/bin/sh

get_pull_request_info() {
  pull_request=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/repos/"${GITHUB_REPOSITORY}"/pulls/${PULL_REQUEST_NUMBER})
  title=$(echo "$pull_request" | jq -r '.title')
  body=$(echo "$pull_request" | jq -r '.body')
  url=$(echo "$pull_request" | jq -r '.html_url')
  user=$(echo "$pull_request" | jq -r '.user.login')
  assignees=$(echo "$pull_request" | jq -r '.assignees[].login')
  reviewers=$(echo "$pull_request" | jq -r '.requested_reviewers[].login')
  labels=$(echo "$pull_request" | jq -r '.labels[].name')

  if [ -z "$issue_id" ]; then
    echo "Erro ao obter informações do pull request!"
    exit 1
  fi

  echo "title: $title"
}

create_linear_issue() {
  issue="{\"title\":\"${title}\",\"description\":\"${body}\",\"priority\":\"high\",\"assigneeIds\":[\"${user}\"]}"
  if [ -n "$reviewers" ]; then
    issue="$issue,\"userIds\":[\"${reviewers// /\",\"}\"]"
  fi
  response=$(curl -s -H "Authorization: Bearer $LINEAR_API_KEY" -H "Content-Type: application/json" -X POST -d "$issue" https://api.linear.app/v1/issues)
  issue_id=$(echo "$response" | jq -r '.id')

  if [ -z "$issue_id" ]; then
    echo "Erro ao criar issue no Linear"
    exit 1
  fi
}

mark_reviewers_in_linear_issue() {
  if [ -n "$reviewers" ]; then
    message="Revisores: @$reviewers"
    curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" $SLACK_WEBHOOK_URL
    curl -s -H "Authorization: Bearer $LINEAR_API_KEY" -H "Content-Type: application/json" -X POST -d "{\"note\":\"${message}\"}" https://api.linear.app/v1/issues/${issue_id}/comments
  fi

  if [ -z "$issue_id" ]; then
    echo "Erro ao criar issue no Linear"
    exit 1
  fi
}

send_slack_notification() {
  message="Novo pull request: <$url|${title}>"
  if [ -n "$assignees" ]; then
    message="$message (para @$assignees)"
  fi
  if [ -n "$labels" ]; then
    message="$message [${labels}]"
  fi
  curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" $SLACK_WEBHOOK_URL

  if [ -z "$issue_id" ]; then
    echo "Erro ao criar issue no Linear"
    exit 1
  fi
}

get_pull_request_info
create_linear_issue
mark_reviewers_in_linear_issue
send_slack_notification
