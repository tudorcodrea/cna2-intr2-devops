# AI-Powered Autoscaling Architecture for Claims Service

## Overview
This document describes the intelligent autoscaling strategy for the Claims Service, which dynamically adjusts compute resources based on workload patterns and AI processing demands.

## Architecture Components for Your Diagram

### 1. **Horizontal Pod Autoscaler (HPA)**
```
┌─────────────────────────────────────────────────────────────┐
│                    Metrics Server                            │
│              (Collects CPU/Memory metrics)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│         Horizontal Pod Autoscaler (HPA)                      │
│  • Min Replicas: 2                                           │
│  • Max Replicas: 10                                          │
│  • Target CPU: 70%                                           │
│  • Target Memory: 80%                                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│            Claims Service Deployment                         │
│  ┌────────┐ ┌────────┐ ┌────────┐     ┌────────┐           │
│  │ Pod 1  │ │ Pod 2  │ │ Pod 3  │ ... │ Pod 10 │           │
│  │250m CPU│ │250m CPU│ │250m CPU│     │250m CPU│           │
│  │512Mi   │ │512Mi   │ │512Mi   │     │512Mi   │           │
│  └────────┘ └────────┘ └────────┘     └────────┘           │
└─────────────────────────────────────────────────────────────┘
```

### 2. **Vertical Pod Autoscaler (VPA)** - Optional
```
┌─────────────────────────────────────────────────────────────┐
│         Vertical Pod Autoscaler (VPA)                        │
│  • Analyzes historical resource usage                        │
│  • Adjusts CPU/Memory requests automatically                 │
│  • Min: 250m CPU, 512Mi Memory                              │
│  • Max: 2000m CPU, 4Gi Memory                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
             Optimizes resource allocation
```

### 3. **EKS Cluster Autoscaler**
```
┌─────────────────────────────────────────────────────────────┐
│            EKS Cluster Autoscaler                            │
│  • Monitors pending pods                                     │
│  • Adds worker nodes when pods can't be scheduled           │
│  • Removes underutilized nodes                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                  EKS Node Group                              │
│  • Instance Type: t3.medium                                  │
│  • Min Nodes: 1                                             │
│  • Max Nodes: 3                                             │
│  • Desired: 2                                               │
└─────────────────────────────────────────────────────────────┘
```

## Autoscaling Triggers

### CPU-Based Scaling
- **Trigger**: Average CPU utilization > 70%
- **Action**: Scale up pods
- **Scale Up Rate**: +100% or +4 pods per 30 seconds (whichever is greater)
- **Use Case**: High volume of API requests, heavy JSON processing

### Memory-Based Scaling
- **Trigger**: Average memory utilization > 80%
- **Action**: Scale up pods
- **Scale Up Rate**: Same as CPU
- **Use Case**: Large claim data processing, Lambda response caching

### Custom Metrics (Future Enhancement)
- **API Request Rate**: Scale based on requests/second
- **Lambda Invocation Queue**: Scale when many Bedrock calls are pending
- **DynamoDB Read/Write Latency**: Scale when data access slows down

## Scaling Policies

### Scale-Up Policy
```yaml
scaleUp:
  stabilizationWindowSeconds: 0  # Immediate scaling
  policies:
  - type: Percent
    value: 100         # Double the pods
    periodSeconds: 30
  - type: Pods
    value: 4           # Or add 4 pods
    periodSeconds: 30
  selectPolicy: Max    # Choose the more aggressive policy
```
**Behavior**: Aggressive scaling to handle sudden load spikes (common with AI workloads)

### Scale-Down Policy
```yaml
scaleDown:
  stabilizationWindowSeconds: 300  # Wait 5 minutes before scaling down
  policies:
  - type: Percent
    value: 50          # Remove up to 50% of pods
    periodSeconds: 60
  - type: Pods
    value: 2           # Or remove 2 pods
    periodSeconds: 60
  selectPolicy: Min    # Choose the more conservative policy
```
**Behavior**: Conservative scaling down to avoid thrashing and maintain stability

## AI Workload Characteristics

### Bedrock Processing Patterns
1. **Burst Traffic**: Claim summarization requests can spike during business hours
2. **Variable Latency**: Bedrock API calls take 2-5 seconds
3. **Memory Intensive**: Caching claim data and Lambda responses
4. **CPU Spikes**: JSON parsing, S3 file processing

### Resource Optimization
- **Baseline**: 2 pods (always-on for availability)
- **Normal Load**: 2-4 pods (handles steady state)
- **Peak Load**: 6-10 pods (handles spikes during business hours)
- **Night/Weekend**: Scales down to 2 pods (minimum for HA)

## Monitoring & Observability

