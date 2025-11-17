# Property TCC - Infraestrutura AWS

Infraestrutura como código (IaC) para deploy do sistema de tokenização de imóveis Property TCC na AWS.

## 📖 Documentação Completa

**👉 [Ver documentação completa em docs/README.md](docs/README.md)**

## 🚀 Quick Start

### Opção 1: Full AWS (Blockchain na AWS)

```bash
cd /Users/leonardodev/tcc/infrastructure

# 1. Gerar configuração Besu
./scripts/1-generate-network.sh

# 2. Criar secrets AWS
./scripts/2-create-secrets.sh

# 3. Deploy infraestrutura
./scripts/3-terraform-deploy.sh

# 4. Upload keys para EFS
./scripts/4-upload-keys.sh

# 5. Verificar deployment
./scripts/5-verify-network.sh
```

📖 **[Documentação completa do Plano A](docs/PLANO_A.md)**

---

### Opção 2: Híbrido (Besu local + Cloudflare Tunnel)

```bash
# 1. Rodar Besu localmente
cd /Users/leonardodev/tcc/besu-property-ledger
./script/setup/setup-all.sh

# 2. Configurar Cloudflare Tunnel
cloudflared tunnel create besu-tcc
cloudflared tunnel run besu-tcc

# 3. Deploy AWS (sem Besu)
cd /Users/leonardodev/tcc/infrastructure
./scripts/2-create-secrets.sh
./scripts/3-terraform-deploy.sh
```

📖 **[Documentação completa do Plano B](docs/PLANO_B.md)**

---

## 📁 Estrutura do Projeto

```
infrastructure/
├── README.md                    # Este arquivo
├── docs/                        # 📚 Documentação completa
│   ├── README.md                # Hub principal
│   ├── PLANO_A.md               # Full AWS
│   ├── PLANO_B.md               # Híbrido (Besu local)
│   ├── ARCHITECTURE.md          # Análise técnica
│   └── TROUBLESHOOTING.md       # Problemas e soluções
│
├── scripts/                     # 🔧 Scripts de automação
│   ├── 1-generate-network.sh   # Gera keys Besu
│   ├── 2-create-secrets.sh     # Cria AWS Secrets
│   ├── 3-terraform-deploy.sh   # Deploy Terraform
│   ├── 4-upload-keys.sh        # Upload para EFS
│   ├── 5-verify-network.sh     # Valida consensus
│   └── lib/                    # Helpers
│       ├── colors.sh           # Output colorido
│       └── validators.sh       # Validações
│
├── terraform-aws/               # 🏗️ Infraestrutura Terraform
│   ├── vpc.tf                  # VPC, subnets, NAT
│   ├── ecs-cluster.tf          # ECS cluster
│   ├── ecs-services.tf         # Services e tasks
│   ├── efs.tf                  # Persistent storage
│   ├── rds.tf                  # PostgreSQL
│   ├── alb.tf                  # Load balancer
│   ├── security-groups.tf      # Firewall rules
│   ├── secrets.tf              # Secrets Manager
│   └── ...                     # Outros recursos
│
└── besu-aws/                    # 🔗 Configuração Besu
    ├── config/                 # Configs por validator
    ├── genesis.json            # Genesis block
    ├── static-nodes.json       # Peer discovery
    ├── Dockerfile              # Container image
    └── entrypoint.sh           # Startup script
```

---

## 🛠️ Pré-requisitos

- **Besu CLI**: `brew install hyperledger/besu/besu`
- **jq**: `brew install jq`
- **Python 3** + rlp: `pip3 install rlp`
- **AWS CLI**: [Instalação](https://aws.amazon.com/cli/)
- **Terraform**: `brew install terraform`
- **Docker**: [Docker Desktop](https://www.docker.com/products/docker-desktop)

Verificar:
```bash
./scripts/lib/validators.sh check_prerequisites
```

---

## 🆘 Ajuda

- **Problemas?** → [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Dúvidas sobre arquitetura?** → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Logs AWS**: `aws logs tail /ecs/property-tcc/... --follow`

---

## ⚠️ Segurança

**NUNCA commite**:
- `scripts/generated/` - Contém private keys 🔐
- `terraform-aws/terraform.tfvars` - Contém configurações sensíveis
- `terraform-aws/.terraform/` - Cache Terraform

Já estão no `.gitignore` ✅

---

## 📊 Arquitetura

```
┌─────────────────────────────────────────────────┐
│               AWS Cloud (us-east-1)              │
│                                                  │
│  ┌──────────┐    ┌─────────┐   ┌──────────────┐ │
│  │ Frontend │───▶│   BFF   │──▶│ Orchestrator │ │
│  │  (ECS)   │    │  (ECS)  │   │    (ECS)     │ │
│  └──────────┘    └─────────┘   └──────┬───────┘ │
│       ▲                  │              │        │
│       │                  │              ▼        │
│   ┌───┴────┐    ┌────────▼─┐    ┌──────────┐   │
│   │  ALB   │    │ Offchain │    │   RDS    │   │
│   └────────┘    │   API    │    │(Postgres)│   │
│                 │  (ECS)   │    └──────────┘   │
│                 └────┬─────┘                    │
│                      │                          │
│              ┌───────▼────────┐                 │
│              │  Besu Network  │                 │
│              │  4 Validators  │                 │
│              │     (ECS)      │                 │
│              └────────────────┘                 │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

**Documentação completa**: [docs/README.md](docs/README.md)

**Última atualização**: 2025-11-17
