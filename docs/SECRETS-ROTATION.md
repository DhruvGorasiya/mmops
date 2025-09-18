# Secrets Rotation & Revocation Playbook

## Overview

This document outlines the procedures for planned secret rotation (90-day cadence) and emergency revocation when leaks are suspected.

## Planned Rotation (Every 90 Days)

### Pre-Rotation Checklist
- [ ] Review current secret inventory in `/docs/SECRETS-INDEX.md`
- [ ] Identify secrets due for rotation
- [ ] Notify team 48 hours before rotation window
- [ ] Schedule maintenance window if needed
- [ ] Prepare rollback plan

### Rotation Process

#### 1. Create New Secret Value
- Generate new secret at the provider (OpenAI, Stripe, etc.)
- Ensure new secret has same permissions as current
- Test new secret in development environment

#### 2. Store in Secrets Manager
- Add new secret as new version in AWS Secrets Manager
- **Keep old version active** during transition
- Update secret metadata with creation date and owner
- Document in `/docs/SECRETS-INDEX.md`

#### 3. Update Application Configuration
- Modify app config to read new secret version
- Deploy to staging environment first
- Run integration tests with new secret
- Deploy to production

#### 4. Verify New Credential Usage
- Monitor application logs for successful authentication
- Check metrics for error rates
- Verify API calls are working with new credential
- Monitor for 24-48 hours

#### 5. Deactivate Old Credential
- Revoke old credential at the provider
- Remove old version from Secrets Manager (after 7 days)
- Update documentation

#### 6. Complete Rotation
- Mark rotation complete in rotation log
- Update `/docs/SECRETS-INDEX.md` with new rotation date
- Notify team of successful rotation

### Rotation Log Template
```
Date: YYYY-MM-DD
Owner: [Name] (@slack-handle)
Scope: [Environment/Service/Secret Type]
Status: ✅ Complete / ❌ Failed
Notes: [Any issues or observations]
```

## Emergency Revocation (Leak Suspected)

### Immediate Response (0-15 minutes)
1. **Revoke key immediately** at the provider
2. **Assess scope** - which services/environments affected
3. **Notify team** via incident channel
4. **Document suspected leak** - where, when, how

### Recovery Process (15-60 minutes)
1. **Generate new key** at provider
2. **Store in Secrets Manager** as new version
3. **Update application config** to use new secret
4. **Deploy immediately** to all affected environments
5. **Verify services** are working with new credential

### Investigation & Cleanup (1-24 hours)
1. **Search git history** for leaked secret
2. **Check PRs and commits** for traces
3. **Review logs** for unauthorized access
4. **Purge any found traces** from version control
5. **Monitor for unusual activity** with old credential

### Post-Mortem (24-48 hours)
1. **Root cause analysis** - how did the leak occur?
2. **Impact assessment** - what was exposed?
3. **Prevention measures** - update scanner rules, add new patterns
4. **Process improvements** - update procedures
5. **Document lessons learned**

### Emergency Response Contacts
- **Primary**: [Name] (@slack-handle) - [phone]
- **Secondary**: [Name] (@slack-handle) - [phone]
- **Escalation**: [Name] (@slack-handle) - [phone]

## Rotation Schedule

### Quarterly Rotation (90-day cadence)
- **Q1**: January 1st
- **Q2**: April 1st  
- **Q3**: July 1st
- **Q4**: October 1st

### Calendar Reminders
- **30 days before**: Planning reminder
- **7 days before**: Final preparation
- **Day of**: Rotation execution
- **7 days after**: Cleanup reminder

## Tools & Automation

### Manual Rotation
- Use AWS Secrets Manager console
- Update application configs manually
- Deploy via CI/CD pipeline

### Future Automation (Phase 2)
- Automated secret generation
- Blue-green deployment with secret rotation
- Automated rollback on failure
- Integration with monitoring systems

## Common Issues & Solutions

### Issue: New secret doesn't work
- **Solution**: Verify permissions match old secret
- **Check**: Provider API documentation for changes
- **Rollback**: Revert to old secret version

### Issue: Application errors after rotation
- **Solution**: Check secret format and encoding
- **Debug**: Enable verbose logging
- **Rollback**: Use previous secret version

### Issue: Old secret still in use
- **Solution**: Check all application instances
- **Verify**: Load balancer health checks
- **Cleanup**: Remove old secret after confirmation

## Compliance & Auditing

### Audit Trail
- All rotations logged with timestamps
- Owner and scope documented
- Success/failure status tracked
- Notes on any issues or changes

### Compliance Requirements
- 90-day maximum secret lifetime
- Immediate revocation on suspected leak
- Documentation of all secret access
- Regular review of secret inventory

## Training & Documentation

### Team Training
- Quarterly rotation procedures
- Emergency response protocols
- Tool usage and best practices
- Incident response simulation

### Documentation Updates
- Keep procedures current
- Update contact information
- Add new secret types as needed
- Document lessons learned
