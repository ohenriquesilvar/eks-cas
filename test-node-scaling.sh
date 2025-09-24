#!/bin/bash

# Nome do arquivo para salvar métricas
METRICS_FILE="scaling_metrics_$(date +%Y%m%d_%H%M%S).csv"

# Inicializar arquivo de métricas com cabeçalho
echo "timestamp,metric,value,instance_type" > $METRICS_FILE

# Função para registrar métricas
log_metric() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local metric_name=$1
    local metric_value=$2
    local instance_type=${3:-"N/A"}  # O tipo de instância é opcional, padrão é N/A
    echo "$timestamp,$metric_name,$metric_value,$instance_type" >> $METRICS_FILE
    echo "Métrica registrada: $metric_name = $metric_value (Instância: $instance_type)"
}

# Função para obter o tipo de instância de um nó
get_instance_type() {
    local node_name=$1
    local instance_type=$(kubectl describe node $node_name | grep -i "beta.kubernetes.io/instance-type\|node.kubernetes.io/instance-type" | awk '{print $2}' | head -1)
    
    # Se não encontrar usando os labels padrão, tenta outros métodos dependendo do provedor
    if [ -z "$instance_type" ]; then
        # Tenta extrair de outras labels que podem indicar o tipo
        instance_type=$(kubectl get node $node_name -o jsonpath='{.metadata.labels}' | grep -o 'instance-type="[^"]*"' | cut -d'"' -f2)
    fi
    
    # Se ainda não encontrou, usa "unknown"
    if [ -z "$instance_type" ]; then
        instance_type="unknown"
    fi
    
    echo $instance_type
}

# Função para registrar informações sobre todos os nós
log_all_nodes_info() {
    echo "Registrando informações de todos os nós..."
    kubectl get nodes -o wide | tail -n +2 | while read -r line; do
        NODE_NAME=$(echo "$line" | awk '{print $1}')
        INSTANCE_TYPE=$(get_instance_type $NODE_NAME)
        
        # Registrar o tipo de instância para cada nó
        log_metric "node_instance_type" "$NODE_NAME" "$INSTANCE_TYPE"
        
        # Registrar o status do nó
        NODE_STATUS=$(echo "$line" | awk '{print $2}')
        log_metric "node_status" "$NODE_STATUS" "$INSTANCE_TYPE"
        
        # Registrar a idade do nó
        NODE_AGE=$(echo "$line" | awk '{print $4}')
        log_metric "node_age" "$NODE_AGE" "$INSTANCE_TYPE"
    done
}

# Capturar timestamp inicial
START_TIME=$(date +%s)
log_metric "test_start_time" $START_TIME

# Aplicar o deployment de teste
echo "Aplicando o deployment de teste Nginx..."
kubectl apply -f nginx-node-scaling.yaml

# Registrar número inicial de nós
INITIAL_NODES=$(kubectl get nodes --no-headers | wc -l)
log_metric "initial_node_count" $INITIAL_NODES

# Registrar informações iniciais de todos os nós
log_all_nodes_info

# Verificar se o namespace e o deployment existem
echo "Verificando se o namespace e o deployment foram criados..."
kubectl get namespace test-scaling
kubectl get deployment -n test-scaling

# Verificar nós atuais
echo "Nós atuais do cluster:"
kubectl get nodes

# Monitorar grupos de nodes
echo "Grupos de autoscaling:"
kubectl -n kube-system describe configmap cluster-autoscaler-status

# Capturar timestamp antes do scale-up
SCALE_UP_START=$(date +%s)
log_metric "scale_up_start_time" $SCALE_UP_START

# Calcular número de pods baseado nos recursos disponíveis
# Cada pod pede 500m de CPU e 512Mi de memória
# Isto deve criar demanda suficiente para forçar o Cluster Autoscaler a adicionar nodes

# Primeira escala: 5 réplicas
echo "Escalando o deployment para 5 réplicas..."
kubectl scale deployment nginx-test -n test-scaling --replicas=5
log_metric "target_replicas" 5

echo "Aguardando 5 minutos após escalar para 5 réplicas..."
FIRST_NEW_NODE_TIME=0
MAX_NODES=0

