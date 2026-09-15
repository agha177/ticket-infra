#!/bin/bash
set -e
echo "=== Deleting EKS cluster (this takes ~10 min) ==="
eksctl delete cluster --name ticket-booking-cluster --region us-east-1
echo "=== Done. Verify no leftover resources in the AWS Console (EC2, VPC, ELB) ==="
