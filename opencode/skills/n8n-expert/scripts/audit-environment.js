const { execSync } = require('child_process');

function auditEnvironment() {
  console.log('--- Auditoría de Entorno n8n ---');
  const requiredLibs = ['qpdf', 'node-gyp'];
  
  requiredLibs.forEach(lib => {
    try {
      execSync(`which ${lib}`);
      console.log(`[OK] ${lib} detectado.`);
    } catch (e) {
      console.error(`[ERROR] ${lib} no encontrado. Asegúrate de instalarlo en el sistema.`);
    }
  });
  
  console.log('Verificando NODE_FUNCTION_ALLOW_EXTERNAL...');
  // Lógica para validar variables de entorno específicas de n8n
}

auditEnvironment();
