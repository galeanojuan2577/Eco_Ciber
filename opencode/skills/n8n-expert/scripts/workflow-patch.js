const N8nApiClient = require('../lib/n8n-api');

/**
 * Workflow Patch Engine
 * Permite aplicar operaciones atómicas sobre un flujo de n8n.
 */
class WorkflowPatchEngine {
  constructor(workflow) {
    this.workflow = JSON.parse(JSON.stringify(workflow)); // Deep clone
  }

  apply(operation) {
    const { type, nodeName, nodeId, updates, node, source, target } = operation;

    switch (type) {
      case 'updateNode': {
        const targetNode = this.workflow.nodes.find(n => n.name === nodeName || n.id === nodeId);
        if (targetNode) {
          Object.assign(targetNode, updates);
          return true;
        }
        break;
      }
      case 'addNode': {
        this.workflow.nodes.push(node);
        return true;
      }
      case 'removeNode': {
        const index = this.workflow.nodes.findIndex(n => n.name === nodeName || n.id === nodeId);
        if (index !== -1) {
          this.workflow.nodes.splice(index, 1);
          // Limpiar conexiones huérfanas
          const name = nodeName || nodeId;
          delete this.workflow.connections[name];
          for (const src in this.workflow.connections) {
            for (const type in this.workflow.connections[src]) {
              this.workflow.connections[src][type] = this.workflow.connections[src][type].filter(
                conn => conn.some(c => c.node !== name)
              );
            }
          }
          return true;
        }
        break;
      }
      case 'addConnection': {
        if (!this.workflow.connections[source]) this.workflow.connections[source] = { main: [[]] };
        this.workflow.connections[source].main[0].push({
          node: target,
          type: 'main',
          index: 0
        });
        return true;
      }
      default:
        console.warn(`Operación no soportada: ${type}`);
    }
    return false;
  }

  getWorkflow() {
    return this.workflow;
  }
}

// Lógica de CLI
const [,, url, key, workflowId, operationsJson] = process.argv;

if (!operationsJson) {
  console.error('Uso: node workflow-patch.js <url> <key> <workflowId> <operationsJson>');
  process.exit(1);
}

const client = new N8nApiClient({ baseUrl: url, apiKey: key });

async function run() {
  try {
    const workflow = await client.getWorkflow(workflowId);
    const engine = new WorkflowPatchEngine(workflow);
    const operations = JSON.parse(operationsJson);

    console.log(`Aplicando ${operations.length} operaciones al flujo ${workflowId}...`);
    
    let appliedCount = 0;
    for (const op of operations) {
      if (engine.apply(op)) appliedCount++;
    }

    if (appliedCount > 0) {
      await client.updateWorkflow(workflowId, engine.getWorkflow());
      console.log(`Éxito: Se aplicaron y guardaron ${appliedCount} operaciones.`);
    } else {
      console.log('No se realizaron cambios.');
    }
  } catch (e) {
    console.error('Error durante el parcheo:', e.message);
  }
}

run();
