## KEDA - Event-Driven Autoscaling para Analytics-Service

### **O que foi implementado**

```
KEDA (Kubernetes Event-Driven Autoscaling) foi instalado para escalar 
analytics-service automaticamente baseado no número de mensagens na fila SQS.
```

### **Componentes implementados:**

 **KEDA Operator** (3 pods em namespace `keda`)
   - `keda-operator`: Monitora triggers e ajusta HPA
   - `keda-metrics-apiserver`: Expõe métricas customizadas
   - `keda-admission`: Valida manifests

## **HPA por CPU vs KEDA por Fila**

| Aspecto | **HPA (CPU/Memória)** | **KEDA (SQS/Eventos)** |
|---------|----------------------|----------------------|
| **Métrica** | CPU/Memória do pod | Eventos externos (fila, mensagens) |
| **Quando escala?** | Quando CPU sobe | Quando há mensagens na fila |
| **Reatividade** | ⏱️ 1-3 minutos | ⚡ 10-30 segundos |
| **Mínimo de pods** | ≥ 1 (sempre rodando) | 0 (pode dormir) |
| **Custo** | Alto (pods sempre online) | Baixo (escala para 0) |
| **Use case** | Serviços síncronos (APIs) | Serviços assincronos (workers) |


## **Como funciona KEDA em tempo real**

```
┌──────────────────────────────────────┐
│ Aplicação envia msgs para SQS        │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ Fila SQS (evaluation-events)         │
│ ApproximateNumberOfMessages: 15      │
└──────────────┬───────────────────────┘
               │
               ▼ (KEDA polling a cada 10s)
┌──────────────────────────────────────┐
│ KEDA Operator                        │
│ - Lê: 15 mensagens                   │
│ - Calcula: 15 / 5 = 3 pods precisos  │
│ - Atualiza HPA com target: 3         │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ HPA (Horizontal Pod Autoscaler)      │
│ - Desired: 3 replicas                │
│ - Current: 1 replica                 │
│ - Action: Scale up → 3 pods          │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ Analytics-Service Deployment         │
│ ┌─ Pod 1 (processando msgs)         │
│ ├─ Pod 2 (processando msgs)         │
│ └─ Pod 3 (processando msgs)         │
└──────────────┬───────────────────────┘
               │
   ┌───────────┴──────────────┐
   ▼                          ▼
Pod 1: Consome              Pod 2: Consome
5 msgs                      5 msgs
│                           │
▼                           ▼
5 registros                 5 registros
em DynamoDB                 em DynamoDB
```

## **Arquivos implementados:**

1. **KEDA Operator** (v2.14.0 - via official manifests)
2. **analytics-service/scaleobject.yml** - Define escalagem por SQS
3. **analytics-service/deployment.yml** - Removed `replicas: 1`
4. **IAM Roles & Policies:**
   - `KEDASQSScalerPolicy` - KEDA read SQS
   - `KEDASQSScalerRole` - IRSA role for KEDA
   - `AnalyticsServicePolicy` - Analytics read/write SQS + DynamoDB
   - `AnalyticsServiceRole` - IRSA role for analytics


---

## 📊 Os 3 Data Stores: RDS, ElastiCache e DynamoDB

### **1. RDS (PostgreSQL)** - Dados Estruturados & Transacionais
```
┌─────────────────────────────────────┐
│         RDS (Single Instance)       │
├─────────────────────────────────────┤
│ • auth_db (autenticação)            │
│ • flag_db (definições de flags)     │
│ • target_db (regras de targeting)   │
└─────────────────────────────────────┘
```
**Propósito:**
- Armazenar dados **estruturados com relacionamentos**
- Garantir **ACID** (consistência transacional)
- Suportar **queries complexas**

**Por que foi escolhido:**
- ✅ Múltiplos bancos com schemas bem definidos
- ✅ Triggers automáticos (updated_at)
- ✅ Integridade referencial entre tabelas
- ✅ Queries JOIN e índices

---

### **2. ElastiCache (Redis)** - Cache em Memória
```
┌─────────────────────────────────────┐
│    ElastiCache Redis (6379)         │
├─────────────────────────────────────┤
│ Key: flag_info:{flag_name}          │
│ TTL: 30 segundos                    │
│ Tamanho: Estrutura complexa (JSON)  │
└─────────────────────────────────────┘
```
**Propósito:**
- **Cache de leitura rápida** para avaliações de flags
- Reduzir latência das requisições
- Evitar consultas repetidas ao RDS

**Por que foi escolhido:**
- ✅ **Muito rápido** (in-memory)
- ✅ TTL automático para expiração
- ✅ Suporta estruturas complexas (JSON serializado)
- ✅ Reduz carga no RDS em padrão de leitura pesada

---

### **3. DynamoDB** - Analytics & Escalabilidade Horizontal
```
┌─────────────────────────────────────┐
│      Table: ToggleMasterAnalytics   │
├─────────────────────────────────────┤
│ Partition Key: flag_id              │
│ Dados: {evaluation_count, ...}      │
│ Mode: On-Demand (PAY_PER_REQUEST)   │
└─────────────────────────────────────┘
```
**Propósito:**
- Armazenar **dados analíticos** de avaliações
- Escalabilidade **automática e elástica**
- Escritas em **alta velocidade** (async)

