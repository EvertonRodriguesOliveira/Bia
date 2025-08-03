#!/bin/bash

echo "=== Testando buildspec.yml localmente ==="

# Simular variáveis do CodeBuild
export CODEBUILD_RESOLVED_SOURCE_VERSION="abc1234567890"

echo "=== PRE_BUILD Phase ==="
echo "Fazendo login no ECR..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $AWS_ACCOUNT_ID"

# Testar login no ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

if [ $? -eq 0 ]; then
    echo "✅ Login no ECR bem-sucedido"
else
    echo "❌ Falha no login do ECR"
    exit 1
fi

REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/bia
echo "Repository URI: $REPOSITORY_URI"

COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
IMAGE_TAG=${COMMIT_HASH:=latest}
echo "Image Tag: $IMAGE_TAG"

echo "=== BUILD Phase ==="
echo "Build iniciado em $(date)"
echo "Gerando imagem da BIA..."

# Testar build da imagem
docker build -t $REPOSITORY_URI:latest .

if [ $? -eq 0 ]; then
    echo "✅ Build da imagem bem-sucedido"
else
    echo "❌ Falha no build da imagem"
    exit 1
fi

docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG

echo "=== POST_BUILD Phase ==="
echo "Build finalizado com sucesso em $(date)"
echo "Verificando variaveis:"
echo "REPOSITORY_URI: $REPOSITORY_URI"
echo "IMAGE_TAG: $IMAGE_TAG"

echo "Fazendo push da imagem para o ECR..."
docker images | grep bia

# Testar push
docker push $REPOSITORY_URI:latest

if [ $? -eq 0 ]; then
    echo "✅ Push da tag latest bem-sucedido"
else
    echo "❌ Falha no push da tag latest"
    exit 1
fi

docker push $REPOSITORY_URI:$IMAGE_TAG

if [ $? -eq 0 ]; then
    echo "✅ Push da tag $IMAGE_TAG bem-sucedido"
else
    echo "❌ Falha no push da tag $IMAGE_TAG"
    exit 1
fi

echo "Gerando artefato da imagem para o ECS"
printf '[{"name":"bia","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
echo "Conteúdo do imagedefinitions.json:"
cat imagedefinitions.json

echo "=== Teste concluído com sucesso! ==="
