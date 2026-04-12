# 1. ALB 먼저 AWS에서 직접 삭제
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].LoadBalancerArn' \
  --output text \
  --region ap-northeast-2

# 출력된 ARN으로 삭제
aws elbv2 delete-load-balancer \
  --load-balancer-arn <위에서나온ARN> \
  --region ap-northeast-2

#ingress 삭제
kubectl patch ingress todo-app-ingress -n default \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge && \
kubectl delete ingress todo-app-ingress -n default --force --grace-period=0

# 2. 나머지 k8s 리소스 삭제
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/rbac.yaml

# 3. LB Controller 삭제
helm uninstall aws-load-balancer-controller -n kube-system

# 4. LB IAM Policy 삭제
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam delete-policy \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy

# 5. ECR 이미지 삭제
IMAGE_IDS=$(aws ecr list-images \
  --repository-name boo-exercise-app \
  --region ap-northeast-2 \
  --query 'imageIds[*]' \
  --output json)
aws ecr batch-delete-image \
  --repository-name boo-exercise-app \
  --image-ids "$IMAGE_IDS" \
  --region ap-northeast-2
