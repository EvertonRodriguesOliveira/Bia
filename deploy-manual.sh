#!/bin/bash

echo "🚀 Deploy manual da BIA"

# Obter Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/bia

# Gerar tag baseada no commit atual
COMMIT_HASH=$(git rev-parse --short HEAD)
IMAGE_TAG=$COMMIT_HASH

echo "📦 Building imagem: $REPOSITORY_URI:$IMAGE_TAG"

# Login no ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build e push
docker build -t $REPOSITORY_URI:latest .
docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG

docker push $REPOSITORY_URI:latest
docker push $REPOSITORY_URI:$IMAGE_TAG

# Gerar imagedefinitions.json
printf '[{"name":"bia","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json

echo "✅ Deploy concluído!"
echo "📄 Imagem: $REPOSITORY_URI:$IMAGE_TAG"
echo "📄 Arquivo imagedefinitions.json criado"
