#!/bin/bash

# Script de Deploy para ECS - Projeto BIA
# Autor: Amazon Q
# Versão: 1.0

set -e  # Parar execução em caso de erro

# Configurações padrão
DEFAULT_REGION="us-east-1"
DEFAULT_ECR_REPO="861276121195.dkr.ecr.us-east-1.amazonaws.com/bia"
DEFAULT_CLUSTER="cluster-bia"
DEFAULT_SERVICE="services-bia"
DEFAULT_TASK_FAMILY="task-def-bia"

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
${GREEN}Script de Deploy ECS - Projeto BIA${NC}

${YELLOW}DESCRIÇÃO:${NC}
    Script para build e deploy da aplicação BIA no Amazon ECS.
    Cada deploy cria uma nova task definition com tag baseada no commit hash,
    permitindo rollback para versões anteriores.

${YELLOW}USO:${NC}
    $0 [OPÇÕES] COMANDO

${YELLOW}COMANDOS:${NC}
    deploy              Faz build e deploy completo da aplicação
    build-only          Apenas faz build e push da imagem
    rollback TAG        Faz rollback para uma tag específica
    list-images         Lista as últimas 10 imagens no ECR
    list-tasks          Lista as últimas 10 task definitions
    help                Exibe esta ajuda

${YELLOW}OPÇÕES:${NC}
    -r, --region REGION         Região AWS (padrão: $DEFAULT_REGION)
    -e, --ecr-repo REPO         Repositório ECR (padrão: $DEFAULT_ECR_REPO)
    -c, --cluster CLUSTER       Nome do cluster ECS (padrão: $DEFAULT_CLUSTER)
    -s, --service SERVICE       Nome do serviço ECS (padrão: $DEFAULT_SERVICE)
    -f, --family FAMILY         Família da task definition (padrão: $DEFAULT_TASK_FAMILY)
    -h, --help                  Exibe esta ajuda

${YELLOW}EXEMPLOS:${NC}
    # Deploy completo com configurações padrão
    $0 deploy

    # Deploy com cluster personalizado
    $0 --cluster meu-cluster deploy

    # Apenas build da imagem
    $0 build-only

    # Rollback para uma tag específica
    $0 rollback a1b2c3d

    # Listar imagens disponíveis
    $0 list-images

    # Listar task definitions
    $0 list-tasks

${YELLOW}FLUXO DO DEPLOY:${NC}
    1. Obtém hash do commit atual (7 caracteres)
    2. Faz login no ECR
    3. Build da imagem Docker com tag do commit
    4. Push da imagem para ECR
    5. Cria nova task definition apontando para a imagem
    6. Atualiza o serviço ECS com a nova task definition

${YELLOW}ROLLBACK:${NC}
    Para fazer rollback, use o comando 'rollback' com a tag desejada.
    Use 'list-images' para ver as tags disponíveis.

EOF
}

