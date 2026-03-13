# hack-fiap233-infra

Infraestrutura Terraform para provisionar um cluster EKS na AWS com arquitetura de microsserviços orientada a eventos, usando API Gateway como ponto de entrada público e um pipeline assíncrono de processamento de vídeos via SNS/SQS.

## Arquitetura

```
Cliente
   │
   ▼
API Gateway (HTTP API — público)
   │
   ├─── Lambda Authorizer (JWT) ─── Secrets Manager (jwt-secret)
   │
   ▼
VPC Link
   │
   ▼
NLB interno (private subnets)
   ├── porta 8081 → NodePort 30081 → PODs do serviço de Usuários → RDS Postgres (usersdb)
   └── porta 8082 → NodePort 30082 → PODs do serviço de Vídeos  → RDS Postgres (videosdb)
                                              │
                                              │ upload de vídeo
                                              ▼
                                        S3 (videos-storage)
                                              │
                                              │ publica evento
                                              ▼
                                        SNS (video-uploaded)
                                              │
                                              │ fan-out
                                              ▼
                                        SQS (video-processor)
                                              │
                                              │ consome
                                              ▼
                                     PODs do Processor Service
```

## Pré-requisitos

- Terraform >= 1.5.0
- Docker instalado e rodando
- AWS CLI configurado com credenciais da AWS Academy
- `kubectl` instalado
- `jq` instalado (para inspecionar secrets)

## Estrutura dos Repositórios

```
hackathon/
├── hack-fiap233-infra/          # Este repositório (infraestrutura)
│   ├── bootstrap/               # S3 bucket para remote state
│   ├── modules/
│   │   ├── api_gateway/         # HTTP API + VPC Link + rotas
│   │   ├── eks/                 # Cluster + managed node group
│   │   ├── nlb/                 # Network Load Balancer interno
│   │   ├── rds/                 # RDS PostgreSQL (reutilizável)
│   │   ├── vpc/                 # VPC, subnets, security groups
│   │   └── authorizer/          # Lambda Authorizer JWT
│   ├── main.tf                  # Composição dos módulos + ECR + S3 + SNS + SQS
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── hack-fiap233-users/          # Microsserviço de usuários (Go)
│   ├── main.go
│   ├── Dockerfile
│   └── k8s/
├── hack-fiap233-videos/         # Microsserviço de vídeos (Go)
│   ├── main.go
│   ├── Dockerfile
│   └── k8s/
└── hack-fiap233-processor/      # Serviço de processamento de vídeos (Go)
    ├── main.go
    ├── Dockerfile
    └── k8s/
```

---

## Recursos Provisionados

| Recurso | Nome / ID | Descrição |
|---|---|---|
| VPC | `hack-fiap233-vpc` | VPC com subnets públicas e privadas |
| EKS | `hack-fiap233-eks` | Cluster Kubernetes (v1.29) |
| NLB | interno | Load balancer para roteamento ao EKS |
| API Gateway | HTTP API | Ponto de entrada público com Lambda Authorizer |
| Lambda Authorizer | `hack-fiap233-authorizer` | Validação JWT em cada request |
| RDS | `usersdb` / `videosdb` | PostgreSQL 16.6 para cada serviço |
| ECR | `users` / `videos` / `processor` | Repositórios de imagens Docker |
| S3 | `hack-fiap233-videos-storage` | Armazenamento de arquivos de vídeo |
| SNS | `hack-fiap233-video-uploaded` | Tópico de eventos de upload de vídeo |
| SQS | `hack-fiap233-video-processor` | Fila consumida pelo processor service |
| Secrets Manager | `jwt-secret`, `users/db-credentials`, `videos/db-credentials` | Segredos gerenciados |

---

## Passo a Passo Completo

### Passo 1 — Criar o bucket S3 para remote state

Execute apenas uma vez:

```bash
cd hack-fiap233-infra/bootstrap
terraform init
terraform apply -auto-approve
cd ..
```

### Passo 2 — Provisionar toda a infraestrutura

```bash
cd hack-fiap233-infra
terraform init
terraform apply -auto-approve
```

Ao final, anote os outputs:

