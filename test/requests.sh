#!/bin/bash

curl -s http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/evaluation/health 
curl -s http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/analytics/health 
echo ""

curl -s http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/flag/health 
curl -s http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/target/health
curl -s http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/auth/health



# Resumo: Fase 5 - NGINX Ingress Controller com IRSA ✅
# Após todos os 5 serviços estarem rodando, foi implementada a exposição externa via Load Balancer:

# 1. Problema Identificado
# Serviços só acessíveis internamente (ClusterIP)
# Precisava de Load Balancer para acesso externo
# Usuário solicitou NGINX Ingress com IRSA (sem Helm)
# 2. IAM Setup (IRSA)

# ✓ Criado IAM Policy: EKSNginxIngressPolicy  - Permissões ELBv2 (CreateLoadBalancer, CreateTargetGroup, CreateListener, etc)  - Permissões EC2 (DescribeSecurityGroups, DescribeSubnets)  ✓ Criado IAM Role: EKSNginxIngressRole  - Trust policy com OIDC do EKS (sem credenciais hardcoded)  ✓ Policy anexada à Role
# 3. NGINX Ingress Controller (sem Helm)

# ✓ Instalado via kubectl apply (manifesto oficial AWS)  - Namespace: ingress-nginx  - Pod: ingress-nginx-controller → Running  ✓ Patchted ServiceAccount com IRSA annotation  - eks.amazonaws.com/role-arn: arn:aws:iam::973397181776:role/EKSNginxIngressRole
# 4. AWS ALB Criado Automaticamente ✓

# DNS: aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.comType: Network Load BalancerPorts: 80, 443Status: Active
# 5. Ingress Manifest com Roteamento
# ingress.yaml criado com:

# Rota	Serviço	Porta
# /auth/*	auth-service	8001
# /flag/*	flag-service	8002
# /target/*	target-service	8003
# /evaluation/*	evaluation-service	8004
# /analytics/*	analytics-service	8005
# Regex Rewriting: /auth/health → reescreve para /health antes de rotear

# 6. Testes Executados ✅

# ✓ http://ALB/auth/health       → {"status":"ok"} 200✓ http://ALB/flag/health       → {"status":"ok"} 200✓ http://ALB/target/health     → {"status":"ok"} 200✓ http://ALB/evaluation/health → {"status":"ok"} 200✓ http://ALB/analytics/health  → {"status":"ok"} 200
# Resultado Final
# ✅ ToggleMaster completamente exposto externamente com:

# Load Balancer automático (ALB)
# IRSA para segurança (sem credenciais)
# Path-based routing para 5 serviços
# Todos respondendo via DNS público




# 🎉 Perfeito! NGINX Ingress Controller está 100% funcional!

# Resumo do Setup NGINX + IRSA:
# ✅ Instalado sem Helm:

# NGINX Ingress Controller via kubectl apply
# Namespace: ingress-nginx
# Pod: ingress-nginx-controller → Running
# ✅ IRSA Configurado:

# IAM Policy: EKSNginxIngressPolicy (permissões ELBv2, EC2, Load Balancing)
# IAM Role: EKSNginxIngressRole (trust policy OIDC)
# ServiceAccount: ingress-nginx com anotação eks.amazonaws.com/role-arn
# Pod agora pode gerenciar ALB sem credenciais hardcoded
# ✅ ALB Criado Automaticamente:


# DNS: aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.comType: Network Load Balancer (AWS ALB)Ports: 80, 443 (configuráveis)
# ✅ Ingress Manifest com Roteamento:

# /auth/* → auth-service:8001
# /flag/* → flag-service:8002
# /target/* → target-service:8003
# /evaluation/* → evaluation-service:8004
# /analytics/* → analytics-service:8005
# ✅ Path Rewriting Funcionando:

# Regex: /auth(/|$)(.*) reescreve para /$2
# Exemplo: /auth/health → Reescreve para /health → Serviço recebe /health
# ✅ Todos os serviços respondendo: