# AI-Powered Autoscaling Architecture

## How It Works

### Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MONITORING LAYER                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ Pod CPU > 70%│  │Pod Mem > 80% │  │API Latency   │              │
│  │              │  │              │  │   > 3s       │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                  │                       │
│         └─────────────────┴──────────────────┘                       │
│                           │                                          │
│                           ▼                                          │
│              ┌─────────────────────────┐                            │
│              │  CloudWatch Alarms      │                            │
│              │  (State Change)         │                            │
│              └────────────┬────────────┘                            │
│                           │                                          │
│                           ▼                                          │
│              ┌─────────────────────────┐                            │
│              │  SNS Topic:             │                            │
│              │  autoscaling-triggers   │                            │
│              └────────────┬────────────┘                            │
└───────────────────────────┼──────────────────────────────────────────┘
                            │
                            │ Trigger Event
                            │
┌───────────────────────────▼──────────────────────────────────────────┐
│                     AI DECISION LAYER                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │           Lambda: AI Autoscaler                            │    │
│  │           (ai_autoscaler.py)                               │    │
│  │                                                            │    │
│  │  STEP 1: Parse CloudWatch Alarm                           │    │
│  │  ├─ Extract: Alarm name, metric, threshold                │    │
│  │  └─ Identify: Trigger reason and state                    │    │
│  │                                                            │    │
│  │  STEP 2: Gather Workload Metrics (Last 30min)             │    │
│  │  ├─ Pod CPU/Memory utilization + trends                   │    │
│  │  ├─ API Gateway request count + latency                   │    │
│  │  ├─ Lambda invocations + duration                         │    │
│  │  └─ Calculate: current, average, max, min, trend          │    │
│  │                                                            │    │
│  │  STEP 3: AI Analysis via Amazon Bedrock ─────────┐        │    │
│  │  ├─ Build context prompt with metrics            │        │    │
│  │  └─ Request scaling recommendation                │        │    │
│  └──────────────────────────────────────────────────┼────────┘    │
│                                                      │             │
│                                                      ▼             │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │         Amazon Bedrock (Nova Lite)                         │  │
│  │                                                            │  │
│  │  ANALYSIS LOGIC:                                           │  │
│  │  • Evaluates current metrics vs thresholds                │  │
│  │  • Considers metric trends (increasing/decreasing)        │  │
│  │  • Accounts for AI workload (Bedrock latency 2-5s)        │  │
│  │  • Analyzes correlation between metrics                   │  │
│  │  • Applies ML-based pattern recognition                   │  │
│  │                                                            │  │
│  │  DECISION OUTPUT (JSON):                                   │  │
│  │  {                                                         │  │
│  │    "action": "SCALE_UP|SCALE_DOWN|NO_ACTION",             │  │
│  │    "target_replicas": 6,                                   │  │
│  │    "confidence": 0.85,                                     │  │
│  │    "reasoning": "High CPU (75%) with increasing API...",  │  │
│  │    "urgency": "MEDIUM"                                     │  │
│  │  }                                                         │  │
│  └──────────────────────────────┬─────────────────────────────┘  │
│                                 │                                  │
│                                 ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Lambda validates decision:                                │  │
│  │  • Constrain target_replicas (2-10 range)                  │  │
│  │  • Verify confidence threshold                             │  │
│  │  • Log decision to CloudWatch Logs                         │  │
│  └──────────────────────────────┬─────────────────────────────┘  │
└───────────────────────────────┼──────────────────────────────────┘
                                │
                                │ Autoscaling Request
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                     EXECUTION LAYER                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Kubernetes API (via kubectl or Python client)             │    │
│  │                                                            │    │
│  │  kubectl scale deployment claims-service                   │    │
│  │         --replicas=<target_replicas>                       │    │
│  │         --namespace=default                                │    │
│  └──────────────────────────────┬─────────────────────────────┘    │
│                                 │                                   │
│                                 ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │            EKS Deployment Controller                       │   │
│  │                                                            │   │
│  │  • Receives scaling request                                │   │
│  │  • Updates desired replica count                           │   │
│  │  • Creates/terminates pods                                 │   │
│  │  • Ensures health checks pass                              │   │
│  └──────────────────────────────┬─────────────────────────────┘   │
│                                 │                                   │
│                                 ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │      Claims Service Pods (Scaled)                          │   │
│  │                                                            │   │
│  │  Before: [Pod1] [Pod2]                    (2 replicas)    │   │
│  │  After:  [Pod1] [Pod2] [Pod3] [Pod4]      (4 replicas)    │   │
│  │          [Pod5] [Pod6]                                     │   │
│  │                                                            │   │
│  │  • New pods scheduled on available nodes                   │   │
│  │  • Load balancer updated with new endpoints                │   │
│  │  • Traffic distributed across all replicas                 │   │
│  └────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

## Trigger Mechanisms

### 1. Reactive Triggers (CloudWatch Alarms)
```
CloudWatch Alarm → SNS Topic → Lambda Invocation
```
**Example Alarms:**
- Pod CPU > 70% for 2 consecutive periods (10 minutes)
- Pod Memory > 80% for 2 consecutive periods
- API Gateway p95 latency > 3 seconds

### 2. Proactive Triggers (EventBridge Schedule)
```
EventBridge Rule (every 5 min) → Lambda Invocation
```
**Purpose:**
- Periodic workload analysis
- Predictive scaling based on patterns
- Preemptive scaling before alarms trigger

## AI Decision Process

### Input to Bedrock

