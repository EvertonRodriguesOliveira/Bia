# Script de Deploy ECS - Projeto BIA

## Visão Geral

O script `deploy-ecs.sh` é uma ferramenta completa para build e deploy da aplicação BIA no Amazon ECS. Ele foi projetado seguindo as melhores práticas do projeto BIA, priorizando simplicidade e facilidade de uso para alunos em aprendizado.

## Características Principais

### 🏷️ Versionamento por Commit Hash
- Cada imagem Docker é taggeada com os últimos 7 caracteres do commit hash
- Permite rastreabilidade completa entre código e deploy
- Facilita identificação de versões específicas

### 🔄 Rollback Simplificado
- Rollback para qualquer versão anterior com um comando
- Lista de imagens disponíveis para rollback
- Processo automatizado e seguro

### 📋 Task Definition Versionada
- Cada deploy cria uma nova revisão da task definition
- Mantém histórico completo de configurações
- Permite rollback de configuração junto com a imagem

## Pré-requisitos

### Ferramentas Necessárias
```bash
# AWS CLI
aws --version

# Docker
docker --version

# Git (para hash do commit)
git --version

# jq (para manipulação JSON)
jq --version
```

### Configuração AWS
```bash
# Configure suas credenciais AWS
aws configure

# Ou use variáveis de ambiente
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-east-1
```

### Permissões IAM Necessárias
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeImages"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:RegisterTaskDefinition",
                "ecs:DescribeTaskDefinition",
                "ecs:ListTaskDefinitions",
                "ecs:UpdateService",
                "ecs:DescribeServices"
            ],
            "Resource": "*"
        }
    ]
}
```

## Uso Básico

### Deploy Completo
```bash
# Deploy com configurações padrão
./deploy-ecs.sh deploy

# Deploy com cluster personalizado
./deploy-ecs.sh --cluster meu-cluster deploy
```

### Build Apenas
```bash
# Apenas build e push da imagem (sem deploy)
./deploy-ecs.sh build-only
```

### Rollback
```bash
# Listar imagens disponíveis
./deploy-ecs.sh list-images

# Fazer rollback para uma tag específica
./deploy-ecs.sh rollback a1b2c3d
```

### Monitoramento
```bash
# Listar imagens no ECR
./deploy-ecs.sh list-images

# Listar task definitions
./deploy-ecs.sh list-tasks
```

## Configurações Padrão

O script usa as seguintes configurações padrão do projeto BIA:

```bash
REGION="us-east-1"
ECR_REPO="905418381762.dkr.ecr.us-east-1.amazonaws.com/bia"
CLUSTER="bia-cluster-alb"
SERVICE="bia-service"
TASK_FAMILY="bia-tf"
```

### Personalizando Configurações
```bash
# Exemplo com todas as opções personalizadas
./deploy-ecs.sh \
  --region us-west-2 \
  --ecr-repo 123456789012.dkr.ecr.us-west-2.amazonaws.com/minha-app \
  --cluster meu-cluster \
  --service meu-service \
  --family minha-task-family \
  deploy
```

## Fluxo de Deploy

### 1. Preparação
- ✅ Verificação de dependências (aws, docker, git, jq)
- ✅ Obtenção do hash do commit atual (7 caracteres)
- ✅ Validação de credenciais AWS

### 2. Build
- 🐳 Login no Amazon ECR
- 🔨 Build da imagem Docker
- 🏷️ Tag da imagem com commit hash
- ⬆️ Push para ECR (latest + commit hash)

### 3. Deploy
- 📋 Criação de nova task definition
- 🔄 Atualização do serviço ECS
- ⏳ Aguarda estabilização do serviço
- ✅ Confirmação de sucesso

## Exemplos Práticos

### Cenário 1: Deploy de Desenvolvimento
```bash
# Deploy rápido para ambiente de desenvolvimento
./deploy-ecs.sh deploy

# Saída esperada:
# [INFO] Hash do commit: a1b2c3d
# [SUCCESS] Build da imagem concluído
# [SUCCESS] Push da imagem concluído
# [SUCCESS] Nova task definition criada
# [SUCCESS] Deploy concluído com sucesso!
```

### Cenário 2: Rollback de Emergência
```bash
# 1. Verificar versões disponíveis
./deploy-ecs.sh list-images

# 2. Fazer rollback para versão anterior
./deploy-ecs.sh rollback f4e5d6c

# 3. Verificar se rollback foi bem-sucedido
./deploy-ecs.sh list-tasks
```

### Cenário 3: Build para Múltiplos Ambientes
```bash
# Build da imagem (sem deploy)
./deploy-ecs.sh build-only

# Deploy para desenvolvimento
./deploy-ecs.sh --cluster bia-dev-cluster deploy

# Deploy para produção (após testes)
./deploy-ecs.sh --cluster bia-prod-cluster deploy
```

## Troubleshooting

### Erro: "Dependências não encontradas"
```bash
# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Instalar jq
sudo yum install jq -y  # Amazon Linux
sudo apt-get install jq -y  # Ubuntu/Debian
```

### Erro: "Login no ECR falhou"
```bash
# Verificar credenciais AWS
aws sts get-caller-identity

# Verificar permissões ECR
aws ecr describe-repositories --region us-east-1
```

### Erro: "Task definition não encontrada"
```bash
# O script criará automaticamente uma task definition básica
# Verifique se o nome da família está correto
./deploy-ecs.sh --family bia-tf deploy
```

### Erro: "Serviço ECS não encontrado"
```bash
# Verificar se o serviço existe
aws ecs describe-services --cluster bia-cluster-alb --services bia-service

# Listar serviços disponíveis
aws ecs list-services --cluster bia-cluster-alb
```

## Logs e Monitoramento

### Logs do Script
O script fornece logs coloridos e informativos:
- 🔵 **INFO**: Informações gerais
- 🟢 **SUCCESS**: Operações bem-sucedidas
- 🟡 **WARNING**: Avisos importantes
- 🔴 **ERROR**: Erros que impedem a execução

### Logs da Aplicação
```bash
# Ver logs do serviço ECS
aws logs tail /ecs/bia-tf --follow

# Ver logs de deploy no CloudWatch
aws logs describe-log-groups --log-group-name-prefix "/ecs/"
```

## Integração com CI/CD

### GitHub Actions
```yaml
name: Deploy to ECS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Deploy to ECS
        run: ./deploy-ecs.sh deploy
```

### AWS CodeBuild
```yaml
# Adicionar ao buildspec.yml
phases:
  post_build:
    commands:
      - ./deploy-ecs.sh deploy
```

## Segurança

### Boas Práticas
- ✅ Use IAM roles com permissões mínimas necessárias
- ✅ Mantenha credenciais AWS seguras
- ✅ Use tags específicas para produção
- ✅ Monitore logs de deploy
- ✅ Teste rollbacks em ambiente de desenvolvimento

### Validações do Script
- ✅ Verificação de dependências antes da execução
- ✅ Validação de existência de imagens para rollback
- ✅ Confirmação de sucesso em cada etapa
- ✅ Tratamento de erros com mensagens claras

## Contribuição

Para melhorar o script:
1. Mantenha a filosofia de simplicidade do projeto BIA
2. Adicione logs informativos para cada operação
3. Inclua validações adequadas
4. Teste em ambiente de desenvolvimento primeiro
5. Documente mudanças neste README

## Suporte

Para dúvidas ou problemas:
1. Verifique a seção de Troubleshooting
2. Execute `./deploy-ecs.sh --help` para ver todas as opções
3. Consulte os logs do CloudWatch para detalhes de erro
4. Verifique as permissões IAM necessárias
