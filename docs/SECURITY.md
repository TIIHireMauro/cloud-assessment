# 🔒 Security and Monitoring Documentation

## 📋 Overview

This document outlines the security measures and monitoring strategies implemented in the IoT Data Collector System.

## 🛡️ Security Architecture

### Network Security

#### VPC Design
```
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                   │
├─────────────────────────────────────────────────────────┤
│  Public Subnets (10.0.1.0/24, 10.0.2.0/24)            │
│  ┌─────────────┐  ┌─────────────┐                      │
│  │ NAT Gateway │  │ Load Balancer│                      │
│  └─────────────┘  └─────────────┘                      │
├─────────────────────────────────────────────────────────┤
│  Private Subnets (10.0.10.0/24, 10.0.11.0/24)         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   EKS       │  │    RDS      │  │   Lambda    │     │
│  │  Cluster    │  │  Database   │  │  Functions  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

#### Security Groups Configuration

##### EKS Cluster Security Group
```hcl
# infrastructure/terraform/eks.tf
resource "aws_security_group" "eks_cluster" {
  name_prefix = "eks-cluster-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

##### RDS Security Group
```hcl
# infrastructure/terraform/rds.tf
resource "aws_security_group" "rds" {
  name_prefix = "rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }
}
```

### Authentication and Authorization

#### MQTT Authentication

##### Local Environment
- **Mosquitto**: No authentication (development only)
- **Configuration**: Basic MQTT broker setup

##### Cloud Environment
- **AWS IoT Core**: Certificate-based authentication
- **Device Certificates**: X.509 certificates for device authentication
- **Policy-based Authorization**: Fine-grained access control

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iot:Connect",
        "iot:Publish",
        "iot:Subscribe",
        "iot:Receive"
      ],
      "Resource": [
        "arn:aws:iot:eu-west-1:123456789012:client/${iot:Connection.Thing.ThingName}",
        "arn:aws:iot:eu-west-1:123456789012:topic/iot/data",
        "arn:aws:iot:eu-west-1:123456789012:topicfilter/iot/data"
      ]
    }
  ]
}
```

#### Kubernetes RBAC

##### Service Account Configuration
```yaml
# chart/templates/backend-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: iot-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/iot-backend-role
```

##### IAM Role for Service Account (IRSA)
```hcl
# infrastructure/terraform/iam.tf
resource "aws_iam_role" "backend_role" {
  name = "iot-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:iot-system:backend-sa"
          }
        }
      }
    ]
  })
}
```

### Secrets Management

#### Local Environment
```bash
# Kubernetes Secrets
kubectl create secret generic db-secret \
  --from-literal=DB_PASSWORD=your_secure_password \
  -n iot-system
```

#### Cloud Environment
```bash
# AWS Secrets Manager
aws secretsmanager create-secret \
  --name "iot-system/db-password" \
  --description "Database password for IoT system" \
  --secret-string '{"DB_PASSWORD":"your_secure_password"}'
```

##### External Secrets Operator
```yaml
# chart/templates/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
  namespace: iot-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-secret
    type: kubernetes.io/opaque
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: iot-system/db-password
        property: DB_PASSWORD
```

### Data Protection

#### Encryption at Rest
- **RDS**: AES-256 encryption enabled
- **EBS Volumes**: Encrypted with AWS managed keys
- **S3**: Server-side encryption (SSE-S3)

#### Encryption in Transit
- **MQTT**: TLS 1.2 for all connections
- **Database**: SSL/TLS connections
- **API**: HTTPS with TLS 1.2+

#### Database Security
```sql
-- PostgreSQL Security Configuration
ALTER SYSTEM SET ssl = on;
ALTER SYSTEM SET ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL';
ALTER SYSTEM SET ssl_prefer_server_ciphers = on;
```

## 📊 Monitoring and Observability

### Metrics Collection

#### Prometheus Configuration
```yaml
# chart/templates/prometheus-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "alert_rules.yml"
    
    scrape_configs:
      - job_name: 'backend'
        static_configs:
          - targets: ['backend:3000']
        metrics_path: '/metrics'
        scrape_interval: 10s
        
      - job_name: 'node-exporter'
        static_configs:
          - targets: ['node-exporter:9100']
```

#### Custom Metrics
```javascript
// backend/src/metrics.js
const promClient = require('prom-client');

// MQTT Message Counter
const mqttMessagesTotal = new promClient.Counter({
  name: 'mqtt_messages_total',
  help: 'Total number of MQTT messages received',
  labelNames: ['topic', 'device_id']
});

// Database Write Counter
const dbWritesTotal = new promClient.Counter({
  name: 'db_writes_total',
  help: 'Total number of database writes',
  labelNames: ['table', 'operation']
});

