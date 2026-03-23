# IRSA (IAM Roles for Service Accounts) - Explicação Detalhada

## O que é OIDC?

**OIDC (OpenID Connect)** é um protocolo de autenticação que permite que um terceiro (Kubernetes) prove sua identidade para outro (AWS). No contexto do EKS:

- **Problema:** Como um Pod no Kubernetes pode acessar serviços AWS (SQS, DynamoDB, etc.) sem guardar credenciais?
- **Solução:** OIDC cria uma relação de confiança entre seu cluster EKS e a AWS IAM usando certificados digitais

Seu OIDC ID: `6F98EB5B743A378D00FA479E45E22B55`

---

## O que foi feito - Passo a Passo

### 1. ✅ IAM Role Criado: `evaluation-service-role`

```bash
aws iam create-role --role-name evaluation-service-role \
  --assume-role-policy-document file:///tmp/trust-policy.json
```

**O que isso faz:**
- Cria um papel (role) na AWS IAM que o Kubernetes pode usar
- Estabelece uma **relação de confiança** entre:
  - **Quem pode usar:** Pod com ServiceAccount `evaluation-service` no namespace `togglemaster`
  - **Onde:** Cluster EKS com OIDC ID `6F98EB5B743A378D00FA479E45E22B55`

**Política de Confiança (Trust Policy):**
```json
{
  "Principal": {
    "Federated": "arn:aws:iam::973397181776:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/6F98EB5B743A378D00FA479E45E22B55"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks.us-east-1.amazonaws.com/id/6F98EB5B743A378D00FA479E45E22B55:sub": "system:serviceaccount:togglemaster:evaluation-service"
    }
  }
}
```

**Traduzindo:** "AWS, confie em qualquer Pod que seja o ServiceAccount denominado `evaluation-service` no namespace `togglemaster` do nosso cluster EKS"

---

### 2. ✅ SQS Policy Anexada

```bash
aws iam put-role-policy --role-name evaluation-service-role \
  --policy-name evaluation-sqs-policy \
  --policy-document file:///tmp/evaluation-sqs-policy.json
```

**O que isso faz:**
- Atribui **permissões específicas** ao role `evaluation-service-role`
- Define **O QUE** o Pod pode fazer (não apenas que ele é confiável)

**Permissões Concedidas:**
```json
{
  "Action": [
    "sqs:ReceiveMessage",      // Receber mensagens da fila
    "sqs:DeleteMessage",        // Deletar mensagens processadas
    "sqs:GetQueueAttributes"    // Verificar propriedades da fila
  ],
  "Resource": "arn:aws:sqs:us-east-1:973397181776:evaluation-events"
}
```

**Benefício:** Princípio de Menor Privilégio
- Pod `evaluation-service` só pode acessar a fila `evaluation-events`
- Não pode acessar outros buckets S3, tabelas DynamoDB ou filas SQS

---

