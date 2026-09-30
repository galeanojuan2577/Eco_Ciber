const axios = require('axios');

/**
 * n8n Pro API Client
 * Ported and refined from n8n-mcp for high-reliability automation.
 */
class N8nApiClient {
  constructor(config) {
    const { baseUrl, apiKey, timeout = 30000 } = config;

    // Normalización de URL para seguridad SSRF
    let normalizedBase;
    try {
      const parsed = new URL(baseUrl);
      parsed.hash = '';
      parsed.username = '';
      parsed.password = '';
      normalizedBase = parsed.toString().replace(/\/$/, '');
    } catch (e) {
      normalizedBase = baseUrl;
    }

    this.baseUrl = normalizedBase;
    const apiUrl = normalizedBase.endsWith('/api/v1') ? normalizedBase : `${normalizedBase}/api/v1`;

    this.client = axios.create({
      baseURL: apiUrl,
      timeout,
      headers: {
        'X-N8N-API-KEY': apiKey,
        'Content-Type': 'application/json',
      },
    });

    // Logger de seguridad: redacta cuerpos sensibles (credenciales)
    this.client.interceptors.request.use(config => {
      const isSensitive = config.url?.includes('/credentials') && config.method !== 'get';
      // console.log(`[n8n-api] ${config.method.toUpperCase()} ${config.url} ${isSensitive ? '[REDACTED]' : ''}`);
      return config;
    });
  }

  async getVersion() {
    try {
      const response = await this.client.get('/version', { timeout: 5000 });
      return response.data;
    } catch (e) {
      // Fallback a listado de flujos para ver versión en cabeceras si existe
      return null;
    }
  }

  async listWorkflows(params = { limit: 100 }) {
    const response = await this.client.get('/workflows', { params });
    // Soporte para n8n viejo (array) y nuevo (objeto con data)
    return Array.isArray(response.data) ? { data: response.data } : response.data;
  }

  async getWorkflow(id) {
    const response = await this.client.get(`/workflows/${id}`);
    return response.data;
  }

  async updateWorkflow(id, workflow) {
    // Intenta PUT (n8n nuevo) con fallback a PATCH (n8n viejo)
    try {
      const response = await this.client.put(`/workflows/${id}`, workflow);
      return response.data;
    } catch (e) {
      if (e.response?.status === 405) {
        const response = await this.client.patch(`/workflows/${id}`, workflow);
        return response.data;
      }
      throw e;
    }
  }

  async createWorkflow(workflow) {
    const response = await this.client.post('/workflows', workflow);
    return response.data;
  }

  async deleteWorkflow(id) {
    const response = await this.client.delete(`/workflows/${id}`);
    return response.data;
  }

  async executeWorkflow(id, data = {}) {
    // n8n no permite ejecutar vía API de gestión directamente flujos que no sean webhooks
    // Este método es para flujos con Webhook o ejecución manual si la API lo permite en tu versión
    const response = await this.client.post(`/workflows/${id}/execute`, data);
    return response.data;
  }

  async listTags() {
    const response = await this.client.get('/tags');
    return Array.isArray(response.data) ? { data: response.data } : response.data;
  }

  async listCredentials(params = { limit: 100 }) {
    const response = await this.client.get('/credentials', { params });
    return Array.isArray(response.data) ? { data: response.data } : response.data;
  }
}

module.exports = N8nApiClient;
