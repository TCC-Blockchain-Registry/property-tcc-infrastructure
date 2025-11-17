# Plano de Implementação AWS
## Property Tokenization Platform - Deployment em Produção

**Versão**: 1.0
**Data**: Novembro 2025
**Projeto**: TCC - Blockchain Registry
**Objetivo**: Deploy completo do sistema de tokenização de imóveis em AWS

---

## 📋 Sumário Executivo

Este documento descreve o plano completo para implementação do Property Tokenization Platform na AWS, incluindo infraestrutura, serviços de aplicação, blockchain privada Hyperledger Besu e configuração de segurança.

**Tempo Total Estimado**: 2-3 horas (primeira execução)
**Custo Estimado**: ~$26 USD para 3 dias de operação
**Complexidade**: Média (automatizada por scripts)

---

## 🎯 Objetivos do Deployment

### Objetivos Técnicos
- ✅ Implementar arquitetura microservices em AWS ECS Fargate
- ✅ Configurar blockchain privada Hyperledger Besu multi-AZ
- ✅ Garantir alta disponibilidade (2 AZs)
- ✅ Implementar segurança em camadas (VPC, SGs, Secrets Manager)
- ✅ Configurar monitoramento com CloudWatch
- ✅ Estabelecer pipeline de deployment reproduzível

### Objetivos de Negócio
- 🎓 Demonstrar viabilidade técnica para TCC
- 💰 Manter custos dentro do orçamento ($100)
- 📊 Permitir apresentação/demo funcional
- 🔒 Garantir compliance (LGPD, segurança de dados)

---

## 🏗️ Arquitetura Resultante

### Diagrama de Alto Nível

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                           │
│                       Region: us-east-1                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │   us-east-1a     │         │   us-east-1b     │        │
│  │                  │         │                  │        │
│  │ • Besu Val 1     │         │ • Besu Val 3     │        │
│  │ • Besu Val 2     │         │ • Besu Val 4     │        │
│  │ • BFF (1/2)      │         │ • BFF (2/2)      │        │
│  │ • Orchestrator   │         │ • Orchestrator   │        │
│  │   (1/2)          │         │   (2/2)          │        │
│  │ • Frontend (1/2) │         │ • Frontend (2/2) │        │
│  │ • Offchain (1/2) │         │ • Offchain (2/2) │        │
│  │ • Worker         │         │                  │        │
│  │ • RabbitMQ       │         │                  │        │
│  └──────────────────┘         └──────────────────┘        │
│           │                            │                   │
│           └────────────┬───────────────┘                   │
│                        │                                   │
│              ┌─────────▼──────────┐                        │
│              │  Load Balancer     │ ◄── Internet           │
│              │   (ALB Public)     │                        │
│              └────────────────────┘                        │
│                        │                                   │
│              ┌─────────▼──────────┐                        │
│              │    ECS Cluster     │                        │
│              │  (Fargate Tasks)   │                        │
│              └────────┬───────────┘                        │
│                       │                                    │
│         ┌─────────────┼─────────────┐                     │
│         │             │             │                     │
│    ┌────▼───┐    ┌───▼────┐   ┌───▼────┐                │
│    │  RDS   │    │  EFS   │   │Secrets │                │
│    │Postgres│    │ (Besu) │   │Manager │                │
│    └────────┘    └────────┘   └────────┘                │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### Componentes AWS

| Componente | Tipo | Quantidade | Função |
|------------|------|------------|--------|
| VPC | Network | 1 | Isolamento de rede |
| Subnets | Network | 4 (2 public, 2 private) | Segmentação multi-AZ |
| ECS Cluster | Compute | 1 | Orquestração de containers |
| Fargate Tasks | Compute | 13 | Serviços containerizados |
| ALB | Network | 2 (public + internal) | Load balancing |
| RDS PostgreSQL | Database | 1 | Banco de dados relacional |
| EFS | Storage | 1 | Storage persistente Besu |
| ECR | Registry | 7 repos | Docker image registry |
| Secrets Manager | Security | 9 secrets | Gerenciamento de credenciais |
| CloudWatch | Monitoring | 10 log groups | Logs e métricas |
| Security Groups | Security | 5 | Firewall rules |
| IAM Roles | Security | 2 | Permissões de serviço |

---

## ✅ Pré-requisitos

### 1. Conta e Credenciais AWS

**Requisitos:**
- [ ] Conta AWS ativa
- [ ] Créditos disponíveis (~$100 recomendado)
- [ ] IAM User com permissões:
  - ECS Full Access
  - VPC Full Access
  - RDS Full Access
  - ECR Full Access
  - Secrets Manager Full Access
  - CloudWatch Logs Full Access
  - IAM Role Creation

**Configuração:**
```bash
aws configure
# AWS Access Key ID: [sua-access-key]
# AWS Secret Access Key: [sua-secret-key]
# Default region name: us-east-1
# Default output format: json
```

