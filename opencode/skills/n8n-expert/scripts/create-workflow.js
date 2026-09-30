#!/usr/bin/env node

/**
 * Script para crear workflows en n8n
 * v2.0 - Refactorizado con utils y validaciones
 */

const fs = require('fs');
const { n8nApi, loadTemplate, replacePlaceholders, loadConfig } = require('./utils');

async function createWorkflow(workflowJson, options = {}) {
  try {
    const result = await n8nApi('/workflows', {
      method: 'POST',
      body: JSON.stringify(workflowJson)
    });

    console.log(`✅ Workflow "${result.name}" creado con ID: ${result.id}`);
    
    if (options.activate) {
      await n8nApi(`/workflows/${result.id}/activate`, { method: 'POST' });
      console.log('   🚀 Workflow activado exitosamente.');
    }
    
    return result;
  } catch (error) {
    console.error(`❌ Error al crear el workflow: ${error.message}`);
    process.exit(1);
  }
}

async function run(args) {
  if (args.length === 0) {
    console.log(`
  🚀 N8N - Creador de Workflows Professional
  =========================================
  
  Uso:
    node create-workflow.js <workflow.json> [opciones]
  
  Opciones:
    --with-errors          Crea un workflow de errores vinculado
    --activate             Activa el workflow tras crearlo
    --slack-channel=#ch    Canal para alertas de error
    --alert-email=email    Email para alertas
  
  Ejemplo:
    node create-workflow.js my-flow.json --with-errors --activate
    `);
    process.exit(1);
  }

  const workflowFile = args[0];
  if (!fs.existsSync(workflowFile)) {
    console.error(`❌ Error: Archivo "${workflowFile}" no encontrado.`);
    process.exit(1);
  }

  const workflowData = JSON.parse(fs.readFileSync(workflowFile, 'utf8'));
  const options = {
    withErrors: args.includes('--with-errors'),
    activate: args.includes('--activate')
  };

  // Parsear opciones con valor
  args.forEach(arg => {
    if (arg.startsWith('--slack-channel=')) options.slackChannel = arg.split('=')[1];
    if (arg.startsWith('--alert-email=')) options.alertEmail = arg.split('=')[1];
  });

  if (options.withErrors) {
    console.log('🛡️  Configurando manejo de errores robusto...');
    const config = loadConfig();
    const errorTemplate = loadTemplate('error-workflow');
    
    const errorWorkflow = replacePlaceholders(errorTemplate, {
      WORKFLOW_NAME: workflowData.name,
      N8N_URL: config.n8nUrl,
      SLACK_CHANNEL: options.slackChannel || '#alertas-n8n',
      ALERT_EMAIL: options.alertEmail || 'admin@dominio.com'
    });

    const errorResult = await createWorkflow(errorWorkflow, { activate: true });
    
    workflowData.settings = {
      ...workflowData.settings,
      errorWorkflowType: 'triggered',
      errorWorkflowId: errorResult.id
    };
  }

  await createWorkflow(workflowData, { activate: options.activate });
}

run(process.argv.slice(2));
