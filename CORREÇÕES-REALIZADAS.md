# Correções Realizadas na Infraestrutura AWS

Data: 2025-11-17

## ✅ FASE 1 - Limpeza e Organização (Completo)

### Terraform Files
- ✅ Removidos comentários redundantes em `variables.tf`
- ✅ Simplificadas descrições e removidos comentários óbvios em `vpc.tf`
- ✅ Limpeza em `security-groups.tf`
- ✅ Limpeza em `ecr.tf`

### Besu AWS Config
- ✅ `Dockerfile` - Removidos comentários desnecessários, condensado
- ✅ `entrypoint.sh` - Simplificadas mensagens de log, código mais conciso

## ✅ FASE 2 - Correções Críticas (Completo)

### 1. ECR Repository References (11 correções)
**Arquivo**: `terraform-aws/ecs-services.tf`

**Problema**: ECR criado com `for_each` mas referenciado com nomes individuais

**Corrigido**:
- ✅ Frontend: `aws_ecr_repository.frontend` → `aws_ecr_repository.repos["frontend"]`
- ✅ BFF Gateway: `aws_ecr_repository.bff_gateway` → `aws_ecr_repository.repos["bff-gateway"]`
- ✅ Orchestrator: `aws_ecr_repository.orchestrator` → `aws_ecr_repository.repos["orchestrator"]`
- ✅ Offchain API: `aws_ecr_repository.offchain_api` → `aws_ecr_repository.repos["offchain-api"]`
- ✅ Queue Worker: `aws_ecr_repository.queue_worker` → `aws_ecr_repository.repos["queue-worker"]`
- ✅ RabbitMQ: `aws_ecr_repository.rabbitmq` → `aws_ecr_repository.repos["rabbitmq"]`
- ✅ Besu Validator 1-4 (4x): `aws_ecr_repository.besu_validator` → `aws_ecr_repository.repos["besu-validator"]`

### 2. EFS Access Point References (4 correções)
**Arquivo**: `terraform-aws/ecs-services.tf`

**Problema**: EFS criado com `count` mas referenciado com nomes individuais

**Corrigido**:
- ✅ Validator 1: `besu_validator_1.id` → `besu_validator[0].id`
- ✅ Validator 2: `besu_validator_2.id` → `besu_validator[1].id`
- ✅ Validator 3: `besu_validator_3.id` → `besu_validator[2].id`
- ✅ Validator 4: `besu_validator_4.id` → `besu_validator[3].id`

### 3. RabbitMQ Task Definition Variables
**Arquivo**: `terraform-aws/ecs-services.tf` (linhas 582-583)

**Problema**: Usando `var.worker_cpu/memory` ao invés de `var.rabbitmq_cpu/memory`

**Corrigido**:
- ✅ `cpu = var.worker_cpu` → `cpu = var.rabbitmq_cpu`
- ✅ `memory = var.worker_memory` → `memory = var.rabbitmq_memory`

### 4. Contract Address Environment Variables
**Arquivos**: `variables.tf`, `ecs-services.tf`, `terraform.tfvars.example`

**Problema**: Offchain API sem variáveis de contract addresses

**Adicionado em `variables.tf`**:
```hcl
variable "property_title_address" {
  description = "PropertyTitleTREX contract address (set after deployment)"
  type        = string
  default     = ""
}

variable "approvals_module_address" {
  description = "ApprovalsModule contract address (set after deployment)"
  type        = string
  default     = ""
}

variable "registry_md_address" {
  description = "RegistryMDCompliance contract address (set after deployment)"
  type        = string
  default     = ""
}
```

**Adicionado em `ecs-services.tf` (Offchain API env vars)**:
- ✅ `PROPERTY_TITLE_ADDRESS`
- ✅ `APPROVALS_MODULE_ADDRESS`
- ✅ `REGISTRY_MD_ADDRESS`

**Adicionado em `terraform.tfvars.example`**:
```hcl
# Smart Contract Addresses (set after deploying contracts to Besu)
# property_title_address = "0x..."
# approvals_module_address = "0x..."
# registry_md_address = "0x..."
```

### 5. RabbitMQ Dockerfile
**Arquivo**: `message-queue/Dockerfile` (CRIADO)

**Problema**: Arquivo não existia, build script falharia

**Solução**:
```dockerfile
FROM rabbitmq:3.12-management-alpine

COPY rabbitmq.conf /etc/rabbitmq/rabbitmq.conf
COPY definitions.json /etc/rabbitmq/definitions.json

EXPOSE 5672 15672
```

### 6. Frontend VITE_RPC_URL
**Arquivo**: `terraform-aws/ecs-services.tf` (Frontend env vars)

**Problema**: Frontend sem URL do RPC do Besu

**Adicionado**:
```hcl
{
  name  = "VITE_RPC_URL"
  value = "http://${var.project_name}-besu-validator-1.${var.project_name}.local:8545"
}
```

## ✅ Validação Estática

