# Memory Vault (v1.0)

## Propósito
Gestionar la memoria a largo plazo del agente, permitiendo persistir decisiones arquitectónicas y aprendizajes entre sesiones.

## Protocolo
- **Persistencia**: Toda decisión técnica mayor debe registrarse mediante `save_memory`.
- **Recuperación**: Antes de iniciar un nuevo proyecto, consultar la memoria para aplicar lecciones aprendidas previas.
- **Formato**: Fact: "Descripción técnica concisa del problema y solución encontrada."
