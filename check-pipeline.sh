#!/bin/bash

echo "🔍 Verificando configuração atual do pipeline BIA"

echo "📋 Verificando stacks CloudFormation..."
aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --region us-east-1 \
    --query 'StackSummaries[?contains(StackName, `bia`) || contains(StackName, `BIA`)].{Nome:StackName,Status:StackStatus,Criado:CreationTime}' \
    --output table

echo ""
echo "📋 Verificando projetos CodeBuild..."
aws codebuild list-projects --region us-east-1 2>/dev/null | grep -i bia || echo "Sem permissão ou nenhum projeto encontrado"

echo ""
echo "📋 Verificando pipelines CodePipeline..."
aws codepipeline list-pipelines --region us-east-1 2>/dev/null | grep -i bia || echo "Sem permissão ou nenhum pipeline encontrado"

echo ""
echo "📋 Verificando repositórios ECR..."
aws ecr describe-repositories --region us-east-1 --query 'repositories[?repositoryName==`bia`].{Nome:repositoryName,URI:repositoryUri,Criado:createdAt}' --output table

echo ""
echo "📋 Verificando últimas imagens no ECR..."
aws ecr describe-images \
    --repository-name bia \
    --region us-east-1 \
    --query 'sort_by(imageDetails,&imagePushedAt)[-5:].{Tag:imageTags[0],Pushed:imagePushedAt,Size:imageSizeInBytes}' \
    --output table 2>/dev/null || echo "Erro ao acessar imagens do ECR"

echo ""
echo "🔧 Para configurar um novo pipeline, execute:"
echo "   export GITHUB_TOKEN=seu_token_aqui"
echo "   ./deploy-pipeline.sh"