```json
{
  "alarm": {
    "name": "pod-high-cpu-ai-trigger",
    "state": "ALARM",
    "metric": "pod_cpu_utilization",
    "threshold": 70
  },
  "metrics": {
    "cpu_util": {
      "current": 75.2,
      "average": 68.5,
      "trend": "increasing"
    },
    "mem_util": {
      "current": 65.0,
      "average": 62.0,
      "trend": "stable"
    },
    "api_requests": {
      "current": 450,
      "average": 380,
      "trend": "increasing"
    },
    "lambda_invocations": {
      "current": 120,
      "average": 95,
      "trend": "increasing"
    }
  }
}
```

### Bedrock Analysis Factors

1. **Threshold Breach Analysis**
   - How far above/below threshold?
   - Multiple metrics breaching?
   
2. **Trend Analysis**
   - Is workload increasing or decreasing?
   - Rate of change (gradual vs sudden)

3. **Correlation Analysis**
   - High CPU + High API requests = legitimate load
   - High CPU + Low API requests = inefficient code

4. **AI Workload Characteristics**
   - Bedrock calls are slow (2-5s)
   - Lambda invocations spike during claims processing
   - Memory usage correlates with concurrent requests

5. **Time-of-Day Patterns**
   - Business hours vs off-hours
   - Historical patterns

### Bedrock Output

```json
{
  "action": "SCALE_UP",
  "target_replicas": 6,
  "confidence": 0.85,
  "reasoning": "High CPU (75%) with increasing trend. API requests up 18% and Lambda invocations up 26%. Proactive scaling recommended to handle expected load spike.",
  "urgency": "MEDIUM"
}
```

## Execution Flow

### Scale-Up Scenario

1. **Detection**: API latency alarm triggers (p95 > 3s)
2. **Lambda Invocation**: SNS delivers alarm to Lambda
3. **Metrics Gathering**: Lambda queries CloudWatch for 30min history
4. **AI Analysis**: Bedrock analyzes metrics and recommends `SCALE_UP` to 6 replicas
5. **Validation**: Lambda constrains to 2-10 range, validates confidence
6. **Execution**: Lambda calls Kubernetes API to scale deployment
7. **EKS Response**: Deployment controller creates 4 new pods
8. **Stabilization**: New pods pass health checks, receive traffic
9. **Monitoring**: CloudWatch tracks new metrics with 6 pods

### Scale-Down Scenario

1. **Detection**: EventBridge periodic trigger (every 5 min)
2. **Metrics Gathering**: CPU at 30%, API requests low, trend decreasing
3. **AI Analysis**: Bedrock recommends `SCALE_DOWN` to 3 replicas
4. **Validation**: Confidence 0.9, urgency LOW
5. **Execution**: Kubernetes terminates 3 pods gracefully
6. **Cost Savings**: Reduced compute resources during low traffic

### No-Action Scenario

1. **Detection**: Memory alarm triggers (82%)
2. **AI Analysis**: Bedrock sees CPU low (40%), API requests stable
3. **Decision**: `NO_ACTION` - memory spike is temporary (caching)
4. **Reasoning**: "Memory utilization temporarily high due to Lambda response caching. CPU and API metrics are normal. No scaling needed."

## Advantages Over Standard HPA

| Feature | Standard HPA | AI-Powered Autoscaling |
|---------|-------------|------------------------|
| **Decision Making** | Simple threshold-based | Context-aware AI analysis |
| **Metrics** | Single metric (CPU/Memory) | Multi-metric correlation |
| **Trends** | Ignores trends | Analyzes increasing/decreasing patterns |
| **Workload Awareness** | Generic | Understands AI workload (Bedrock latency) |
| **Proactive Scaling** | Reactive only | Predictive + Reactive |
| **False Positives** | Common (temp spikes) | Reduced (AI filters noise) |
| **Reasoning** | None | Provides explanation for decisions |

## Monitoring & Observability

### CloudWatch Logs Insights Query

```sql
fields @timestamp, ai_decision.action, ai_decision.target_replicas, 
       ai_decision.confidence, ai_decision.reasoning
| filter @message like /SCALING_DECISION/
| stats count() by ai_decision.action
| sort @timestamp desc
```

### Key Metrics to Track

1. **Scaling Frequency**: How often AI triggers scaling
2. **Decision Confidence**: Average confidence scores
3. **Action Distribution**: SCALE_UP vs SCALE_DOWN vs NO_ACTION ratio
4. **Execution Success Rate**: % of successful scaling operations
5. **Cost Impact**: Compute cost before/after AI autoscaling

## Configuration

### Environment Variables

- `CLUSTER_NAME`: EKS cluster name
- `NAMESPACE`: Kubernetes namespace (default)
- `DEPLOYMENT_NAME`: Target deployment (claims-service)
- `MIN_REPLICAS`: Minimum pod count (2)
- `MAX_REPLICAS`: Maximum pod count (10)

### Tuning Parameters

- **Alarm Thresholds**: Adjust CPU/Memory thresholds for triggers
- **Evaluation Periods**: Change sensitivity to metric breaches
- **EventBridge Schedule**: Adjust frequency of proactive analysis
- **Confidence Threshold**: Require minimum confidence for scaling

## Cost Considerations

### Lambda Costs
- **Invocations**: ~288/day (every 5 min) + alarm triggers
- **Duration**: ~5-10 seconds per invocation
- **Memory**: 512 MB
- **Estimated**: ~$5/month

### Bedrock Costs
- **Model**: Amazon Nova Lite (cost-effective)
- **Input Tokens**: ~500 tokens per request
- **Output Tokens**: ~200 tokens per response
- **Estimated**: ~$10/month

### Savings from Optimized Scaling
- Reduces over-provisioning during low traffic
- Prevents under-provisioning during spikes
- **Estimated Savings**: 20-30% on compute costs

---

**Total AI Autoscaling Cost**: ~$15/month
**Potential Savings**: $30-50/month
**Net Benefit**: $15-35/month + improved performance
