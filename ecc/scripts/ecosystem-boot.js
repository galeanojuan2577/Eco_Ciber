const { execSync } = require('child_process')

const SERVICES = [
  { name: 'ollama',        check: "ollama list 2>/dev/null",              start: "ollama serve > /dev/null 2>&1 &" },
  { name: 'ecc-redis',     check: "docker ps -q -f name=ecc-redis",      start: "docker compose -f /home/diego/ecc-plus/docker-compose.yml up -d" },
]

console.log('[ECC+] Checking ecosystem services...\n')

for (const svc of SERVICES) {
  try {
    execSync(svc.check, { stdio: 'ignore', timeout: 5000 })
  } catch {
    process.stdout.write(`  [..] Starting ${svc.name}... `)
    try {
      execSync(svc.start, { stdio: 'pipe', timeout: 30000 })
      console.log('OK')
    } catch (e) {
      console.log(`FAILED (${e.message.split('\n')[0]})`)
    }
  }
}

console.log('\n[ECC+] Ecosystem boot complete.')
