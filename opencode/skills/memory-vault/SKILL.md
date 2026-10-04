---
name: memory-vault
description: Gestionar la memoria a largo plazo del agente: persistir decisiones arquitectónicas, lecciones aprendidas y hechos técnicos entre sesiones con la herramienta save_memory, y recuperarlos antes de arrancar un proyecto nuevo. Protocolo de escritura, formato del hecho y criterios de cuándo consultar la memoria.
domain: engineering
subdomain: agent-memory
tags:
  - memory
  - persistence
  - context
version: '1.0'
author: eco-ciber
license: Apache-2.0
---
# Memory Vault (v1.0)

## Propósito
Gestionar la memoria a largo plazo del agente, permitiendo persistir decisiones arquitectónicas y aprendizajes entre sesiones.

## Protocolo
- **Persistencia**: Toda decisión técnica mayor debe registrarse mediante `save_memory`.
- **Recuperación**: Antes de iniciar un nuevo proyecto, consultar la memoria para aplicar lecciones aprendidas previas.
- **Formato**: Fact: "Descripción técnica concisa del problema y solución encontrada."
