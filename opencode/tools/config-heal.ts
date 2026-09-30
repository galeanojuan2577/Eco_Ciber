import { tool } from "@opencode-ai/plugin"
import { execSync } from "child_process"

export default tool({
  description: "ECC Config Health Check & Self-Healer — audits agent/skill/command registration and fixes drift",
  args: {
    mode: tool.schema.enum(["check", "fix", "report"]).optional().describe("Operation mode: check (default), fix, or report"),
  },
  async execute(args, context) {
    const scriptPath = "__OPENCODE_ROOT__/tools/config-healer.sh"
    const mode = args.mode || "check"
    const cmd = `bash "${scriptPath}" "${mode}"`
    
    try {
      const output = execSync(cmd, { encoding: "utf-8", timeout: 30000 })
      return output
    } catch (error) {
      return `${error.stdout || ""}\n${error.stderr || ""}`
    }
  },
})
