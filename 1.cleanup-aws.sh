#!/bin/bash

# ============================================
# BOO Exercise - AWS 리소스 전체 삭제 스크립트
# ============================================

REGION="ap-northeast-2"
PROJECT="boo-exercise"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}  BOO Exercise AWS 리소스 삭제 시작  ${NC}"
echo -e "${YELLOW}======================================${NC}"
echo ""
echo -e "${RED}⚠️  이 스크립트는 모든 boo-exercise 리소스를 삭제합니다.${NC}"
read -p "계속하시겠습니까? (yes 입력): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "취소되었습니다."
  exit 0
fi

echo ""

# ----------------------
# 1. EKS 노드그룹 삭제
# ----------------------
echo -e "${YELLOW}[1/14] EKS 노드그룹 삭제 중...${NC}"
aws eks delete-nodegroup \
  --cluster-name ${PROJECT}-cluster \
  --nodegroup-name ${PROJECT}-nodes \
  --region $REGION 2>/dev/null

if [ $? -eq 0 ]; then
  echo "  노드그룹 삭제 완료 대기 중... (최대 10분)"
  aws eks wait nodegroup-deleted \
    --cluster-name ${PROJECT}-cluster \
    --nodegroup-name ${PROJECT}-nodes \
    --region $REGION
  echo -e "  ${GREEN}✓ 노드그룹 삭제 완료${NC}"
else
  echo "  노드그룹 없음 또는 이미 삭제됨, 스킵"
fi

# ----------------------
# 2. EKS 클러스터 삭제
# ----------------------
echo -e "${YELLOW}[2/14] EKS 클러스터 삭제 중...${NC}"
aws eks delete-cluster \
  --name ${PROJECT}-cluster \
  --region $REGION 2>/dev/null

if [ $? -eq 0 ]; then
  echo "  클러스터 삭제 완료 대기 중... (최대 10분)"
  aws eks wait cluster-deleted \
    --name ${PROJECT}-cluster \
    --region $REGION
  echo -e "  ${GREEN}✓ EKS 클러스터 삭제 완료${NC}"
else
  echo "  클러스터 없음 또는 이미 삭제됨, 스킵"
fi

# ----------------------
# 3. EC2 인스턴스 삭제
# ----------------------
echo -e "${YELLOW}[3/14] EC2 인스턴스 삭제 중...${NC}"
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PROJECT}-mongodb" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region $REGION 2>/dev/null)

if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION
  echo "  EC2 종료 대기 중..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION
  echo -e "  ${GREEN}✓ EC2 인스턴스 삭제 완료${NC}"
else
  echo "  EC2 없음 또는 이미 삭제됨, 스킵"
fi

# ----------------------
# 4. ECR 삭제
# ----------------------
echo -e "${YELLOW}[4/14] ECR 레포지토리 삭제 중...${NC}"
aws ecr delete-repository \
  --repository-name ${PROJECT}-app \
  --force \
  --region $REGION 2>/dev/null

if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓ ECR 삭제 완료${NC}"
else
  echo "  ECR 없음 또는 이미 삭제됨, 스킵"
fi

# ----------------------
# 5. S3 버킷 삭제
# ----------------------
echo -e "${YELLOW}[5/14] S3 버킷 삭제 중...${NC}"
for BUCKET in $(aws s3 ls | grep ${PROJECT} | awk '{print $3}'); do
  echo "  버킷 비우는 중: $BUCKET"
  aws s3 rm s3://$BUCKET --recursive 2>/dev/null
  aws s3 rb s3://$BUCKET 2>/dev/null
  echo -e "  ${GREEN}✓ $BUCKET 삭제 완료${NC}"
done

# ----------------------
# 6. NAT Gateway 삭제 (💸 돈 나가는 리소스!)
# ----------------------
echo -e "${YELLOW}[6/14] NAT Gateway 삭제 중... (💸 과금 리소스)${NC}"
for NAT_ID in $(aws ec2 describe-nat-gateways \
  --filter "Name=tag:Name,Values=${PROJECT}-nat" "Name=state,Values=available" \
  --query 'NatGateways[].NatGatewayId' \
  --output text \
  --region $REGION 2>/dev/null); do
  aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID --region $REGION
  echo "  NAT Gateway 삭제 대기 중..."
  aws ec2 wait nat-gateway-deleted --nat-gateway-id $NAT_ID --region $REGION 2>/dev/null || sleep 30
  echo -e "  ${GREEN}✓ NAT Gateway 삭제 완료${NC}"
done

# ----------------------
# 7. Elastic IP 삭제
# ----------------------
echo -e "${YELLOW}[7/14] Elastic IP 삭제 중...${NC}"
for EIP_ID in $(aws ec2 describe-addresses \
  --region $REGION \
  --query 'Addresses[?AssociationId==null].AllocationId' \
  --output text 2>/dev/null); do
  aws ec2 release-address --allocation-id $EIP_ID --region $REGION 2>/dev/null
  echo -e "  ${GREEN}✓ EIP $EIP_ID 삭제 완료${NC}"
