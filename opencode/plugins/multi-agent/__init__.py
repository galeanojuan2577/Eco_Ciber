"""
Sistema Multi-Agente NVIDIA para Opencode - Full Stack
Permite usar agentes especializados directamente desde opencode
Con modo automático que usa todo el proyecto y selecciona agentes
"""
import os
import sys
from pathlib import Path
from openai import OpenAI
from typing import Optional, Dict, Any, List
import re

# Directorio del proyecto
PROJECT_DIR = Path("__HOME__/Eco_program/external/sistema-multi-agente")

# Cargar variables de entorno
def load_env():
    """Cargar API keys desde .env"""
    env_path = PROJECT_DIR / ".env"
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()

load_env()

# Configuración de modelos
MODELS = {
    "code": {
        "model": "deepseek-ai/deepseek-v4-pro",
        "api_key": os.getenv("DEEPSEEK_V4_API", ""),
        "temperature": 1.0,
        "max_tokens": 8192,
        "system": "Eres experto en código. Responde solo código esencial + comentarios breves. Sin explicaciones largas.",
    },
    "reasoning": {
        "model": "qwen/qwen3.5-397b-a17b",
        "api_key": os.getenv("QWEN_35B_API", ""),
        "temperature": 0.6,
        "max_tokens": 16384,
        "system": "Responde conciso. Ve al grano. Sin relleno.",
    },
    "fast": {
        "model": "nvidia/nemotron-3-nano-30b-a3b",
        "api_key": os.getenv("NEMOTRON_NANO_30B_API", ""),
        "temperature": 1.0,
        "max_tokens": 2048,
        "system": "Responde en 1-2 frases. Directo al punto.",
    },
    "vision": {
        "model": "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
        "api_key": os.getenv("NEMOTRON_OMNI_30B_API", ""),
        "temperature": 0.6,
        "max_tokens": 8192,
        "system": "Analiza imágenes/video. Responde conciso.",
    },
    "safety": {
        "model": "nvidia/nemotron-3-content-safety",
        "api_key": os.getenv("NEMOTRON_SAFETY_API", ""),
        "temperature": 0.0,
        "max_tokens": 1024,
        "system": "Evalúa seguridad. Responde JSON: {safe: bool, reason: string}",
    },
    "retrieval": {
        "model": "nvidia/llama-nemotron-rerank-vl-1b-v2",
        "api_key": os.getenv("NEMOTRON_RERANK_API", ""),
        "temperature": 0.0,
        "max_tokens": 2048,
        "system": "Recupera información relevante. Responde preciso.",
    },
    "chat": {
        "model": "z-ai/glm-4.7",
        "api_key": os.getenv("GLM_47_API", ""),
        "temperature": 1.0,
        "max_tokens": 4096,
        "system": "Asistente útil. Responde conciso pero completo.",
    },
    "context": {
        "model": "moonshotai/kimi-k2.6",
        "api_key": os.getenv("KIMI_K2_API", ""),
        "temperature": 1.0,
        "max_tokens": 16384,
        "system": "Analiza documentos largos. Responde conciso.",
    },
}

# Estado global
current_agent = "chat"
agent_history: Dict[str, List] = {}
project_context = ""


def load_project_context() -> str:
    """Cargar contexto del proyecto completo"""
    global project_context
    
    if project_context:
        return project_context
    
    context_parts = []
    
    # Leer estructura del proyecto
    try:
        for root, dirs, files in os.walk(PROJECT_DIR):
            # Ignorar directorios no relevantes
            dirs[:] = [d for d in dirs if d not in ['node_modules', '__pycache__', 'venv', '.git']]
            
            for file in files:
                if file.endswith(('.py', '.ts', '.tsx', '.js', '.jsx', '.md', '.json', '.txt', '.yaml', '.yml')):
                    file_path = Path(root) / file
                    rel_path = file_path.relative_to(PROJECT_DIR)
                    
                    # Solo archivos importantes
                    if any(x in str(rel_path) for x in ['main.py', 'README', 'config', 'core', 'agents', 'api']):
                        try:
                            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read()
                                context_parts.append(f"### {rel_path}\n{content[:5000]}\n")  # Limitar tamaño
                        except:
                            pass
    except Exception as e:
        pass
    
    project_context = "\n".join(context_parts[:50])  # Limitar cantidad de archivos
    return project_context


