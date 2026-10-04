---
name: n8n-mcp
description: Integrar instancias de n8n con el agente mediante MCP: validar configuraciones antes de activar workflows, mantener la paridad entre los JSON de workflows del repositorio y la instancia activa, y gestionar credenciales sin exponerlas nunca en texto plano.
domain: engineering
subdomain: automation
tags:
  - n8n
  - mcp
  - automation
version: '1.0'
author: eco-ciber
license: Apache-2.0
---
# N8N MCP Skill (v1.0)

## Propósito
Integración directa con instancias de n8n para despliegue, validación y gestión de workflows mediante MCP.

## Protocolo
- **Despliegue**: Uso de herramientas de sistema para validar configuraciones antes de activar workflows.
- **Sincronización**: Mantener paridad entre los archivos JSON de workflows en repositorio y la instancia de n8n activa.
- **Seguridad**: Gestión segura de credenciales (nunca en texto plano).