Todos os arquivos foram verificados estaticamente:
- ✅ Todas as 11 referências ECR corrigidas
- ✅ Todas as 4 referências EFS corrigidas
- ✅ Variáveis RabbitMQ corretas
- ✅ Contract addresses adicionados
- ✅ VITE_RPC_URL presente
- ✅ Variáveis declaradas em variables.tf

---

## ⚠️ PENDÊNCIAS MANUAIS CRÍTICAS

### 1. Besu Node Keys e Static Nodes (BLOQUEADOR)
**Status**: ❌ NÃO IMPLEMENTADO - REQUER AÇÃO MANUAL

**Problema**:
- `static-nodes.json.template` contém placeholders `NODE1_PUBKEY`, `NODE2_PUBKEY`, etc.
- Validators não conseguirão se conectar sem enodes válidos
- Genesis.json contém addresses fixos que não vão bater com keys auto-geradas

**Solução Necessária**:
1. Gerar 4 pares de chaves Besu localmente
2. Extrair public keys de cada validador
3. Atualizar `besu-aws/static-nodes.json.template` com enodes reais
4. Regenerar `besu-aws/genesis.json` com addresses derivados das keys
5. Upload das keys para EFS em `/validator-{1-4}/key/key`

**Exemplo de comando**:
```bash
cd besu-property-ledger
besu --data-path=validator-1 public-key export --to=validator-1-pubkey
# Repetir para validators 2, 3, 4
# Extrair addresses e regenerar genesis.json extraData
```

### 2. Contract Addresses (REQUER DEPLOY PRIMEIRO)
**Status**: ⏳ VARIÁVEIS CRIADAS - VALORES PENDENTES

**O que foi feito**:
- Variáveis criadas em `variables.tf`
- Environment variables adicionadas ao Offchain API
- Documentação adicionada em `terraform.tfvars.example`

**O que falta**:
1. Deploy dos smart contracts no Besu
2. Obter os 3 contract addresses do deploy
3. Atualizar `terraform.tfvars` com os valores reais:
   ```hcl
   property_title_address = "0xABCD..."
   approvals_module_address = "0xEFGH..."
   registry_md_address = "0xIJKL..."
   ```
4. Rodar `terraform apply` novamente para atualizar env vars

### 3. Besu Private Keys nos Secrets Manager
**Status**: ⚠️ PLACEHOLDERS - ATUALIZAR ANTES DE PRODUÇÃO

**Arquivo**: `terraform-aws/secrets.tf`

Atualmente com valores placeholder:
```
0x0000000000000000000000000000000000000000000000000000000000000000
```

**Atualizar via AWS CLI**:
```bash
aws secretsmanager update-secret \
  --secret-id property-tcc/besu/admin-private-key \
  --secret-string "0xSUA_CHAVE_REAL"
```

---

## 📋 Workflow de Deploy Recomendado

### Pré-Deploy (Local)
1. [ ] Gerar 4 pares de chaves Besu
2. [ ] Atualizar `static-nodes.json.template`
3. [ ] Regenerar `genesis.json` com addresses corretos

### Deploy Fase 1 - Infraestrutura
4. [ ] `cd terraform-aws && terraform init`
5. [ ] Criar `terraform.tfvars` (copiar do `.example`)
6. [ ] `terraform plan` (revisar mudanças)
7. [ ] `terraform apply` (provisiona AWS resources)

### Deploy Fase 2 - Images
8. [ ] Build e push Docker images para ECR
9. [ ] Upload Besu keys para EFS access points

### Deploy Fase 3 - Besu
10. [ ] Deploy Besu validators (4 tasks)
11. [ ] Aguardar consensus (verificar logs)

### Deploy Fase 4 - Smart Contracts
12. [ ] Deploy smart contracts via script 05
13. [ ] Anotar os 3 contract addresses

### Deploy Fase 5 - Atualização
14. [ ] Atualizar `terraform.tfvars` com contract addresses
15. [ ] `terraform apply` (atualiza Offchain API env vars)

### Deploy Fase 6 - Application Services
16. [ ] Deploy remaining services (Frontend, BFF, Orchestrator, Offchain, Worker, RabbitMQ)
17. [ ] Health check all services
18. [ ] Teste end-to-end

---

## 🎯 Status Final

| Categoria | Status |
|-----------|--------|
| **Limpeza de Código** | ✅ COMPLETO |
| **Correções Terraform** | ✅ COMPLETO (7/7) |
| **Dockerfile RabbitMQ** | ✅ COMPLETO |
| **Contract Address Vars** | ⏳ ESTRUTURA PRONTA |
| **Besu Keys & Genesis** | ❌ MANUAL REQUIRED |
| **Deploy Pronto?** | ⚠️ APÓS BESU KEYS |

---

## 🚀 Próximos Passos Imediatos

1. **CRÍTICO**: Gerar Besu keys e atualizar `static-nodes.json.template` + `genesis.json`
2. Deploy da infraestrutura com Terraform
3. Deploy dos smart contracts
4. Atualizar contract addresses e re-aplicar Terraform
5. Testar deployment completo

---

**Resumo**: Infraestrutura **tecnicamente pronta** para deploy, mas **Besu keys são bloqueadoras** e devem ser geradas antes do primeiro deploy.