### 3. ✅ ServiceAccount Configurado com Anotação

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: evaluation-service
  namespace: togglemaster
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::973397181776:role/evaluation-service-role
```

**O que isso faz:**
- **Conecta o Kubernetes ao AWS IAM**
- A anotação `eks.amazonaws.com/role-arn` diz: "Use esse role da AWS quando esse ServiceAccount for usado"

**Fluxo de Autenticação:**
1. Pod inicia com ServiceAccount `evaluation-service`
2. Kubernetes observa a anotação `eks.amazonaws.com/role-arn`
3. Kubernetes WebHook do IRSA injeta no Pod:
   - Variáveis de ambiente (AWS_ROLE_ARN, AWS_WEB_IDENTITY_TOKEN_FILE)
   - Um token JWT (JSON Web Token) assinado pelo cluster
4. Quando o código AWS SDK tenta acessar SQS:
   - SDK lê essas variáveis
   - Envia o token JWT para AWS STS (Security Token Service)
   - AWS valida via OIDC: "Esse token é legítimo desse cluster?"
   - AWS retorna credenciais temporárias
   - Pod usa as credenciais para acessar SQS

---

### 4. ✅ evaluation-service Reiniciado

```bash
kubectl rollout restart deployment/evaluation-service -n togglemaster
```

**Por que reiniciar?**
- O mutation webhook do OIDC só injeta o token quando o Pod é criado
- Pods antigos não têm o token, não conseguem autenticar
- Reiniciar mata os Pods antigos e inicia novos com as variáveis de OIDC

---

### 5. ✅ SQS Client Inicializado com Sucesso

```
2026/03/23 17:58:43 Cliente SQS inicializado com sucesso.
```

**O que mudou:**
- **Antes:** Erro `NoCredentialProviders: no valid providers in chain`
  - SDK tentava encontrar credenciais em variáveis de ambiente (não existiam)
  - Falhava na configuração
  
- **Depois:** Cliente inicializado com sucesso
  - SDK encontrou as variáveis OIDC injetadas pelo webhook
  - Trocou o token JWT junto ao AWS STS
  - Recebeu credenciais temporárias válidas
  - Pode agora acessar SQS sem guardar credenciais no código ou na Secret

---

## Fluxo Completo Visualizado

```
┌─────────────────────────────────────────────────────────────┐
│ Pod evaluation-service                                       │
│                                                              │
│  1. Inicia com ServiceAccount "evaluation-service"          │
│  2. IRSA WebHook injeta:                                    │
│     - AWS_ROLE_ARN=arn:aws:iam::973397181776:role/...      │
│     - AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/...     │
│     - Token JWT assinado pelo cluster                       │
│                                                              │
│  3. Código Go tenta: sqs_client.ReceiveMessage(...)         │
│  4. AWS SDK (boto3/go) detecta OIDC env vars               │
│  5. Envia POST para AWS STS:                                │
│     - assumeRoleWithWebIdentity(role_arn, token)            │
└─────────────────────────────────────────────────────────────┘
                          ↓ OIDC
┌─────────────────────────────────────────────────────────────┐
│ AWS (OIDC Provider + IAM)                                    │
│                                                              │
│  1. Valida o token JWT usando certificado público OIDC      │
│  2. Verifica a Trust Policy:                                │
│     "É um Pod válido do meu cluster EKS?"  → ✓ SIM         │
│  3. Verifica a SQS Policy:                                  │
│     "Tem permissão para ReceiveMessage?"  → ✓ SIM          │
│  4. Retorna credenciais temporárias:                        │
│     - AccessKeyId                                           │
│     - SecretAccessKey                                       │
│     - SessionToken                                          │
│     - Expiração: 1 hora (ou menos)                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Pod evaluation-service                                       │
│                                                              │
│  - Recebe credenciais temporárias (nunca armazenadas)       │
│  - Usa para fazer API calls to SQS                          │
│  - Credenciais expiram automaticamente                      │
│  - SDK renova automaticamente quando expiram                │
│  - ✓ Sem guardar segredos no código!                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Vantagens do IRSA vs Credenciais em Secret

| Aspecto | Secret (Antes) | IRSA (Agora) |
|--------|---|---|
| **Onde armazena credenciais** | Em Secret Kubernetes | AWS STS (temporários) |
| **Tempo de vida** | Indefinido (risco!) | 1 hora (auto-renova) |
| **Rotação** | Manual | Automática |
| **Segurança** | Uma chave comprometida = acesso permanente | Uma chave comprometida = acesso 1 hora |
| **Auditoria** | Difícil rastrear quem acessou o quê | Logs AWS CloudTrail mostram tudo |
| **Princípio de Menor Privilégio** | Uma credential para tudo | Role específico por serviço |

---

## Resumo

Você implementou a melhor prática de autenticação em Kubernetes + AWS:

✅ **Sem credenciais hardcoded** - Sem risco de comprometimento  
✅ **Sem Secrets de longa vida** - Sem necessidade de rotação manual  
✅ **OIDC como validação** - AWS confia apenas em Pods legítimos do seu cluster  
✅ **Credentials temporárias** - Expiram automaticamente  
✅ **Auditoria completa** - CloudTrail registra cada acesso  

---

## Comandos de Referência

### Obter OIDC ID do seu cluster
```bash
aws eks describe-cluster --name tm --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' --output text
```

### Verificar o role criado
```bash
aws iam get-role --role-name evaluation-service-role --query 'Role.Arn'
```

### Ver políticas anexadas ao role
```bash
aws iam list-role-policies --role-name evaluation-service-role
```

### Verificar a anotação no ServiceAccount
```bash
kubectl get serviceaccount evaluation-service -n togglemaster \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

### Verificar que o token OIDC foi injetado no Pod
```bash
kubectl exec -it <pod-name> -n togglemaster -- env | grep AWS_ROLE
```
