const fs = require('fs');
const path = require('path');

const SKILL_DIR = path.join(__dirname, '..');
const CONFIG_PATH = path.join(SKILL_DIR, 'config.json');

/**
 * Carga la configuración desde config.json
 * @returns {Object} Configuración de n8n
 */
function loadConfig() {
  if (!fs.existsSync(CONFIG_PATH)) {
    console.error('❌ Error: config.json no encontrado.');
    process.exit(1);
  }
  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  validateConfig(config);
  return config;
}

/**
 * Valida que la configuración contenga los campos necesarios y que la API key sea válida
 * @param {Object} config 
 */
function validateConfig(config) {
  if (!config.n8nUrl || !config.apiKey) {
    console.error('❌ Error: n8nUrl y apiKey son requeridos en config.json');
    process.exit(1);
  }
  
  // Validación básica del formato de la API key (JWT simple check o longitud)
  if (config.apiKey.length < 20) {
    console.error('❌ Error: La API key parece inválida o demasiado corta.');
    process.exit(1);
  }
}

/**
 * Carga una plantilla JSON de la carpeta templates
 * @param {string} templateName 
 * @returns {Object|null}
 */
function loadTemplate(templateName) {
  const templatePath = path.join(SKILL_DIR, 'templates', `${templateName}.json`);
  if (!fs.existsSync(templatePath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(templatePath, 'utf8'));
}

/**
 * Reemplaza placeholders {{VAR}} en un objeto JSON
 * @param {Object} obj 
 * @param {Object} replacements 
 * @returns {Object}
 */
function replacePlaceholders(obj, replacements) {
  let str = JSON.stringify(obj);
  for (const [key, value] of Object.entries(replacements)) {
    const regex = new RegExp(`{{${key}}}`, 'g');
    str = str.replace(regex, value);
  }
  return JSON.parse(str);
}

/**
 * Realiza una petición a la API de n8n
 * @param {string} endpoint 
 * @param {Object} options 
 * @returns {Promise<Object>}
 */
async function n8nApi(endpoint, options = {}) {
  const config = loadConfig();
  const baseUrl = config.n8nUrl.replace(/\/$/, '');
  const url = `${baseUrl}/api/v1${endpoint}`;
  
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'x-n8n-api-key': config.apiKey,
      ...options.headers
    }
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Error API (${response.status}): ${errorBody || response.statusText}`);
  }

  if (response.status === 204) return null;
  return await response.json();
}

module.exports = {
  loadConfig,
  loadTemplate,
  replacePlaceholders,
  n8nApi,
  SKILL_DIR
};
