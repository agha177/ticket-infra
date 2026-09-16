#!/bin/bash
set -e

CLUSTER_NAME="ticket-booking-cluster"
REGION="us-east-1"
ACCOUNT_ID="861097501014"

echo "=== Getting VPC ID for cluster ==="
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "VPC ID: $VPC_ID"

echo "=== Downloading IAM policy for AWS Load Balancer Controller ==="
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

echo "=== Creating IAM policy (skips if it already exists) ==="
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json \
  --region "$REGION" || echo "Policy may already exist, continuing..."

echo "=== Creating IAM service account for the controller ==="
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy" \
  --override-existing-serviceaccounts \
  --approve

echo "=== Installing Helm (if not already present) ==="
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "=== Adding the EKS Helm chart repo ==="
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "=== Installing AWS Load Balancer Controller via Helm ==="
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="$REGION" \
  --set vpcId="$VPC_ID"

echo "=== Waiting for controller pod to be ready ==="
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

echo "=== Done! Controller should now be running. Apply your ALB Ingress next. ==="
kubectl get pods -n kube-system | grep aws-load-balancer-controller
