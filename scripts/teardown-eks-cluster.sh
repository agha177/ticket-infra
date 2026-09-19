#!/bin/bash
set -e

echo "=== Deleting Ingress and LoadBalancer services to trigger AWS ALB/NLB cleanup ==="
# Delete all Ingresses (this triggers the ALB Controller to destroy the physical AWS ALB)
kubectl delete ingress --all --all-namespaces --timeout=3m || true

# Delete any LoadBalancer type services
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --timeout=3m || true

echo "=== Waiting 30s for AWS Load Balancers to fully tear down ==="
sleep 30

echo "=== Deleting EKS cluster (this takes ~10 min) ==="
eksctl delete cluster --name ticket-booking-cluster --region us-east-1

echo "=== Cleanup complete! ==="