done

# ----------------------
# 8. 서브넷 삭제
# ----------------------
echo -e "${YELLOW}[8/14] 서브넷 삭제 중...${NC}"
for SUBNET_ID in $(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=${PROJECT}*" \
  --query 'Subnets[].SubnetId' \
  --output text \
  --region $REGION 2>/dev/null); do
  aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION 2>/dev/null
  echo -e "  ${GREEN}✓ 서브넷 $SUBNET_ID 삭제 완료${NC}"
done

# ----------------------
# 9. 라우팅 테이블 삭제
# ----------------------
echo -e "${YELLOW}[9/14] 라우팅 테이블 삭제 중...${NC}"
for RT_ID in $(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=${PROJECT}*" \
  --query 'RouteTables[].RouteTableId' \
  --output text \
  --region $REGION 2>/dev/null); do
  aws ec2 delete-route-table --route-table-id $RT_ID --region $REGION 2>/dev/null
  echo -e "  ${GREEN}✓ 라우팅 테이블 $RT_ID 삭제 완료${NC}"
done

# ----------------------
# 10. 인터넷 게이트웨이 삭제
# ----------------------
echo -e "${YELLOW}[10/14] 인터넷 게이트웨이 삭제 중...${NC}"
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${PROJECT}-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region $REGION 2>/dev/null)

for IGW_ID in $(aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=${PROJECT}-igw" \
  --query 'InternetGateways[].InternetGatewayId' \
  --output text \
  --region $REGION 2>/dev/null); do
  aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION 2>/dev/null
  aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION 2>/dev/null
  echo -e "  ${GREEN}✓ IGW 삭제 완료${NC}"
done

# ----------------------
# 11. 보안 그룹 삭제
# ----------------------
echo -e "${YELLOW}[11/14] 보안 그룹 삭제 중...${NC}"
for SG_ID in $(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=${PROJECT}*" \
  --query 'SecurityGroups[].GroupId' \
  --output text \
  --region $REGION 2>/dev/null); do
  aws ec2 delete-security-group --group-id $SG_ID --region $REGION 2>/dev/null
  echo -e "  ${GREEN}✓ 보안 그룹 $SG_ID 삭제 완료${NC}"
done

# ----------------------
# 12. IAM 역할 삭제
# ----------------------
echo -e "${YELLOW}[12/14] IAM 역할 삭제 중...${NC}"
for ROLE in ${PROJECT}-mongodb-role ${PROJECT}-eks-cluster-role ${PROJECT}-eks-nodes-role; do
  # 정책 분리
  for POLICY_ARN in $(aws iam list-attached-role-policies \
    --role-name $ROLE \
    --query 'AttachedPolicies[].PolicyArn' \
    --output text 2>/dev/null); do
    aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY_ARN 2>/dev/null
  done
  # 인스턴스 프로파일 삭제
  PROFILE_NAME="${PROJECT}-mongodb-profile"
  aws iam remove-role-from-instance-profile \
    --instance-profile-name $PROFILE_NAME \
    --role-name $ROLE 2>/dev/null
  aws iam delete-instance-profile \
    --instance-profile-name $PROFILE_NAME 2>/dev/null
  # 역할 삭제
  aws iam delete-role --role-name $ROLE 2>/dev/null
  echo -e "  ${GREEN}✓ IAM 역할 $ROLE 삭제 완료${NC}"
done

# ----------------------
# 13. Key Pair 삭제
# ----------------------
echo -e "${YELLOW}[13/14] Key Pair 삭제 중...${NC}"
aws ec2 delete-key-pair \
  --key-name ${PROJECT}-key \
  --region $REGION 2>/dev/null
echo -e "  ${GREEN}✓ Key Pair 삭제 완료${NC}"

# ----------------------
# 14. VPC 삭제 (마지막)
# ----------------------
echo -e "${YELLOW}[14/14] VPC 삭제 중...${NC}"
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓ VPC 삭제 완료${NC}"
  else
    echo -e "  ${RED}VPC 삭제 실패 - 의존 리소스가 남아있을 수 있습니다. AWS 콘솔에서 확인하세요.${NC}"
  fi
else
  echo "  VPC 없음 또는 이미 삭제됨, 스킵"
fi

# ----------------------
# 최종 확인
# ----------------------
echo ""
echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}       최종 잔여 리소스 확인          ${NC}"
echo -e "${YELLOW}======================================${NC}"

echo -n "VPC: "
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT}*" --query 'Vpcs[].VpcId' --output text --region $REGION 2>/dev/null || echo "없음"

echo -n "EKS: "
aws eks list-clusters --region $REGION --query 'clusters' --output text 2>/dev/null || echo "없음"

echo -n "EC2: "
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PROJECT}*" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text --region $REGION 2>/dev/null || echo "없음"

echo -n "S3:  "
aws s3 ls 2>/dev/null | grep ${PROJECT} || echo "없음"

echo ""
echo -e "${GREEN}✅ 삭제 완료! AWS 콘솔 Billing에서 최종 확인을 권장합니다.${NC}"
