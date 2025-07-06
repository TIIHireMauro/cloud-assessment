# 🏗️ Architecture Documentation

## 📋 System Overview

The IoT Data Collector System is a microservices-based architecture designed to collect, process, and monitor IoT sensor data. The system supports both local development and cloud deployment on AWS.

## 🏛️ High-Level Architecture

![System Architecture](docs/images/architecture.png)

*For a detailed visual representation of the system architecture, see the diagram above.*

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   IoT Devices   │    │   Simulator     │    │   External      │
│   (Real/Sensor) │    │   (Testing)     │    │   MQTT Clients  │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │      MQTT Broker         │
                    │  Local: Mosquitto        │
                    │  Cloud: AWS IoT Core     │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │     Backend API          │
                    │   (Node.js + Express)    │
                    │   Port: 3000             │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │      Database            │
                    │  Local: PostgreSQL       │
                    │  Cloud: AWS RDS          │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │    Monitoring Stack      │
                    │  Prometheus + Grafana    │
                    └───────────────────────────┘
```

## 🏗️ Component Architecture

### 1. MQTT Layer

#### Local Environment
- **Mosquitto Broker**: Docker container on port 1883
- **Configuration**: MQTT topic `iot/data`
- **Authentication**: None (development only)

#### Cloud Environment
- **AWS IoT Core**: Managed MQTT broker
- **Features**: 
  - Device authentication via certificates
  - Message routing and filtering
  - Integration with AWS services
- **Security**: TLS 1.2, certificate-based authentication

### 2. Backend API Layer

#### Node.js Application
```javascript
// Core components
- Express.js server (port 3000)
- MQTT client for data ingestion
- PostgreSQL client for data storage
- Prometheus metrics collection
- REST API endpoints
```

#### API Endpoints
- `GET /metrics` - Prometheus metrics
- `GET /api/data` - Retrieve IoT data
- `POST /api/data` - Store IoT data (MQTT integration)

### 3. Database Layer

#### PostgreSQL Schema
```sql
CREATE TABLE iot_data (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50),
    sensor_type VARCHAR(20),
    value DECIMAL(10,2),
    unit VARCHAR(10),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Local vs Cloud
- **Local**: PostgreSQL in Docker container
- **Cloud**: AWS RDS PostgreSQL with:
  - Multi-AZ deployment
  - Automated backups
  - Encryption at rest
  - VPC isolation

### 4. Monitoring Stack

#### Prometheus Configuration
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'backend'
    static_configs:
      - targets: ['backend:3000']
    metrics_path: '/metrics'
```

#### Grafana Dashboards
- **MQTT Message Rate**: Real-time message processing
- **Database Performance**: Query times, connection pool
- **System Metrics**: CPU, memory, disk usage
- **Custom Metrics**: Temperature, humidity trends

## 🔒 Security Architecture

### Network Security
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

### Security Groups
- **EKS Cluster**: Inbound from ALB only
- **RDS Database**: Inbound from EKS only
- **ALB**: Inbound HTTP/HTTPS from internet

### Secrets Management
- **Local**: Kubernetes Secrets
- **Cloud**: External Secrets Operator + AWS Secrets Manager
- **Rotation**: Automatic credential rotation

## 📊 Data Flow

### 1. Data Ingestion Flow
```
IoT Device → MQTT Broker → Backend API → Database
     ↓              ↓           ↓           ↓
  Simulator    Mosquitto    Node.js    PostgreSQL
```

### 2. Monitoring Flow
```
Backend API → Prometheus → Grafana → Dashboards
     ↓           ↓           ↓           ↓
  /metrics    Scraping   Queries    Visualization
```

### 3. CI/CD Flow
```
Git Push → GitHub Actions → Build → Test → Deploy
    ↓           ↓           ↓       ↓       ↓
  Code      Workflows    Docker   Tests   EKS
