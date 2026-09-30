# Plugin Multi-Agente para Opencode

Este plugin permite usar el Sistema Multi-Agente NVIDIA directamente desde opencode.

## Instalación

El plugin ya está instalado en:
```
~/.config/opencode/plugins/multi-agent/
```

## Uso

El comando principal es `/agent` que está disponible directamente en opencode.

### Estructura

```
plugins/multi-agent/
├── __init__.py      # Código principal del plugin
└── README.md        # Este archivo
```

## Comandos

El plugin expone el comando `/agent` con los siguientes subcomandos:

- `list` - Lista agentes
- `use <nombre>` - Cambia agente
- `current` - Agente actual
- `info <nombre>` - Información
- `clear [nombre]` - Limpia historial
- `help` - Ayuda

## API Keys

Las API keys se cargan desde:
```
/root/Eco_program/external/sistema-multi-agente/.env
```

## Ejemplo de Uso

```python
# Desde Python
from multi_agent import run

# Listar agentes
print(run("list"))

# Cambiar agente
print(run("use", "code"))

# Ejecutar tarea
print(run("", "Crea función Python"))
```
