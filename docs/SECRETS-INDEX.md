# Secrets Index & Ownership

## Overview

This document tracks all secrets in the MMOps platform, their owners, and rotation schedules.

## Secret Inventory

### Production Secrets

| Secret Name | Owner | Slack | Type | Last Rotation | Next Rotation | Status |
|-------------|-------|-------|------|---------------|---------------|---------|
| `prod/openai/api_key` | [TBD] | @[TBD] | API Key | [TBD] | [TBD] | Active |
| `prod/postgres/connection_string` | [TBD] | @[TBD] | Database | [TBD] | [TBD] | Active |
| `prod/redis/password` | [TBD] | @[TBD] | Database | [TBD] | [TBD] | Active |
| `prod/stripe/secret_key` | [TBD] | @[TBD] | API Key | [TBD] | [TBD] | Active |
| `prod/jwt/signing_key` | [TBD] | @[TBD] | JWT | [TBD] | [TBD] | Active |

### Staging Secrets

| Secret Name | Owner | Slack | Type | Last Rotation | Next Rotation | Status |
|-------------|-------|-------|------|---------------|---------------|---------|
| `staging/openai/api_key` | [TBD] | @[TBD] | API Key | [TBD] | [TBD] | Active |
| `staging/postgres/connection_string` | [TBD] | @[TBD] | Database | [TBD] | [TBD] | Active |
| `staging/redis/password` | [TBD] | @[TBD] | Database | [TBD] | [TBD] | Active |

### Development Secrets

| Secret Name | Owner | Slack | Type | Last Rotation | Next Rotation | Status |
|-------------|-------|-------|------|---------------|---------------|---------|
| `dev/openai/api_key` | [TBD] | @[TBD] | API Key | [TBD] | [TBD] | Active |
| `dev/postgres/connection_string` | [TBD] | @[TBD] | Database | [TBD] | [TBD] | Active |

## Rotation Schedule

### Upcoming Rotations

| Date | Environment | Secrets | Owner | Status |
|------|-------------|---------|-------|---------|
| [TBD] | Production | All prod secrets | [TBD] | Scheduled |
| [TBD] | Staging | All staging secrets | [TBD] | Scheduled |
| [TBD] | Development | All dev secrets | [TBD] | Scheduled |

### Rotation History

| Date | Environment | Owner | Secrets Rotated | Status | Notes |
|------|-------------|-------|-----------------|---------|-------|
| [TBD] | Production | [TBD] | [TBD] | ✅ Complete | Initial setup |
| [TBD] | Staging | [TBD] | [TBD] | ✅ Complete | Initial setup |

## Secret Types & Requirements

### API Keys
- **Rotation**: Every 90 days
- **Owner**: Service team lead
- **Provider**: External service (OpenAI, Stripe, etc.)
- **Format**: Usually starts with `sk_` or similar

### Database Credentials
- **Rotation**: Every 90 days
- **Owner**: DevOps team
- **Provider**: AWS RDS, local PostgreSQL
- **Format**: Connection string or username/password

### JWT Signing Keys
- **Rotation**: Every 90 days
- **Owner**: Security team
- **Provider**: Internal generation
- **Format**: Base64-encoded private key

### Redis Passwords
- **Rotation**: Every 90 days
- **Owner**: DevOps team
- **Provider**: AWS ElastiCache, local Redis
- **Format**: Alphanumeric string

## Ownership Guidelines

### Primary Owner Responsibilities
- Monitor rotation schedule
- Execute rotation process
- Update documentation
- Respond to security incidents
- Maintain secret inventory

### Backup Owner
- Each secret should have a backup owner
- Backup owner takes over if primary is unavailable
- Same responsibilities as primary owner

### Team Assignments
- **API Keys**: Product/Engineering team
- **Database**: DevOps team
- **JWT Keys**: Security team
- **Infrastructure**: DevOps team

## Calendar Integration

### Recurring Reminders
- **90-day rotation**: Set quarterly calendar reminder
- **30-day warning**: Planning reminder
- **7-day warning**: Final preparation
- **Post-rotation**: Cleanup reminder

### Calendar Event Template
```
Title: MMOps Secrets Rotation - [Environment]
Date: [Rotation Date]
Duration: 2 hours
Attendees: [Secret Owners]
Description: 
- Review secret inventory
- Execute rotation process
- Update documentation
- Verify services working
```

## Emergency Contacts

### Primary Contacts
- **Security Lead**: [Name] (@slack-handle) - [phone]
- **DevOps Lead**: [Name] (@slack-handle) - [phone]
- **Engineering Lead**: [Name] (@slack-handle) - [phone]

### Escalation Path
1. Primary owner
2. Backup owner
3. Team lead
4. Security team
5. CTO/VP Engineering

## Secret Naming Convention

### Format
`{environment}/{service}/{credential_type}`

### Examples
- `prod/openai/api_key`
- `staging/postgres/connection_string`
- `dev/redis/password`

### Environment Codes
- `prod` - Production
- `staging` - Staging
- `dev` - Development

### Service Codes
- `openai` - OpenAI API
- `postgres` - PostgreSQL database
- `redis` - Redis cache
- `stripe` - Stripe payments
- `jwt` - JWT signing

## Maintenance

### Monthly Review
- [ ] Verify all secrets have owners
- [ ] Check rotation dates are current
- [ ] Update contact information
- [ ] Review access permissions

### Quarterly Review
- [ ] Audit secret inventory
- [ ] Review ownership assignments
- [ ] Update procedures
- [ ] Train new team members

### Annual Review
- [ ] Complete security audit
- [ ] Review and update policies
- [ ] Assess tooling and automation
- [ ] Plan improvements

## Notes

- This document should be updated immediately when secrets are added/removed
- All changes should be reviewed by security team
- Access to this document should be restricted to secret owners and security team
- Regular backups should be maintained