```

## 🚀 Deployment Architecture

### Local Development
```
┌─────────────────────────────────────────────────┐
│              Kind Kubernetes Cluster            │
├─────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │  Mosquitto  │  │   Backend   │  │Simulator│  │
│  │   (MQTT)    │  │   (API)     │  │ (Data)  │  │
│  └─────────────┘  └─────────────┘  └─────────┘  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │ PostgreSQL  │  │ Prometheus  │  │ Grafana │  │
│  │ (Database)  │  │ (Metrics)   │  │ (UI)    │  │
│  └─────────────┘  └─────────────┘  └─────────┘  │
└─────────────────────────────────────────────────┘
```

### Cloud Production
```
┌─────────────────────────────────────────────────┐
│                    AWS Cloud                    │
├─────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │ AWS IoT     │  │   EKS       │  │   RDS   │  │
│  │   Core      │  │  Cluster    │  │Database │  │
│  └─────────────┘  └─────────────┘  └─────────┘  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │ Application │  │ Prometheus  │  │ Grafana │  │
│  │ Load Balancer│  │ (Metrics)   │  │ (UI)    │  │
│  └─────────────┘  └─────────────┘  └─────────┘  │
└─────────────────────────────────────────────────┘
```

## 🔧 Technology Decisions

### Why These Technologies?

#### 1. **MQTT Broker Choice**
- **Local**: Mosquitto - As requested in the assessment. Didn't know it before, but I liked it.
- **Cloud**: AWS IoT Core - I chose it because it is a dedicated managed service, highly scalable, and already includes the necessary security features to protect the environment, avoiding the complexity of load balancers and firewalls.

#### 2. **Database Choice**
- **PostgreSQL**: ACID compliance, JSON support, I chose it due to previous experience, as it is simple and compatible.
- **RDS**: RDS already provides high availability, integrated backup, and security features (such as integration with secrets and rotation policies), saving a lot of time on infrastructure configurations. Additionally, it offers flexible pricing.

#### 3. **Monitoring Stack**
- **Prometheus and Grafana**: As requested in the assessment. I like these options; they are ideal for the project. I kept everything in containers to facilitate portability and avoid impacting users during the migration. However, both Grafana and Prometheus could be converted to managed services, which would greatly simplify access security management without the need to configure mappings or VPNs for dashboard access.

#### 4. **Container Orchestration**
- **Kubernetes**: I chose KinD for its simplicity.
- **EKS**: It is a robust and reliable system for managing containers, in addition to being integrated with secrets (via ESO) and allowing for high availability management with great ease.

#### 5. **Infrastructure as Code**
- **Terraform**:  Multi-cloud portability and provides clear infrastructure development, making it useful even for beginners.
- **Helm**: I choose it because it allows the same project to be reused both locally and in the cloud, making tests/demos much easier.

## 📈 Scalability Considerations

### Horizontal Scaling
- **Backend API**: Multiple replicas in EKS (3 minimum, due to quorum)
- **Database**: Standby replicas for HA, with possibility of turning read replicas on for read-heavy workloads
- **MQTT**: AWS IoT Core auto-scales

### Vertical Scaling
- **EKS Nodes**: Auto-scaling groups
- **RDS**: Instance size upgrades
- **Monitoring**: Resource allocation based on load

### Performance Optimization (optional)
- **Connection Pooling**: Database connections
- **Queues**: For saving costs
- **Kinesis**: If there is too much data in the future
- **Caching**: Redis for frequently accessed data (historical)

## 🔍 Monitoring and Alerting

### Key Metrics
- **MQTT Message Rate**: Messages per second
- **Database Performance**: Query times, connections
- **API Response Time**: Endpoint performance
- **System Resources**: CPU, memory, disk

### Alerting Rules
- **High Error Rate**: >5% HTTP 5xx errors
- **Database Issues**: Connection timeouts
- **MQTT Disconnections**: Device offline
- **Resource Exhaustion**: High CPU/memory usage

## 🛡️ Disaster Recovery

### Backup Strategy
- **Database**: Automated daily backups
- **Configuration**: Git version control
- **Application**: Container images in ECR

### Recovery Procedures
- **RTO**: 15 minutes (automated deployment)
- **RPO**: 24 hours (daily backups)
- **Testing**: Monthly disaster recovery drills

## 💰 Cost Optimization

### Resource Sizing
- **EKS**: Spot instances for non-critical workloads
- **RDS**: Reserved instances for predictable workloads
- **Storage**: S3 lifecycle policies

### Monitoring Costs
- **CloudWatch**: Basic monitoring included
- **Custom Metrics**: Cost-aware implementation
- **Log Retention**: Configurable retention periods 