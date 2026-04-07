ORG="Vtex-AI-Code-Review-Experiment"
LABEL_NAME="ai-review"
LABEL_COLOR="#ff7221"
LABEL_DESCRIPTION="Trigger AI code review"

TOKEN="$1"

if [ -z "$TOKEN" ]; then
  echo "Uso: ./sync-labels.sh <GITHUB_TOKEN>"
  echo "Crie um token em: https://github.com/settings/tokens"
  echo "Permissões necessárias: repo (Full control of private repositories)"
  exit 1
fi

echo "Buscando repositórios da organização $ORG..."

# Listar todos os repositórios da organização
REPOS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/$ORG/repos?per_page=100" | \
  jq -r '.[].name' | tr -d '\r')

if [ -z "$REPOS" ]; then
  echo "Nenhum repositório encontrado ou erro de autenticação."
  exit 1
fi

echo "Repositórios encontrados:"
echo "$REPOS"
echo ""

# Criar label em cada repositório
for RAW_REPO in $REPOS; do
  # Limpar o nome do repositório de qualquer caracter não-imprimível/espaço
  REPO=$(echo "$RAW_REPO" | tr -dc '[:alnum:]-_.')
  
  if [ -z "$REPO" ]; then
    continue
  fi

  echo "Criando label '$LABEL_NAME' em $ORG/$REPO..."
  
  # Preparar JSON seguro
  JSON_DATA=$(jq -n \
    --arg name "$LABEL_NAME" \
    --arg color "$LABEL_COLOR" \
    --arg desc "$LABEL_DESCRIPTION" \
    '{name: $name, color: $color, description: $desc}')

  RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/$ORG/$REPO/labels" \
    -d "$JSON_DATA")
  
  # Verificar se já existe
  if echo "$RESPONSE" | grep -q "already_exists"; then
    echo "  ✓ Label já existe em $REPO"
  elif echo "$RESPONSE" | grep -q "\"name\": \"$LABEL_NAME\"" || echo "$RESPONSE" | grep -q "\"name\":\"$LABEL_NAME\""; then
    echo "  ✓ Label criada em $REPO"
  else
    echo "  ✗ Erro em $REPO: $(echo "$RESPONSE" | jq -r '.message // "erro desconhecido"')"
    # Tentar atualizar a label caso ela exista com cor/descrição diferente
    if echo "$RESPONSE" | grep -q "Validation Failed"; then
      echo "  ℹ Tentando atualizar a label existente..."
      curl -s -X PATCH \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$ORG/$REPO/labels/$LABEL_NAME" \
        -d "$JSON_DATA" > /dev/null
    fi
  fi
  sleep 1
done

echo ""
echo "Sincronização concluída!"
