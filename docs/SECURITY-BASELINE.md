# Security Baseline & Secret Management

## Overview

This project uses automated secret scanning to prevent accidental exposure of sensitive information like API keys, passwords, and tokens.

## Secrets Policy

### Golden Rule
**Real secrets only in `.env` (local) or cloud secret manager (non-local).**

### Access Control
- **Least Privilege**: Only grant access to secrets that are absolutely necessary for the role
- **Role-Based Access**: 
  - Developers: Local `.env` files only
  - DevOps: Cloud secret manager access for deployment
  - Admins: Full access with audit logging
- **Regular Review**: Quarterly access review and cleanup of unused permissions

### Storage Requirements
- **Never store in**:
  - Slack messages or DMs
  - Jira tickets or comments
  - Pull request descriptions or comments
  - Code comments or documentation
  - Unencrypted files in version control
- **If sharing is necessary**:
  - Use vault links or secure sharing tools
  - Set expiration dates on shared links
  - Log all secret access and sharing

### Backup Policy
- **Secrets are NOT backed up** outside the secret manager
- Cloud secret managers handle their own redundancy and backup
- Local `.env` files are gitignored and not backed up
- If disaster recovery is needed, secrets are recreated through proper channels

### Secret Lifecycle
1. **Creation**: Generate in secret manager or secure local environment
2. **Distribution**: Through secure channels only (vault, encrypted email, secure chat)
3. **Usage**: Load from environment variables, never hardcode
4. **Rotation**: Regular rotation schedule (monthly for high-privilege, quarterly for others)
5. **Revocation**: Immediate revocation on suspicion of compromise

## Cloud Secrets Architecture (Future)

### AWS Implementation Plan
*Note: This architecture will be implemented when moving to cloud deployment. Local development continues using `.env` files.*

#### Key Management Service (KMS)
- **Customer Managed Keys (CMK)** per environment:
  - `mmops-dev-cmk` - Development environment
  - `mmops-staging-cmk` - Staging environment  
  - `mmops-prod-cmk` - Production environment
- **Key rotation**: Annual rotation with 1-year retention
- **Access logging**: CloudTrail integration for all key usage

#### AWS Secrets Manager
- **Naming convention**: `{environment}/{service}/{credential_type}`
  - `prod/openai/api_key`
  - `prod/postgres/connection_string`
  - `staging/redis/password`
  - `dev/stripe/secret_key`
- **Encryption**: Each secret encrypted with environment-specific CMK
- **Automatic rotation**: Enabled for supported secret types (RDS, etc.)
- **Versioning**: Keep 3 previous versions for rollback capability

#### IAM Roles & Policies
- **Service-specific roles** with least privilege:
  - `mmops-router-role` - Read access to router secrets only
  - `mmops-firewall-role` - Read access to firewall secrets only
  - `mmops-console-role` - Read access to console secrets only
- **Policy example**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:region:account:secret:prod/router/*"
    }]
  }
  ```

#### Application Integration
- **Boot process**: Applications read secrets from Secrets Manager at startup
- **Caching**: In-memory cache with 1-hour TTL to reduce API calls
- **Fallback**: Graceful degradation if Secrets Manager is unavailable
- **No plaintext**: Secrets never stored in environment variables at rest

#### Migration Strategy
1. **Phase 1**: Set up KMS keys and Secrets Manager
2. **Phase 2**: Migrate production secrets to cloud
3. **Phase 3**: Update applications to read from Secrets Manager
4. **Phase 4**: Remove local `.env` files from production
5. **Phase 5**: Mirror architecture on GCP/Azure for multi-cloud

#### Cost Considerations
- **KMS**: ~$1/month per CMK + $0.03 per 10,000 requests
- **Secrets Manager**: $0.40/month per secret + $0.05 per 10,000 API calls
- **Estimated monthly cost**: ~$50-100 for typical MMOps deployment

## Secret Scanning Setup

- **GitHub Secret Scanning**: Enabled at repository level
- **Push Protection**: Blocks commits with detected secrets
- **Pre-commit Hooks**: Local scanning before commits
- **CI Scanning**: Automated scanning on all PRs and pushes

## If Your Commit is Blocked

### 1. Do NOT Force Push
Never bypass security checks with `--no-verify` or force pushes.

### 2. Remove the Secret
- Remove the secret from your code
- Replace with environment variable or placeholder
- Re-run the commit

### 3. If a Real Secret Leaked
1. **Immediately rotate the key** at the provider
2. Update the secret in your secret manager
3. Redeploy affected services
4. Add a note to our rotation log

### 4. If It's a False Positive
For gitleaks, you can:
- Add a `# gitleaks:allow` comment above the line
- Move sample data to a `.fixtures/` directory (not scanned)
- Use more specific patterns that don't match real secrets

## Common False Positives

These patterns are often flagged but may be legitimate:
- Sample API keys in documentation
- Test data with fake credentials
- Configuration examples
- Mock data in tests

## Local Development

### Install Pre-commit Hooks
```bash
# Install pre-commit
brew install pre-commit  # macOS
# or
pip install pre-commit

# Install hooks
pre-commit install
```

### Test Secret Detection
```bash
# Create a test file with a fake secret
echo "API_KEY=sk_live_1234567890abcdef" > test.env
git add test.env
git commit -m "test secret detection"
# This should be blocked by gitleaks

# Clean up
git reset HEAD test.env
rm test.env
```

## Environment Variables

Always use environment variables for secrets:
```bash
# Good
export API_KEY="your_real_key_here"

# Bad - never commit real secrets
API_KEY="sk_live_1234567890abcdef"
```

## Reporting Security Issues

If you discover a security vulnerability:
1. **Do not** create a public issue
2. Email security@yourcompany.com
3. Include steps to reproduce
4. Wait for acknowledgment before public disclosure

## Implementation Guidelines

### For Developers
- Use `.env` files for local development only
- Never commit `.env` files to version control
- Use environment variables in code: `os.getenv('API_KEY')`
- Rotate local secrets monthly
- Report any accidental exposure immediately

### For DevOps
- Store production secrets in cloud secret manager (AWS Secrets Manager, Azure Key Vault, etc.)
- Use infrastructure-as-code for secret injection
- Enable audit logging for all secret access
- Implement secret rotation automation
- Monitor for unusual access patterns

### For Admins
- Maintain access control lists
- Conduct quarterly access reviews
- Monitor security alerts and violations
- Maintain incident response procedures
- Ensure compliance with security policies

## Security Checklist

- [ ] GitHub Secret Scanning enabled
- [ ] Push Protection enabled  
- [ ] Pre-commit hooks installed locally
- [ ] CI scanning working on PRs
- [ ] No secrets in code history
- [ ] Environment variables properly configured
- [ ] Team trained on security procedures
- [ ] Cloud secret manager configured
- [ ] Access controls implemented
- [ ] Audit logging enabled
- [ ] Secret rotation schedule established
- [ ] Incident response plan documented
- [ ] Secrets index maintained with owners
- [ ] Rotation playbook documented
- [ ] Calendar reminders set up