### Key Metrics to Watch
1. **Pod CPU/Memory**: Track against 70%/80% thresholds
2. **HPA Status**: Monitor current/desired replica counts
3. **Scaling Events**: Log scale-up/down decisions
4. **Lambda Throttling**: Indicates need for more pods
5. **API Gateway 429 Errors**: Shows insufficient capacity

### CloudWatch Integration
```
CloudWatch Metrics:
- pod_cpu_utilization (ContainerInsights)
- pod_memory_utilization (ContainerInsights)
- kube_hpa_status_current_replicas (Prometheus)
- kube_hpa_status_desired_replicas (Prometheus)
```

## Diagram Elements to Add

### Component Boxes:
1. **Metrics Server** (top layer)
   - Collects pod metrics every 15 seconds
   - Feeds data to HPA

2. **Horizontal Pod Autoscaler** (control plane)
   - Decision engine
   - Shows min/max replicas (2-10)
   - CPU/Memory targets (70%/80%)

3. **Pod Replicas** (data plane)
   - Show variable number of pods (2-10)
   - Display resource requests/limits
   - Show scaling arrows (up/down)

4. **EKS Cluster Autoscaler** (infrastructure layer)
   - Monitors node capacity
   - Adds/removes worker nodes
   - Connection to AWS Auto Scaling Group

### Arrows & Flows:
- **Metrics Flow**: Pods → Metrics Server → HPA
- **Control Flow**: HPA → Deployment → Pod Replicas
- **Node Scaling**: HPA (pending pods) → Cluster Autoscaler → Node Group
- **Load Flow**: API Gateway → ALB → Pods (show load distribution)

### Annotations:
- **Scale Up**: Arrow pointing up with "+100% or +4 pods"
- **Scale Down**: Arrow pointing down with "-50% or -2 pods"
- **Stabilization**: Note "5min cooldown before scale-down"
- **AI Workload**: Badge showing "Bedrock AI Processing"

## Implementation Steps

### Step 1: Install Metrics Server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Step 2: Deploy HPA
```bash
kubectl apply -f k8s-hpa.yaml
```

### Step 3: Verify HPA
```bash
kubectl get hpa claims-service-hpa
kubectl describe hpa claims-service-hpa
```

### Step 4: Test Autoscaling
```bash
# Generate load
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://claims-service/api/v1/claims/test; done"

# Watch scaling
kubectl get hpa claims-service-hpa --watch
```

## Cost Optimization

### Resource Efficiency
- **Right-Sizing**: VPA ensures pods request exactly what they need
- **Dynamic Scaling**: Pay only for resources during peak hours
- **Node Consolidation**: Cluster Autoscaler packs pods efficiently

### Expected Costs (Estimated)
- **Baseline (2 pods)**: 2 × t3.medium nodes = $0.0832/hr × 730hr = ~$61/month
- **Peak (10 pods)**: 3 × t3.medium nodes = $0.0832/hr × 8hr/day × 22 days = ~$44/month extra during business hours
- **Total**: ~$105/month for fully auto-scaled infrastructure

## Best Practices

1. **Set Appropriate Limits**: Prevent runaway resource consumption
2. **Use Readiness Probes**: Ensure new pods are ready before receiving traffic
3. **Monitor Scaling Events**: Alert on frequent scale-up/down cycles
4. **Test Under Load**: Validate scaling behavior before production
5. **Document Thresholds**: Keep autoscaling parameters in version control

## Future Enhancements

1. **KEDA (Kubernetes Event-Driven Autoscaling)**
   - Scale based on SQS queue depth
   - Scale based on DynamoDB read/write capacity
   - Scale based on Lambda invocation metrics

2. **Predictive Scaling**
   - Use historical patterns to pre-scale before expected load
   - ML-based forecasting for business hour spikes

3. **Multi-Metric HPA**
   - Combine CPU, Memory, and custom metrics
   - More sophisticated decision-making

---

## Visual Representation for Draw.io

**Layer 1 (Top): Monitoring**
```
[CloudWatch] ← [Metrics Server] ← [Prometheus]
```

**Layer 2: Control Plane**
```
[HPA Controller] → [VPA Controller] → [Cluster Autoscaler]
      ↓                  ↓                    ↓
   Scale Pods      Optimize Resources    Add/Remove Nodes
```

**Layer 3: Compute**
```
[Pod 1] [Pod 2] [Pod 3] ... [Pod 10]
  250m    250m    250m        250m CPU
  512Mi   512Mi   512Mi       512Mi MEM
```

**Layer 4: Infrastructure**
```
[Node 1: t3.medium] [Node 2: t3.medium] [Node 3: t3.medium]
```

**Color Coding:**
- Green: HPA (active autoscaling)
- Blue: Pods (scaled instances)
- Orange: Metrics/Monitoring
- Gray: Infrastructure (nodes)
