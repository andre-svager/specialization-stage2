# KEDA - Event-Driven Autoscaling para Analytics-Service

## **O que foi implementado**

```
KEDA (Kubernetes Event-Driven Autoscaling) foi instalado para escalar 
analytics-service automaticamente baseado no número de mensagens na fila SQS.
```

### **Componentes implementados:**

1. **KEDA Operator** (3 pods em namespace `keda`)
   - `keda-operator`: Monitora triggers e ajusta HPA
   - `keda-metrics-apiserver`: Expõe métricas customizadas
   - `keda-admission`: Valida manifests

2. **IAM Setup (IRSA para KEDA)**
   - Policy: `KEDASQSScalerPolicy` (permissões SQS)
   - Role: `KEDASQSScalerRole` (trust OIDC)
   - ServiceAccount: `keda-operator` com IRSA

3. **ScaleObject** (`analytics-service-sqs-scaler`)
   ```yaml
   spec:
     scaleTargetRef:
       name: analytics-service
     minReplicaCount: 0      # Escala de 0 pods
     maxReplicaCount: 5      # Até 5 pods
     triggers:
       - type: aws-sqs-queue
         metadata:
           queueURL: https://sqs.us-east-1.amazonaws.com/.../evaluation-events
           queueLength: "5"   # 1 pod por 5 mensagens
   ```

4. **Analytics-Service atualizado**
   - ❌ Removido: `replicas: 1` (KEDA gerencia)
   - ✅ Adicionado: `serviceAccountName: analytics-service` (IRSA)
   - Pode escalar de **0 → 5 replicas** automaticamente

---

## **HPA por CPU vs KEDA por Fila**

| Aspecto | **HPA (CPU/Memória)** | **KEDA (SQS/Eventos)** |
|---------|----------------------|----------------------|
| **Métrica** | CPU/Memória do pod | Eventos externos (fila, mensagens) |
| **Quando escala?** | Quando CPU sobe | Quando há mensagens na fila |
| **Reatividade** | ⏱️ 1-3 minutos | ⚡ 10-30 segundos |
| **Mínimo de pods** | ≥ 1 (sempre rodando) | 0 (pode dormir) |
| **Custo** | Alto (pods sempre online) | Baixo (escala para 0) |
| **Use case** | Serviços síncronos (APIs) | Serviços assincronos (workers) |

### **Exemplo prático:**

**HPA por CPU:**
```
Pod rodando continuamente (8h)
├─ 0h-4h: CPU 10% (desperdiçando)
├─ 4h-7h: CPU 80% → Escala para 3 pods
└─ 7h-8h: CPU 5% (desperdiçando)

Custo: 8 horas × CPU reservado
```

**KEDA por SQS:**
```
Pod dorme quando fila vazia (0 replicas)
├─ 0h-4h: 0 pods (dormindo - sem custo!)
├─ 4h: 10 msgs chega → 2 pods acordam
├─ 4h30m: Fila vazia → Cooldown 300s
└─ 5h: 0 pods dormem novamente

Custo: ~30 min rodando, 7h30m dormindo
```

---

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
               ▼ (KEDA polinga a cada 10s)
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

---

## **Vantagens do KEDA vs HPA tradicional**

### **1. Zero-based Scaling (Economia)**
```
HPA por CPU:
- Pod mínimo: 1 (sempre custa)
- Custo 24/7: 24 × CPU_cost

KEDA por SQS:
- Pod mínimo: 0 (descendo custo a zero)
- Custo só quando há trabalho
- Economia: 70-90% em períodos inativos
```

### **2. Reatividade a Eventos**
```
HPA: Espera CPU subir → pode levar 2-3 min
KEDA: Deteta mensagem → 10-30 seg para escalar
```

### **3. Escalagem Inteligente**
```
HPA: Pode escalar por qualquer razão (CPU sobe)
KEDA: Escala APENAS quando há trabalho real na fila
     → Menos desperdício de recursos
```

### **4. Multi-source Triggers**
```yaml
KEDA suporta:
- SQS (filas AWS)
- Kafka (streaming)
- RabbitMQ
- PostgreSQL (chegadas de dados)
- HTTP (webhooks)
- 50+ outras fontes
```

---

## **Monitorar escalamento em tempo real**

```bash
# Ver pods escalando
watch "kubectl get pods -n togglemaster -l app=analytics-service"

# Ver HPA status
kubectl get hpa -n togglemaster

# Ver ScaleObject
kubectl get scaledobjects -n togglemaster

# Ver fila SQS
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/973397181776/evaluation-events \
  --attribute-names ApproximateNumberOfMessages \
  --region us-east-1
```