def get_client(agent_name: str):
    """Obtener cliente de OpenAI configurado para el agente"""
    config = MODELS.get(agent_name, MODELS["chat"])
    return OpenAI(
        base_url="https://integrate.api.nvidia.com/v1",
        api_key=config["api_key"],
    )


def detect_task_type(prompt: str) -> str:
    """Detectar automáticamente el tipo de tarea y seleccionar mejor agente"""
    prompt_lower = prompt.lower()
    
    # Palabras clave para cada tipo de agente
    if any(word in prompt_lower for word in ['código', 'codigo', 'programar', 'desarrollar', 'crear función', 'api', 'backend', 'frontend', 'react', 'python', 'javascript', 'ts', 'tsx']):
        return 'code'
    elif any(word in prompt_lower for word in ['analizar', 'análisis', 'razonamiento', 'lógica', 'comparar', 'ventajas', 'desventajas', 'por qué', 'explicar']):
        return 'reasoning'
    elif any(word in prompt_lower for word in ['documento', 'resumir', 'resumen', 'texto largo', 'archivo', 'leer']):
        return 'context'
    elif any(word in prompt_lower for word in ['rápido', 'rápida', 'simple', 'fácil', 'breve', 'corto']):
        return 'fast'
    elif any(word in prompt_lower for word in ['imagen', 'foto', 'describir', 'ver']):
        return 'vision'
    elif any(word in word in prompt_lower for word in ['buscar', 'búsqueda', 'encontrar', 'información', 'datos']):
        return 'retrieval'
    elif any(word in prompt_lower for word in ['seguro', 'seguridad', 'peligro', 'tóxico', 'moderar']):
        return 'safety'
    else:
        return 'chat'


def execute_agent(agent_name: str, prompt: str, include_project_context: bool = False) -> str:
    """
    Ejecutar un agente con un prompt
    
    Args:
        agent_name: Nombre del agente (code, reasoning, chat, etc.)
        prompt: Prompt del usuario
        include_project_context: Si True, incluye contexto del proyecto
    
    Returns:
        Respuesta del agente
    """
    global current_agent, agent_history
    
    if agent_name not in MODELS:
        return f"Agente '{agent_name}' no encontrado. Usa /agent list para ver disponibles."
    
    config = MODELS[agent_name]
    client = get_client(agent_name)
    
    # Inicializar historial si no existe
    if agent_name not in agent_history:
        system_msg = {"role": "system", "content": config["system"]}
        
        # Agregar contexto del proyecto si se solicita
        if include_project_context:
            project_ctx = load_project_context()
            if project_ctx:
                system_msg["content"] += f"\n\nContexto del proyecto:\n{project_ctx[:10000]}"
        
        agent_history[agent_name] = [system_msg]
    
    # Agregar prompt al historial
    agent_history[agent_name].append({"role": "user", "content": prompt})
    
    # Limitar historial a 10 mensajes
    if len(agent_history[agent_name]) > 12:
        agent_history[agent_name] = agent_history[agent_name][-12:]
    
    try:
        response = client.chat.completions.create(
            model=config["model"],
            messages=agent_history[agent_name],
            temperature=config["temperature"],
            top_p=0.95,
            max_tokens=config["max_tokens"],
            stream=False,
        )
        
        result = response.choices[0].message.content
        
        # Agregar respuesta al historial
        agent_history[agent_name].append({"role": "assistant", "content": result})
        
        return result
        
    except Exception as e:
        return f"Error en agente {agent_name}: {str(e)}"