```
api_gateway_url          = "https://xxxxx.execute-api.us-east-1.amazonaws.com/"
eks_cluster_name         = "hack-fiap233-eks"
ecr_users_url            = "432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users"
ecr_videos_url           = "432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-videos"
ecr_processor_url        = "432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-processor"
rds_users_endpoint       = "..."
rds_videos_endpoint      = "..."
s3_videos_bucket         = "hack-fiap233-videos-storage"
sns_video_uploaded_arn   = "arn:aws:sns:us-east-1:432686365376:hack-fiap233-video-uploaded"
sqs_video_processor_url  = "https://sqs.us-east-1.amazonaws.com/432686365376/hack-fiap233-video-processor"
jwt_secret_name          = "hack-fiap233/jwt-secret"
```

### Passo 3 — Configurar kubectl

```bash
aws eks update-kubeconfig --name hack-fiap233-eks --region us-east-1
```

Verifique se os nodes estão prontos:

```bash
kubectl get nodes
```

### Passo 4 — Login no ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 432686365376.dkr.ecr.us-east-1.amazonaws.com
```

### Passo 5 — Build e push das imagens Docker

```bash
# Users
docker build -t 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users:latest ../hack-fiap233-users
docker push 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users:latest

# Videos
docker build -t 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-videos:latest ../hack-fiap233-videos
docker push 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-videos:latest

# Processor
docker build -t 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-processor:latest ../hack-fiap233-processor
docker push 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-processor:latest
```

> **Mac com Apple Silicon (M1/M2/M3):** faça build multi-platform para compatibilidade com os nodes x86:
> ```bash
> docker build --platform linux/amd64 -t <ECR_URL>:latest <diretório>
> ```

### Passo 6 — Atualizar as imagens nos manifests K8s

```bash
ECR_USERS=$(terraform output -raw ecr_users_url)
ECR_VIDEOS=$(terraform output -raw ecr_videos_url)
ECR_PROCESSOR=$(terraform output -raw ecr_processor_url)

sed -i '' "s|ECR_USERS_URL|${ECR_USERS}|"         ../hack-fiap233-users/k8s/deployment.yaml
sed -i '' "s|ECR_VIDEOS_URL|${ECR_VIDEOS}|"       ../hack-fiap233-videos/k8s/deployment.yaml
sed -i '' "s|ECR_PROCESSOR_URL|${ECR_PROCESSOR}|" ../hack-fiap233-processor/k8s/deployment.yaml
```

### Passo 7 — Deploy no EKS

```bash
kubectl apply -f ../hack-fiap233-users/k8s/
kubectl apply -f ../hack-fiap233-videos/k8s/
kubectl apply -f ../hack-fiap233-processor/k8s/
```

Acompanhe o rollout:

```bash
kubectl rollout status deployment/users-deployment
kubectl rollout status deployment/videos-deployment
kubectl rollout status deployment/processor-deployment
```

### Passo 8 — Testar

```bash
API=$(terraform output -raw api_gateway_url)

# Health checks (sem autenticação)
curl ${API}users/health
curl ${API}videos/health

# Endpoints autenticados (Bearer JWT)
TOKEN="<seu-jwt>"
curl -H "Authorization: Bearer ${TOKEN}" ${API}users/hello
curl -H "Authorization: Bearer ${TOKEN}" ${API}videos/hello
```

---

## Credenciais e Secrets

Todos os segredos são gerados automaticamente e armazenados no **AWS Secrets Manager**:

```bash
# JWT Secret (usado pelo Lambda Authorizer e pelo serviço de Usuários)
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/jwt-secret \
  --region us-east-1 \
  --query SecretString \
  --output text

# Credenciais do banco de Usuários
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/users/db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq .

# Credenciais do banco de Vídeos
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/videos/db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq .
```

---

## CI/CD com GitHub Actions

Configure estas secrets no repositório GitHub em **Settings > Secrets and variables > Actions**:

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key da conta AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Secret Key da conta AWS Academy |
| `AWS_SESSION_TOKEN` | Session Token da AWS Academy (rotaciona a cada sessão) |

### Workflow — Provisionar Infraestrutura

Arquivo `.github/workflows/infra.yml`:

```yaml
name: Terraform Infrastructure

on:
  push:
    branches: [main]
    paths:
      - '*.tf'
      - 'modules/**'
      - 'terraform.tfvars'
  workflow_dispatch:

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_SESSION_TOKEN: ${{ secrets.AWS_SESSION_TOKEN }}
  AWS_REGION: us-east-1

jobs:
  terraform:
    name: Terraform Apply
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0
      - run: terraform init
      - run: terraform validate
      - run: terraform plan -out=tfplan
      - run: terraform apply -auto-approve tfplan
