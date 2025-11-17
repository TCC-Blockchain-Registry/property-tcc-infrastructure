# Troubleshooting - Property TCC

Problemas comuns e soluções para infraestrutura AWS.

## 🔍 Diagnóstico Rápido

```bash
# Verificar pré-requisitos
./scripts/lib/validators.sh check_prerequisites

# Verificar configuração Besu
./scripts/lib/validators.sh validate_besu_config

# Verificar secrets AWS
./scripts/lib/validators.sh validate_aws_secrets

# Verificar EFS
./scripts/lib/validators.sh validate_efs

# Verificação completa pós-deploy
./scripts/5-verify-network.sh
```

---

## 🚨 Besu Validators

### ❌ Validators stuck at block 0

**Sintomas**:
```bash
curl http://validator-1:8545 -d '{"method":"eth_blockNumber"}'
# {"result":"0x0"}  ← Sempre 0
```

**Causas possíveis**:

1. **Keys não uploadadas para EFS**
   ```bash
   # Verificar via ECS Exec
   aws ecs execute-command \
     --cluster property-tcc \
     --task <task-id> \
     --container besu-validator-1 \
     --command "ls -la /opt/besu/data/key"

   # Se vazio, re-upload keys
   ./scripts/4-upload-keys.sh
   ```

2. **Genesis extraData não corresponde às keys**
   ```bash
   # Re-gerar network com keys corretas
   ./scripts/1-generate-network.sh

   # Rebuild Docker image
   cd besu-aws
   docker build -t besu-validator .
   docker push <ECR_URL>/property-tcc-besu-validator:latest

   # Force new deployment
   aws ecs update-service --cluster property-tcc \
     --service property-tcc-besu-validator-1 \
     --force-new-deployment
   ```

3. **Portas inconsistentes (config.toml vs ECS)**
   ```bash
   # Verificar config.toml
   grep "rpc-http-port" besu-aws/config/validator-*/config.toml
   # Devem ser TODOS 8545

   # Verificar ECS portMappings
   aws ecs describe-task-definition \
     --task-definition property-tcc-besu-validator-1 \
     | jq '.taskDefinition.containerDefinitions[0].portMappings'
   # Devem ser 8545 e 30303
   ```

### ❌ 0 peers connected

**Sintomas**:
```bash
curl http://validator-1:8545 -d '{"method":"net_peerCount"}'
# {"result":"0x0"}  ← Sem peers
```

**Causas possíveis**:

1. **Security Group bloqueando P2P (porta 30303)**
   ```bash
   # Verificar Security Group
   aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=property-tcc-besu-sg" \
     --query 'SecurityGroups[*].IpPermissions'

   # Deve ter:
   # - TCP 30303 self-referencing
   # - UDP 30303 self-referencing
   ```

2. **Cloud Map DNS não resolvendo**
   ```bash
   # Testar DNS de dentro de uma task
   aws ecs execute-command \
     --cluster property-tcc \
     --task <task-id> \
     --command "nslookup property-tcc-besu-validator-1.property-tcc.local"

   # Deve retornar IP privado
   ```

3. **static-nodes.json com enodes incorretos**
   ```bash
   # Verificar dentro do container
   aws ecs execute-command \
     --cluster property-tcc \
     --task <task-id> \
     --command "cat /opt/besu/static-nodes.json"

   # Deve ter 4 enodes com public keys reais (não placeholders)
   ```

### ❌ Health check failing

**Sintomas**:
```
Tasks repeatedly starting and stopping
ECS logs: "Task health check failed"
```

**Soluções**:

1. **Aumentar startPeriod**
   ```hcl
   # ecs-services.tf
   healthCheck = {
     startPeriod = 180  # Era 120, aumentar para 180
     retries     = 5    # Era 3, aumentar para 5
   }
   ```

