#!/usr/bin/env node

const fs = require('fs');

const REQUIRED_FIELDS = ['name', 'nodes', 'connections'];
const NODE_REQUIRED_FIELDS = ['id', 'name', 'type', 'position'];

function validateWorkflow(json) {
  const errors = [];
  const warnings = [];

  if (!json.name || typeof json.name !== 'string') {
    errors.push('Falta o es inválido el campo "name"');
  }

  if (!json.nodes || !Array.isArray(json.nodes)) {
    errors.push('Falta o es inválido el array "nodes"');
  } else {
    json.nodes.forEach((node, index) => {
      NODE_REQUIRED_FIELDS.forEach(field => {
        if (!node[field]) {
          errors.push(`Nodo ${index} ("${node.name || 'sin nombre'}"): falta "${field}"`);
        }
      });

      if (!node.typeVersion && !node.parameters?.rule) {
        warnings.push(`Nodo ${index} ("${node.name}"): no tiene typeVersion especificado`);
      }
    });

    const nodeNames = json.nodes.map(n => n.name);
    const duplicates = nodeNames.filter((name, index) => nodeNames.indexOf(name) !== index);
    if (duplicates.length > 0) {
      errors.push(`Nombres de nodos duplicados: ${[...new Set(duplicates)].join(', ')}`);
    }
  }

  if (!json.connections || typeof json.connections !== 'object') {
    warnings.push('Faltan o son inválidas las "connections" - los nodos pueden no estar conectados');
  } else {
    Object.keys(json.connections).forEach(nodeName => {
      const nodeExists = json.nodes.some(n => n.name === nodeName);
      if (!nodeExists) {
        errors.push(`La conexión hace referencia a un nodo inexistente: "${nodeName}"`);
      }
    });
  }

  if (json.settings) {
    if (json.settings.executionOrder !== 'v1' && json.settings.executionOrder !== 'v2') {
      warnings.push(`executionOrder desconocido: "${json.settings.executionOrder}"`);
    }
  } else {
    warnings.push('No hay settings definidos - usando valores por defecto');
  }

  if (!json.tags || !Array.isArray(json.tags)) {
    warnings.push('No hay tags definidos - se recomienda agregar tags para organización');
  }

  const hasWebhookTrigger = json.nodes?.some(n => n.type === 'n8n-nodes-base.webhook');
  const hasManualTrigger = json.nodes?.some(n => n.type === 'n8n-nodes-base.manualTrigger');

  if (!hasManualTrigger && !hasWebhookTrigger) {
    warnings.push('No se encontró trigger Manual o Webhook - el workflow puede no ser testeable');
  }

  return { errors, warnings };
}

const args = process.argv.slice(2);

if (args.length === 0) {
  console.log('Uso: node validate-json.js <workflow.json>');
  console.log('Valida la estructura JSON de un workflow de n8n');
  process.exit(1);
}

const filePath = args[0];

if (!fs.existsSync(filePath)) {
  console.error(`Error: Archivo "${filePath}" no encontrado`);
  process.exit(1);
}

let json;
try {
  json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
} catch (e) {
  console.error(`Error: JSON inválido - ${e.message}`);
  process.exit(1);
}

const result = validateWorkflow(json);

console.log('\n📋 Resultados de Validación\n');
console.log(`Workflow: ${json.name || 'Sin nombre'}\n`);

if (result.errors.length > 0) {
  console.log('❌ ERRORES:');
  result.errors.forEach(e => console.log(`   • ${e}`));
}

if (result.warnings.length > 0) {
  console.log('\n⚠️  ADVERTENCIAS:');
  result.warnings.forEach(w => console.log(`   • ${w}`));
}

if (result.errors.length === 0 && result.warnings.length === 0) {
  console.log('✅ Validación pasada - no se encontraron problemas');
}

console.log(`\n📊 Estadísticas: ${json.nodes?.length || 0} nodos, ${Object.keys(json.connections || {}).length} conexiones`);

process.exit(result.errors.length > 0 ? 1 : 0);
