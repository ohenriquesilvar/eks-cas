# EKS Cluster com Autoscaler

Este projeto Terraform cria um cluster EKS na AWS com as seguintes características:

- Cluster EKS com dois grupos de nós: um com instâncias do tipo t3.medium e outro com instâncias do tipo m5.large
- Cluster Autoscaler configurado e pronto para escalar os nós conforme a demanda
- Deployment de teste para verificar o autoscaling

## Pré-requisitos

- AWS CLI configurado com credenciais válidas
- Terraform instalado (versão >= 1.0.0)
- kubectl instalado
- Acesso à AWS com permissões suficientes para criar recursos EKS

## Arquivos do Projeto

- `main.tf`: Configuração principal, incluindo o cluster EKS e grupos de nós
- `variables.tf`: Variáveis do projeto
- `outputs.tf`: Outputs do Terraform
- `cluster-autoscaler.tf`: Configuração do Cluster Autoscaler
- `test-deployment.tf`: Deployment de teste para verificar o autoscaling
- `test-scaling.sh`: Script para testar o scaling de nós

## Como Usar

1. Inicialize o Terraform:

```bash
terraform init
```

2. Valide a configuração:

```bash
terraform validate
```

3. Crie um plano de execução:

```bash
terraform plan -out=tfplan
```

4. Aplique a configuração:

```bash
terraform apply tfplan
```

5. Configure o kubectl para acessar o cluster:

```bash
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

6. Verifique se o Cluster Autoscaler está em execução:

```bash
kubectl get pods -n kube-system | grep cluster-autoscaler
```

7. Execute o script de teste para verificar o autoscaling:

```bash
./test-scaling.sh
```

## Teste de Autoscaling

O script `test-scaling.sh` fará o seguinte:

1. Escalar o deployment de teste para 20 réplicas, o que deve causar um scale-up dos nós
2. Aguardar 5 minutos e monitorar os logs do Cluster Autoscaler
3. Reduzir o deployment para 1 réplica, o que deve causar um scale-down dos nós
4. Aguardar 10 minutos e monitorar novamente os logs

## Limpar Recursos

Para remover todos os recursos criados:

```bash
terraform destroy
```

## Estrutura de Nós

- Nós do tipo t3.medium: Para cargas leves e uso em desenvolvimento
- Nós do tipo m5.large: Para cargas mais intensivas

O Cluster Autoscaler irá criar e remover nós conforme necessário com base na utilização dos recursos.
