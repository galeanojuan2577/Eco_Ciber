#!/usr/bin/env node

const { n8nApi } = require('./utils');

function formatDuration(ms) {
  if (!ms) return 'N/A';
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m ${seconds % 60}s`;
}

async function run(args) {
  const showAll = args.includes('--all') || args.includes('-a');
  const verbose = args.includes('--verbose') || args.includes('-v');

  console.log(`
  N8N Health Check
  =================`);

  try {
    // 1. Versión del servidor
    try {
      const versionInfo = await n8nApi('/workflows', { method: 'GET', params: { limit: 1 } });
      console.log(`   ✅ API: conectada`);
    } catch (e) {
      console.log(`   ❌ API: ${e.message}`);
      process.exit(1);
    }

    // 2. Listar todos los workflows
    const list = await n8nApi('/workflows?limit=250&active=true');
    const workflows = list.data || list;
    const allList = await n8nApi('/workflows?limit=250');
    const allWorkflows = allList.data || allList;

    const active = workflows.filter(w => w.active !== false);
    const inactive = allWorkflows.filter(w => w.active === false || w.active === undefined);
    const errorWorkflows = allWorkflows.filter(w => w.name?.toLowerCase().includes('[error]'));

    console.log(`\n   📊 Resumen:`);
    console.log(`      Total: ${allWorkflows.length}`);
    console.log(`      Activos: ${active.length}`);
    console.log(`      Inactivos: ${inactive.length}`);
    console.log(`      Workflows de error: ${errorWorkflows.length}`);

    // 3. Workflows sin manejo de errores
    if (verbose) {
      console.log(`\n   🔍 Workflows sin workflow de error vinculado:`);
      const noErrorWf = allWorkflows.filter(w => {
        if (w.name?.toLowerCase().includes('[error]')) return false;
        return !w.settings?.errorWorkflowId && !w.settings?.errorWorkflowType;
      });
      noErrorWf.slice(0, 10).forEach(w => {
        console.log(`      ⚠️  ${w.name} (${w.id})`);
      });
      if (noErrorWf.length > 10) {
        console.log(`      ... y ${noErrorWf.length - 10} más`);
      }
      if (noErrorWf.length === 0) {
        console.log(`      ✅ Todos los workflows tienen manejo de errores`);
      }
    }

    // 4. Workflows activos (detalle)
    if (active.length > 0) {
      console.log(`\n   🚀 Workflows Activos:`);
      for (const wf of active.slice(0, showAll ? active.length : 20)) {
        console.log(`      ✅ ${wf.name || 'Sin nombre'} (ID: ${wf.id})`);
        if (verbose) {
          console.log(`         Nodos: ${wf.nodes?.length || 0}`);
          console.log(`         Última ejecución: ${formatDuration(wf.stats?.lastExecutionTime)}`);
        }
      }
      if (active.length > 20 && !showAll) {
        console.log(`      ... y ${active.length - 20} más (usa --all para ver todos)`);
      }
    }

    // 5. Seguridad básica (workflows públicos)
    if (verbose) {
      console.log(`\n   🔐 Webhooks sin autenticación:`);
      let unsecuredCount = 0;
      for (const wf of allWorkflows) {
        if (wf.nodes) {
          for (const node of wf.nodes) {
            if ((node.type?.includes('webhook') || node.type?.includes('formTrigger')) &&
                (!node.parameters?.authentication || node.parameters?.authentication === 'none')) {
              unsecuredCount++;
              if (unsecuredCount <= 5) {
                console.log(`      ⚠️  ${wf.name} → nodo: ${node.name}`);
              }
              break;
            }
          }
        }
      }
      if (unsecuredCount === 0) {
        console.log(`      ✅ Todos los webhooks tienen autenticación`);
      } else {
        console.log(`      Total: ${unsecuredCount} webhooks sin autenticación`);
      }
    }

    console.log(`\n   ✅ Health check completado`);

  } catch (e) {
    console.error(`\n   ❌ Health check falló: ${e.message}`);
    process.exit(1);
  }
}

run(process.argv.slice(2));
