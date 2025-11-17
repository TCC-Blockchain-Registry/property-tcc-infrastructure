# Property TCC - Infraestrutura AWS

Documentação completa para deploy da infraestrutura blockchain do Property TCC.

## 🚀 Início Rápido

**Escolha seu plano de deploy:**

### Plano A: Full AWS (Blockchain na AWS)
Deploy completo com Besu rodando em ECS Fargate na AWS.

📖 [Ver documentação completa do Plano A](PLANO_A.md)

**Prós:**
- ✅ Infraestrutura 100% na nuvem
- ✅ Alta disponibilidade (multi-AZ)
- ✅ Escalável
- ✅ Gerenciamento simplificado

**Contras:**
- ⚠️ Custo mais alto (~$150-200/mês)
- ⚠️ Setup mais complexo (keys no EFS, etc)
- ⚠️ Mais difícil de debugar

---

### Plano B: Híbrido (Blockchain local + Cloudflare Tunnel)
Besu roda localmente, exposto via Cloudflare Tunnel. Demais serviços na AWS.

📖 [Ver documentação completa do Plano B](PLANO_B.md)

**Prós:**
- ✅ Custo reduzido (~$80-100/mês)
- ✅ Debug muito mais fácil
- ✅ Setup Besu simplificado (usa Docker Compose local)
- ✅ Cloudflare Tunnel gratuito e seguro

**Contras:**
- ⚠️ Depende do computador local estar ligado
- ⚠️ Latência pode ser maior (Cloudflare Tunnel)
- ⚠️ Não recomendado para produção 24/7

---

## 📋 Pré-requisitos

Ambos os planos requerem:

- [x] **Besu CLI**: `brew install hyperledger/besu/besu`
- [x] **jq**: `brew install jq`
- [x] **Python 3** com biblioteca `rlp`: `pip3 install rlp`
- [x] **AWS CLI**: [Instruções de instalação](https://aws.amazon.com/cli/)
- [x] **Terraform**: `brew install terraform`
- [x] **Docker**: [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [x] **AWS Account** configurado: `aws configure`

Para verificar pré-requisitos:
```bash
./scripts/lib/validators.sh check_prerequisites
```

---

## 🗂️ Estrutura de Scripts

Os scripts são numerados na ordem de execução:

1. **`1-generate-network.sh`** - Gera keys Besu, atualiza configs
2. **`2-create-secrets.sh`** - Cria private keys e AWS Secrets
3. **`3-terraform-deploy.sh`** - Deploy da infraestrutura AWS
4. **`4-upload-keys.sh`** - Upload de keys para EFS (Plano A only)
5. **`5-verify-network.sh`** - Valida que consensus está funcionando

---

## 📚 Documentação Adicional

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Análise técnica detalhada e decisões de design
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Problemas comuns e soluções

---

## 🆘 Suporte

Se encontrar problemas:

1. Consulte [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Verifique logs CloudWatch: `aws logs tail /ecs/property-tcc/...`
3. Execute o script de verificação: `./scripts/5-verify-network.sh`

---

## ⚠️ Segurança

**IMPORTANTE**: Nunca commite para git:
- `scripts/generated/` - Contém private keys
- `terraform-aws/terraform.tfvars` - Contém configurações sensíveis
- `terraform-aws/.terraform/` - Cache do Terraform

Estes já estão no `.gitignore`.

---

**Última atualização**: 2025-11-17