for i in {1..5}; do
  echo "Minuto $i/5 (5 réplicas)..."
  
  # Coletar métricas atuais
  CURRENT_NODES=$(kubectl get nodes --no-headers | wc -l)
  PENDING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Pending --no-headers | wc -l)
  RUNNING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Running --no-headers | wc -l)
  
  # Registrar métricas
  log_metric "current_node_count" $CURRENT_NODES
  log_metric "pending_pods" $PENDING_PODS
  log_metric "running_pods" $RUNNING_PODS
  
  # Verificar se novos nós foram adicionados
  if [[ $CURRENT_NODES -gt $INITIAL_NODES && $FIRST_NEW_NODE_TIME -eq 0 ]]; then
    FIRST_NEW_NODE_TIME=$(date +%s)
    TIME_TO_FIRST_NODE=$((FIRST_NEW_NODE_TIME - SCALE_UP_START))
    log_metric "time_to_first_node_seconds_5replicas" $TIME_TO_FIRST_NODE
    
    # Registrar informações do novo nó
    log_all_nodes_info
  fi
  
  # Atualizar contagem máxima de nós
  if [[ $CURRENT_NODES -gt $MAX_NODES ]]; then
    MAX_NODES=$CURRENT_NODES
    log_metric "max_node_count_5replicas" $MAX_NODES
  fi
  
  # Coletar uso de recursos por nó
  echo "Coletando métricas de utilização de recursos..."
  kubectl top nodes | tail -n +2 | while read -r line; do
    NODE_NAME=$(echo "$line" | awk '{print $1}')
    CPU_USAGE=$(echo "$line" | awk '{print $3}' | sed 's/%//')
    MEM_USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    INSTANCE_TYPE=$(get_instance_type $NODE_NAME)
    
    log_metric "node_${NODE_NAME}_cpu_percent" $CPU_USAGE "$INSTANCE_TYPE"
    log_metric "node_${NODE_NAME}_memory_percent" $MEM_USAGE "$INSTANCE_TYPE"
  done
  
  echo "Status atual dos nós:"
  kubectl get nodes
  echo "Status dos pods:"
  kubectl get pods -n test-scaling
  echo "Status do Cluster Autoscaler (últimos logs):"
  kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20
  echo "Detalhes do grupos de autoscaling:"
  kubectl -n kube-system describe configmap cluster-autoscaler-status | grep -A5 "NodeGroups:"
  
  sleep 60
done

# Segunda escala: 10 réplicas
SCALE_10_START=$(date +%s)
log_metric "scale_10_start_time" $SCALE_10_START

echo "Escalando o deployment para 10 réplicas..."
kubectl scale deployment nginx-test -n test-scaling --replicas=10
log_metric "target_replicas" 10

echo "Aguardando 5 minutos após escalar para 10 réplicas..."
for i in {1..5}; do
  echo "Minuto $i/5 (10 réplicas)..."
  
  # Coletar métricas atuais
  CURRENT_NODES=$(kubectl get nodes --no-headers | wc -l)
  PENDING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Pending --no-headers | wc -l)
  RUNNING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Running --no-headers | wc -l)
  
  # Registrar métricas
  log_metric "current_node_count" $CURRENT_NODES
  log_metric "pending_pods" $PENDING_PODS
  log_metric "running_pods" $RUNNING_PODS
  
  # Verificar se novos nós foram adicionados desde a última verificação
  if [[ $CURRENT_NODES -gt $MAX_NODES ]]; then
    NEW_NODE_TIME=$(date +%s)
    TIME_SINCE_SCALE=$((NEW_NODE_TIME - SCALE_10_START))
    log_metric "new_node_time_since_scale_10" $TIME_SINCE_SCALE
    MAX_NODES=$CURRENT_NODES
    log_metric "max_node_count_10replicas" $MAX_NODES
    
    # Registrar informações dos nós
    log_all_nodes_info
  fi
  
  # Coletar uso de recursos por nó
  echo "Coletando métricas de utilização de recursos..."
  kubectl top nodes | tail -n +2 | while read -r line; do
    NODE_NAME=$(echo "$line" | awk '{print $1}')
    CPU_USAGE=$(echo "$line" | awk '{print $3}' | sed 's/%//')
    MEM_USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    INSTANCE_TYPE=$(get_instance_type $NODE_NAME)
    
    log_metric "node_${NODE_NAME}_cpu_percent" $CPU_USAGE "$INSTANCE_TYPE"
    log_metric "node_${NODE_NAME}_memory_percent" $MEM_USAGE "$INSTANCE_TYPE"
  done
  
  echo "Status atual dos nós:"
  kubectl get nodes
  echo "Status dos pods:"
  kubectl get pods -n test-scaling
  echo "Status do Cluster Autoscaler (últimos logs):"
  kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20
  echo "Detalhes do grupos de autoscaling:"
  kubectl -n kube-system describe configmap cluster-autoscaler-status | grep -A5 "NodeGroups:"
  
  sleep 60
done

# Terceira escala: 30 réplicas
SCALE_30_START=$(date +%s)
log_metric "scale_30_start_time" $SCALE_30_START

echo "Escalando o deployment para 30 réplicas..."
kubectl scale deployment nginx-test -n test-scaling --replicas=30
log_metric "target_replicas" 30

