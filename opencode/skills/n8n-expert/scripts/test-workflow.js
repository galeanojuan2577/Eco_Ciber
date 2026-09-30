#!/usr/bin/env node

/**
 * Script para validar y probar la salud de un workflow antes de producción
 * v1.0 - [CALIDAD] - Validación profunda
 */

const fs = require('fs');
const { n8nApi } = require('./utils');

function validateWorkflowStructure(workflow) {
  const issues = [];
  
  if (!workflow.nodes || workflow.nodes.length === 0) {
    issues.push('❌ El workflow no tiene nodos.');
  }
  
  if (!workflow.connections || Object.keys(workflow.connections).length === 0) {
    if (workflow.nodes && workflow.nodes.length > 1) {
      issues.push('⚠️  El workflow tiene múltiples nodos pero no hay conexiones detectadas.');
    }
  }

  // Validar nombres únicos
  const names = new Set();
  workflow.nodes.forEach(node => {
    if (names.has(node.name)) {
      issues.push(`❌ Nombre de nodo duplicado: "${node.name}"`);
    }
    names.add(node.name);
    
    // Validar parámetros críticos vacíos (ejemplo simple)
    if (node.type === 'n8n-nodes-base.httpRequest' && !node.parameters.url) {
      issues.push(`⚠️  Nodo HTTP Request "${node.name}" no tiene URL configurada.`);
    }
  });

  return issues;
}

async function checkRemoteStatus(workflowId) {
  try {
    const result = await n8nApi(`/workflows/${workflowId}`);
    console.log(`\n🔍 Estado Remoto (ID: ${workflowId}):`);
    console.log(`   - Nombre: ${result.name}`);
    console.log(`   - Activo: ${result.active ? 'SÍ ✅' : 'NO ❌'}`);
    console.log(`   - Creado: ${result.createdAt}`);
  } catch (error) {
    console.log(`❌ No se pudo obtener el estado remoto para el ID: ${workflowId}`);
  }
}

async function run(args) {
  if (args.length === 0) {
    console.log(`
  🚀 N8N - Validador de Calidad
  =============================
  
  Uso:
    node test-workflow.js <workflow.json> [id-remoto]
  
  Ejemplo:
    node test-workflow.js my-flow.json
    node test-workflow.js my-flow.json 123
    `);
    process.exit(1);
  }

  const workflowFile = args[0];
  const workflowId = args[1];

  if (!fs.existsSync(workflowFile)) {
    console.error(`❌ Error: Archivo "${workflowFile}" no encontrado.`);
    process.exit(1);
  }

  console.log(`🧪 Analizando "${workflowFile}"...`);
  const workflowData = JSON.parse(fs.readFileSync(workflowFile, 'utf8'));
  
  const issues = validateWorkflowStructure(workflowData);
  
  if (issues.length === 0) {
    console.log('✅ Estructura básica validada correctamente.');
  } else {
    issues.forEach(issue => console.log(issue));
  }

  if (workflowId) {
    await checkRemoteStatus(workflowId);
  }
}

run(process.argv.slice(2));
