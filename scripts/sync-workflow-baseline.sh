#!/bin/bash

# Script para adicionar o workflow ai-review.yml na branch BASELINE
# Uso: ./sync-workflow-baseline.sh <GITHUB_TOKEN>

if [ -z "$1" ]; then
  echo "Uso: ./sync-workflow-baseline.sh <GITHUB_TOKEN>"
  exit 1
fi

TOKEN="$1"
ORG="Vtex-AI-Code-Review-Experiment"
FILE_PATH=".github/workflows/ai-review.yml"
TARGET_BRANCH="baseline"

REPOS="Electron.NET RestSharp AMSITrigger query shoreline sdui-backend django LaTeX-OCR googler prometheus gin go-querystring"

WORKFLOW_CONTENT='name: Trigger AI Code Review

on:
  pull_request:
    types: [labeled]

permissions:
  contents: read
  pull-requests: write

jobs:
  call-gemini:
    if: github.event.label.name == '\''ai-review'\''
    uses: Vtex-AI-Code-Review-Experiment/review-workflow/.github/workflows/gemini-template.yml@main
    secrets:
      GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
'

CONTENT_BASE64=$(echo -n "$WORKFLOW_CONTENT" | base64 -w 0)

echo "Adicionando workflow na branch '$TARGET_BRANCH'..."
echo ""

for REPO in $REPOS; do
  echo "=== $ORG/$REPO ==="

  # Verificar se a branch baseline existe
  BRANCH_CHECK=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$ORG/$REPO/git/ref/heads/$TARGET_BRANCH")

  if echo "$BRANCH_CHECK" | jq -e '.ref' > /dev/null 2>&1; then
    echo "  ℹ Branch '$TARGET_BRANCH' encontrada"
  else
    echo "  ✗ Branch '$TARGET_BRANCH' não existe"
    echo ""
    continue
  fi

  # Verificar se o arquivo já existe
  EXISTING=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$ORG/$REPO/contents/$FILE_PATH?ref=$TARGET_BRANCH")

  SHA=$(echo "$EXISTING" | jq -r '.sha // empty')

  if [ -n "$SHA" ]; then
    echo "  ℹ Arquivo já existe, atualizando..."
    RESPONSE=$(curl -s -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/$ORG/$REPO/contents/$FILE_PATH" \
      -d "{\"message\":\"chore: add AI code review workflow to baseline\",\"content\":\"$CONTENT_BASE64\",\"sha\":\"$SHA\",\"branch\":\"$TARGET_BRANCH\"}")
  else
    RESPONSE=$(curl -s -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/$ORG/$REPO/contents/$FILE_PATH" \
      -d "{\"message\":\"chore: add AI code review workflow to baseline\",\"content\":\"$CONTENT_BASE64\",\"branch\":\"$TARGET_BRANCH\"}")
  fi

  if echo "$RESPONSE" | jq -e '.content.name' > /dev/null 2>&1; then
    echo "  ✓ Workflow adicionado na branch '$TARGET_BRANCH'"
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // "erro desconhecido"')
    echo "  ✗ Erro: $ERROR"
  fi

  echo ""
  sleep 1
done

echo "Concluído!"
