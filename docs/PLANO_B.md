# Plano B: Besu Local + Cloudflare Tunnel

Deploy híbrido onde Besu roda localmente exposto via Cloudflare Tunnel, e demais serviços rodam na AWS.

## 🎯 Arquitetura

```
AWS Cloud (us-east-1)
├── ALB (público)
├── Frontend (ECS)
├── BFF Gateway (ECS)
├── Orchestrator (ECS) → PostgreSQL (RDS)
├── Offchain API (ECS)
├── Queue Worker (ECS)
└── RabbitMQ (ECS)
         │
         │ HTTPS
         ▼
https://besu-tcc.seudominio.com (Cloudflare Tunnel)
         │
         ▼
Seu PC (localhost:8545)
└── Besu Network (4 validators via Docker Compose)
```

## ✅ Vantagens

- **Custo reduzido**: ~$80-100/mês (vs ~$200/mês do Plano A)
- **Debug facilitado**: Logs Besu diretos no terminal
- **Setup simplificado**: Usa Docker Compose local que já funciona
- **Flexibilidade**: Pode resetar blockchain facilmente

## ⚠️ Desvantagens

- **Disponibilidade**: Depende do PC local estar ligado
- **Produção**: Não recomendado para 24/7
- **Latência**: Pode ser maior (AWS → Cloudflare → PC)

---

## 📋 Workflow Completo

### 1. Setup Besu Local

```bash
cd /Users/leonardodev/tcc/besu-property-ledger
./script/setup/setup-all.sh

# Verificar funcionando
curl http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### 2. Instalar Cloudflare Tunnel

```bash
# macOS
brew install cloudflare/cloudflare/cloudflared

# Verificar instalação
cloudflared --version
```

### 3. Configurar Cloudflare Tunnel

```bash
# 1. Login (abre navegador)
cloudflared tunnel login

# 2. Criar tunnel
cloudflared tunnel create besu-tcc

# Output mostra:
# Tunnel credentials written to ~/.cloudflared/<TUNNEL_ID>.json
# Anote o TUNNEL_ID

# 3. Criar arquivo de config
cat > ~/.cloudflared/config.yml <<EOF
tunnel: <TUNNEL_ID>  # Substituir pelo ID do passo 2
credentials-file: ~/.cloudflared/<TUNNEL_ID>.json

ingress:
  # Expor Besu RPC
  - hostname: besu-tcc.seudominio.com
    service: http://localhost:8545

  # Catch-all (obrigatório)
  - service: http_status:404
EOF

# 4. Configurar DNS no Cloudflare
cloudflared tunnel route dns besu-tcc besu-tcc.seudominio.com

# 5. Rodar tunnel
cloudflared tunnel run besu-tcc
```

### 4. Testar Cloudflare Tunnel

```bash
# Em outro terminal
curl https://besu-tcc.seudominio.com \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Deve retornar: {"jsonrpc":"2.0","id":1,"result":"0x..."}
```

### 5. (Opcional) Rodar Tunnel como Serviço

```bash
# Instalar como serviço macOS
sudo cloudflared service install

# Iniciar
sudo launchctl start com.cloudflare.cloudflared

# Logs
tail -f /usr/local/var/log/cloudflared.log
```

### 6. Modificar Terraform

Remover componentes Besu do Terraform:

```bash
cd /Users/leonardodev/tcc/infrastructure/terraform-aws

# Comentar ou deletar:
# - ecs-services.tf: Besu validator tasks e services
# - efs.tf: Tudo (não precisa EFS)
# - security-groups.tf: Regras porta 30303
```

### 7. Atualizar Variáveis de Ambiente

**offchain-consumer-srv/.env**:
```bash
RPC_URL=https://besu-tcc.seudominio.com
CHAIN_ID=1337
# ... resto igual
```

**bff-gateway/.env**:
```bash
BESU_RPC_URL=https://besu-tcc.seudominio.com
# ... resto igual
```

### 8. Deploy AWS (sem Besu)

```bash
cd /Users/leonardodev/tcc/infrastructure

# Gerar secrets
./scripts/2-create-secrets.sh

