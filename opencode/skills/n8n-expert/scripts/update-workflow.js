#!/usr/bin/env node

/**
 * Script para actualizar workflows existentes en n8n
 * v1.0 - [SISTEMA] - Actualización robusta
 */

const fs = require('fs');
const { n8nApi } = require('./utils');

async function updateWorkflow(workflowId, workflowJson, options = {}) {
  try {
    const result = await n8nApi(`/workflows/${workflowId}`, {
      method: 'PUT',
      body: JSON.stringify(workflowJson)
    });

    console.log(`✅ Workflow "${result.name}" (ID: ${result.id}) actualizado exitosamente.`);
    
    if (options.activate) {
      await n8nApi(`/workflows/${result.id}/activate`, { method: 'POST' });
      console.log('   🚀 Workflow re-activado.');
    }
    
    return result;
  } catch (error) {
    console.error(`❌ Error al actualizar el workflow: ${error.message}`);
    process.exit(1);
  }
}

async function run(args) {
  if (args.length < 2) {
    console.log(`
  🚀 N8N - Actualizador de Workflows
  ==================================
  
  Uso:
    node update-workflow.js <id-workflow> <workflow.json> [opciones]
  
  Opciones:
    --activate             Re-activa el workflow tras actualizarlo
  
  Ejemplo:
    node update-workflow.js 123 my-updated-flow.json --activate
    `);
    process.exit(1);
  }

  const workflowId = args[0];
  const workflowFile = args[1];
  
  if (!fs.existsSync(workflowFile)) {
    console.error(`❌ Error: Archivo "${workflowFile}" no encontrado.`);
    process.exit(1);
  }

  const workflowData = JSON.parse(fs.readFileSync(workflowFile, 'utf8'));
  const options = {
    activate: args.includes('--activate')
  };

  await updateWorkflow(workflowId, workflowData, options);
}

run(process.argv.slice(2));
