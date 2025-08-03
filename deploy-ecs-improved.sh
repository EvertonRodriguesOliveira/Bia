#!/bin/bash

# Script de Deploy para ECS - Projeto BIA (Versão Melhorada)
# Autor: Amazon Q
# Versão: 2.0

set -e  # Parar execução em caso de erro

# Configurações padrão
DEFAULT_REGION="us-east-1"
DEFAULT_ECR_REPO="861276121195.dkr.ecr.us-east-1.amazonaws.com/bia"
DEFAULT_CLUSTER="cluster-bia"
DEFAULT_SERVICE="service-bia-alb"
DEFAULT_TASK_FAMILY="task-def-bia-alb"
DEFAULT_API_URL="http://bia-alb-1261425897.us-east-1.elb.amazonaws.com"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens coloridas
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para exibir help
show_help() {
    cat << EOF
${GREEN}Script de Deploy ECS - Projeto BIA (Versão Melhorada)${NC}

${YELLOW}DESCRIÇÃO:${NC}
    Script para build e deploy da aplicação BIA no Amazon ECS.
    Permite configurar a URL da API durante o build.

${YELLOW}USO:${NC}
    $0 [OPÇÕES]

${YELLOW}OPÇÕES:${NC}
    -r, --region REGION        Região AWS (padrão: $DEFAULT_REGION)
    -e, --ecr-repo REPO        Repositório ECR (padrão: $DEFAULT_ECR_REPO)
    -c, --cluster CLUSTER      Nome do cluster ECS (padrão: $DEFAULT_CLUSTER)
    -s, --service SERVICE      Nome do serviço ECS (padrão: $DEFAULT_SERVICE)
    -t, --task-family FAMILY   Família da task definition (padrão: $DEFAULT_TASK_FAMILY)
    -a, --api-url URL          URL da API para o frontend (padrão: $DEFAULT_API_URL)
    -h, --help                 Exibir esta ajuda

${YELLOW}EXEMPLOS:${NC}
    # Deploy básico
    $0

    # Deploy com URL da API customizada
    $0 --api-url http://meu-alb.amazonaws.com

    # Deploy em região diferente
    $0 --region us-west-2 --api-url http://meu-alb-west.amazonaws.com

EOF
}

# Parsing dos argumentos
REGION="$DEFAULT_REGION"
ECR_REPO="$DEFAULT_ECR_REPO"
CLUSTER="$DEFAULT_CLUSTER"
SERVICE="$DEFAULT_SERVICE"
TASK_FAMILY="$DEFAULT_TASK_FAMILY"
API_URL="$DEFAULT_API_URL"

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -e|--ecr-repo)
            ECR_REPO="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        -t|--task-family)
            TASK_FAMILY="$2"
            shift 2
            ;;
        -a|--api-url)
            API_URL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validações
if [[ -z "$REGION" || -z "$ECR_REPO" || -z "$CLUSTER" || -z "$SERVICE" || -z "$TASK_FAMILY" || -z "$API_URL" ]]; then
    log_error "Todos os parâmetros são obrigatórios"
    show_help
    exit 1
fi

# Exibir configurações
log_info "=== CONFIGURAÇÕES DO DEPLOY ==="
log_info "Região: $REGION"
log_info "Repositório ECR: $ECR_REPO"
log_info "Cluster ECS: $CLUSTER"
log_info "Serviço ECS: $SERVICE"
log_info "Task Family: $TASK_FAMILY"
log_info "API URL: $API_URL"
log_info "================================"

# Gerar tag baseada no commit hash
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
IMAGE_TAG="$ECR_REPO:$COMMIT_HASH"
LATEST_TAG="$ECR_REPO:latest"

log_info "Tag da imagem: $IMAGE_TAG"

# Função para fazer login no ECR
ecr_login() {
    log_info "Fazendo login no ECR..."
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO"
    log_success "Login no ECR realizado com sucesso"
}

# Função para build da imagem
build_image() {
    log_info "Iniciando build da imagem Docker..."
    log_info "API URL configurada: $API_URL"
    
    # Build da imagem com API URL configurável
    docker build --build-arg API_URL="$API_URL" -t "$LATEST_TAG" -f Dockerfile.improved .
    docker tag "$LATEST_TAG" "$IMAGE_TAG"
    
    log_success "Build da imagem concluído"
}

# Função para push da imagem
push_image() {
    log_info "Fazendo push da imagem para o ECR..."
    
    docker push "$IMAGE_TAG"
    docker push "$LATEST_TAG"
    
    log_success "Push da imagem concluído"
}

# Função para atualizar o serviço ECS
update_service() {
    log_info "Atualizando serviço ECS..."
    
    # Obter a task definition atual
    TASK_DEF=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION")
    
    # Criar nova task definition com a nova imagem
    NEW_TASK_DEF=$(echo "$TASK_DEF" | jq --arg IMAGE "$IMAGE_TAG" '.taskDefinition | .containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn) | del(.revision) | del(.status) | del(.requiresAttributes) | del(.placementConstraints) | del(.compatibilities) | del(.registeredAt) | del(.registeredBy)')
    
    # Registrar nova task definition
    NEW_TASK_INFO=$(aws ecs register-task-definition --region "$REGION" --cli-input-json "$NEW_TASK_DEF")
    NEW_REVISION=$(echo "$NEW_TASK_INFO" | jq -r '.taskDefinition.revision')
    
    log_info "Nova task definition registrada: $TASK_FAMILY:$NEW_REVISION"
    
    # Atualizar o serviço
    aws ecs update-service --region "$REGION" --cluster "$CLUSTER" --service "$SERVICE" --task-definition "$TASK_FAMILY:$NEW_REVISION"
    
    log_success "Serviço ECS atualizado"
}

# Função para aguardar o deploy
wait_deployment() {
    log_info "Aguardando conclusão do deploy..."
    
    aws ecs wait services-stable --region "$REGION" --cluster "$CLUSTER" --services "$SERVICE"
    
    log_success "Deploy concluído com sucesso!"
}

# Função principal
main() {
    log_info "Iniciando deploy da aplicação BIA..."
    
    ecr_login
    build_image
    push_image
    update_service
    wait_deployment
    
    log_success "=== DEPLOY CONCLUÍDO COM SUCESSO ==="
    log_info "Imagem: $IMAGE_TAG"
    log_info "API URL: $API_URL"
    log_info "Acesse: $API_URL"
}

# Executar função principal
main
