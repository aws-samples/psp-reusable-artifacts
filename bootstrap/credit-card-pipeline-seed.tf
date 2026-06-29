################################################################################
# Seed credit-card-java repo with Hello World Spring Boot app
################################################################################

resource "null_resource" "seed_credit_card_java" {
  depends_on = [aws_codecommit_repository.credit_card_java]

  triggers = {
    repo_name = aws_codecommit_repository.credit_card_java.repository_name
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
    }
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      REPO_NAME="${aws_codecommit_repository.credit_card_java.repository_name}"
      REGION="${var.region}"
      ECR_REPO="${aws_ecr_repository.credit_card_java.repository_url}"
      IMAGE_REPO="${var.spoke_account_id}.dkr.ecr.${var.spoke_region}.amazonaws.com/${local.java_ecr_name}"

      PUT_FILES="[]"

      # --- pom.xml ---
      POM=$(base64 <<'POMEOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.4.1</version>
    <relativePath/>
  </parent>
  <groupId>com.creditcard</groupId>
  <artifactId>credit-card</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>credit-card</name>
  <description>Credit Card Java Application</description>
  <properties>
    <java.version>21</java.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
POMEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "pom.xml" --arg content "$POM" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- Main Application ---
      APP=$(base64 <<'APPEOF'
package com.creditcard;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class CreditCardApplication {
    public static void main(String[] args) {
        SpringApplication.run(CreditCardApplication.class, args);
    }
}
APPEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "src/main/java/com/creditcard/CreditCardApplication.java" --arg content "$APP" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- HelloController ---
      CTRL=$(base64 <<'CTRLEOF'
package com.creditcard.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
public class HelloController {

    @GetMapping("/")
    public Map<String, String> hello() {
        return Map.of("message", "Hello from Credit Card Service!");
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }
}
CTRLEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "src/main/java/com/creditcard/controller/HelloController.java" --arg content "$CTRL" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- application.yaml ---
      APPYML=$(base64 <<'YMLEOF'
server:
  port: 8080

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: always
YMLEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "src/main/resources/application.yaml" --arg content "$APPYML" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- Dockerfile ---
      DOCKER=$(base64 <<'DKEOF'
FROM public.ecr.aws/amazoncorretto/amazoncorretto:21
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
DKEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "Dockerfile" --arg content "$DOCKER" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- buildspec.yml ---
      BUILDSPEC=$(base64 <<BSEOF
version: 0.2
phases:
  install:
    runtime-versions:
      java: corretto21
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region \$AWS_DEFAULT_REGION | docker login --username AWS --password-stdin \$ECR_REPO
      - COMMIT_HASH=\$(echo \$CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=$${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Building Java application...
      - mvn clean package -DskipTests
      - echo Building Docker image...
      - docker build -t \$ECR_REPO:\$IMAGE_TAG .
      - docker tag \$ECR_REPO:\$IMAGE_TAG \$ECR_REPO:latest
  post_build:
    commands:
      - echo Pushing Docker image...
      - docker push \$ECR_REPO:\$IMAGE_TAG
      - docker push \$ECR_REPO:latest
      - echo "IMAGE_TAG=\$IMAGE_TAG" > image_tag.env
artifacts:
  files:
    - image_tag.env
    - '**/*'
BSEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "buildspec.yml" --arg content "$BUILDSPEC" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- .gitignore ---
      GITIGNORE=$(base64 <<'GIEOF'
target/
*.class
*.jar
.idea/
*.iml
.DS_Store
GIEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path ".gitignore" --arg content "$GITIGNORE" '. + [{"filePath": $path, "fileContent": $content}]')

      # Create initial commit
      PARENT_COMMIT_ID=$(aws codecommit get-branch \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --region "$REGION" \
        --query 'branch.commitId' \
        --output text 2>/dev/null || echo "")

      PARENT_ARG=""
      if [ -n "$PARENT_COMMIT_ID" ] && [ "$PARENT_COMMIT_ID" != "None" ]; then
        PARENT_ARG="--parent-commit-id $PARENT_COMMIT_ID"
      fi

      aws codecommit create-commit \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --commit-message "Initial commit: Hello World Spring Boot app" \
        --put-files "$PUT_FILES" \
        --region "$REGION" \
        $PARENT_ARG
    EOT
  }
}


################################################################################
# Seed credit-card-data-plane repo with Helm chart
################################################################################

resource "null_resource" "seed_credit_card_data_plane" {
  depends_on = [aws_codecommit_repository.credit_card_data_plane]

  triggers = {
    repo_name = aws_codecommit_repository.credit_card_data_plane.repository_name
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
    }
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      REPO_NAME="${aws_codecommit_repository.credit_card_data_plane.repository_name}"
      REGION="${var.region}"
      ECR_REPO="${aws_ecr_repository.credit_card_java.repository_url}"

      PUT_FILES="[]"

      # --- Chart.yaml ---
      CHART=$(base64 <<'CHARTEOF'
apiVersion: v2
name: credit-card
description: Credit Card application Helm chart
type: application
version: 0.1.0
appVersion: "1.0.0"
CHARTEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "credit-card/Chart.yaml" --arg content "$CHART" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- values.yaml ---
      VALUES=$(base64 <<VALEOF
replicaCount: 2

image:
  repository: $${IMAGE_REPO}
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
VALEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "credit-card/values.yaml" --arg content "$VALUES" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- templates/deployment.yaml ---
      DEPLOY=$(base64 <<'DEPLOYEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
              protocol: TCP
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
DEPLOYEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "credit-card/templates/deployment.yaml" --arg content "$DEPLOY" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- templates/service.yaml ---
      SVC=$(base64 <<'SVCEOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
      protocol: TCP
  selector:
    app: {{ .Chart.Name }}
SVCEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "credit-card/templates/service.yaml" --arg content "$SVC" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- .gitignore ---
      GITIGNORE=$(base64 <<'GIEOF'
*.tgz
.DS_Store
GIEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path ".gitignore" --arg content "$GITIGNORE" '. + [{"filePath": $path, "fileContent": $content}]')

      # Create initial commit
      PARENT_COMMIT_ID=$(aws codecommit get-branch \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --region "$REGION" \
        --query 'branch.commitId' \
        --output text 2>/dev/null || echo "")

      PARENT_ARG=""
      if [ -n "$PARENT_COMMIT_ID" ] && [ "$PARENT_COMMIT_ID" != "None" ]; then
        PARENT_ARG="--parent-commit-id $PARENT_COMMIT_ID"
      fi

      aws codecommit create-commit \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --commit-message "Initial commit: Credit Card Helm chart" \
        --put-files "$PUT_FILES" \
        --region "$REGION" \
        $PARENT_ARG
    EOT
  }
}

################################################################################
# Seed the credit-card app entry in control-plane-operations
################################################################################
# Adds a config.json pointing to the OCI chart in ECR so ArgoCD's
# apps-development ApplicationSet picks it up.
################################################################################

resource "null_resource" "seed_credit_card_app_entry" {
  depends_on = [
    null_resource.seed_repo,
    aws_ecr_repository.credit_card_java,
  ]

  triggers = {
    ecr_repo = aws_ecr_repository.credit_card_java.repository_url
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
    }
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      REPO_NAME="${var.git_repo_url}"
      REGION="${var.region}"
      ECR_REPO="${local.account_id}.dkr.ecr.${var.region}.amazonaws.com"
      IMAGE_REPO="${var.spoke_account_id}.dkr.ecr.${var.spoke_region}.amazonaws.com/${local.java_ecr_name}"
      CHART_NAME="${local.java_ecr_name}"

      PUT_FILES="[]"

      # --- config.json pointing to OCI chart ---
      CONFIG=$(echo '{}' | jq \
        --arg url "$ECR_REPO" \
        --arg name "$CHART_NAME" \
        --arg version "0.1.0" \
        '{chartUrl: $url, chartName: $name, chartVersion: $version}' | base64)

      PUT_FILES=$(echo "$PUT_FILES" | jq \
        --arg path "applications/development/credit-card-development/credit-card/config.json" \
        --arg content "$CONFIG" \
        '. + [{"filePath": $path, "fileContent": $content}]')

      # --- values.yaml ---
      VALUES=$(base64 <<VALEOF
replicaCount: 2

image:
  repository: $${IMAGE_REPO}
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
VALEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "applications/development/credit-card-development/credit-card/values.yaml" --arg content "$VALUES" '. + [{"filePath": $path, "fileContent": $content}]')

      # Also seed the values.yaml in the new runtime/development/credit-card/apps/ path
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "runtime/development/credit-card/apps/values.yaml" --arg content "$VALUES" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- templates/deployment.yaml ---
      DEPLOY=$(base64 <<'DEPLOYEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
              protocol: TCP
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
DEPLOYEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "applications/development/credit-card-development/credit-card/templates/deployment.yaml" --arg content "$DEPLOY" '. + [{"filePath": $path, "fileContent": $content}]')

      # --- templates/service.yaml ---
      SVC=$(base64 <<'SVCEOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
      protocol: TCP
  selector:
    app: {{ .Chart.Name }}
SVCEOF
      )
      PUT_FILES=$(echo "$PUT_FILES" | jq --arg path "applications/development/credit-card-development/credit-card/templates/service.yaml" --arg content "$SVC" '. + [{"filePath": $path, "fileContent": $content}]')

      PARENT_COMMIT_ID=$(aws codecommit get-branch \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --region "$REGION" \
        --query 'branch.commitId' \
        --output text 2>/dev/null || echo "")

      PARENT_ARG=""
      if [ -n "$PARENT_COMMIT_ID" ] && [ "$PARENT_COMMIT_ID" != "None" ]; then
        PARENT_ARG="--parent-commit-id $PARENT_COMMIT_ID"
      fi

      aws codecommit create-commit \
        --repository-name "$REPO_NAME" \
        --branch-name main \
        --commit-message "feat: add credit-card application entry for development" \
        --put-files "$PUT_FILES" \
        --region "$REGION" \
        $PARENT_ARG
    EOT
  }
}
