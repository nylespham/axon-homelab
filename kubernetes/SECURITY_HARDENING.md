# Security Hardening Guide

This guide provides examples and best practices for implementing Kubernetes security controls during the interview.

## Security Areas to Implement

### 1. Network Security

#### Network Policies
- **Purpose**: Control pod-to-pod communication
- **Implementation**: Create network policies for each namespace
- **Testing**: Verify isolation between namespaces

#### Example Network Policy:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-network-policy
  namespace: database
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: vulnerable-app
    ports:
    - protocol: TCP
      port: 5432
```

### 2. Pod Security

#### Pod Security Standards (PSS)
- **Purpose**: Enforce security policies at the pod level
- **Implementation**: Configure namespace-level security standards
- **Testing**: Verify pods cannot run with elevated privileges

#### Example PSS Configuration:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 3. Security Contexts

#### Container Security
- **Purpose**: Run containers with minimal privileges
- **Implementation**: Configure security contexts in pod specs
- **Testing**: Verify containers run as non-root

#### Example Security Context:
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
```

### 4. Resource Management

#### Resource Limits
- **Purpose**: Prevent resource exhaustion attacks
- **Implementation**: Set CPU and memory limits
- **Testing**: Verify resource constraints are enforced

#### Example Resource Limits:
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### 5. Secrets Management

#### Secret Encryption
- **Purpose**: Protect sensitive data at rest
- **Implementation**: Enable etcd encryption
- **Testing**: Verify secrets are encrypted

#### Example Secret Configuration:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: vulnerable-app
type: Opaque
data:
  password: <base64-encoded-password>
```

### 6. RBAC (Role-Based Access Control)

#### Service Accounts
- **Purpose**: Limit pod permissions
- **Implementation**: Create service accounts with minimal permissions
- **Testing**: Verify pods cannot access unauthorized resources

#### Example RBAC:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: vulnerable-app
automountServiceAccountToken: false
```

### 7. Monitoring and Logging

#### Audit Logging
- **Purpose**: Track security events
- **Implementation**: Enable audit logging
- **Testing**: Verify security events are logged

#### Example Audit Configuration:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-policy
  namespace: kube-system
data:
  audit-policy.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
    - level: Metadata
      namespaces: ["vulnerable-app"]
```

## Implementation Checklist

### Network Security
- [ ] Create network policies for each namespace
- [ ] Test pod-to-pod communication restrictions
- [ ] Verify ingress/egress rules work correctly
- [ ] Document network isolation

### Pod Security
- [ ] Implement Pod Security Standards
- [ ] Configure security contexts
- [ ] Test privilege escalation prevention
- [ ] Verify non-root execution

### Resource Management
- [ ] Set resource limits and requests
- [ ] Configure resource quotas
- [ ] Test resource constraint enforcement
- [ ] Monitor resource usage

### Secrets Management
- [ ] Enable secret encryption
- [ ] Implement proper secret rotation
- [ ] Test secret access controls
- [ ] Document secret management

### Monitoring
- [ ] Enable audit logging
- [ ] Configure security monitoring
- [ ] Set up alerting
- [ ] Test log collection

## Testing Security Controls

### Network Policy Testing
```bash
# Test network isolation
kubectl exec -it pod-in-namespace-a -- curl pod-in-namespace-b
# Should fail if network policy is working
```

### Pod Security Testing
```bash
# Test security context enforcement
kubectl run test-pod --image=nginx --overrides='{"spec":{"securityContext":{"runAsUser":0}}}'
# Should fail if PSS is working
```

### Resource Limit Testing
```bash
# Test resource constraints
kubectl run stress-test --image=busybox --limits="cpu=100m,memory=128Mi" -- stress --cpu 1
# Should be throttled if limits are working
```

## Documentation Requirements

### Security Baseline
- Document implemented security controls
- Explain security decisions
- Identify remaining risks
- Suggest additional measures

### Testing Results
- Network policy effectiveness
- Pod security enforcement
- Resource constraint compliance
- Monitoring and alerting status

## Common Security Issues

### Network Policies
- **Issue**: Too restrictive policies blocking legitimate traffic
- **Solution**: Test policies thoroughly, use allow-by-default approach

### Pod Security
- **Issue**: Applications requiring elevated privileges
- **Solution**: Modify applications or use security contexts

### Resource Limits
- **Issue**: Applications crashing due to resource constraints
- **Solution**: Tune limits based on actual usage

### Monitoring
- **Issue**: Too many security alerts
- **Solution**: Tune alerting thresholds, focus on critical events

## Best Practices

1. **Start with restrictive policies** and relax as needed
2. **Test security controls** before deploying to production
3. **Monitor security events** continuously
4. **Document security decisions** for future reference
5. **Regular security reviews** and updates