**Validação:**
```bash
aws sts get-caller-identity
# Deve retornar: UserId, Account, Arn
```

---

### 2. Ferramentas Instaladas

**Obrigatórias:**

| Ferramenta | Versão Mínima | Instalação | Validação |
|------------|---------------|------------|-----------|
| AWS CLI | 2.x | `brew install awscli` | `aws --version` |
| Terraform | 1.5+ | `brew install terraform` | `terraform version` |
| Docker | 20+ | `brew install docker` | `docker --version` |
| jq | 1.6+ | `brew install jq` | `jq --version` |
| git | 2.x | `brew install git` | `git --version` |

**Opcional (para deploy de contratos):**
| Ferramenta | Versão | Instalação | Validação |
|------------|--------|------------|-----------|
| Foundry | Latest | `curl -L https://foundry.paradigm.xyz \| bash` | `forge --version` |
| Node.js | 18+ | `brew install node` | `node --version` |

---

### 3. Código Fonte Preparado

**Repositórios Necessários:**

```bash
# 1. Repositório de Infraestrutura (obrigatório)
git clone https://github.com/TCC-Blockchain-Registry/property-tcc-infrastructure.git

# 2. Repositórios de Aplicação (para build de imagens)
git clone https://github.com/TCC-Blockchain-Registry/wallet-property-fed.git
git clone https://github.com/TCC-Blockchain-Registry/bff-gateway.git
git clone https://github.com/TCC-Blockchain-Registry/core-orchestrator-srv.git
git clone https://github.com/TCC-Blockchain-Registry/offchain-consumer-srv.git
git clone https://github.com/TCC-Blockchain-Registry/queue-worker.git
git clone https://github.com/TCC-Blockchain-Registry/message-queue.git
git clone https://github.com/TCC-Blockchain-Registry/besu-property-ledger.git
```

**Estrutura Esperada:**
```
/Users/leonardodev/tcc/
├── infrastructure/                  # Este repo
├── wallet-property-fed/            # Frontend
├── bff-gateway/                    # BFF
├── core-orchestrator-srv/          # Backend
├── offchain-consumer-srv/          # Offchain API
├── queue-worker/                   # Worker
├── message-queue/                  # RabbitMQ
└── besu-property-ledger/           # Blockchain
```

---

### 4. Ajustes Pré-Deployment (CRÍTICO)

**⚠️ ATENÇÃO**: Estes ajustes devem ser feitos ANTES de executar o deployment:

#### 4.1 Frontend - Ajustar Portas
```dockerfile
# wallet-property-fed/Dockerfile
# Linha 19: Mudar porta
EXPOSE 3000  # (atualmente 80)

# wallet-property-fed/nginx.conf
# Linha 2: Mudar listener
listen 3000;  # (atualmente 80)
```

#### 4.2 Orchestrator - Ajustar Porta
```dockerfile
# core-orchestrator-srv/Dockerfile
# Linha 39: Mudar porta
EXPOSE 8081  # (atualmente 8080)
```

#### 4.3 RabbitMQ - Criar Dockerfile
```dockerfile
# message-queue/Dockerfile (CRIAR ARQUIVO NOVO)
FROM rabbitmq:3.12-management-alpine

COPY rabbitmq.conf /etc/rabbitmq/rabbitmq.conf
COPY definitions.json /etc/rabbitmq/definitions.json

RUN rabbitmq-plugins enable --offline rabbitmq_management

EXPOSE 5672 15672

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD rabbitmq-diagnostics -q ping || exit 1
```

**Validação dos Ajustes:**
```bash
# Verificar se as portas estão corretas
grep -n "EXPOSE" */Dockerfile
# Deve mostrar:
#   wallet-property-fed/Dockerfile:19:EXPOSE 3000
#   core-orchestrator-srv/Dockerfile:39:EXPOSE 8081
#   message-queue/Dockerfile:7:EXPOSE 5672 15672
```

---

## 📅 Fases do Deployment

### 🔵 FASE 0: Preparação e Validação (15 min)

**Objetivo**: Garantir que todos os pré-requisitos estão atendidos

**Tarefas:**
1. ✅ Validar credenciais AWS
2. ✅ Verificar ferramentas instaladas
3. ✅ Confirmar estrutura de diretórios
4. ✅ Revisar configurações Terraform
5. ✅ Validar Dockerfiles ajustados

**Script Automatizado:**
```bash
cd property-tcc-infrastructure/deploy-scripts
./01-setup-aws-cli.sh
```

**Outputs Esperados:**
```
✅ AWS CLI: OK (version 2.x)
✅ Terraform: OK (version 1.5+)
✅ Docker: OK (version 20+)
✅ jq: OK
✅ AWS Credentials: OK (account: xxxxx)
✅ Default Region: us-east-1
```

**Critérios de Sucesso:**
- [ ] Todas as ferramentas instaladas
- [ ] AWS CLI autenticado
- [ ] Região configurada para us-east-1
- [ ] Sem erros no script

