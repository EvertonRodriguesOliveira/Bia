#!/bin/bash

echo "🚀 Configurando Pipeline BIA"

# Verificar se o token do GitHub foi fornecido
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Erro: Variável GITHUB_TOKEN não definida"
    echo "💡 Execute: export GITHUB_TOKEN=seu_token_aqui"
    echo "💡 Para criar um token: https://github.com/settings/tokens"
    echo "💡 Permissões necessárias: repo, admin:repo_hook"
    exit 1
fi

echo "📋 Validando template CloudFormation..."
aws cloudformation validate-template \
    --template-body file://aws/pipeline-template.yaml \
    --region us-east-1

if [ $? -ne 0 ]; then
    echo "❌ Template inválido"
    exit 1
fi

echo "✅ Template válido"

echo "🚀 Fazendo deploy do pipeline..."
aws cloudformation deploy \
    --template-file aws/pipeline-template.yaml \
    --stack-name bia-pipeline-stack \
    --parameter-overrides \
        GitHubOwner=EvertonRodriguesOliveira \
        GitHubRepo=Bia \
        GitHubBranch=main \
        GitHubToken=$GITHUB_TOKEN \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1

if [ $? -eq 0 ]; then
    echo "✅ Pipeline configurado com sucesso!"
    echo ""
    echo "📋 Obtendo informações do pipeline..."
    
    # Obter outputs do stack
    aws cloudformation describe-stacks \
        --stack-name bia-pipeline-stack \
        --region us-east-1 \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    echo ""
    echo "🎉 Pipeline configurado e pronto para uso!"
    echo "💡 O webhook foi automaticamente configurado no GitHub"
    echo "💡 Próximo commit irá disparar o pipeline automaticamente"
else
    echo "❌ Erro no deploy do pipeline"
    exit 1
fi
