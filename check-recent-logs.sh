#!/bin/bash

echo "🔍 Monitorando logs do CodeBuild bia-build..."

# Função para verificar novos logs
check_logs() {
    echo "📋 Verificando logs em $(date)..."
    
    # Obter o stream mais recente
    LATEST_STREAM=$(aws logs describe-log-streams \
        --log-group-name "/aws/codebuild/bia-build" \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --region us-east-1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null)
    
    if [ "$LATEST_STREAM" != "None" ] && [ "$LATEST_STREAM" != "" ]; then
        echo "📄 Stream mais recente: $LATEST_STREAM"
        
        # Verificar se há eventos recentes (últimos 10 minutos)
        RECENT_EVENTS=$(aws logs get-log-events \
            --log-group-name "/aws/codebuild/bia-build" \
            --log-stream-name "$LATEST_STREAM" \
            --start-time $(($(date +%s) * 1000 - 600000)) \
            --region us-east-1 \
            --query 'events[*].message' \
            --output text 2>/dev/null)
        
        if [ "$RECENT_EVENTS" != "" ]; then
            echo "🆕 Eventos recentes encontrados:"
            echo "$RECENT_EVENTS"
            return 0
        else
            echo "⏰ Nenhum evento recente (últimos 10 minutos)"
            return 1
        fi
    else
        echo "❌ Erro ao acessar logs ou nenhum stream encontrado"
        return 1
    fi
}

# Verificar logs atuais
check_logs

echo ""
echo "🔄 Monitoramento contínuo (pressione Ctrl+C para parar)..."
echo "   Verificando a cada 30 segundos por novos builds..."

# Loop de monitoramento
LAST_CHECK=$(date +%s)
while true; do
    sleep 30
    
    echo ""
    echo "🔍 Verificação $(date +%H:%M:%S)..."
    
    if check_logs; then
        echo "🎉 Novo build detectado!"
        break
    else
        echo "⏳ Aguardando novo build..."
    fi
done