2. **Verificar porta do health check**
   ```hcl
   # Deve ser localhost:8545 (não 8546, 8547, 8548)
   command = ["CMD-SHELL", "curl -f http://localhost:8545 ..."]
   ```

3. **Besu não iniciando (verificar logs)**
   ```bash
   aws logs tail /ecs/property-tcc/besu-validator-1 --follow

   # Procurar por:
   # - "Starting Besu Validator"
   # - "Ethereum main loop"
   # - Erros de inicialização
   ```

---

## 🗄️ RDS PostgreSQL

### ❌ Connection refused

**Sintomas**:
```
Orchestrator logs: "Connection to database failed"
```

**Soluções**:

1. **Verificar Security Group**
   ```bash
   aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=property-tcc-rds-sg" \
     --query 'SecurityGroups[*].IpPermissions'

   # Deve permitir TCP 5432 de ECS tasks SG
   ```

2. **Verificar endpoint**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier property-tcc-db \
     --query 'DBInstances[0].Endpoint'

   # Comparar com SPRING_DATASOURCE_URL no ECS
   ```

3. **Testar conexão de dentro de task**
   ```bash
   aws ecs execute-command \
     --cluster property-tcc \
     --task <orchestrator-task-id> \
     --command "pg_isready -h <rds-endpoint> -p 5432"
   ```

---

## 📦 ECS Tasks

### ❌ Task fails to start (PROVISIONING → STOPPED)

**Causas possíveis**:

1. **Imagem Docker não existe no ECR**
   ```bash
   # Listar imagens
   aws ecr list-images --repository-name property-tcc-besu-validator

   # Se vazio, build e push
   docker build -t besu-validator .
   docker tag besu-validator:latest <ECR_URL>/property-tcc-besu-validator:latest
   docker push <ECR_URL>/property-tcc-besu-validator:latest
   ```

2. **IAM role sem permissões**
   ```bash
   # Verificar task execution role
   aws iam get-role --role-name property-tcc-ecs-task-execution-role

   # Deve ter policies:
   # - AmazonECSTaskExecutionRolePolicy
   # - ECR pull permissions
   # - Secrets Manager read permissions
   ```

3. **Subnet sem capacidade**
   ```bash
   # Verificar IPs disponíveis nas subnets
   aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=property-tcc-private-*" \
     --query 'Subnets[*].[SubnetId,AvailableIpAddressCount]'

   # Se <10, considerar expandir CIDR
   ```

### ❌ Task running but unreachable

1. **Verificar Service Discovery**
   ```bash
   # Listar instâncias registradas
   aws servicediscovery list-instances \
     --service-id <service-id>

   # Deve ter IPs das tasks
   ```

2. **Verificar ALB Target Health**
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <target-group-arn>

   # Status deve ser "healthy"
   ```

---

## 🔐 Secrets Manager

### ❌ Secret not found

**Sintomas**:
```
Terraform: Error: reading Secrets Manager Secret
```

**Solução**:
```bash
# Criar secrets manualmente ANTES de terraform apply
./scripts/2-create-secrets.sh

# Verificar que foram criados
aws secretsmanager list-secrets \
  --query 'SecretList[?contains(Name, `property-tcc/besu`)]'
```

---

## 💾 EFS

### ❌ Mount timeout

**Sintomas**:
```
Task logs: "mount.nfs4: Connection timed out"
```

**Soluções**:

1. **Verificar Security Group permite NFS (2049)**
   ```bash
   aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=property-tcc-efs-sg" \
     --query 'SecurityGroups[*].IpPermissions'
   ```

2. **Verificar mount targets nas subnets corretas**
   ```bash
   aws efs describe-mount-targets \
     --file-system-id <efs-id>

   # Deve ter mount target em cada subnet privada
   ```

3. **Verificar EFS lifecycle state**
   ```bash
   aws efs describe-file-systems \
     --file-system-id <efs-id> \
     --query 'FileSystems[0].LifeCycleState'

   # Deve ser "available"
   ```