**Em caso de falha:**
- Instalar ferramenta faltante
- Configurar `aws configure`
- Verificar permissões IAM

---

### 🟢 FASE 1: Infraestrutura Base (Terraform) (5-7 min)

**Objetivo**: Provisionar toda infraestrutura AWS com Terraform

**Recursos Criados:**
- VPC (10.0.0.0/16)
- 2 Public Subnets (10.0.0.0/24, 10.0.1.0/24)
- 2 Private Subnets (10.0.10.0/24, 10.0.11.0/24)
- Internet Gateway
- NAT Gateway (1 para reduzir custos)
- 5 Security Groups
- 2 IAM Roles (execution + task)
- 7 ECR Repositories
- RDS PostgreSQL (db.t4g.micro)
- EFS File System (4 access points)
- ECS Cluster (Fargate)
- 2 Application Load Balancers
- CloudWatch Log Groups (10)
- Secrets Manager (9 secrets)

**Script Automatizado:**
```bash
cd property-tcc-infrastructure/deploy-scripts
./02-terraform-apply.sh
```

**Fluxo do Script:**
```
1. Navega para terraform-aws/
2. Cria terraform.tfvars (se não existir)
3. terraform init
4. terraform validate
5. terraform plan -out=tfplan
6. [PAUSA] Solicita confirmação do usuário
7. terraform apply tfplan
8. Salva outputs em terraform-outputs.json
9. Exibe resumo (ALB URL, RDS endpoint, cluster name)
```

**Interação do Usuário:**
```
Review the plan above
=========================================

Do you want to apply this plan? (yes/no): yes  ← DIGITE "yes"
```

**Outputs Esperados:**
```
Apply complete! Resources: 35 added, 0 changed, 0 destroyed.

alb_url = "http://property-tcc-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
rds_endpoint = "property-tcc-postgres.xxxxxxxxx.us-east-1.rds.amazonaws.com:5432"
ecs_cluster_name = "property-tcc-cluster"
```

**Critérios de Sucesso:**
- [ ] 35 recursos criados (0 erros)
- [ ] ALB URL acessível (pode dar 404, mas responde)
- [ ] RDS endpoint disponível
- [ ] ECS cluster visível no console AWS

**Troubleshooting:**

| Erro | Causa Provável | Solução |
|------|----------------|---------|
| "Error: UnauthorizedOperation" | Permissões IAM insuficientes | Adicionar permissões ou usar Admin |
| "Error: VPC limit exceeded" | Já tem 5 VPCs na conta | Deletar VPCs antigas |
| "Error: Elastic IP limit" | Limite de EIPs atingido | Liberar EIPs não usados |
| "Error: subnet conflict" | CIDR já em uso | Mudar variável `vpc_cidr` |

**Tempo**: ~5-7 minutos
**Custo**: $0 (recursos criados, mas serviços ainda não rodando)

---

### 🟡 FASE 2: Build e Push de Imagens Docker (10-20 min)

**Objetivo**: Construir todas as imagens Docker e enviar para ECR

**Imagens a serem construídas:**
1. Frontend (wallet-property-fed)
2. BFF Gateway (bff-gateway)
3. Orchestrator (core-orchestrator-srv)
4. Offchain API (offchain-consumer-srv)
5. Queue Worker (queue-worker)
6. RabbitMQ (message-queue)
7. Besu Validator (infrastructure/besu-aws)

**Script Automatizado:**
```bash
cd property-tcc-infrastructure/deploy-scripts
./03-build-push-images.sh
```

**Fluxo do Script:**
```
1. Obtém AWS Account ID e Region
2. Login no ECR: aws ecr get-login-password | docker login
3. Para cada serviço:
   a. cd /path/to/service
   b. docker build -t service:latest .
   c. docker tag service:latest <ecr-url>:latest
   d. docker push <ecr-url>:latest
   e. cd back
4. Exibe resumo de imagens
```

**Progresso Esperado:**
```
Building: frontend
  [+] Building 145.2s (15/15) FINISHED
  => [internal] load build definition
  => [stage-0 1/6] FROM node:18-alpine
  => [stage-1 1/3] FROM nginx:alpine
  ✓ frontend pushed successfully

Building: bff-gateway
  [+] Building 67.3s (12/12) FINISHED
  ✓ bff-gateway pushed successfully

Building: orchestrator
  [+] Building 312.5s (17/17) FINISHED  ← Mais demorado (Maven build)
  ✓ orchestrator pushed successfully

... (continua para todos os 7 serviços)
```

**Critérios de Sucesso:**
- [ ] 7 imagens construídas sem erros
- [ ] 7 imagens enviadas para ECR
- [ ] Tag `:latest` visível no console ECR

**Troubleshooting:**

| Erro | Causa | Solução |
|------|-------|---------|
| "docker: command not found" | Docker não instalado | `brew install docker` |
| "Cannot connect to Docker daemon" | Docker não iniciado | Abrir Docker Desktop |
| "Error: denied: invalid token" | ECR login expirado | Re-executar login no ECR |
| "Error: COPY failed" | Dockerfile inválido | Verificar ajustes da Fase 0 |
| "Error: network timeout" | Rede lenta | Aumentar timeout Docker |

