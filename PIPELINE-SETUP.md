# 🚀 Guia de Configuração do Pipeline BIA

## Situação Atual
✅ **Buildspec.yml funcionando perfeitamente**  
✅ **ECR configurado e funcionando**  
✅ **Build e push manuais funcionando**  
❌ **Pipeline automático não configurado**  

## Solução: Configurar Pipeline Completo

### Passo 1: Criar Token do GitHub
1. Acesse: https://github.com/settings/tokens
2. Clique em "Generate new token (classic)"
3. Selecione as permissões:
   - ✅ `repo` (acesso completo aos repositórios)
   - ✅ `admin:repo_hook` (gerenciar webhooks)
4. Copie o token gerado

### Passo 2: Configurar o Pipeline
```bash
# No terminal, defina o token
export GITHUB_TOKEN=seu_token_aqui

# Execute o script de configuração
./deploy-pipeline.sh
```

### Passo 3: Verificar Configuração
```bash
# Verificar se tudo foi criado corretamente
./check-pipeline.sh
```

## O que o Pipeline Criará

### 🏗️ Recursos AWS
- **S3 Bucket**: Para artefatos do pipeline
- **CodePipeline**: Pipeline principal
- **CodeBuild**: Projeto de build (novo, configurado corretamente)
- **IAM Roles**: Permissões necessárias
- **GitHub Webhook**: Trigger automático

### 🔄 Fluxo do Pipeline
1. **Source**: Monitora commits no GitHub
2. **Build**: Executa buildspec.yml
3. **Deploy**: Gera imagedefinitions.json

### 🎯 Resultado
- ✅ Commits automáticos disparam o pipeline
- ✅ Build e push automáticos para ECR
- ✅ Arquivo imagedefinitions.json gerado
- ✅ Logs detalhados no CloudWatch

## Alternativas Enquanto Não Configura

### Deploy Manual Rápido
```bash
# Execute sempre que quiser fazer deploy
./deploy-manual.sh
```

### Teste Local
```bash
# Teste o buildspec.yml localmente
./test-buildspec.sh
```

## Troubleshooting

### Se der erro de permissões
- Verifique se tem permissões de CloudFormation
- Verifique se tem permissões de IAM
- Execute via Console AWS se necessário

### Se o webhook não funcionar
- Verifique o token do GitHub
- Verifique as permissões do token
- Verifique se o repositório está correto

### Se o build falhar
- O buildspec.yml já está funcionando
- Verifique os logs no CloudWatch
- Use o script de teste local para debug

## Próximos Passos

1. **Configure o pipeline** usando o guia acima
2. **Teste com um commit** para verificar o trigger automático
3. **Monitore os logs** no CloudWatch
4. **Configure deploy para ECS** (próxima etapa)

## Arquivos Criados

- `aws/pipeline-template.yaml` - Template CloudFormation
- `deploy-pipeline.sh` - Script de configuração
- `check-pipeline.sh` - Script de verificação
- `deploy-manual.sh` - Deploy manual
- `test-buildspec.sh` - Teste local

## Suporte

Se encontrar problemas:
1. Execute `./check-pipeline.sh` para diagnóstico
2. Verifique os logs no CloudWatch
3. Use o deploy manual como fallback