// API Response Time
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});
```

### Alerting Rules

#### Prometheus Alert Rules
```yaml
# chart/templates/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: iot-alerts
  namespace: iot-system
spec:
  groups:
    - name: iot.rules
      rules:
        - alert: HighErrorRate
          expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.05
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value }} errors per second"
        
        - alert: DatabaseConnectionIssues
          expr: db_connection_errors_total > 0
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "Database connection issues"
            description: "Database connection errors detected"
        
        - alert: MQTTDisconnection
          expr: mqtt_connection_status == 0
          for: 30s
          labels:
            severity: critical
          annotations:
            summary: "MQTT connection lost"
            description: "MQTT broker connection is down"
```

### Grafana Dashboards

#### IoT Dashboard Configuration
```json
{
  "dashboard": {
    "title": "IoT Data Collector Dashboard",
    "panels": [
      {
        "title": "MQTT Message Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(mqtt_messages_total[5m])",
            "legendFormat": "{{device_id}}"
          }
        ]
      },
      {
        "title": "Database Write Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(db_writes_total[5m])",
            "legendFormat": "{{operation}}"
          }
        ]
      },
      {
        "title": "API Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      }
    ]
  }
}
```

### Log Management

#### Application Logging
```javascript
// backend/src/index.js
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});
```

#### Kubernetes Logging
```yaml
# chart/templates/backend-deployment.yaml
spec:
  template:
    spec:
      containers:
        - name: backend
          image: backend:latest
          env:
            - name: LOG_LEVEL
              value: "info"
          volumeMounts:
            - name: logs
              mountPath: /app/logs
      volumes:
        - name: logs
          emptyDir: {}
```

## 🔍 Security Monitoring

### Vulnerability Scanning

#### Container Scanning
```yaml
# .github/workflows/ci-cd.yml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    format: 'sarif'
    output: 'trivy-results.sarif'
```

#### Dependency Scanning
```bash
# npm audit
npm audit --audit-level=high

# Snyk security scan
snyk test --severity-threshold=high
```

### Network Security Monitoring

#### AWS GuardDuty
- **Enabled**: Automatic threat detection
- **Alerts**: Suspicious activity notifications
- **Integration**: CloudWatch Events

#### VPC Flow Logs
```hcl
# infrastructure/terraform/vpc.tf
resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}
```

### Compliance Monitoring

#### AWS Config Rules
```hcl
# infrastructure/terraform/config.tf
resource "aws_config_rule" "rds_encryption" {
  name = "rds-instance-encryption-check"
  
  source {
    owner             = "AWS"
    source_identifier = "RDS_INSTANCE_ENCRYPTION_CHECK"
  }
}
```

## 🚨 Incident Response

### Security Incident Playbook

#### 1. Detection
- **Automated Alerts**: Prometheus + Grafana
- **Manual Reports**: Security team notifications
- **External Sources**: AWS GuardDuty, CloudTrail

#### 2. Assessment
```bash
# Check for unauthorized access
aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=suspicious_user

# Check for data exfiltration
aws logs filter-log-events --log-group-name /aws/rds/instance/iot-database/error
```

#### 3. Containment
- **Network Isolation**: Update security groups
- **Access Revocation**: Remove compromised credentials
- **Service Suspension**: Stop affected services

#### 4. Eradication
- **Patch Vulnerabilities**: Update affected systems
- **Remove Malware**: Clean compromised instances
- **Rotate Credentials**: Update all secrets

#### 5. Recovery
- **Service Restoration**: Deploy clean instances
- **Data Validation**: Verify data integrity
- **Monitoring Enhancement**: Improve detection

### Communication Plan

#### Internal Communication
- **Security Team**: Immediate notification
- **Development Team**: Technical details
- **Management**: Executive summary

#### External Communication
- **Customers**: Service status updates
- **Regulators**: Compliance reporting
- **Vendors**: Security advisories

## 📋 Security Checklist

### Pre-deployment
- [ ] Security groups configured
- [ ] IAM roles and policies reviewed
- [ ] Secrets stored securely
- [ ] Encryption enabled
- [ ] Monitoring configured

### Post-deployment
- [ ] Vulnerability scans completed
- [ ] Access logs reviewed
- [ ] Backup verification
- [ ] Incident response tested
- [ ] Compliance audit passed

### Ongoing
- [ ] Regular security updates
- [ ] Access review quarterly
- [ ] Penetration testing annually
- [ ] Security training monthly
- [ ] Incident response drills

## 📚 Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/security/security-learning/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [Prometheus Security](https://prometheus.io/docs/operating/security/)
- [Grafana Security](https://grafana.com/docs/grafana/latest/administration/security/) 