echo "Aguardando 7 minutos após escalar para 30 réplicas..."
for i in {1..7}; do
  echo "Minuto $i/7 (30 réplicas)..."
  
  # Coletar métricas atuais
  CURRENT_NODES=$(kubectl get nodes --no-headers | wc -l)
  PENDING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Pending --no-headers | wc -l)
  RUNNING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Running --no-headers | wc -l)
  
  # Registrar métricas
  log_metric "current_node_count" $CURRENT_NODES
  log_metric "pending_pods" $PENDING_PODS
  log_metric "running_pods" $RUNNING_PODS
  
  # Verificar se novos nós foram adicionados desde a última verificação
  if [[ $CURRENT_NODES -gt $MAX_NODES ]]; then
    NEW_NODE_TIME=$(date +%s)
    TIME_SINCE_SCALE=$((NEW_NODE_TIME - SCALE_30_START))
    log_metric "new_node_time_since_scale_30" $TIME_SINCE_SCALE
    MAX_NODES=$CURRENT_NODES
    log_metric "max_node_count_30replicas" $MAX_NODES
    
    # Registrar informações dos nós
    log_all_nodes_info
  fi
  
  # Coletar uso de recursos por nó
  echo "Coletando métricas de utilização de recursos..."
  kubectl top nodes | tail -n +2 | while read -r line; do
    NODE_NAME=$(echo "$line" | awk '{print $1}')
    CPU_USAGE=$(echo "$line" | awk '{print $3}' | sed 's/%//')
    MEM_USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    INSTANCE_TYPE=$(get_instance_type $NODE_NAME)
    
    log_metric "node_${NODE_NAME}_cpu_percent" $CPU_USAGE "$INSTANCE_TYPE"
    log_metric "node_${NODE_NAME}_memory_percent" $MEM_USAGE "$INSTANCE_TYPE"
  done
  
  echo "Status atual dos nós:"
  kubectl get nodes
  echo "Status dos pods:"
  kubectl get pods -n test-scaling
  echo "Status do Cluster Autoscaler (últimos logs):"
  kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20
  echo "Detalhes do grupos de autoscaling:"
  kubectl -n kube-system describe configmap cluster-autoscaler-status | grep -A5 "NodeGroups:"
  
  sleep 60
done

# Registrar fim do scale-up
SCALE_UP_END=$(date +%s)
SCALE_UP_DURATION=$((SCALE_UP_END - SCALE_UP_START))
log_metric "scale_up_duration_seconds" $SCALE_UP_DURATION
log_metric "max_node_count" $MAX_NODES

# Capturar timestamp antes do scale-down
SCALE_DOWN_START=$(date +%s)
log_metric "scale_down_start_time" $SCALE_DOWN_START

echo "Reduzindo o deployment para testar o scale-down dos nodes..."
kubectl scale deployment nginx-test -n test-scaling --replicas=1
log_metric "target_replicas" 1

echo "Aguardando 15 minutos para que o Cluster Autoscaler remova nodes..."
FIRST_NODE_REMOVAL_TIME=0

for i in {1..15}; do
  echo "Minuto $i/15..."
  
  # Coletar métricas atuais
  CURRENT_NODES=$(kubectl get nodes --no-headers | wc -l)
  PENDING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Pending --no-headers | wc -l)
  RUNNING_PODS=$(kubectl get pods -n test-scaling --field-selector=status.phase=Running --no-headers | wc -l)
  
  # Registrar métricas
  log_metric "current_node_count" $CURRENT_NODES
  log_metric "pending_pods" $PENDING_PODS
  log_metric "running_pods" $RUNNING_PODS
  
  # Detectar primeira remoção de nó
  if [[ $CURRENT_NODES -lt $MAX_NODES && $FIRST_NODE_REMOVAL_TIME -eq 0 ]]; then
    FIRST_NODE_REMOVAL_TIME=$(date +%s)
    TIME_TO_FIRST_REMOVAL=$((FIRST_NODE_REMOVAL_TIME - SCALE_DOWN_START))
    log_metric "time_to_first_node_removal_seconds" $TIME_TO_FIRST_REMOVAL
    log_all_nodes_info
  fi
  
  # Coletar uso de recursos por nó
  echo "Coletando métricas de utilização de recursos..."
  kubectl top nodes | tail -n +2 | while read -r line; do
    NODE_NAME=$(echo "$line" | awk '{print $1}')
    CPU_USAGE=$(echo "$line" | awk '{print $3}' | sed 's/%//')
    MEM_USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    INSTANCE_TYPE=$(get_instance_type $NODE_NAME)
    
    log_metric "node_${NODE_NAME}_cpu_percent" $CPU_USAGE "$INSTANCE_TYPE"
    log_metric "node_${NODE_NAME}_memory_percent" $MEM_USAGE "$INSTANCE_TYPE"
  done
  
  echo "Status atual dos nós:"
  kubectl get nodes
  echo "Status dos pods:"
  kubectl get pods -n test-scaling
  echo "Status do Cluster Autoscaler (últimos logs):"
  kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20
  echo "Detalhes do grupos de autoscaling:"
  kubectl -n kube-system describe configmap cluster-autoscaler-status | grep -A5 "NodeGroups:"
  
  sleep 60
done

# Registrar fim do scale-down
SCALE_DOWN_END=$(date +%s)
SCALE_DOWN_DURATION=$((SCALE_DOWN_END - SCALE_DOWN_START))
log_metric "scale_down_duration_seconds" $SCALE_DOWN_DURATION
log_metric "final_node_count" $CURRENT_NODES

# Registrar tempo total do teste
TEST_END_TIME=$(date +%s)
TOTAL_TEST_DURATION=$((TEST_END_TIME - START_TIME))
log_metric "total_test_duration_seconds" $TOTAL_TEST_DURATION

echo "Teste concluído. Métricas salvas em $METRICS_FILE"
echo "Para limpar os recursos de teste, execute: kubectl delete -f nginx-node-scaling.yaml" 