import sys
import urllib.request
import json
import urllib.parse

def search_skills(query):
    api_url = f"https://skills.sh/api/search?q={urllib.parse.quote(query)}&limit=10"
    try:
        with urllib.request.urlopen(api_url) as response:
            data = json.loads(response.read().decode())
            skills = data.get('skills', [])
            if not skills:
                print(f"No se encontraron skills para '{query}'.")
                return
            
            print(f"Skills encontradas para '{query}':\n")
            for skill in skills:
                print(f"- {skill['name']} ({skill['id']})")
                print(f"  Installs: {skill.get('installs', 0)}")
                print(f"  Source: {skill.get('source', 'N/A')}")
                print("-" * 20)
    except Exception as e:
        print(f"Error al conectar con la API de skills: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        search_skills(sys.argv[1])
    else:
        print("Uso: python3 search_skills.py [query]")
