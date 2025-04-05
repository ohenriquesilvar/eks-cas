#!/bin/bash

# Aplicar o deployment de teste
echo "Aplicando o deployment de teste Nginx..."
kubectl apply -f nginx-node-scaling.yaml

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

# Calcular número de pods baseado nos recursos disponíveis
# Cada pod pede 500m de CPU e 512Mi de memória
# Isto deve criar demanda suficiente para forçar o Cluster Autoscaler a adicionar nodes
echo "Escalando o deployment para forçar o scaling de nodes..."
  kubectl scale deployment nginx-test -n test-scaling --replicas=10

echo "Aguardando 10 minutos para que o Cluster Autoscaler adicione nodes..."
for i in {1..10}; do
  echo "Minuto $i/10..."
  sleep 60
  echo "Status atual dos nós:"
  kubectl get nodes
  echo "Status dos pods (verificando se estão em estado Pending, que pode acionar o autoscaling):"
  kubectl get pods -n test-scaling
  echo "Status do Cluster Autoscaler (últimos logs):"
  kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20
  echo "Detalhes do grupos de autoscaling:"
  kubectl -n kube-system describe configmap cluster-autoscaler-status | grep -A5 "NodeGroups:"
done

echo "Reduzindo o deployment para testar o scale-down dos nodes..."
kubectl scale deployment nginx-test -n test-scaling --replicas=1

echo "Aguardando 20 minutos para que o Cluster Autoscaler remova nodes (geralmente leva mais tempo)..."
for i in {1..20}; do
  echo "Minuto $i/20..."
  sleep 60
  echo "Status atual dos nós:"
  kubectl get nodes
  echo "Status dos pods:"
  kubectl get pods -n test-scaling
  echo "Status do Cluster Autoscaler (últimos logs):"
  kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20
  echo "Detalhes do grupos de autoscaling:"
  kubectl -n kube-system describe configmap cluster-autoscaler-status | grep -A5 "NodeGroups:"
done

echo "Teste concluído. Verifique os logs para entender como o Cluster Autoscaler se comportou."
echo "Para limpar os recursos de teste, execute: kubectl delete -f nginx-node-scaling.yaml" 