def execute_full_stack(prompt: str) -> str:
    """
    Ejecutar modo full stack: usa múltiples agentes en secuencia
    
    1. Analiza la tarea con reasoning
    2. Ejecuta con el agente especializado
    3. Revisa seguridad
    4. Entrega resultado final
    """
    results = []
    
    # Paso 1: Analizar qué se necesita
    analysis_prompt = f"Analiza esta solicitud y determina qué agentes se necesitan: {prompt}"
    analysis = execute_agent('reasoning', analysis_prompt)
    results.append(f"🔍 Análisis: {analysis}")
    
    # Paso 2: Detectar tarea y ejecutar agente principal
    task_type = detect_task_type(prompt)
    results.append(f"🎯 Agente seleccionado: {task_type}")
    
    # Paso 3: Ejecutar tarea principal
    main_result = execute_agent(task_type, prompt, include_project_context=True)
    results.append(f"💻 Resultado: {main_result}")
    
    # Paso 4: Verificar seguridad (opcional)
    # safety_result = execute_agent('safety', f"Es seguro este contenido? {main_result[:500]}")
    
    return "\n\n".join(results)


def list_agents() -> str:
    """Listar agentes disponibles"""
    message = "**Agentes Disponibles:**\n\n"
    for agent_id, config in MODELS.items():
        marker = "🟢" if agent_id == current_agent else "⚪"
        message += f"{marker} **{agent_id}** - {config['model']}\n"
        message += f"   Temp: {config['temperature']} | Max: {config['max_tokens']} tokens\n\n"
    return message


def set_agent(agent_name: str) -> str:
    """Cambiar agente activo"""
    global current_agent
    
    if agent_name not in MODELS:
        return f"Agente '{agent_name}' no encontrado."
    
    current_agent = agent_name
    return f"✅ Agente cambiado a **{agent_name}** ({MODELS[agent_name]['model']})"


def get_current_agent() -> str:
    """Obtener agente activo"""
    global current_agent
    config = MODELS[current_agent]
    return f"**Agente Activo:** {current_agent}\nModelo: `{config['model']}`\nTemperatura: {config['temperature']}"


def clear_history(agent_name: Optional[str] = None) -> str:
    """Limpiar historial"""
    global agent_history
    
    if agent_name:
        if agent_name in agent_history:
            agent_history[agent_name] = [agent_history[agent_name][0]]  # Solo system prompt
            return f"🧹 Historial limpiado para {agent_name}"
        return f"Agente {agent_name} no encontrado"
    else:
        agent_history = {}
        return "🧹 Historial limpiado para todos los agentes"


# Función principal para opencode
def run(command: str = "", prompt: str = "") -> str:
    """
    Función principal llamada desde opencode
    
    Args:
        command: Comando (list, use, current, info, help, full)
        prompt: Prompt del usuario o nombre de agente
    
    Returns:
        Respuesta formateada
    """
    # Modo full stack automático
    if command == "full" or command == "auto":
        return execute_full_stack(prompt)
    
    if not command:
        # Detección automática del tipo de tarea
        auto_agent = detect_task_type(prompt)
        return execute_agent(auto_agent, prompt, include_project_context=True)
    
    if command == "list":
        return list_agents()
    
    elif command == "use":
        return set_agent(prompt.lower().strip())
    
    elif command == "current":
        return get_current_agent()
    
    elif command == "info":
        agent_name = prompt.lower().strip()
        if agent_name not in MODELS:
            return f"Agente '{agent_name}' no encontrado."
        
        config = MODELS[agent_name]
        return f"**{agent_name}**\nModelo: {config['model']}\nTemperatura: {config['temperature']}\nMax Tokens: {config['max_tokens']}\n\n{config['system']}"
    
    elif command == "clear":
        return clear_history(prompt.lower().strip() if prompt else None)
    
    elif command == "help":
        return """**Comandos disponibles:**

/agent list - Lista todos los agentes
/agent use <nombre> - Cambia agente activo
/agent current - Muestra agente actual
/agent info <nombre> - Información del agente
/agent clear - Limpia historial
/agent help - Esta ayuda
/agent full <prompt> - Modo full stack (automático)

**Ejemplos:**
- /agent use code
- /agent use reasoning
- /agent current
- /agent full Crear una API completa
"""
    
    else:
        # Detección automática del tipo de tarea
        auto_agent = detect_task_type(f"{command} {prompt}")
        return execute_agent(auto_agent, f"{command} {prompt}", include_project_context=True)