**Tempo**:
- Primeira execução: ~15-20 min (cache vazio)
- Execuções seguintes: ~5-8 min (cache preenchido)

**Custo**: ~$0.10 (storage ECR)

---

### 🔵 FASE 3: Deploy da Blockchain Besu (3-5 min)

**Objetivo**: Iniciar 4 validadores Besu distribuídos em 2 AZs

**Validadores:**
- Validator 1 (us-east-1a) - RPC: 8545, P2P: 30303
- Validator 2 (us-east-1a) - RPC: 8546, P2P: 30304
- Validator 3 (us-east-1b) - RPC: 8547, P2P: 30305
- Validator 4 (us-east-1b) - RPC: 8548, P2P: 30306

**Script Automatizado:**
```bash
cd property-tcc-infrastructure/deploy-scripts
./04-deploy-besu.sh
```

**Fluxo do Script:**
```
1. Obtém cluster name do Terraform output
2. Para cada validator (1-4):
   a. aws ecs update-service --force-new-deployment
   b. Espera deployment estabilizar (aws ecs wait services-stable)
3. Verifica running count de cada validator
4. Exibe endpoints de Service Discovery
```

**Progresso Esperado:**
```
Deploying: property-tcc-besu-validator-1
Waiting for property-tcc-besu-validator-1 to stabilize...
✓ property-tcc-besu-validator-1 is stable

Deploying: property-tcc-besu-validator-2
Waiting for property-tcc-besu-validator-2 to stabilize...
✓ property-tcc-besu-validator-2 is stable

Deploying: property-tcc-besu-validator-3
Waiting for property-tcc-besu-validator-3 to stabilize...
✓ property-tcc-besu-validator-3 is stable

Deploying: property-tcc-besu-validator-4
Waiting for property-tcc-besu-validator-4 to stabilize...
✓ property-tcc-besu-validator-4 is stable
```

**Validação Manual:**
```bash
# Ver logs do validator 1
aws logs tail /ecs/property-tcc-besu-validator-1 --follow

# Procurar por:
#   "Imported block" ou "Produced block" → Consenso funcionando
#   "Peer count: 3" → Conectado aos outros validadores
```

**Critérios de Sucesso:**
- [ ] 4 validators rodando (running count = 1 cada)
- [ ] Logs mostram "Imported block" ou "Produced block"
- [ ] Peer count >= 3 (cada validator conectado aos outros)
- [ ] Block number crescendo

**Troubleshooting:**

| Problema | Causa | Solução |
|----------|-------|---------|
| Validator não inicia | Imagem não encontrada | Verificar ECR push (Fase 2) |
| Peer count = 0 | Security Group bloqueando P2P | Verificar SG permite 30303-30306 TCP/UDP |
| Logs: "Failed to connect" | Service Discovery não funciona | Verificar namespace `.local` criado |
| Consensus não forma | < 3 validators rodando | Garantir 3+ validators ativos (QBFT requer maioria) |

**Tempo**: ~3-5 minutos
**Custo**: +$2/dia (4 validators × 1024 CPU × 2048 MB)

---

### 🟢 FASE 4: Deploy dos Smart Contracts (10-30 min)

**Objetivo**: Implantar contratos ERC-3643 na rede Besu

**Contratos a serem deployados:**
1. PropertyTitleTREX (token principal)
2. ApprovalsModule (sistema de aprovações)
3. RegistryMDCompliance (registro de propriedades)
4. ApproversRegistry (registro de aprovadores)
5. IdentityRegistry (OnchainID)
6. ModularCompliance (regras de compliance)

**Opções de Deployment:**

#### **Opção A: Local (Recomendado para primeira vez)**

```bash
cd property-tcc-infrastructure/deploy-scripts
./05-deploy-contracts.sh

# No menu, escolher opção 1
Choose deployment method (1/2/3): 1

# Script irá:
# 1. Perguntar se já tem DEPLOYED_ADDRESSES.txt → Responder "no"
# 2. Iniciar Besu local (script/setup/setup-network.sh)
# 3. Compilar contratos (forge build)
# 4. Deployer contratos (script/setup/deploy-contracts.sh)
# 5. Salvar endereços em DEPLOYED_ADDRESSES.txt
```

**Endereços gerados** (exemplo):
```
PROPERTY_TITLE_TREX=0x5FbDB2315678afecb367f032d93F642f64180aa3
APPROVALS_MODULE=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
REGISTRY_MD_COMPLIANCE=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
APPROVERS_REGISTRY=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
IDENTITY_REGISTRY=0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
MODULAR_COMPLIANCE=0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
```

**⚠️ IMPORTANTE:** Após deployment local, você precisa:

