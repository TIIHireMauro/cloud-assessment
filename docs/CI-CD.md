# 🔄 CI/CD Pipeline Documentation

## 📋 Overview

This project implements a complete CI/CD pipeline using GitHub Actions to automate the build, test, security, and deployment of the IoT Data Collector system.

## 🏗️ Pipeline Architecture

### Implemented Workflows

1. **`ci-cd.yml`** - Main pipeline for automatic deployment
2. **`pr-check.yml`** - Validations for Pull Requests
3. **`manual-deploy.yml`** - Manual deployment via GitHub Actions UI
4. **`codeql.yml`** - Code security analysis

## 🔧 Required Configuration

### GitHub Secrets

Configure the following secrets in your GitHub repository:

```bash
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
```

### Required AWS Permissions

The AWS user must have the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ecr:*",
                "ec2:*",
                "iam:*",
                "rds:*",
                "iot:*",
                "lambda:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🚀 How It Works

### 1. Main Pipeline (`ci-cd.yml`)

**Triggers:**
- Push to `main` or `develop`
- Pull Request to `main`

**Jobs:**
1. **Security Scan** - Vulnerability analysis with Trivy
2. **Test** - Testing of backend and simulator applications
3. **Build and Push** - Build and push Docker images to ECR
4. **Deploy Infrastructure** - Infrastructure deployment with Terraform
5. **Deploy Application** - Application deployment with Helm
6. **Notify** - Success/failure notifications

### 2. Pull Request Check (`pr-check.yml`)

**Triggers:**
- Pull Request to `main` or `develop`

**Jobs:**
1. **Validate** - Terraform validation
2. **Security Scan** - Security scan (CRITICAL/HIGH only)
3. **Test** - Application testing
4. **Build Test** - Image build test (no push)
5. **Helm Lint** - Helm charts validation

### 3. Manual Deploy (`manual-deploy.yml`)

**Triggers:**
- Manual via GitHub Actions UI

**Features:**
- Environment selection (staging/production)
- Optional version specification
- Complete deployment with verification

## 📊 Monitoring and Observability

### Collected Metrics

- **Build Metrics:**
  - Build time
  - Image size
  - Cache hit rate

- **Deploy Metrics:**
  - Deployment time
  - Pod status
  - Service availability

- **Security Metrics:**
  - Vulnerabilities found
  - Issue severity
  - Fix time

### Dashboards

Workflows send data to:
- GitHub Security tab
- GitHub Actions insights
- AWS CloudWatch (via Terraform)

## 🔒 Security

### Security Implementations

1. **Trivy Vulnerability Scanner**
   - Dependency scanning
   - Docker image scanning
   - SARIF reports

2. **CodeQL Analysis**
   - Static code analysis
   - Vulnerability detection
   - Weekly automatic analysis

3. **Secret Management**
   - GitHub Secrets usage
   - AWS Secrets Manager integration
   - Automatic credential rotation

4. **Network Security**
   - Isolated VPC
   - Restrictive Security Groups
   - WAF for public APIs

## 🛠️ Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Check logs
   gh run view --log
   
   # Re-run failed job
   gh run rerun <run-id>
   ```

2. **Deploy Failures**
   ```bash
   # Check cluster status
   aws eks describe-cluster --name iot-cluster --region eu-west-1
   
   # Check pods
   kubectl get pods -n iot-system
   ```

3. **Security Issues**
   ```bash
   # Check vulnerabilities
   trivy fs .
   
   # Update dependencies
   npm audit fix
   ```

### Logs and Debugging

- **GitHub Actions:** Available in the repository's Actions tab
- **EKS:** `kubectl logs -f <pod-name> -n <namespace>`
- **Terraform:** Logs in AWS CloudTrail console

## 📈 Future Improvements

### Planned

1. **Multi-environment Support**
   - Deploy to multiple environments
   - Blue-green deployments
   - Canary releases

2. **Advanced Monitoring**
   - Datadog/New Relic integration
   - Custom dashboards
   - Automatic alerting

3. **Security Enhancements**
   - Container signing
   - SBOM generation
   - Compliance scanning

4. **Performance Optimization**
   - Parallel job execution
   - Build caching
   - Resource optimization

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS EKS Best Practices](https://aws.amazon.com/eks/resources/best-practices/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) 