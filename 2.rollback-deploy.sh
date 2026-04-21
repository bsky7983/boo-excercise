#!/bin/bash

# ============================================
# BOO Exercise - Deploy 파이프라인 롤백 스크립트
# (두번째 파이프라인이 만든 것만 삭제)
# terraform 인프라는 건드리지 않습니다
# ============================================

REGION="us-east-1"
PROJECT="boo-exercise"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}  Deploy 파이프라인 롤백 (k8s + LB + ECR)  ${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""
echo -e "${GREEN}✅ 유지되는 것: VPC, EKS 클러스터, EC2(MongoDB), S3, IAM 역할${NC}"
echo -e "${RED}🗑️  삭제되는 것: k8s 리소스, LB Controller, ALB, ECR 이미지, LB IAM Policy${NC}"
echo ""
read -p "계속하시겠습니까? (yes 입력): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "취소되었습니다."
  exit 0
fi

echo ""

# kubectl 연결 확인
echo -e "${YELLOW}[사전 확인] kubectl EKS 연결 중...${NC}"
aws eks update-kubeconfig --region $REGION --name ${PROJECT}-cluster 2>/dev/null
if [ $? -ne 0 ]; then
  echo -e "${RED}EKS 연결 실패. AWS Credentials 및 클러스터 상태를 확인하세요.${NC}"
  exit 1
fi
echo -e "  ${GREEN}✓ kubectl 연결 완료${NC}"
echo ""

# ----------------------
# 1. Ingress 삭제 (ALB 먼저 제거)
# ----------------------
echo -e "${YELLOW}[1/6] Ingress 삭제 중... (ALB 제거)${NC}"
kubectl delete -f k8s/ingress.yaml 2>/dev/null
if [ $? -eq 0 ]; then
  echo "  ALB 삭제 대기 중... (30초)"
  sleep 30
  echo -e "  ${GREEN}✓ Ingress 삭제 완료${NC}"
else
  echo "  Ingress 없음, 스킵"
fi

# ----------------------
# 2. Service 삭제
# ----------------------
echo -e "${YELLOW}[2/6] Service 삭제 중...${NC}"
kubectl delete -f k8s/service.yaml 2>/dev/null
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓ Service 삭제 완료${NC}"
else
  echo "  Service 없음, 스킵"
fi

# ----------------------
# 3. Deployment 삭제
# ----------------------
echo -e "${YELLOW}[3/6] Deployment 삭제 중...${NC}"
kubectl delete -f k8s/deployment.yaml 2>/dev/null
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓ Deployment 삭제 완료${NC}"
else
  echo "  Deployment 없음, 스킵"
fi

# ----------------------
# 4. RBAC 삭제
# ----------------------
echo -e "${YELLOW}[4/6] RBAC 삭제 중... (ServiceAccount + ClusterRoleBinding)${NC}"
kubectl delete -f k8s/rbac.yaml 2>/dev/null
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓ RBAC 삭제 완료${NC}"
else
  echo "  RBAC 없음, 스킵"
fi

# ----------------------
# 5. Helm LB Controller 삭제
# ----------------------
echo -e "${YELLOW}[5/6] AWS Load Balancer Controller 삭제 중...${NC}"
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓ LB Controller 삭제 완료${NC}"
else
  echo "  LB Controller 없음, 스킵"
fi

# LB Controller IAM Policy 삭제
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam delete-policy \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  2>/dev/null
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓ LB IAM Policy 삭제 완료${NC}"
else
  echo "  LB IAM Policy 없음, 스킵"
fi

# ----------------------
# 6. ECR 이미지 삭제 (레포지토리는 유지, 이미지만 삭제)
# ----------------------
echo -e "${YELLOW}[6/6] ECR 이미지 삭제 중... (레포지토리는 유지)${NC}"
IMAGE_IDS=$(aws ecr list-images \
  --repository-name ${PROJECT}-app \
  --region $REGION \
  --query 'imageIds[*]' \
  --output json 2>/dev/null)

if [ "$IMAGE_IDS" != "[]" ] && [ -n "$IMAGE_IDS" ]; then
  aws ecr batch-delete-image \
    --repository-name ${PROJECT}-app \
    --image-ids "$IMAGE_IDS" \
    --region $REGION 2>/dev/null
  echo -e "  ${GREEN}✓ ECR 이미지 삭제 완료 (레포지토리는 유지됨)${NC}"
else
  echo "  ECR 이미지 없음, 스킵"
fi

# ----------------------
# 최종 확인
# ----------------------
echo ""
echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}         최종 상태 확인                     ${NC}"
echo -e "${YELLOW}============================================${NC}"

echo ""
echo "[ k8s 리소스 ]"
kubectl get pods 2>/dev/null || echo "  없음"
kubectl get svc 2>/dev/null || echo "  없음"
kubectl get ingress 2>/dev/null || echo "  없음"

echo ""
echo "[ EKS 노드 - 유지되어야 함 ]"
kubectl get nodes 2>/dev/null

echo ""
echo -e "${GREEN}✅ 롤백 완료!${NC}"
echo -e "${GREEN}terraform으로 만든 인프라(EKS, EC2, VPC 등)는 그대로 유지됩니다.${NC}"
echo -e "${GREEN}파이프라인 수정 후 GitHub Actions에서 'Run workflow'로 재배포하세요.${NC}"