1. **Atualizar Secrets Manager na AWS:**
```bash
aws secretsmanager put-secret-value \
  --secret-id property-tcc/contract/property-title-address \
  --secret-string "0x5FbDB2315678afecb367f032d93F642f64180aa3"

# Repetir para os outros 5 contratos...
```

2. **Re-deployer contratos na AWS Besu** (quando estiver acessível):
   - Via ECS Exec (Opção 3 do script)
   - Ou via NLB temporário (Opção 2 do script)

#### **Opção B: Via ECS Exec (Deploy direto na AWS)**

```bash
# 1. Obter task ARN do orchestrator
TASK=$(aws ecs list-tasks \
  --cluster property-tcc-cluster \
  --service property-tcc-orchestrator \
  --query 'taskArns[0]' \
  --output text)

# 2. Conectar ao container
aws ecs execute-command \
  --cluster property-tcc-cluster \
  --task $TASK \
  --container orchestrator \
  --interactive \
  --command /bin/bash

# 3. Dentro do container:
apt-get update && apt-get install -y curl git
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc && foundryup
cd /tmp
git clone <repo-besu-property-ledger>
cd besu-property-ledger
forge script script/Deploy.s.sol \
  --rpc-url http://property-tcc-besu-validator-1.property-tcc.local:8545 \
  --broadcast
```

**Critérios de Sucesso:**
- [ ] 6 contratos deployados
- [ ] DEPLOYED_ADDRESSES.txt criado
- [ ] Endereços atualizados no Secrets Manager

**Tempo**: 10-30 min (dependendo da opção)
**Custo**: $0 (gas fee = 0 na rede privada)

---

### 🟡 FASE 5: Deploy dos Serviços de Aplicação (5-10 min)

**Objetivo**: Iniciar todos os serviços de aplicação na ordem correta

**Ordem de Deployment** (respeitando dependências):
1. RabbitMQ (sem dependências)
2. Offchain API (depende de Besu)
3. Queue Worker (depende de RabbitMQ + Offchain)
4. Orchestrator (depende de RabbitMQ + PostgreSQL)
5. BFF Gateway (depende de Orchestrator + Offchain)
6. Frontend (depende de BFF)

**Script Automatizado:**
```bash
cd property-tcc-infrastructure/deploy-scripts
./06-deploy-services.sh
```

**Fluxo do Script:**
```
1. Deployment sequencial:
   - aws ecs update-service --service property-tcc-rabbitmq --force-new-deployment
   - [espera estabilizar]
   - aws ecs update-service --service property-tcc-offchain-api --force-new-deployment
   - [espera estabilizar]
   - ... (continua para todos)

2. Verifica running count de cada serviço

3. Exibe resumo de saúde
```

**Progresso Esperado:**
```
Deploying: property-tcc-rabbitmq
✓ property-tcc-rabbitmq is stable

Deploying: property-tcc-offchain-api
✓ property-tcc-offchain-api is stable

Deploying: property-tcc-queue-worker
✓ property-tcc-queue-worker is stable

Deploying: property-tcc-orchestrator
✓ property-tcc-orchestrator is stable

Deploying: property-tcc-bff-gateway
✓ property-tcc-bff-gateway is stable

Deploying: property-tcc-frontend
✓ property-tcc-frontend is stable

All Services: HEALTHY
✓ property-tcc-rabbitmq: 1/1 running
✓ property-tcc-offchain-api: 2/2 running
✓ property-tcc-queue-worker: 1/1 running
✓ property-tcc-orchestrator: 2/2 running
✓ property-tcc-bff-gateway: 2/2 running
✓ property-tcc-frontend: 2/2 running
```

**Critérios de Sucesso:**
- [ ] 6 serviços rodando
- [ ] Running count = Desired count para todos
- [ ] Health checks passando
- [ ] Logs sem erros críticos

**Troubleshooting:**

| Serviço | Sintoma | Causa Provável | Solução |
|---------|---------|----------------|---------|
| Orchestrator | CrashLoopBackOff | DB connection failed | Verificar RDS endpoint, security group |
| BFF Gateway | 502 Bad Gateway | Orchestrator não acessível | Verificar Service Discovery, health check |
| Offchain API | "Cannot connect to Besu" | Besu validators não rodando | Verificar Fase 3 |
| Queue Worker | "ECONNREFUSED RabbitMQ" | RabbitMQ não iniciou | Esperar mais tempo, verificar logs |
| Frontend | Nginx 404 | Build falhou | Verificar logs do build, Dockerfile |

**Comandos de Debug:**
```bash
# Ver logs de um serviço
aws logs tail /ecs/property-tcc-orchestrator --follow

# Ver status detalhado
aws ecs describe-services \
  --cluster property-tcc-cluster \
  --services property-tcc-orchestrator

# Verificar health check do ALB
aws elbv2 describe-target-health \
  --target-group-arn <arn-do-target-group>
```

**Tempo**: ~5-10 minutos
**Custo**: +$10/dia (todos os serviços rodando)

---