---

## 🌐 ALB

### ❌ 503 Service Unavailable

**Causas possíveis**:

1. **Nenhum target healthy**
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <target-group-arn>

   # Se todos "unhealthy", verificar health checks
   ```

2. **Path routing incorreto**
   ```bash
   # Verificar listener rules
   aws elbv2 describe-rules \
     --listener-arn <listener-arn>

   # Exemplo: /rpc/validator-1 → besu-validator-1
   ```

### ❌ 504 Gateway Timeout

**Soluções**:

1. **Aumentar timeout do ALB**
   ```hcl
   # alb.tf
   resource "aws_lb_target_group" "..." {
     deregistration_delay = 30  # Era 300
   }
   ```

2. **Verificar se serviço está respondendo**
   ```bash
   # Testar direto na task
   aws ecs execute-command \
     --cluster property-tcc \
     --task <task-id> \
     --command "curl http://localhost:8545"
   ```

---

## 📜 Logs CloudWatch

### Como acessar logs

```bash
# Tail (follow) logs
aws logs tail /ecs/property-tcc/besu-validator-1 --follow

# Últimas 100 linhas
aws logs tail /ecs/property-tcc/besu-validator-1 --since 10m

# Filtrar por erro
aws logs filter-log-events \
  --log-group-name /ecs/property-tcc/besu-validator-1 \
  --filter-pattern "ERROR"
```

### Logs importantes

| Serviço | Log Group |
|---------|-----------|
| Besu Validator 1 | `/ecs/property-tcc/besu-validator-1` |
| Besu Validator 2-4 | `/ecs/property-tcc/besu-validator-{2-4}` |
| Orchestrator | `/ecs/property-tcc/orchestrator` |
| Offchain API | `/ecs/property-tcc/offchain-api` |
| BFF Gateway | `/ecs/property-tcc/bff-gateway` |
| Queue Worker | `/ecs/property-tcc/queue-worker` |
| Frontend | `/ecs/property-tcc/frontend` |

---

## 🧪 Testes de Validação

### Testar RPC Besu

```bash
# Via ALB (externo)
curl http://<ALB_DNS>/rpc/validator-1 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Deve retornar block number crescente
```

### Testar peer count

```bash
curl http://<ALB_DNS>/rpc/validator-1 \
  -X POST \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

# Deve retornar 0x3 (3 peers)
```

### Testar Orchestrator

```bash
curl http://<ALB_DNS>/api/health
# {"status":"UP"}
```

---

## 🔄 Recovery Procedures

### Reset completo

```bash
# 1. Destroy infraestrutura
cd terraform-aws
terraform destroy

# 2. Limpar gerados
rm -rf ../scripts/generated/*

# 3. Re-gerar tudo
cd ..
./scripts/1-generate-network.sh
./scripts/2-create-secrets.sh
./scripts/3-terraform-deploy.sh
./scripts/4-upload-keys.sh
```

### Re-deploy apenas Besu

```bash
# 1. Re-gerar keys
./scripts/1-generate-network.sh

# 2. Rebuild image
cd besu-aws
docker build -t besu-validator .
docker push <ECR_URL>/property-tcc-besu-validator:latest

# 3. Re-upload keys
./scripts/4-upload-keys.sh

# 4. Force new deployment
for i in {1..4}; do
  aws ecs update-service --cluster property-tcc \
    --service property-tcc-besu-validator-$i \
    --force-new-deployment
done
```

---

## 📞 Suporte

Se o problema persiste:

1. Verificar todos os logs CloudWatch
2. Executar `./scripts/5-verify-network.sh` e anexar relatório
3. Consultar [ARCHITECTURE.md](ARCHITECTURE.md) para entender design
4. Revisar [PLANO_A.md](PLANO_A.md) ou [PLANO_B.md](PLANO_B.md) para workflow correto

---

**Última atualização**: 2025-11-17
