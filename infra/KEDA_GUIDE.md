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
