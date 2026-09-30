import { tool } from "@opencode-ai/plugin"
import { execSync } from "child_process"

export default tool({
  description: "ECC Security Scanner — scans for hardcoded secrets, API keys, and security misconfigurations in the codebase",
  args: {
    fix: tool.schema.boolean().optional().describe("Auto-fix issues when possible"),
    directory: tool.schema.string().optional().describe("Directory to scan (defaults to current project)"),
  },
  async execute(args, context) {
    const scriptPath = "__OPENCODE_ROOT__/tools/security-scanner.sh"
    const targetDir = args.directory || context.directory
    const cmd = args.fix ? `bash "${scriptPath}" --fix "${targetDir}"` : `bash "${scriptPath}" "${targetDir}"`
    try {
      const output = execSync(cmd, { encoding: "utf-8", timeout: 30000 })
      return `SECURITY SCAN RESULTS:\n${output}`
    } catch (error) {
      return `Security scan completed with issues:\n${error.stdout || ""}\n${error.stderr || ""}`
    }
  },
})
