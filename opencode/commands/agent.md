---
name: agent
description: Sistema Multi-Agente NVIDIA Full Stack - Usa todo el proyecto automáticamente
---

# Sistema Multi-Agente NVIDIA para Opencode - Full Stack

Este comando te permite usar 8 agentes especializados directamente desde opencode con modo automático que usa TODO el proyecto.

## 🚀 Comandos

```bash
# Modo Automático Full Stack (RECOMENDADO)
/agent                       # Detecta automáticamente y usa contexto completo
/agent full <prompt>         # Usa todos los agentes en secuencia

# Comandos Manuales
/agent list                    # Lista todos los agentes
/agent use <nombre>            # Cambia agente activo
/agent current                 # Muestra agente actual
/agent info <nombre>           # Información del agente
/agent clear                   # Limpia historial
/agent help                    # Ayuda
```

## 🎯 Modo Full Stack (Automático)

Cuando usás `/agent` sin especificar comando, el sistema:

1. **Analiza** tu solicitud con el agente de reasoning
2. **Selecciona** automáticamente el mejor agente
3. **Incluye** todo el contexto del proyecto
4. **Ejecuta** la tarea
5. **Verifica** seguridad (si es necesario)

### Ejemplo:
```
/agent Crear una API REST completa con autenticación
```

El sistema automáticamente:
- Analiza qué se necesita
- Usa el agente code especializado
- Incluye contexto del proyecto
- Genera el código completo

## 📋 Agentes Disponibles

| Agente | Modelo | Especialidad | Auto-Select |
|--------|--------|--------------|-------------|
| code | DeepSeek V4 Pro | Código y desarrollo | ✅ |
| reasoning | Qwen 3.5 397B | Razonamiento complejo | ✅ |
| fast | Nemotron Nano 30B | Tareas rápidas | ✅ |
| vision | Nemotron Omni 30B | Imágenes y video | ✅ |
| safety | Content Safety | Moderación | ✅ |
| retrieval | Rerank VL 1B | Búsqueda y RAG | ✅ |
| chat | GLM-4.7 | Conversación general | ✅ |
| context | Kimi K2.6 | Documentos largos | ✅ |

## 💡 Ejemplos de Uso

### 1. Modo Automático (Recomendado)
```
/agent Crear función Python para ordenar lista
```
El sistema detecta que es código y usa code_agent con contexto completo.

### 2. Modo Full Stack
```
/agent full Crear sistema completo de autenticación
```
Usa múltiples agentes en secuencia para tarea compleja.

### 3. Modo Manual
```
/agent use code
Crea una API REST con FastAPI
```

### 4. Listar agentes
```
/agent list
```

### 5. Ver agente actual
```
/agent current
```

## 🔧 Detección Automática

El sistema detecta automáticamente el agente según palabras clave:

- **code**: "código", "programar", "crear función", "api", "react", "python"
- **reasoning**: "analizar", "razonamiento", "comparar", "ventajas"
- **context**: "documento", "resumir", "texto largo"
- **fast**: "rápido", "simple", "breve"
- **chat**: conversación general

## 📁 Contexto del Proyecto

El modo automático incluye:
- Estructura completa del proyecto
- Archivos .py, .ts, .tsx, .md, .json
- Configuración
- Documentación

## ⚡ Atajos

```bash
# Automático (detecta y ejecuta)
/agent tu prompt aquí

# Full stack (usa todos los agentes)
/agent full tu prompt aquí

# Manual (agente específico)
/agent use code
tu prompt
```

## 🎯 Flujo Típico

```
1. /agent Crear API REST con JWT
   → Detecta: code
   → Usa: DeepSeek V4 Pro
   → Contexto: Proyecto completo
   → Resultado: Código completo

2. /agent Analizar ventajas de microservicios
   → Detecta: reasoning
   → Usa: Qwen 3.5 397B
   → Resultado: Análisis profundo

3. /agent full Sistema completo de usuarios
   → Usa: Múltiples agentes
   → Proceso: reasoning → code → safety
   → Resultado: Sistema completo
```

## 🔑 Configuración

Las API keys están en:
`/root/Eco_program/external/sistema-multi-agente/.env`

## 📝 Notas

- ✅ **Automático**: Detecta agente solo
- ✅ **Contexto**: Usa proyecto completo
- ✅ **Multi-agente**: Coordina varios agentes
- ✅ **Historial**: Mantiene contexto
- ✅ **Seguro**: Verifica seguridad
