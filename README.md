# hack-fiap233-infra

Infraestrutura Terraform para provisionar um cluster EKS na AWS com arquitetura de microsserviços, usando API Gateway como ponto de entrada público...

## Arquitetura

```
Cliente
   │
   ▼
API Gateway (HTTP API — público)
   │
   ▼
VPC Link
   │
   ▼
NLB interno (private subnets)
   ├── porta 8081 → NodePort 30081 → PODs do serviço de Usuários → RDS Postgres (usersdb)
   └── porta 8082 → NodePort 30082 → PODs do serviço de Vídeos  → RDS Postgres (videosdb)
```

## Pré-requisitos

- Terraform >= 1.5.0
- Docker instalado e rodando
- AWS CLI configurado com credenciais da AWS Academy
- `kubectl` instalado

## Estrutura dos Repositórios

```
hackathon/
├── hack-fiap233-infra/        # Este repositório (infraestrutura)
│   ├── bootstrap/             # S3 bucket para remote state
│   ├── modules/               # Módulos Terraform (vpc, eks, nlb, api_gateway, rds)
│   ├── main.tf                # Composição dos módulos + ECR repos
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── hack-fiap233-users/        # Microsserviço de usuários (Go)
│   ├── main.go
│   ├── Dockerfile
│   └── k8s/                   # Manifests Kubernetes
└── hack-fiap233-videos/       # Microsserviço de vídeos (Go)
    ├── main.go
    ├── Dockerfile
    └── k8s/                   # Manifests Kubernetes
```

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
api_gateway_url    = "https://xxxxx.execute-api.us-east-1.amazonaws.com/"
eks_cluster_name   = "hack-fiap233-eks"
ecr_users_url      = "432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users"
ecr_videos_url     = "432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-videos"
rds_users_endpoint = "..."
rds_videos_endpoint = "..."
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
```

> **Nota:** se você estiver em Mac com Apple Silicon (M1/M2/M3), faça build multi-platform:
> ```bash
> docker build --platform linux/amd64 -t 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users:latest ../hack-fiap233-users
> ```

### Passo 6 — Atualizar as imagens nos manifests K8s

Substitua os placeholders nos arquivos de deployment:

```bash
# Pega a URL do ECR do output do Terraform
ECR_USERS=$(terraform output -raw ecr_users_url)
ECR_VIDEOS=$(terraform output -raw ecr_videos_url)

# Atualiza os deployments
sed -i '' "s|ECR_USERS_URL|${ECR_USERS}|" ../hack-fiap233-users/k8s/deployment.yaml
sed -i '' "s|ECR_VIDEOS_URL|${ECR_VIDEOS}|" ../hack-fiap233-videos/k8s/deployment.yaml
```

### Passo 7 — Deploy no EKS

```bash
kubectl apply -f ../hack-fiap233-users/k8s/
kubectl apply -f ../hack-fiap233-videos/k8s/
```

Acompanhe o rollout:

```bash
kubectl rollout status deployment/users-deployment
kubectl rollout status deployment/videos-deployment
```

### Passo 8 — Testar

```bash
# Health checks
curl https://$(terraform output -raw api_gateway_url)users/health
curl https://$(terraform output -raw api_gateway_url)videos/health

# Endpoints
curl https://$(terraform output -raw api_gateway_url)users/hello
curl https://$(terraform output -raw api_gateway_url)videos/hello
```

Respostas esperadas:

```json
{"message":"Hello from Users Service","method":"GET","path":"/users/hello"}
{"message":"Hello from Videos Service","method":"GET","path":"/videos/hello"}
```

---

## Credenciais dos Bancos de Dados

As credenciais são geradas automaticamente e armazenadas no **AWS Secrets Manager**:

```bash
# Users DB
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/users/db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq .

# Videos DB
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/videos/db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq .
```

---

## CI/CD com GitHub Actions

Todos os passos podem ser automatizados. Configure estas secrets no repositório GitHub em **Settings > Secrets and variables > Actions**:

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
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
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
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure kubectl
        run: aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

      - name: Deploy users
        if: github.event.inputs.service == 'users' || github.event.inputs.service == 'all'
        run: kubectl apply -f k8s/users/

      - name: Deploy videos
        if: github.event.inputs.service == 'videos' || github.event.inputs.service == 'all'
        run: kubectl apply -f k8s/videos/

      - name: Verify rollout users
        if: github.event.inputs.service == 'users' || github.event.inputs.service == 'all'
        run: kubectl rollout status deployment/users-deployment --timeout=120s

      - name: Verify rollout videos
        if: github.event.inputs.service == 'videos' || github.event.inputs.service == 'all'
        run: kubectl rollout status deployment/videos-deployment --timeout=120s
```

---

## Comandos Úteis

```bash
# Ver pods
kubectl get pods

# Ver services
kubectl get svc

# Logs de um pod
kubectl logs -f deployment/users-deployment

# Escalar replicas
kubectl scale deployment/users-deployment --replicas=3

# Credenciais DB
aws secretsmanager get-secret-value --secret-id hack-fiap233/users/db-credentials --query SecretString --output text | jq .
```

## Variáveis Configuráveis

| Variável | Padrão | Descrição |
|---|---|---|
| `region` | `us-east-1` | Regiao AWS |
| `project_name` | `hack-fiap233` | Nome do projeto |
| `kubernetes_version` | `1.29` | Versao do Kubernetes |
| `node_instance_types` | `["t3.medium"]` | Tipo de instancia dos nodes |
| `node_desired_size` | `2` | Quantidade desejada de nodes |
| `node_min_size` | `1` | Minimo de nodes |
| `node_max_size` | `3` | Maximo de nodes |
| `nlb_port_users` | `8081` | Porta do NLB para usuarios |
| `nlb_port_videos` | `8082` | Porta do NLB para videos |
| `node_port_users` | `30081` | NodePort para usuarios |
| `node_port_videos` | `30082` | NodePort para videos |
| `rds_instance_class` | `db.t3.micro` | Classe da instancia RDS |
| `rds_engine_version` | `16.6` | Versao do PostgreSQL |

## AWS Academy

Este projeto usa o role `LabRole` existente na conta AWS Academy. Nenhum IAM Role, Policy ou attachment e criado pelo Terraform. O `AWS_SESSION_TOKEN` expira a cada sessao do lab — atualize-o antes de executar os comandos.

## Destruir a Infraestrutura

```bash
# Remover pods primeiro
kubectl delete -f ../hack-fiap233-users/k8s/
kubectl delete -f ../hack-fiap233-videos/k8s/

# Destruir a infraestrutura
terraform destroy

# Destruir o bucket de state (opcional)
cd bootstrap && terraform destroy
```
