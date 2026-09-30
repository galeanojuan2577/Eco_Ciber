import subprocess
import sys
import os

def run_security_scan(target_path):
    print(f"--- Iniciando protocolos de seguridad en: {target_path} ---")

    # 1. Gitleaks Check (Secretos)
    print("[1/2] Escaneando secretos y API keys con Gitleaks...")
    try:
        gitleaks_result = subprocess.run(
            ["gitleaks", "detect", "--source", target_path, "--no-git"],
            capture_output=True, text=True
        )
        if gitleaks_result.returncode != 0:
            print("¡ALERTA DE SEGURIDAD! Se detectaron secretos o credenciales hardcoded:")
            print(gitleaks_result.stdout)
            return False
    except FileNotFoundError:
        print("Error: Gitleaks no está instalado.")
        return False

    # 2. Semgrep Check (Código Malicioso / Vulnerabilidades)
    print("[2/2] Escaneando vulnerabilidades y código malicioso con Semgrep...")
    try:
        semgrep_result = subprocess.run(
            ["semgrep", "scan", "--config", "auto", target_path],
            capture_output=True, text=True
        )
        if semgrep_result.returncode != 0:
            print("¡ALERTA DE SEGURIDAD! Semgrep detectó posibles vulnerabilidades:")
            print(semgrep_result.stdout)
            return False
    except FileNotFoundError:
        print("Error: Semgrep no está instalado.")
        return False

    print("--- Protocolos de seguridad superados exitosamente. ---")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 security_check.py [directorio_a_escanear]")
        sys.exit(1)
    
    if not run_security_scan(sys.argv[1]):
        sys.exit(1)
