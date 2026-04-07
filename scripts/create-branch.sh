#!/bin/bash

# Script para criar branch "gemini-review" a partir da branch "baseline"
# em repositórios da organização
# Uso: ./create-branch.sh <GITHUB_TOKEN>

if [ -z "$1" ]; then
  echo "Uso: ./create-branch.sh <GITHUB_TOKEN>"
  exit 1
fi

TOKEN="$1"
ORG="Vtex-AI-Code-Review-Experiment"
SOURCE_BRANCH="baseline"
NEW_BRANCH="gemini-review"

REPOS="Electron.NET RestSharp AMSITrigger query shoreline sdui-backend django LaTeX-OCR googler prometheus gin go-querystring"

echo "Criando branch '$NEW_BRANCH' a partir de '$SOURCE_BRANCH'..."
echo ""

for REPO in $REPOS; do
  echo "=== $ORG/$REPO ==="

  # Obter o SHA da branch baseline
  SHA=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$ORG/$REPO/git/ref/heads/$SOURCE_BRANCH" | jq -r '.object.sha // empty')

  if [ -z "$SHA" ]; then
    echo "  ✗ Branch '$SOURCE_BRANCH' não encontrada"
    echo ""
    continue
  fi

  echo "  ℹ SHA de '$SOURCE_BRANCH': $SHA"

  # Criar a nova branch
  RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/$ORG/$REPO/git/refs" \
    -d "{\"ref\":\"refs/heads/$NEW_BRANCH\",\"sha\":\"$SHA\"}")

  if echo "$RESPONSE" | jq -e '.ref' > /dev/null 2>&1; then
    echo "  ✓ Branch '$NEW_BRANCH' criada"
  elif echo "$RESPONSE" | grep -q "Reference already exists"; then
    echo "  ℹ Branch '$NEW_BRANCH' já existe"
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.message // "erro desconhecido"')
    echo "  ✗ Erro: $ERROR"
  fi

  echo ""
  sleep 1
done

echo "Concluído!"
