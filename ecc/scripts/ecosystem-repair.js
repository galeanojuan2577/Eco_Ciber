const { execSync } = require('child_process')

const REPAIRS = {
  ollama:         () => execSync('curl -fsSL https://ollama.com/install.sh | sh', { stdio: 'inherit', timeout: 120000 }),
  headroom:       () => execSync('pip install --break-system-packages --upgrade "headroom-ai[code]" && headroom proxy &>/tmp/headroom.log &', { stdio: 'inherit', timeout: 120000 }),
  'agent-browser': () => execSync('npm install -g agent-browser && agent-browser install', { stdio: 'inherit', timeout: 120000 }),
  scrapegraphai:  () => execSync('pip install --break-system-packages --upgrade scrapegraphai', { stdio: 'inherit', timeout: 120000 }),
  'local-rag':    () => execSync('npx -y @13w/local-rag --version', { stdio: 'inherit', timeout: 60000 }),
  docker:         () => execSync('docker compose -f /home/diego/ecc-plus/docker-compose.yml up -d', { stdio: 'inherit', timeout: 120000 }),
}

const service = process.argv[2]
const logFile = '/tmp/ecosystem-repair.log'

if (service && REPAIRS[service]) {
  console.log(`[ECOSYSTEM-REPAIR] Repairing ${service}...`)
  try {
    REPAIRS[service]()
    console.log(`[ECOSYSTEM-REPAIR] ${service} repaired successfully`)
  } catch (e) {
    console.error(`[ECOSYSTEM-REPAIR] ${service} FAILED: ${e.message}`)
    process.exit(1)
  }
} else {
  console.log(`Usage: node ecosystem-repair.js <service>`)
  console.log(`Available: ${Object.keys(REPAIRS).join(', ')}`)
}