**Por que foi escolhido:**
- ✅ **NoSQL sem schema fixo** (flexível)
- ✅ **Escala horizontalmente** automaticamente
- ✅ **Pay-per-request** (custo sob demanda)
- ✅ Ideal para **séries temporais/analytics**
- ✅ Integração nativa com SQS (event-driven)

---

### **Fluxo de Dados**
```
┌──────────────┐
│ Flag Request │
└──────────────┘
       ↓
┌──────────────────────────┐
│ 1. Check Redis Cache     │  ← ElastiCache (rápido!)
│    flag_info:{flag_name} │
└──────────────────────────┘
       │ MISS
       ↓
┌──────────────────────────┐
│ 2. Query Flag Service    │  ← RDS (flag_db)
│    Query Target Service  │  ← RDS (target_db)
└──────────────────────────┘
       ↓
┌──────────────────────────┐
│ 3. Cache Result          │  ← ElastiCache (30s TTL)
└──────────────────────────┘
       ↓
┌──────────────────────────┐
│ 4. Send Event (async)    │  ← SQS Queue
│    analytics-service     │
└──────────────────────────┘
       ↓
┌──────────────────────────┐
│ 5. Store Analytics       │  ← DynamoDB
│    ToggleMasterAnalytics │
└──────────────────────────┘
```

### **Resumo Comparativo**

| Aspecto | RDS | Redis | DynamoDB |
|---------|-----|-------|----------|
| **Tipo** | SQL Relacional | NoSQL Cache | NoSQL Document |
| **Latência** | ms (disco) | µs (memória) | ms |
| **Consistência** | Forte (ACID) | Eventual | Eventual |
| **Escalabilidade** | Vertical | Vertical | Horizontal |
| **Custo** | Fixo (instância) | Fixo (instância) | Por requisição |
| **Use Case** | Dados estruturados | Cache/Session | Analytics/Timeseries |

---



## 🎯 3 Maiores Desafios do Projeto

### **1️⃣ Networking & Conectividade Entre Serviços e AWS Services**

**Problema:**
- Pods do EKS em uma subnet (192.168.29.x) não conseguiam alcançar Redis em outra subnet (192.168.9.x)
- RDS com security groups mal configurados bloqueava conexões
- Múltiplas subnets causando timeout nas conexões entre serviços

**Solução:**
- ✅ Configurar security groups permitindo tráfego entre subnets
- ✅ Verificar conectividade com `nslookup` dentro dos pods
- ✅ Usar nomes de DNS internos ao invés de IPs hardcoded

**Impacto:** Serviços não conseguiam comunicar → aplicação não funcionava

---

### **2️⃣ Gerenciamento de Credenciais e Sincronização Entre Ambientes**

**Problema:**
- Credenciais no `.env` não batiam com as do RDS real
- Secrets Kubernetes vs ConfigMap vs arquivo `.env` em conflito
- Cada serviço esperava credenciais em formatos diferentes (DATABASE_URL vs USER/PASSWORD separados)
- Chaves de API não existiam no banco (hash mismatch na validação)

**Solução:**
- ✅ Criar Secrets Kubernetes para credenciais sensíveis
- ✅ Usar ConfigMap apenas para não-sensível (URLs, ports)
- ✅ Jobs Kubernetes para sincronizar credenciais RDS em tempo de deploy
- ✅ Validação de chaves via hash SHA-256

**Impacto:** Falhas 401/403 repetidas até sincronizar credenciais corretas

---

### **3️⃣ Implementação de KEDA: Métricas Externas e IAM Integration**

**Problema:**
- KEDA tentava acessar SQS mas Secret `analytics-secret-sqs` não existia
- Pod CrashLoopBackOff: erro `Secret "analytics-secret-sqs" not found`
- Falta de entendimento sobre IRSA (IAM Roles for Service Accounts)
- Diferença entre `authenticationRef` do KEDA vs `identityOwner: workload`

**Solução:**
- ✅ Remover dependência de Secret: usar `identityOwner: workload` (IAM role da pod)
- ✅ Deletar TriggerAuthentication desnecessária
- ✅ Configurar IRSA: ServiceAccount + IAM Role + Trust Policy
- ✅ Simplificar ScaledObject: remover `authenticationRef`, deixar KEDA usar pod identity

**Impacto:** KEDA agora escala analytics-service automaticamente baseado em mensagens SQS

---

## 📊 Ranking de Criticidade

| Desafio | Severidade | Tempo | Fix |
|---------|-----------|------|-----|
| **Networking** | 🔴 Crítico | 2h+ | Security groups + DNS |
| **Credenciais** | 🔴 Crítico | 2h+ | Secrets Kubernetes + Jobs |
| **KEDA + IAM** | 🟠 Alto | 1.5h+ | Remove Secret, use workload identity |

**Takeaway:** A maioria dos problemas veio de **configuração incorreta** (credenciais, redes, IAM) e **falta de compreensão de Kubernetes/AWS integration**, não de código lógico.

