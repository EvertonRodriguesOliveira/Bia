#!/bin/bash

echo "🔧 Tentando disparar o pipeline BIA existente..."

# Método 1: Tentar via CodePipeline (se existir)
echo "📋 Tentativa 1: Disparar via CodePipeline..."
aws codepipeline start-pipeline-execution --name bia --region us-east-1 2>/dev/null && echo "✅ Pipeline disparado via CodePipeline" || echo "❌ Falha ou sem permissão para CodePipeline"

# Método 2: Tentar via CodeBuild direto
echo "📋 Tentativa 2: Disparar via CodeBuild..."
aws codebuild start-build --project-name bia-build --region us-east-1 2>/dev/null && echo "✅ Build disparado via CodeBuild" || echo "❌ Falha ou sem permissão para CodeBuild"

# Método 3: Verificar se há outros projetos
echo "📋 Tentativa 3: Verificar outros projetos..."
aws codebuild list-projects --region us-east-1 2>/dev/null | grep -i bia || echo "❌ Sem permissão para listar projetos"

# Método 4: Tentar com nomes alternativos
echo "📋 Tentativa 4: Tentar nomes alternativos..."
for project in "bia-pipeline" "bia-build-pipeline" "BIA" "bia-codebuild"; do
    echo "  Tentando: $project"
    aws codebuild start-build --project-name $project --region us-east-1 2>/dev/null && echo "  ✅ Sucesso com $project" && break || echo "  ❌ Falha com $project"
done

echo ""
echo "💡 Se nenhum método funcionou, o problema pode ser:"
echo "   1. Webhook do GitHub não configurado"
echo "   2. Pipeline pausado ou com erro"
echo "   3. Permissões insuficientes"
echo ""
echo "🔍 Verificando logs mais recentes..."
echo "   Execute: ./check-recent-logs.sh"