# Deploy infra (sem Besu)
./scripts/3-terraform-deploy.sh
```

### 9. Build e Push Imagens

```bash
# Frontend, BFF, Orchestrator, Offchain, Worker
# (mesmos comandos do Plano A)
```

### 10. Deploy Contratos

```bash
cd /Users/leonardodev/tcc/besu-property-ledger

# Apontar para tunnel (não localhost)
forge script script/Deploy.s.sol \
  --rpc-url https://besu-tcc.seudominio.com \
  --broadcast
```

### 11. Atualizar terraform.tfvars

```bash
# Editar terraform.tfvars com contract addresses
property_title_address = "0xABC..."
approvals_module_address = "0xDEF..."
# ...

# Re-deploy Offchain API
./scripts/3-terraform-deploy.sh
```

---

## 🔒 Segurança do Tunnel

### Opção 1: Cloudflare Access (Recomendado)

```bash
# No Cloudflare Dashboard → Zero Trust → Access
# Criar Application:
# - Name: Besu RPC
# - Domain: besu-tcc.seudominio.com
# - Policy: Allow apenas IPs da AWS
```

Obter IPs NAT Gateway da AWS:
```bash
aws ec2 describe-nat-gateways \
  --query 'NatGateways[*].NatGatewayAddresses[*].PublicIp' \
  --output text
```

### Opção 2: Cloudflare Firewall Rules

```bash
# No Cloudflare Dashboard → Firewall Rules
# Criar regra:
# - If: Hostname = besu-tcc.seudominio.com AND IP not in {AWS NAT IPs}
# - Then: Block
```

---

## 🐛 Troubleshooting

### Tunnel não conecta

```bash
# Verificar logs
cloudflared tunnel info besu-tcc

# Testar conexão
cloudflared tunnel run besu-tcc --loglevel debug
```

### Besu não responde via tunnel

```bash
# 1. Verificar Besu local
curl http://localhost:8545 -X POST -d '{"method":"eth_blockNumber"}'

# 2. Verificar tunnel está rodando
ps aux | grep cloudflared

# 3. Verificar DNS
dig besu-tcc.seudominio.com

# 4. Testar conexão direta
curl https://besu-tcc.seudominio.com \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Latência alta

```bash
# Medir latência
time curl https://besu-tcc.seudominio.com \
  -X POST \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Se >1s, considerar:
# - Mover serviços AWS para região mais próxima
# - Usar Cloudflare Argo Tunnel (pago, mas mais rápido)
```

---

## 📊 Comparação de Custos

### Plano A (Full AWS)
| Componente | Custo/mês |
|------------|-----------|
| 4x ECS Fargate Besu | $80 |
| EFS | $15 |
| RDS | $25 |
| Outros ECS | $40 |
| ALB | $20 |
| **Total** | **~$180** |

### Plano B (Híbrido)
| Componente | Custo/mês |
|------------|-----------|
| Besu local | $0 |
| Cloudflare Tunnel | $0 |
| RDS | $25 |
| ECS (sem Besu) | $40 |
| ALB | $20 |
| **Total** | **~$85** |

**Economia: ~$95/mês (53%)**

---

## 🎓 Quando Usar Plano B

✅ **Recomendado para:**
- TCC / Projetos acadêmicos
- Desenvolvimento / Testes
- PoC / Demos
- Budget limitado

❌ **Não recomendado para:**
- Produção 24/7
- Alta disponibilidade crítica
- Múltiplos desenvolvedores
- Ambientes regulados

---

## 📝 Checklist de Deploy

- [ ] Besu local rodando (`./setup-all.sh`)
- [ ] Cloudflare Tunnel configurado
- [ ] DNS apontando para tunnel
- [ ] Tunnel testado (curl funcionando)
- [ ] Terraform modificado (Besu removido)
- [ ] Secrets criados (`2-create-secrets.sh`)
- [ ] Infraestrutura AWS deployada (`3-terraform-deploy.sh`)
- [ ] Contratos deployados
- [ ] terraform.tfvars atualizado com contract addresses
- [ ] Offchain API re-deployado
- [ ] Sistema testado end-to-end

---

**Última atualização**: 2025-11-17