# Função para validar dependências
check_dependencies() {
    log_info "Verificando dependências..."
    
    local deps=("aws" "docker" "git" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Dependências não encontradas: ${missing_deps[*]}"
        log_error "Instale as dependências necessárias antes de continuar."
        exit 1
    fi
    
    log_success "Todas as dependências estão instaladas"
}

# Função para obter hash do commit
get_commit_hash() {
    if [ -d ".git" ]; then
        git rev-parse --short=7 HEAD
    else
        log_warning "Não é um repositório Git. Usando timestamp como tag."
        date +%s | tail -c 8
    fi
}

# Função para fazer login no ECR
ecr_login() {
    log_info "Fazendo login no ECR..."
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO"
    log_success "Login no ECR realizado com sucesso"
}

# Função para build da imagem
build_image() {
    local commit_hash="$1"
    local image_tag="$ECR_REPO:$commit_hash"
    local latest_tag="$ECR_REPO:latest"
    
    log_info "Iniciando build da imagem..."
    log_info "Tag do commit: $commit_hash"
    
    # Build da imagem
    docker build -t "$latest_tag" .
    docker tag "$latest_tag" "$image_tag"
    
    log_success "Build da imagem concluído"
    echo "  - Imagem: $image_tag"
    echo "  - Latest: $latest_tag"
}

# Função para push da imagem
push_image() {
    local commit_hash="$1"
    local image_tag="$ECR_REPO:$commit_hash"
    local latest_tag="$ECR_REPO:latest"
    
    log_info "Fazendo push da imagem para ECR..."
    
    docker push "$latest_tag"
    docker push "$image_tag"
    
    log_success "Push da imagem concluído"
}

# Função para obter task definition atual
get_current_task_definition() {
    aws ecs describe-task-definition \
        --region "$REGION" \
        --task-definition "$TASK_FAMILY" \
        --query 'taskDefinition' \
        --output json 2>/dev/null || echo "{}"
}

# Função para criar nova task definition
create_task_definition() {
    local commit_hash="$1"
    local image_uri="$ECR_REPO:$commit_hash"
    
    log_info "Criando nova task definition..."
    
    # Obter task definition atual
    local current_task_def=$(get_current_task_definition)
    
    if [ "$current_task_def" = "{}" ]; then
        log_error "Task definition não encontrada. Verifique se a família '$TASK_FAMILY' existe."
        exit 1
    else
        # Atualizar imagem na task definition existente
        current_task_def=$(echo "$current_task_def" | jq --arg image "$image_uri" '
            .containerDefinitions[0].image = $image |
            del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy, .runtimePlatform, .enableFaultInjection)
        ')
    fi
    
    # Salvar temporariamente para debug
    echo "$current_task_def" > /tmp/task-def-debug.json
    
    # Registrar nova task definition
    local new_task_def_arn=$(echo "$current_task_def" | aws ecs register-task-definition \
        --region "$REGION" \
        --cli-input-json file:///dev/stdin \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text 2>/tmp/task-def-error.log)
    
    if [ $? -eq 0 ]; then
        log_success "Nova task definition criada: $new_task_def_arn"
        echo "$new_task_def_arn"
    else
        log_error "Falha ao criar task definition"
        log_error "Erro detalhado:"
        cat /tmp/task-def-error.log
        log_error "JSON gerado:"
        cat /tmp/task-def-debug.json
        exit 1
    fi
}

# Função para atualizar serviço ECS
update_service() {
    local task_def_arn="$1"
    
    log_info "Atualizando serviço ECS..."
    
    aws ecs update-service \
        --region "$REGION" \
        --cluster "$CLUSTER" \
        --service "$SERVICE" \
        --task-definition "$task_def_arn" \
        --output table
    
    if [ $? -eq 0 ]; then
        log_success "Serviço ECS atualizado com sucesso"
        log_info "Aguardando estabilização do serviço..."
        
        aws ecs wait services-stable \
            --region "$REGION" \
            --cluster "$CLUSTER" \
            --services "$SERVICE"
        
        log_success "Deploy concluído com sucesso!"
    else
        log_error "Falha ao atualizar serviço ECS"
        exit 1
    fi
}

# Função para listar imagens no ECR
list_images() {
    log_info "Listando últimas 10 imagens no ECR..."
    
    aws ecr describe-images \
        --region "$REGION" \
        --repository-name "$(basename "$ECR_REPO")" \
        --query 'sort_by(imageDetails,&imagePushedAt)[-10:].[imageTags[0],imagePushedAt]' \
        --output table
}

# Função para listar task definitions
list_task_definitions() {
    log_info "Listando últimas 10 task definitions..."
    
    aws ecs list-task-definitions \
        --region "$REGION" \
        --family-prefix "$TASK_FAMILY" \
        --status ACTIVE \
        --sort DESC \
        --max-items 10 \
        --query 'taskDefinitionArns' \
        --output table
}

# Função para rollback
rollback() {
    local target_tag="$1"
    
    if [ -z "$target_tag" ]; then
        log_error "Tag para rollback não especificada"
        log_info "Use: $0 rollback <tag>"
        log_info "Para ver tags disponíveis: $0 list-images"
        exit 1
    fi
    
    log_info "Iniciando rollback para tag: $target_tag"
    
    # Verificar se a imagem existe
    local image_exists=$(aws ecr describe-images \
        --region "$REGION" \
        --repository-name "$(basename "$ECR_REPO")" \
        --image-ids imageTag="$target_tag" \
        --query 'imageDetails[0].imageTags[0]' \
        --output text 2>/dev/null)
    
    if [ "$image_exists" = "None" ] || [ -z "$image_exists" ]; then
        log_error "Imagem com tag '$target_tag' não encontrada no ECR"
        log_info "Tags disponíveis:"
        list_images
        exit 1
    fi
    
    # Criar nova task definition com a imagem do rollback
    local task_def_arn=$(create_task_definition "$target_tag")
    
    # Atualizar serviço
    update_service "$task_def_arn"
    
    log_success "Rollback para tag '$target_tag' concluído!"
}

# Função principal de deploy
deploy() {
    log_info "Iniciando deploy da aplicação BIA..."
    
    # Verificar dependências
    check_dependencies
    
    # Obter hash do commit
    local commit_hash=$(get_commit_hash)
    log_info "Hash do commit: $commit_hash"
    
    # Login no ECR
    ecr_login
    
    # Build da imagem
    build_image "$commit_hash"
    
    # Push da imagem
    push_image "$commit_hash"
    
    # Criar task definition
    local task_def_arn=$(create_task_definition "$commit_hash")
    
    # Atualizar serviço
    update_service "$task_def_arn"
    
    log_success "Deploy concluído com sucesso!"
    echo ""
    echo "Resumo do deploy:"
    echo "  - Commit: $commit_hash"
    echo "  - Imagem: $ECR_REPO:$commit_hash"
    echo "  - Task Definition: $task_def_arn"
    echo "  - Cluster: $CLUSTER"
    echo "  - Serviço: $SERVICE"
}

# Função apenas para build
build_only() {
    log_info "Executando apenas build da imagem..."
    
    # Verificar dependências
    check_dependencies
    
    # Obter hash do commit
    local commit_hash=$(get_commit_hash)
    log_info "Hash do commit: $commit_hash"
    
    # Login no ECR
    ecr_login
    
    # Build da imagem
    build_image "$commit_hash"
    
    # Push da imagem
    push_image "$commit_hash"
    
    log_success "Build concluído com sucesso!"
    echo "Imagem disponível: $ECR_REPO:$commit_hash"
}

# Parsing dos argumentos
REGION="$DEFAULT_REGION"
ECR_REPO="$DEFAULT_ECR_REPO"
CLUSTER="$DEFAULT_CLUSTER"
SERVICE="$DEFAULT_SERVICE"
TASK_FAMILY="$DEFAULT_TASK_FAMILY"

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
        -f|--family)
            TASK_FAMILY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        deploy)
            COMMAND="deploy"
            shift
            ;;
        build-only)
            COMMAND="build-only"
            shift
            ;;
        rollback)
            COMMAND="rollback"
            ROLLBACK_TAG="$2"
            shift 2
            ;;
        list-images)
            COMMAND="list-images"
            shift
            ;;
        list-tasks)
            COMMAND="list-tasks"
            shift
            ;;
        help)
            show_help
            exit 0
            ;;
        *)
            log_error "Opção desconhecida: $1"
            echo "Use '$0 --help' para ver as opções disponíveis."
            exit 1
            ;;
    esac
done

# Verificar se um comando foi especificado
if [ -z "$COMMAND" ]; then
    log_error "Nenhum comando especificado"
    echo "Use '$0 --help' para ver os comandos disponíveis."
    exit 1
fi

# Executar comando
case $COMMAND in
    deploy)
        deploy
        ;;
    build-only)
        build_only
        ;;
    rollback)
        rollback "$ROLLBACK_TAG"
        ;;
    list-images)
        list_images
        ;;
    list-tasks)
        list_task_definitions
        ;;
    *)
        log_error "Comando desconhecido: $COMMAND"
        exit 1
        ;;
esac
