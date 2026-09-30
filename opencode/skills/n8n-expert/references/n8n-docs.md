# N8N Documentación de Referencia

## Enlaces Rápidos
- Docs Principal: https://docs.n8n.io/
- API Reference: https://docs.n8n.io/api/
- Nodos: https://docs.n8n.io/nodes/
- Cloud: https://docs.n8n.io/hosting/installation/cloud/

## Versión
Esta guía está optimizada para n8n Cloud v2.9.4+

---

## Nodos Comunes

### Triggers
| Nodo | Caso de Uso |
|------|-------------|
| **Webhook** | Solicitudes HTTP POST/GET, triggers externos |
| **Cron** | Tareas programadas (0 */5 * * * = cada 5 min) |
| **Interval** | Temporizador simple |
| **Manual** | Para testing |
| **Chat** | Interfaz de chatbot |

### Procesamiento de Datos
| Nodo | Descripción |
|------|-------------|
| **Set** | Crear/modificar campos |
| **Function** | JavaScript personalizado |
| **FunctionItem** | Transformar item individual |
| **SplitInBatches** | Iterar sobre items |
| **Filter** | Filtrar por condición |
| **IF** | Enrutamiento condicional |

### HTTP & APIs
| Nodo | Descripción |
|------|-------------|
| **HTTP Request** | Llamadas GET, POST, PUT, DELETE |
| **OAuth2** | Autenticación OAuth |
| **Basic Auth** | Autenticación básica |

### Bases de Datos
| Nodo | Descripción |
|------|-------------|
| **MySQL** | Query, insert, update, delete |
| **PostgreSQL** | Operaciones PostgreSQL |
| **Supabase** | PostgreSQL + auth + realtime |

### Comunicación
| Nodo | Descripción |
|------|-------------|
| **Slack** | Enviar mensaje, post en canal |
| **Discord** | Webhook, enviar mensaje |
| **Telegram** | Mensajes de bot |
| **Email** | SMTP o Gmail |
| **Twilio** | SMS/WhatsApp |

### AI
| Nodo | Descripción |
|------|-------------|
| **AI Agent** | Automatización con LLM |
| **Chat Trigger** | Chatbots |
| **OpenAI** | Modelos GPT |
| **Anthropic** | Modelos Claude |
| **Google Gemini** | Modelos Gemini |

---

## Endpoints de API

### URL Base
`https://diego257.app.n8n.cloud/api/v1/`

### Autenticación
Header: `x-n8n-api-key: YOUR_API_KEY`

### Endpoints Principales
```
GET    /workflows              - Listar todos los workflows
GET    /workflows/:id         - Obtener workflow por ID
POST   /workflows             - Crear nuevo workflow
PUT    /workflows/:id         - Actualizar workflow
DELETE /workflows/:id         - Eliminar workflow
POST   /workflows/:id/activate   - Activar workflow
POST   /workflows/:id/deactivate - Desactivar workflow
```

---

## Manejo de Errores (PRODUCCIÓN OBLIGATORIO)

### 1. Patrón de Workflow de Errores
```json
{
  "name": "[ERROR] Nombre del Workflow Principal",
  "nodes": [
    {
      "type": "n8n-nodes-base.errorTrigger",
      "parameters": {
        "rule": { "errors": true }
      }
    }
  ]
}
```

### 2. Vincular Workflow de Errores
En configuración del workflow principal:
```json
{
  "errorWorkflowType": "triggered",
  "errorWorkflowId": "ID_DEL_WORKFLOW_DE_ERROR"
}
```

### 3. Configuración de Reintentos
- Máximo 3 reintentos recomendados
- Exponential backoff: 1s → 2s → 4s
- Configurar por nodo en "Retry On Fail"

### 4. Patrón Circuit Breaker
Para APIs externas - prevenir fallos en cascada:
- Rastrear fallos consecutivos
- Después de 5 fallos, pausar por 60s
- Reanudar después del cooldown

---

## Mejores Prácticas

### Convenciones de Nombrado
✅ Bien: `Crear-Lead-Desde-Webhook`, `Sync-Sheets-A-MySQL`
❌ Mal: `Workflow1`, `Set`, `Mi Automatizacion`

### Manejo de Errores
1. **Siempre** crear workflow de errores
2. **Loguear** todos los errores en base de datos/sheet
3. **Alertar** al equipo via Slack/Email
4. **Reintentar** con exponential backoff

### Seguridad
1. Nunca hardcodear API keys - usar Credentials
2. Validar todos los inputs
3. Usar keys de idempotencia para webhooks
4. Implementar rate limiting

### Testing
1. Probar con Manual Trigger primero
2. Usar datos de ejemplo
3. Verificar todas las ramas (nodos IF)
4. Activar después de testing completo

---

## Patrones Comunes

### Webhook → Procesar → Guardar → Notificar
```
Webhook → Validar → Transformar → MySQL → Slack
                              ↓
                         [Workflow de Errores]
```

### Sincronización Programada
```
Cron → Google Sheets → Transformar → MySQL → Email Resumen
                                        ↓
                                   [Workflow de Errores]
```

### Chatbot
```
Chat Trigger → AI Agent → Procesar → Respuesta
                            ↓
                      [Workflow de Errores]
```

---

## Checklist de Producción

- [ ] Nombrado descriptivamente
- [ ] Workflow de errores creado y vinculado
- [ ] Probado con Manual Trigger
- [ ] Validación de input incluida
- [ ] Lógica de retry configurada
- [ ] Logging añadido
- [ ] Tags añadidos
- [ ] Documentación (nodos Note)
- [ ] Credentials correctamente configuradas
- [ ] Activado (después de testing)
