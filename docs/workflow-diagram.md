# Gemini Code Review Workflow

## Fluxo Principal

```mermaid
flowchart TD
    A[PR Created/Updated<br/>with label 'ai-review'] --> B[Checkout PR Code]
    B --> C[Get Changed Files]
    
    C --> D{Has files<br/>to review?}
    D -->|No| E[End - Skip Review]
    D -->|Yes| F[Create Prompt File]
    
    F --> G[Estimate Input Tokens<br/>via Gemini API]
    G --> H[Send to Gemini API<br/>gemini-2.5-flash]
    
    H --> I[Extract Review Text]
    I --> J[Calculate Token Costs<br/>USD & BRL]
    
    J --> K[Parse Table Output]
    K --> L{Found inline<br/>comments?}
    
    L -->|Yes| M[Create PR Review<br/>with Inline Comments<br/>via GitHub API]
    L -->|No| N[Skip Inline Comments]
    
    M --> O[Post Summary Comment<br/>on PR]
    N --> O
    
    O --> P[End]

    subgraph "File Filtering"
        C1[git diff --name-only] --> C2[Exclude binaries<br/>.png, .jpg, .pdf, etc.]
        C2 --> C3[Exclude lock files<br/>package-lock.json, etc.]
    end

    subgraph "Gemini API Response"
        I1[Review Text<br/>with Occurrence Table] --> I2[Token Usage Metadata]
    end

    subgraph "Parser Logic"
        K1[Read table rows] --> K2[Extract: ID, Category,<br/>Severity, File, Line, Desc]
        K2 --> K3[Build JSON array<br/>for GitHub API]
    end
```

## Steps do Workflow

| Step | Nome | Descrição |
|------|------|-----------|
| 1 | Checkout PR code | Clona o repositório com histórico completo |
| 2 | Get changed files and diff | Lista arquivos alterados, excluindo binários e lock files |
| 3 | Create prompt file | Cria arquivo com prompt de code review |
| 4 | Estimate input tokens | Conta tokens antes de enviar (opcional) |
| 5 | Send to Gemini API | Envia código + prompt para Gemini 2.5 Flash |
| 6 | Parse table and create inline comments | Extrai dados da tabela e cria comentários inline |
| 7 | Comment on PR | Posta review completo + custos no PR |

## Estrutura de Saída do Gemini

```
| ID | Category | Severity | File | Approx. line | Short description |
|----|----------|----------|------|--------------|-------------------|
| 1  | Functional.Logic | Block | src/app.js | 42 | Missing null check |

---
Detalhes do Finding #1:
- Category: Functional.Logic
- Severity: Block
- File: src/app.js
- Approx. line: 42
- Description: [Functional.Logic] Missing null check before accessing property
- Suggestion: Add null/undefined check

---
Final summary:
- PR risk: Medium
- Main defect categories found: Functional.Logic
- Blocking items: #1
```

## Custos (Gemini 2.5 Flash)

| Tipo | Preço por 1M tokens (USD) |
|------|---------------------------|
| Input | $0.15 |
| Thinking | $3.50 |
| Output | $0.60 |
