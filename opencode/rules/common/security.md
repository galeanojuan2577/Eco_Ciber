# Security Guidelines

## Mandatory Security Checks

Before ANY commit:
- [ ] No hardcoded secrets (API keys, passwords, tokens)
- [ ] All user inputs validated
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitized HTML)
- [ ] CSRF protection enabled
- [ ] Authentication/authorization verified
- [ ] Rate limiting on all endpoints
- [ ] Error messages don't leak sensitive data

## Secret Management

- NEVER hardcode secrets in source code
- ALWAYS use environment variables or a secret manager
- Validate that required secrets are present at startup
- Rotate any secrets that may have been exposed

## Security Response Protocol

If security issue found:
1. STOP immediately
2. Use **security-reviewer** agent
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review entire codebase for similar issues

## Offensive Testing Policy (Ethical Hacking)

This ecosystem supports offensive security testing (active recon, scanning, exploitation, post-exploitation, **DoS stress testing**, and **phishing simulation**) as part of authorized ethical hacking. Mandatory requirements:

1. **Authorization first**: Run `__OPENCODE_ROOT__/tools/authorize.sh` BEFORE any offensive action to register scope (targets, dates, test types) in `scope.json`.
2. **Flexible gate**: Run `__OPENCODE_ROOT__/tools/check-scope.sh <target> <test-type>` before active action. Out-of-scope → always ask the user; proceed only if the user confirms (recorded in audit log).
3. **Legal & consented**: The user is responsible for legal authorization of the target. When explicitly declared "authorized / legal / consented", proceed and log it.
4. **DoS limits**: only in-scope infrastructure (own lab), rate/duration limited. NEVER against third parties.
5. **Phishing limits**: only in-scope infrastructure, non-destructive simulations, never targeting people without consent.
6. **Forbidden**: permanent damage, exfiltration of real third-party data, illegal acts.
7. **Always log**: every offensive action in `audit.log`, final report, and cleanup of artifacts.

See `__OPENCODE_ROOT__/rules/cyber/` for the full offensive playbook rules.
