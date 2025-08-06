# BIA Infrastructure - Terraform

Este diretório contém o código Terraform para provisionar a infraestrutura completa da aplicação BIA na AWS.

## Arquitetura

A infraestrutura inclui:

- **ECS Cluster** com instâncias EC2 (t3.micro)
- **Application Load Balancer (ALB)** para distribuição de tráfego
- **RDS PostgreSQL** (t3.micro) para banco de dados
- **ECR Repository** para armazenar imagens Docker
- **Auto Scaling Group** para gerenciar instâncias EC2
- **Security Groups** configurados seguindo o princípio de menor privilégio
- **CloudWatch Logs** para logging da aplicação

## Pré-requisitos

1. **Terraform** instalado (versão >= 1.0)
2. **AWS CLI** configurado com credenciais apropriadas
3. **Permissões IAM** necessárias para criar os recursos

## Como usar

### 1. Configurar variáveis

Copie o arquivo de exemplo e configure suas variáveis:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite o arquivo `terraform.tfvars` com seus valores:

```hcl
aws_region = "us-east-1"
environment = "dev"
db_name     = "bia"
db_username = "postgres"
db_password = "sua-senha-segura-aqui"
app_image_tag = "latest"
```

### 2. Inicializar Terraform

```bash
terraform init
```

### 3. Planejar a infraestrutura

```bash
terraform plan
```

### 4. Aplicar a infraestrutura

```bash
terraform apply
```

### 5. Verificar os outputs

Após a aplicação, você verá outputs importantes como:

- URL do Load Balancer
- URL do repositório ECR
- Nome do cluster ECS
- IDs dos Security Groups

## Recursos Criados

### Networking
- Utiliza a VPC padrão da AWS
- Security Groups com regras específicas para cada camada

### Compute
- **ECS Cluster**: `bia-cluster-alb`
- **ECS Service**: `bia-service`
- **Task Definition**: `bia-tf`
- **Auto Scaling Group**: Para gerenciar instâncias EC2

### Database
- **RDS PostgreSQL 17.4**: Instância t3.micro
- **Subnet Group**: Para distribuição em múltiplas AZs
- **Security Group**: Acesso restrito apenas do ECS

### Load Balancer
- **Application Load Balancer**: `bia-alb`
- **Target Group**: `tg-bia`
- **Health Check**: Configurado para `/api/versao`

### Container Registry
- **ECR Repository**: `bia`
- **Scan on Push**: Habilitado para segurança

## Configurações Importantes

### Security Groups

1. **bia-alb**: Permite tráfego HTTP/HTTPS da internet
2. **bia-ec2**: Permite tráfego apenas do ALB
3. **bia-db**: Permite tráfego apenas das instâncias EC2

### ECS Configuration

- **Launch Type**: EC2
- **Network Mode**: Bridge
- **CPU**: 1024 units
- **Memory Reservation**: 410 MB
- **Health Check Grace Period**: 1 segundo

### Database Configuration

- **Engine**: PostgreSQL 17.4
- **Instance Class**: db.t3.micro
- **Storage**: 20GB (auto-scaling até 1TB)
- **Backup**: Desabilitado (ambiente de desenvolvimento)

## Monitoramento

- **CloudWatch Logs**: `/ecs/bia-tf`
- **Retention**: 7 dias
- **Health Checks**: Configurados no Target Group

## Limpeza

Para destruir toda a infraestrutura:

```bash
terraform destroy
```

## Troubleshooting

### Problemas Comuns

1. **Instâncias ECS não aparecem no cluster**
   - Verifique se o user_data está correto
   - Confirme se a role IAM tem as permissões necessárias

2. **Health checks falhando**
   - Verifique se a aplicação está respondendo em `/api/versao`
   - Confirme se a porta 8080 está exposta no container

3. **Problemas de conectividade com RDS**
   - Verifique os Security Groups
   - Confirme se as variáveis de ambiente estão corretas

### Logs Úteis

- **ECS Agent**: `/var/log/ecs/ecs-agent.log`
- **CloudWatch**: Console AWS > CloudWatch > Log Groups
- **ALB**: Console AWS > EC2 > Load Balancers > Monitoring

## Segurança

- Senhas são marcadas como `sensitive` no Terraform
- Security Groups seguem o princípio de menor privilégio
- RDS não é publicamente acessível
- ECR tem scan de vulnerabilidades habilitado

## Customização

Para personalizar a infraestrutura:

1. Modifique as variáveis em `variables.tf`
2. Ajuste os recursos em `main.tf`
3. Execute `terraform plan` para revisar as mudanças
4. Execute `terraform apply` para aplicar

## Suporte

Para dúvidas sobre a infraestrutura, consulte:

- [Documentação do Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentação do Amazon ECS](https://docs.aws.amazon.com/ecs/)
- [Documentação do Amazon RDS](https://docs.aws.amazon.com/rds/)