### 🟢 FASE 6: Validação e Testes (10-15 min)

**Objetivo**: Verificar que todo o sistema está funcional

**Script Automatizado:**
```bash
cd property-tcc-infrastructure/deploy-scripts
./07-health-check.sh
```

**Checklist de Validação:**

#### 6.1 External Services (via ALB)
```bash
ALB_URL=$(cd ../terraform-aws && terraform output -raw alb_url)

# ✅ Frontend
curl -I $ALB_URL
# Esperado: HTTP/1.1 200 OK

# ✅ BFF API
curl $ALB_URL/api/health
# Esperado: {"status":"ok","timestamp":"..."}

# ✅ Orchestrator
curl $ALB_URL/actuator/health
# Esperado: {"status":"UP"}
```

#### 6.2 ECS Services
```bash
# Verificar todos os serviços
aws ecs list-services --cluster property-tcc-cluster

# Esperado: 10 serviços (6 app + 4 Besu)
```

#### 6.3 Database
```bash
aws rds describe-db-instances \
  --db-instance-identifier property-tcc-postgres \
  --query 'DBInstances[0].DBInstanceStatus'

# Esperado: "available"
```

#### 6.4 Blockchain Consensus
```bash
# Ver logs de qualquer validator
aws logs tail /ecs/property-tcc-besu-validator-1 --since 2m

# Procurar por:
# ✓ "Imported block #123" (blocos sendo importados)
# ✓ "Peer count: 3" (conectado aos outros)
```

#### 6.5 Testes Funcionais

**Teste 1: Criar Usuário (Orchestrator)**
```bash
curl -X POST $ALB_URL/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "teste@tcc.com",
    "password": "senha123",
    "cpf": "12345678900",
    "walletAddress": "0x1234567890123456789012345678901234567890"
  }'

# Esperado: 201 Created
```

**Teste 2: Login (BFF)**
```bash
TOKEN=$(curl -X POST $ALB_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "teste@tcc.com",
    "password": "senha123"
  }' | jq -r '.token')

echo $TOKEN
# Esperado: eyJhbGciOiJIUzI1NiIs...
```

**Teste 3: Health Check Completo (Script)**
```bash
./07-health-check.sh

# Esperado:
# Overall Health: EXCELLENT (90%+)
```

**Critérios de Sucesso:**
- [ ] Todos endpoints HTTP respondem 200
- [ ] ECS: 10/10 serviços running
- [ ] Database: available
- [ ] Besu: consensus ativo (blocos crescendo)
- [ ] Testes funcionais passam

**Outputs do Script:**
```
==========================================
System Health Check
==========================================

✓ Frontend: OK (HTTP 200)
✓ BFF API: OK (HTTP 200)
✓ Orchestrator: OK (HTTP 200)

✓ property-tcc-frontend: 2/2 tasks running
✓ property-tcc-bff-gateway: 2/2 tasks running
✓ property-tcc-orchestrator: 2/2 tasks running
✓ property-tcc-offchain-api: 2/2 tasks running
✓ property-tcc-queue-worker: 1/1 tasks running
✓ property-tcc-rabbitmq: 1/1 tasks running
✓ property-tcc-besu-validator-1: 1/1 tasks running
✓ property-tcc-besu-validator-2: 1/1 tasks running
✓ property-tcc-besu-validator-3: 1/1 tasks running
✓ property-tcc-besu-validator-4: 1/1 tasks running

Overall Health: EXCELLENT (100%)
```

**Tempo**: ~10-15 minutos
**Custo**: $0 (apenas testes)

---

### 🔵 FASE 7: Monitoramento e Ajustes (Contínuo)

**Objetivo**: Garantir operação contínua e resolver problemas

