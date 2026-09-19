#!/bin/bash
set -e

CLUSTER_NAME="ticket-booking-cluster"
REGION="us-east-1"
ACCOUNT_ID="861097501014"

echo "=== Creating EKS cluster (this takes ~15 min) ==="
eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --nodegroup-name ticket-workers \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed

echo "=== Setting gp2 as default StorageClass ==="
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "=== Enabling OIDC provider ==="
eksctl utils associate-iam-oidc-provider --cluster "$CLUSTER_NAME" --region "$REGION" --approve

echo "=== Creating IAM service account for EBS CSI driver ==="
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --namespace kube-system \
  --name ebs-csi-controller-sa \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --override-existing-serviceaccounts \
  --approve

echo "=== Installing EBS CSI driver addon ==="
eksctl create addon --cluster "$CLUSTER_NAME" --name aws-ebs-csi-driver --region "$REGION"

echo "=== Waiting for addon to become ACTIVE ==="
until eksctl get addon --cluster "$CLUSTER_NAME" --region "$REGION" | grep aws-ebs-csi-driver | grep -q ACTIVE; do
  echo "Still creating, waiting 15s..."
  sleep 15
done

echo "=== Linking EBS CSI driver to IAM role ==="
eksctl update addon \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --name aws-ebs-csi-driver \
  --service-account-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole"

echo "=== Restarting EBS CSI controller pods to pick up new role ==="
kubectl delete pod -n kube-system -l app=ebs-csi-controller

echo "=== Applying application manifests ==="
kubectl apply -f ~/ticket-infra/k8s/mysql-pvc.yaml
kubectl apply -f ~/ticket-infra/k8s/mysql-statefulset.yaml
kubectl apply -f ~/ticket-infra/k8s/mysql-service.yaml
kubectl apply -f ~/ticket-infra/k8s/app-configmap.yaml
kubectl apply -f ~/ticket-infra/k8s/app-secret.yaml
kubectl apply -f ~/ticket-infra/k8s/event-service-deployment.yaml
kubectl apply -f ~/ticket-infra/k8s/event-service-service.yaml
kubectl apply -f ~/ticket-infra/k8s/booking-service-deployment.yaml
kubectl apply -f ~/ticket-infra/k8s/booking-service-service.yaml
kubectl apply -f ~/ticket-infra/k8s/auth-service-deployment.yaml
kubectl apply -f ~/ticket-infra/k8s/auth-service-service.yaml
kubectl apply -f ~/ticket-infra/k8s/frontend-deployment.yaml
kubectl apply -f ~/ticket-infra/k8s/frontend-service.yaml

echo "=== Done! Checking pod status (MySQL/services may take a minute to stabilize) ==="
kubectl get pods