```

### Workflow — Deploy dos Microsserviços

Arquivo `.github/workflows/deploy.yml`:

```yaml
name: Deploy to EKS

on:
  workflow_dispatch:
    inputs:
      service:
        description: 'Serviço para deploy'
        required: true
        type: choice
        options:
          - users
          - videos
          - processor
          - all

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_SESSION_TOKEN: ${{ secrets.AWS_SESSION_TOKEN }}
  AWS_REGION: us-east-1
  EKS_CLUSTER_NAME: hack-fiap233-eks

jobs:
  deploy:
    name: Deploy ${{ github.event.inputs.service }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

      - name: Deploy users
        if: inputs.service == 'users' || inputs.service == 'all'
        run: kubectl apply -f k8s/users/

      - name: Deploy videos
        if: inputs.service == 'videos' || inputs.service == 'all'
        run: kubectl apply -f k8s/videos/

      - name: Deploy processor
        if: inputs.service == 'processor' || inputs.service == 'all'
        run: kubectl apply -f k8s/processor/

      - name: Verify rollout users
        if: inputs.service == 'users' || inputs.service == 'all'
        run: kubectl rollout status deployment/users-deployment --timeout=120s

      - name: Verify rollout videos
        if: inputs.service == 'videos' || inputs.service == 'all'
        run: kubectl rollout status deployment/videos-deployment --timeout=120s

      - name: Verify rollout processor
        if: inputs.service == 'processor' || inputs.service == 'all'
        run: kubectl rollout status deployment/processor-deployment --timeout=120s
```

---

## Comandos Úteis

```bash
# Ver pods e services
kubectl get pods
kubectl get svc

# Logs de um serviço
kubectl logs -f deployment/users-deployment
kubectl logs -f deployment/videos-deployment
kubectl logs -f deployment/processor-deployment

# Escalar replicas
kubectl scale deployment/users-deployment --replicas=3

# Inspecionar fila SQS
aws sqs get-queue-attributes \
  --queue-url $(terraform output -raw sqs_video_processor_url) \
  --attribute-names ApproximateNumberOfMessages \
  --region us-east-1

# Publicar manualmente no SNS (para testar o pipeline)
aws sns publish \
  --topic-arn $(terraform output -raw sns_video_uploaded_arn) \
  --message '{"bucket":"hack-fiap233-videos-storage","key":"test/video.mp4"}' \
  --region us-east-1

# Credenciais DB
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/users/db-credentials \
  --query SecretString --output text | jq .
```

---

## Variáveis Configuráveis

| Variável | Padrão | Descrição |
|---|---|---|
| `region` | `us-east-1` | Região AWS |
| `project_name` | `hack-fiap233` | Nome do projeto (prefixo de todos os recursos) |
| `kubernetes_version` | `1.29` | Versão do Kubernetes |
| `node_instance_types` | `["t3.medium"]` | Tipo de instância dos nodes EKS |
| `node_desired_size` | `2` | Quantidade desejada de nodes |
| `node_min_size` | `1` | Mínimo de nodes |
| `node_max_size` | `3` | Máximo de nodes |
| `nlb_port_users` | `8081` | Porta do NLB para o serviço de usuários |
| `nlb_port_videos` | `8082` | Porta do NLB para o serviço de vídeos |
| `node_port_users` | `30081` | NodePort Kubernetes para usuários |
| `node_port_videos` | `30082` | NodePort Kubernetes para vídeos |
| `rds_instance_class` | `db.t3.micro` | Classe de instância RDS |
| `rds_allocated_storage` | `20` | Armazenamento alocado para o RDS (GB) |
| `rds_db_username` | `dbadmin` | Usuário master do RDS |
| `rds_engine_version` | `16.6` | Versão do PostgreSQL |

---

## AWS Academy

Este projeto usa o role `LabRole` existente na conta AWS Academy. Nenhum IAM Role, Policy ou attachment é criado pelo Terraform. O `AWS_SESSION_TOKEN` expira a cada sessão do lab — atualize-o antes de executar qualquer comando.

---

## Destruir a Infraestrutura

```bash
# 1. Remover todos os pods
kubectl delete -f ../hack-fiap233-users/k8s/
kubectl delete -f ../hack-fiap233-videos/k8s/
kubectl delete -f ../hack-fiap233-processor/k8s/

# 2. Destruir a infraestrutura
terraform destroy

# 3. Destruir o bucket de state (opcional — ação irreversível)
cd bootstrap && terraform destroy
```