**CloudWatch Dashboards:**
```bash
# Ver métricas ECS
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=property-tcc-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Logs em Tempo Real:**
```bash
# Seguir logs de todos os serviços
aws logs tail /ecs/property-tcc-frontend --follow &
aws logs tail /ecs/property-tcc-bff-gateway --follow &
aws logs tail /ecs/property-tcc-orchestrator --follow &
```

**Alertas Configurados:**
- 🚨 ALB Unhealthy Targets (threshold: 0)
- 🚨 ECS CPU High (threshold: 80%)
- 🚨 RDS CPU High (threshold: 80%)

**Ajustes Comuns:**

| Situação | Ação |
|----------|------|
| CPU > 80% | Aumentar CPU/memory em terraform.tfvars |
| Logs volumosos | Reduzir retention para 1 dia |
| Custo alto | Reduzir desired_count de 2→1 |
| Lentidão | Adicionar read replica RDS |

**Tempo**: Contínuo durante operação
**Custo**: Incluído nas fases anteriores

---

## 📊 Resumo de Tempo e Custos

### Tempo Total por Fase

| Fase | Duração | Acumulado |
|------|---------|-----------|
| 0. Preparação | 15 min | 15 min |
| 1. Terraform | 7 min | 22 min |
| 2. Build Images | 15 min | 37 min |
| 3. Deploy Besu | 5 min | 42 min |
| 4. Deploy Contracts | 20 min | 62 min |
| 5. Deploy Services | 10 min | 72 min |
| 6. Validação | 15 min | 87 min |
| **TOTAL** | **~1h30min** | - |

### Custos Estimados (3 dias)

| Recurso | Custo/hora | Custo/dia | 3 dias |
|---------|------------|-----------|--------|
| ECS Tasks (small) | $0.12 | $2.88 | $8.64 |
| ECS Tasks (medium) | $0.30 | $7.20 | $21.60 |
| ALBs (2) | $0.05 | $1.08 | $3.24 |
| NAT Gateway | $0.05 | $1.08 | $3.24 |
| RDS | Free Tier | $0 | $0 |
| EFS | $0.00 | $0.01 | $0.03 |
| ECR | - | $0.03 | $0.10 |
| **TOTAL** | - | **~$12.28** | **~$36.85** |

**Nota**: Valores aproximados. Monitorar com AWS Cost Explorer.

---

## 🛡️ Segurança e Compliance

### Secrets Gerenciados

| Secret | Uso | Rotação |
|--------|-----|---------|
| JWT_SECRET | Autenticação BFF/Orchestrator | Manual |
| DB_PASSWORD | PostgreSQL RDS | Automática AWS |
| RABBITMQ_PASSWORD | RabbitMQ admin | Manual |
| BESU_ADMIN_KEY | Deployment contratos | Manual |
| BESU_ORCHESTRATOR_KEY | Operações backend | Manual |
| BESU_REGISTRAR_KEY | Registro propriedades | Manual |

### Dados Sensíveis (LGPD)

**Armazenamento:**
- CPF: PostgreSQL (encrypted at rest) - NUNCA na blockchain
- Wallet addresses: Blockchain (público)
- Metadata de propriedades: Blockchain (hash only)
- Detalhes pessoais: PostgreSQL (encrypted)

**Anonimização:**
- CPF ↔ Wallet mapping: Off-chain apenas
- Blockchain: Apenas endereços Ethereum (pseudônimos)

---

## 🔄 Rollback e Cleanup

### Rollback Parcial (Se algo der errado)

```bash
# Reverter serviço específico para versão anterior
aws ecs update-service \
  --cluster property-tcc-cluster \
  --service property-tcc-orchestrator \
  --task-definition property-tcc-orchestrator:1  # versão anterior

# Ou reverter deploy forçado
aws ecs update-service \
  --cluster property-tcc-cluster \
  --service property-tcc-orchestrator \
  --force-new-deployment \
  --desired-count 0  # parar serviço temporariamente
```

### Destruição Completa (Após Apresentação)

```bash
cd property-tcc-infrastructure/deploy-scripts
./99-destroy-all.sh

# ⚠️ ATENÇÃO: Isto é IRREVERSÍVEL!
# Vai deletar:
# - Todos os serviços ECS
# - Banco de dados (PERDA DE DADOS)
# - EFS com blockchain (PERDA DE BLOCKCHAIN)
# - Load balancers
# - VPC
# - Todos os recursos AWS
```

**Confirmações Necessárias:**
```
Are you ABSOLUTELY SURE? (type 'destroy' to confirm): destroy
Second confirmation - Type 'YES DELETE EVERYTHING': YES DELETE EVERYTHING
```

**Tempo de Destruição:** ~5-10 minutos

**Verificação Pós-Destruição:**
```bash
# Verificar se VPC foi deletada
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=property-tcc-vpc"
# Esperado: empty

# Verificar ECS cluster
aws ecs describe-clusters --clusters property-tcc-cluster
# Esperado: status="INACTIVE"

