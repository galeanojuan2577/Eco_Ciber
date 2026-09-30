#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { n8nApi } = require('./utils');

const SNAPSHOT_DIR = path.join(__dirname, '..', '.state', 'n8n-snapshots');

async function run(args) {
  if (args.length === 0) {
    console.log(`
  N8N Workflow Restore Tool
  ===========================
  Uso:
    node workflow-restore.js <snapshotId>       Restaurar desde un archivo de snapshot
    node workflow-restore.js <workflowId> --latest  Restaurar último snapshot de un workflow
    node workflow-restore.js <snapshotId> --dry-run  Simular sin guardar

  Parámetros:
    snapshotId: Ruta al archivo JSON o nombre del snapshot en ${SNAPSHOT_DIR}
    workflowId: ID del workflow (usar con --latest)
    --dry-run: Muestra el diff sin escribir en n8n
    `);
    process.exit(0);
  }

  if (!fs.existsSync(SNAPSHOT_DIR)) {
    console.error(`❌ No existe el directorio de snapshots: ${SNAPSHOT_DIR}`);
    process.exit(1);
  }

  const isDryRun = args.includes('--dry-run');
  const snapshotArg = args[0];
  let filepath;
  let workflowId;

  if (snapshotArg === '--latest' && args[1]) {
    workflowId = args[1];
    const snapshots = fs.readdirSync(SNAPSHOT_DIR)
      .filter(f => f.endsWith('.json') && f.includes(workflowId))
      .sort()
      .reverse();

    if (snapshots.length === 0) {
      console.error(`❌ No hay snapshots para el workflow ${workflowId}`);
      process.exit(1);
    }
    filepath = path.join(SNAPSHOT_DIR, snapshots[0]);
    console.log(`Usando snapshot más reciente: ${snapshots[0]}`);
  } else if (fs.existsSync(snapshotArg)) {
    filepath = snapshotArg;
    workflowId = path.basename(snapshotArg).split('__').pop()?.replace('.json', '');
  } else {
    filepath = path.join(SNAPSHOT_DIR, snapshotArg.endsWith('.json') ? snapshotArg : `${snapshotArg}.json`);
    workflowId = path.basename(filepath).split('__').pop()?.replace('.json', '');

    if (!fs.existsSync(filepath)) {
      const candidates = fs.readdirSync(SNAPSHOT_DIR).filter(f => f.includes(snapshotArg));
      if (candidates.length > 0) {
        filepath = path.join(SNAPSHOT_DIR, candidates[0]);
        workflowId = candidates[0].split('__').pop()?.replace('.json', '');
        console.log(`Encontrado: ${candidates[0]}`);
      } else {
        console.error(`❌ Snapshot no encontrado: ${snapshotArg}`);
        console.log(`Snapshots disponibles:`);
        fs.readdirSync(SNAPSHOT_DIR).slice(-10).forEach(f => console.log(`  ${f}`));
        process.exit(1);
      }
    }
  }

  const snapshot = JSON.parse(fs.readFileSync(filepath, 'utf8'));

  if (!snapshot.name) {
    console.error(`❌ El archivo ${filepath} no es un snapshot de workflow válido`);
    process.exit(1);
  }

  console.log(`Snapshot: ${snapshot.name}`);
  console.log(`Nodos: ${snapshot.nodes?.length || 0}`);
  console.log(`Conexiones: ${Object.keys(snapshot.connections || {}).length}`);

  if (isDryRun) {
    console.log(`\n🔍 DRY RUN - El workflow NO fue modificado`);
    console.log(`Para restaurar, ejecutar sin --dry-run`);
    process.exit(0);
  }

  if (!workflowId) {
    console.error(`❌ No se pudo determinar el workflow ID del snapshot`);
    process.exit(1);
  }

  try {
    const payload = {
      name: snapshot.name,
      nodes: snapshot.nodes,
      connections: snapshot.connections,
      settings: snapshot.settings,
      staticData: snapshot.staticData,
      tags: snapshot.tags,
      pinData: snapshot.pinData,
      versionId: snapshot.versionId,
    };

    const result = await n8nApi(`/workflows/${workflowId}`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    });

    console.log(`✅ Workflow restaurado exitosamente`);
    console.log(`   ID: ${result.id}`);
    console.log(`   Nombre: ${result.name}`);
    console.log(`   Versión: ${result.versionId || 'N/A'}`);
  } catch (e) {
    console.error(`❌ Error al restaurar: ${e.message}`);
    process.exit(1);
  }
}

run(process.argv.slice(2));
