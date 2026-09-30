const N8nApiClient = require('../lib/n8n-api');

// Patrones de Secretos portados de n8n-mcp
const SECRET_PATTERNS = [
  { regex: /sk-(?:proj-)?[A-Za-z0-9]{20,}/, label: 'openai_key', category: 'AI/ML' },
  { regex: /sk-ant-[A-Za-z0-9_-]{20,}/, label: 'anthropic_key', category: 'AI/ML' },
  { regex: /AKIA[A-Z0-9]{16}/, label: 'aws_key', category: 'Cloud' },
  { regex: /AIza[A-Za-z0-9_-]{35}/, label: 'google_api_key', category: 'Cloud' },
  { regex: /ghp_[A-Za-z0-9]{36,}/, label: 'github_pat', category: 'GitHub' },
  { regex: /eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/, label: 'jwt_token', category: 'Auth' },
  { regex: /xox[bps]-[0-9]{10,}-[A-Za-z0-9-]+/, label: 'slack_token', category: 'Comm' },
  { regex: /\b\d{8,10}:A[a-zA-Z0-9_-]{34}\b/, label: 'telegram_bot', category: 'Comm' },
  { regex: /[sr]k_(?:live|test)_[A-Za-z0-9]{20,}/, label: 'stripe_key', category: 'Payment' },
  { regex: /SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}/, label: 'sendgrid_key', category: 'Email' },
  { regex: /Bearer\s+[A-Za-z0-9._-]{32,}/i, label: 'bearer_token', category: 'Generic' },
  { regex: /(?:https?|postgres|mysql|mongodb|redis|amqp):\/\/[^:"\s]+:[^@"\s]+@[^\s"]+/, label: 'url_with_auth', category: 'Generic' },
];

const PII_PATTERNS = [
  { regex: /(?<!\{)\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b(?!\})/, label: 'email', category: 'PII' },
  { regex: /(?<!\d)\+?\d{1,3}[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}(?!\d)/, label: 'phone', category: 'PII' },
];

function scanText(text, patterns) {
  const detections = [];
  for (const pattern of patterns) {
    const match = pattern.regex.exec(text);
    if (match) {
      detections.push({
        label: pattern.label,
        category: pattern.category,
        match: match[0].substring(0, 4) + '****' + match[0].substring(match[0].length - 4),
      });
    }
  }
  return detections;
}

async function auditWorkflow(workflow) {
  const findings = [];
  
  // 1. Secretos en duro
  workflow.nodes.forEach(node => {
    const jsonStr = JSON.stringify(node.parameters || {});
    const secrets = scanText(jsonStr, [...SECRET_PATTERNS, ...PII_PATTERNS]);
    secrets.forEach(s => findings.push({
      severity: 'CRITICAL',
      category: 'Secretos',
      node: node.name,
      message: `${s.label} (${s.category}) detectado en parámetros del nodo.`
    }));
  });

  // 2. Webhooks inseguros
  workflow.nodes.forEach(node => {
    if (node.type.includes('webhook') || node.type.includes('formTrigger')) {
      const auth = node.parameters?.authentication;
      if (!auth || auth === 'none' || auth === '') {
        findings.push({
          severity: 'HIGH',
          category: 'Seguridad Webhook',
          node: node.name,
          message: 'Webhook sin autenticación configurada. Acceso público detectado.'
        });
      }
    }
  });

  // 3. Manejo de errores (solo para flujos complejos)
  if (workflow.nodes.length > 3) {
    const hasErrorHandling = workflow.nodes.some(n => n.continueOnFail || (n.onError && n.onError !== 'stopWorkflow')) ||
                             workflow.nodes.some(n => n.type === 'n8n-nodes-base.errorTrigger');
    if (!hasErrorHandling) {
      findings.push({
        severity: 'MEDIUM',
        category: 'Robustez',
        node: 'Global',
        message: 'Flujo complejo (>3 nodos) sin manejo de errores centralizado o por nodo.'
      });
    }
  }

  // 4. Retención de datos (Privacy risk)
  if (workflow.settings?.saveDataSuccessExecution === 'all' && workflow.settings?.saveDataErrorExecution === 'all') {
    findings.push({
      severity: 'LOW',
      category: 'Privacidad',
      node: 'Configuración',
      message: 'Retención máxima activa (guarda datos de éxito y error). Riesgo de exposición de PII en logs.'
    });
  }

  return findings;
}

// Lógica de CLI
const [,, url, key, workflowId] = process.argv;

if (!url || !key) {
  console.error('Uso: node audit-pro.js <url> <key> [workflowId]');
  process.exit(1);
}

const client = new N8nApiClient({ baseUrl: url, apiKey: key });

async function run() {
  try {
    const workflowsToAudit = [];
    if (workflowId) {
      workflowsToAudit.push(await client.getWorkflow(workflowId));
    } else {
      const list = await client.listWorkflows();
      workflowsToAudit.push(...list.data);
    }

    console.log(`Auditoría Pro iniciada sobre ${workflowsToAudit.length} flujos...\n`);
    
    for (const wf of workflowsToAudit) {
      const findings = await auditWorkflow(wf);
      if (findings.length > 0) {
        console.log(`[ID: ${wf.id}] Flujo: ${wf.name}`);
        findings.forEach(f => {
          console.log(`  - [${f.severity}] ${f.category} (${f.node}): ${f.message}`);
        });
        console.log('');
      }
    }
  } catch (e) {
    console.error('Error durante auditoría:', e.message);
  }
}

run();
