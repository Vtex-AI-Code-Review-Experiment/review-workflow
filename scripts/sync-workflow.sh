#!/bin/bash

# Script para adicionar o workflow ai-review.yml em todos os repositórios da organização
# Uso: ./sync-workflow.sh <GITHUB_TOKEN>

if [ -z "$1" ]; then
  echo "Uso: ./sync-workflow.sh <GITHUB_TOKEN>"
  exit 1
fi

TOKEN="$1"
ORG="Vtex-AI-Code-Review-Experiment"
TEMPLATE_REPO="review-workflow"
FILE_PATH=".github/workflows/ai-review.yml"
BRANCH="main"

# Conteúdo do workflow
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

# Codificar em base64
CONTENT_BASE64=$(echo -n "$WORKFLOW_CONTENT" | base64 -w 0)

echo "Buscando repositórios da organização $ORG..."
REPOS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/$ORG/repos?per_page=100" | \
  jq -r '.[].name' | tr -d '\r')

echo "Repositórios encontrados:"
echo "$REPOS"
echo ""

for REPO in $REPOS; do
  # Pular o repositório template (já tem o workflow)
  if [ "$REPO" = "$TEMPLATE_REPO" ]; then
    echo "⏭ Pulando $REPO (repositório template)"
    continue
  fi

  echo "Criando workflow em $ORG/$REPO..."
  
  # Obter a branch padrão do repositório
  DEFAULT_BRANCH=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$ORG/$REPO" | jq -r '.default_branch')
  
  echo "  ℹ Branch padrão: $DEFAULT_BRANCH"
  
  # Verificar se o arquivo já existe
  EXISTING=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$ORG/$REPO/contents/$FILE_PATH?ref=$DEFAULT_BRANCH")
  
  SHA=$(echo "$EXISTING" | jq -r '.sha // empty')
  
  if [ -n "$SHA" ]; then
    echo "  ℹ Arquivo já existe, atualizando..."
    # Atualizar arquivo existente
    RESPONSE=$(curl -s -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/$ORG/$REPO/contents/$FILE_PATH" \
      -d "{\"message\":\"chore: update AI code review workflow\",\"content\":\"$CONTENT_BASE64\",\"sha\":\"$SHA\",\"branch\":\"$DEFAULT_BRANCH\"}")
  else
    # Criar novo arquivo
    RESPONSE=$(curl -s -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/$ORG/$REPO/contents/$FILE_PATH" \
      -d "{\"message\":\"chore: add AI code review workflow\",\"content\":\"$CONTENT_BASE64\",\"branch\":\"$DEFAULT_BRANCH\"}")
  fi
  
  # Verificar resultado
  if echo "$RESPONSE" | jq -e '.content.name' > /dev/null 2>&1; then
    echo "  ✓ Workflow criado/atualizado em $REPO"
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // "erro desconhecido"')
    echo "  ✗ Erro em $REPO: $ERROR"
  fi
  
  sleep 1
done

echo ""
echo "Concluído!"