---

## **Testar escalamento**

```bash
# 1. Enviar mensagens para fila
for i in {1..20}; do
  aws sqs send-message \
    --queue-url https://sqs.us-east-1.amazonaws.com/973397181776/evaluation-events \
    --message-body "{\"id\": $i, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
    --region us-east-1
done

# 2. Monitorar pods escalando (em outro terminal)
watch "kubectl get pods -n togglemaster -l app=analytics-service && echo '---' && kubectl get hpa -n togglemaster"

# 3. Ver fila sendo consumida
watch "aws sqs get-queue-attributes --queue-url https://sqs.us-east-1.amazonaws.com/973397181776/evaluation-events --attribute-names ApproximateNumberOfMessages --region us-east-1 | grep ApproximateNumberOfMessages"

# Observar:
# ✓ Mensagens chegam → ApproximateNumberOfMessages: 20
# ✓ KEDA detecta → 5 segundos
# ✓ Pods escalem → De 0 para 4 pods (20 msgs / 5 por pod)
# ✓ Pods processam mensagens
# ✓ Fila vazia → Espera cooldown 300s
# ✓ Pods voltam para 0
```

---

## **Configurar KEDA (parâmetros ajustáveis)**

No arquivo `analytics-service/scaleobject.yml`:

```yaml
spec:
  minReplicaCount: 0          # Mínimo de pods (0 = pode dormir)
  maxReplicaCount: 5          # Máximo de pods
  triggers:
  - type: aws-sqs-queue
    metadata:
      queueLength: "5"        # Mensagens por pod (↓ = mais pods)
  pollingInterval: 10         # Frequência de checagem (segundos)
  cooldownPeriod: 300         # Tempo p/ scale-down (segundos)
```

### **Exemplos de ajuste:**

| Situação | `queueLength` | `maxReplicaCount` | Efeito |
|----------|---------------|-------------------|--------|
| Muitas msgs rápidas | `"2"` | 20 | Escala agressivamente |
| Processamento lento | `"10"` | 3 | Menos pods, mais econômico |
| Picos imprevistos | `"3"` | 10 | Reativo e protegido |
| Steady-state | `"5"` | 5 | Balanceado |

---

## **Resumo: KEDA vs HPA**

### **HPA (Horizontal Pod Autoscaler)**
- ✅ Bom para: APIs, serviços síncronos (auth, flag, target)
- ❌ Desvantagem: Sempre mantém mínimo de 1 pod (custo 24/7)
- Métrica: CPU/Memória

### **KEDA (Event-Driven Autoscaling)**
- ✅ Bom para: Workers, processadores assíncronos (analytics com SQS)
- ✅ Vantagem: Escala para 0 quando sem trabalho (economia massiva)
- Métrica: Eventos externos (filas, streams, etc)

### **Seu setup ideal:**
```
┌─────────────────────────────────────┐
│ auth-service (síncrono/API)         │ ← HPA por CPU
│ flag-service (síncrono/API)         │ ← HPA por CPU
│ target-service (síncrono/API)       │ ← HPA por CPU
│ evaluation-service (background job) │ ← KEDA por SQS
│ analytics-service (worker)          │ ← KEDA por SQS ⭐
└─────────────────────────────────────┘
```

---

## **Arquivos implementados:**

1. **KEDA Operator** (v2.14.0 - via official manifests)
2. **analytics-service/scaleobject.yml** - Define escalagem por SQS
3. **analytics-service/triggerauthentication.yml** - IRSA credentials
4. **analytics-service/deployment.yml** - Removed `replicas: 1`
5. **IAM Roles & Policies:**
   - `KEDASQSScalerPolicy` - KEDA read SQS
   - `KEDASQSScalerRole` - IRSA role for KEDA
   - `AnalyticsServicePolicy` - Analytics read/write SQS + DynamoDB
   - `AnalyticsServiceRole` - IRSA role for analytics

---

## **Status atual:**

✅ **KEDA Instalado** - 3 pods rodando em namespace `keda`  
✅ **IRSA Configurado** - Sem credenciais hardcoded  
✅ **ScaleObject Ativo** - Monitora fila evaluation-events  
✅ **Analytics escalando** - De 0 → 5 replicas baseado em SQS  
✅ **Pronto para produção** - Event-driven e cost-optimized  

Sistema agora está **fully event-driven e auto-escalável**! 🚀
