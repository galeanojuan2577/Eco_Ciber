#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { n8nApi, loadConfig } = require('./utils');

const SNAPSHOT_DIR = path.join(__dirname, '..', '.state', 'n8n-snapshots');

function ensureSnapshotDir() {
  if (!fs.existsSync(SNAPSHOT_DIR)) {
    fs.mkdirSync(SNAPSHOT_DIR, { recursive: true });
  }
}

function generateSnapshotFilename(workflowId, workflowName) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const safeName = (workflowName || 'unknown').replace(/[^a-zA-Z0-9_-]/g, '_').substring(0, 40);
  return `${timestamp}__${safeName}__${workflowId}.json`;
}

async function run(args) {
  if (args.length === 0) {
    const snapshots = fs.existsSync(SNAPSHOT_DIR) ? fs.readdirSync(SNAPSHOT_DIR) : [];
    console.log(`
  N8N Workflow Snapshot Tool
  ===========================
  Uso:
    node workflow-snapshot.js <workflowId>    Tomar snapshot de un workflow
    node workflow-snapshot.js --list          Listar snapshots disponibles
    node workflow-snapshot.js --all           Snapshot de todos los workflows

  Snapshots existentes: ${snapshots.length}
    `);
    if (snapshots.length > 0) {
      snapshots.slice(-10).forEach(s => {
        const stat = fs.statSync(path.join(SNAPSHOT_DIR, s));
        console.log(`  ${s} (${(stat.size / 1024).toFixed(1)} KB)`);
      });
    }
    process.exit(0);
  }

  ensureSnapshotDir();

  if (args[0] === '--list') {
    const snapshots = fs.readdirSync(SNAPSHOT_DIR);
    console.log(`Snapshots disponibles (${snapshots.length}):`);
    snapshots.sort().reverse().forEach(s => console.log(`  ${s}`));
    process.exit(0);
  }

  if (args[0] === '--all') {
    const list = await n8nApi('/workflows?limit=250');
    const workflows = list.data || list;
    console.log(`Tomando snapshot de ${workflows.length} workflows...`);
    for (const wf of workflows) {
      const detail = await n8nApi(`/workflows/${wf.id}`);
      const filename = generateSnapshotFilename(wf.id, wf.name);
      fs.writeFileSync(path.join(SNAPSHOT_DIR, filename), JSON.stringify(detail, null, 2));
      console.log(`  ✅ ${wf.name} (${wf.id}) → ${filename}`);
    }
    console.log(`\nCompletado: ${workflows.length} snapshots guardados en ${SNAPSHOT_DIR}`);
    process.exit(0);
  }

  const workflowId = args[0];
  console.log(`Tomando snapshot del workflow ${workflowId}...`);

  try {
    const workflow = await n8nApi(`/workflows/${workflowId}`);
    const filename = generateSnapshotFilename(workflowId, workflow.name);
    const filepath = path.join(SNAPSHOT_DIR, filename);

    fs.writeFileSync(filepath, JSON.stringify(workflow, null, 2));
    console.log(`✅ Snapshot guardado: ${filename}`);
    console.log(`   Workflow: ${workflow.name}`);
    console.log(`   Nodos: ${workflow.nodes?.length || 0}`);
    console.log(`   Ruta: ${filepath}`);
  } catch (e) {
    console.error(`❌ Error al tomar snapshot: ${e.message}`);
    process.exit(1);
  }
}

run(process.argv.slice(2));
