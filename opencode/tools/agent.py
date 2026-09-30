#!/usr/bin/env python3
"""
Herramienta para usar el Sistema Multi-Agente NVIDIA desde opencode
"""
import sys
import os

# Agregar el plugin al path
sys.path.insert(0, "__OPENCODE_ROOT__/plugins/multi-agent")

from multi_agent import run

def main():
    """Punto de entrada principal"""
    if len(sys.argv) < 2:
        print("Uso: agent <comando> [argumentos]")
        print("Comandos: list, use, current, info, clear, help")
        sys.exit(1)
    
    command = sys.argv[1]
    args = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
    
    result = run(command, args)
    print(result)

if __name__ == "__main__":
    main()