# Verificar RDS
aws rds describe-db-instances --db-instance-identifier property-tcc-postgres
# Esperado: DBInstanceNotFound
```

---

## 📚 Apêndices

### A. Checklist Completo de Deployment

**Pré-Deployment:**
- [ ] Conta AWS configurada
- [ ] Credenciais válidas (aws sts get-caller-identity)
- [ ] Ferramentas instaladas (AWS CLI, Terraform, Docker, jq)
- [ ] Código clonado (7+ repositórios)
- [ ] Dockerfiles ajustados (portas corretas)
- [ ] RabbitMQ Dockerfile criado

**Deployment:**
- [ ] Fase 0: Validação (./01-setup-aws-cli.sh)
- [ ] Fase 1: Terraform (./02-terraform-apply.sh)
- [ ] Fase 2: Build Images (./03-build-push-images.sh)
- [ ] Fase 3: Deploy Besu (./04-deploy-besu.sh)
- [ ] Fase 4: Deploy Contracts (./05-deploy-contracts.sh)
- [ ] Fase 5: Deploy Services (./06-deploy-services.sh)
- [ ] Fase 6: Validação (./07-health-check.sh)

**Pós-Deployment:**
- [ ] URLs salvas (./08-show-urls.sh)
- [ ] Testes funcionais executados
- [ ] Apresentação/demo realizada
- [ ] Cleanup (./99-destroy-all.sh)

### B. Portas e Endpoints

| Serviço | Porta | Protocolo | Acesso |
|---------|-------|-----------|--------|
| Frontend | 3000 | HTTP | ALB público |
| BFF Gateway | 4000 | HTTP | ALB público |
| Orchestrator | 8081 | HTTP | ALB público + Service Discovery |
| Offchain API | 3001 | HTTP | ALB interno + Service Discovery |
| Queue Worker | - | - | Interno apenas |
| RabbitMQ AMQP | 5672 | AMQP | Service Discovery |
| RabbitMQ Management | 15672 | HTTP | Service Discovery |
| Besu RPC (val1) | 8545 | JSON-RPC | Service Discovery |
| Besu RPC (val2) | 8546 | JSON-RPC | Service Discovery |
| Besu RPC (val3) | 8547 | JSON-RPC | Service Discovery |
| Besu RPC (val4) | 8548 | JSON-RPC | Service Discovery |
| Besu P2P | 30303-30306 | TCP/UDP | Inter-validator |

### C. URLs de Acesso (Exemplo)

**Após Deployment:**
```bash
./deploy-scripts/08-show-urls.sh
```

**Output Exemplo:**
```
Application URLs:
  Frontend:     http://property-tcc-alb-123456789.us-east-1.elb.amazonaws.com
  BFF API:      http://property-tcc-alb-123456789.us-east-1.elb.amazonaws.com/api
  Orchestrator: http://property-tcc-alb-123456789.us-east-1.elb.amazonaws.com/actuator/health

Internal Services (inside VPC):
  property-tcc-orchestrator.property-tcc.local:8081
  property-tcc-offchain-api.property-tcc.local:3001
  property-tcc-rabbitmq.property-tcc.local:5672
  property-tcc-besu-validator-1.property-tcc.local:8545
```

### D. Comandos AWS Úteis

**ECS:**
```bash
# Listar todos os serviços
aws ecs list-services --cluster property-tcc-cluster

# Ver detalhes de um serviço
aws ecs describe-services --cluster property-tcc-cluster --services property-tcc-frontend

# Listar tasks rodando
aws ecs list-tasks --cluster property-tcc-cluster --service property-tcc-frontend

# Conectar a um container
TASK=$(aws ecs list-tasks --cluster property-tcc-cluster --service property-tcc-orchestrator --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster property-tcc-cluster --task $TASK --container orchestrator --interactive --command /bin/bash
```

**CloudWatch:**
```bash
# Ver logs recentes
aws logs tail /ecs/property-tcc-frontend --since 10m

# Seguir logs em tempo real
aws logs tail /ecs/property-tcc-orchestrator --follow

# Buscar erro específico
aws logs filter-log-events --log-group-name /ecs/property-tcc-orchestrator --filter-pattern "ERROR"
```

**RDS:**
```bash
# Status do banco
aws rds describe-db-instances --db-instance-identifier property-tcc-postgres

# Criar snapshot
aws rds create-db-snapshot --db-instance-identifier property-tcc-postgres --db-snapshot-identifier tcc-backup-$(date +%Y%m%d)
```

**Cost Explorer:**
```bash
# Custo do mês atual
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### E. Contatos e Suporte

**AWS Support:**
- Console: https://console.aws.amazon.com/support/
- Docs: https://docs.aws.amazon.com/

**Projeto TCC:**
- GitHub Org: https://github.com/TCC-Blockchain-Registry
- Issues: https://github.com/TCC-Blockchain-Registry/property-tcc-infrastructure/issues

**Terraform:**
- Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Community: https://discuss.hashicorp.com/c/terraform-providers/tf-aws/

**Hyperledger Besu:**
- Docs: https://besu.hyperledger.org/
- Discord: https://discord.gg/hyperledger

---

## ✅ Conclusão

Este plano de implementação fornece um guia completo e passo-a-passo para deployment do Property Tokenization Platform na AWS. Seguindo as 7 fases descritas, o sistema completo estará operacional em aproximadamente 1h30min a 2 horas.

**Pontos-Chave:**
- ✅ Deployment automatizado via scripts
- ✅ Infraestrutura como código (Terraform)
- ✅ Alta disponibilidade (multi-AZ)
- ✅ Custos otimizados (~$12/dia)
- ✅ Monitoramento integrado (CloudWatch)
- ✅ Segurança em camadas (VPC, SG, Secrets)

**Próximos Passos Após Deployment:**
1. Realizar testes funcionais completos
2. Preparar demo para apresentação TCC
3. Documentar resultados e métricas
4. Executar cleanup (./99-destroy-all.sh)

**Lembre-se**: Destruir toda infraestrutura após apresentação para evitar custos desnecessários!

---

**Documento elaborado por**: TCC Blockchain Registry Team
**Última atualização**: Novembro 2025
**Versão**: 1.0
