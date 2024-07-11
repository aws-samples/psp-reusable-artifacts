#!/bin/bash

aws iam create-role --role-name PSP-ControlPlane-Execution --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::'$CONTROLPLANE_ACCOUNT_ID':root"},"Action":"sts:AssumeRole"}]}'

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess

aws iam attach-role-policy --role-name PSP-ControlPlane-Execution --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess

aws iam put-role-policy --role-name PSP-ControlPlane-Execution --policy-name AmazonEKSFullAccess --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["eks:*"],"Resource":["*"]}]}'

aws iam put-role-policy --role-name PSP-ControlPlane-Execution --policy-name AmazonKMSFullAccess --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["kms:*"],"Resource":["*"]}]}'

aws iam put-role-policy --role-name PSP-ControlPlane-Execution --policy-name STSandECR --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["ecr-public:GetAuthorizationToken","sts:GetServiceBearerToken"],"Resource":["*"]}]}'
