# Kubernetes Security Examples

This directory contains Kubernetes security manifests and examples for the DevSecOps interview lab.

## Files

- **`kubernetes-security-examples.yaml`** - Example security manifests
- **`SECURITY_HARDENING.md`** - Comprehensive security hardening guide

## Security Examples Included

### Network Policies
- Database network isolation
- Application network policies
- Namespace-to-namespace communication rules

### Pod Security
- Pod Security Standards (PSS) examples
- Security context configurations
- Resource limits and requests

### RBAC (Role-Based Access Control)
- Service account configurations
- Role and RoleBinding examples
- Minimal permission principles

### Resource Management
- Resource quotas
- Pod disruption budgets
- Resource limits

## Usage

### For Candidates
1. **Reference these examples** during Task 5 (Security Hardening)
2. **Customize configurations** for your specific needs
3. **Test security controls** to ensure they work correctly
4. **Document your security decisions** and rationale

### For Interviewers
1. **Review security implementations** in candidate's work
2. **Evaluate security knowledge** and best practices
3. **Assess risk management** and decision-making
4. **Check documentation quality** and completeness

## Security Areas Covered

### 1. Network Security
- Network policies for pod isolation
- Ingress/egress rule configuration
- Namespace-level network controls

### 2. Pod Security
- Pod Security Standards implementation
- Security context configuration
- Privilege escalation prevention

### 3. Resource Security
- Resource limits and requests
- Resource quota enforcement
- Pod disruption budgets

### 4. Access Control
- Service account configuration
- RBAC implementation
- Minimal permission principles

### 5. Monitoring
- Audit logging configuration
- Security event monitoring
- Alerting setup

## Implementation Checklist

- [ ] Network policies for each namespace
- [ ] Pod security standards enforcement
- [ ] Security contexts for all pods
- [ ] Resource limits and quotas
- [ ] RBAC configuration
- [ ] Audit logging setup
- [ ] Security testing and validation
- [ ] Documentation of security decisions

## Best Practices

1. **Start with restrictive policies** and relax as needed
2. **Test security controls** before deploying
3. **Document security decisions** for future reference
4. **Monitor security events** continuously
5. **Regular security reviews** and updates

## Security Testing

### Network Policy Testing
```bash
# Test network isolation
kubectl exec -it pod-in-namespace-a -- curl pod-in-namespace-b
```

### Pod Security Testing
```bash
# Test security context enforcement
kubectl run test-pod --image=nginx --overrides='{"spec":{"securityContext":{"runAsUser":0}}}'
```

### Resource Limit Testing
```bash
# Test resource constraints
kubectl run stress-test --image=busybox --limits="cpu=100m,memory=128Mi" -- stress --cpu 1
```

## Common Issues

### Network Policies
- **Issue**: Too restrictive policies blocking legitimate traffic
- **Solution**: Test policies thoroughly, use allow-by-default approach

### Pod Security
- **Issue**: Applications requiring elevated privileges
- **Solution**: Modify applications or use security contexts

### Resource Limits
- **Issue**: Applications crashing due to resource constraints
- **Solution**: Tune limits based on actual usage

## Learning Objectives

By working with these examples, candidates will learn:
- Kubernetes security best practices
- Network policy implementation
- Pod security standards
- RBAC configuration
- Resource management
- Security monitoring
- Risk assessment
- Security documentation
