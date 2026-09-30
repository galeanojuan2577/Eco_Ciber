import { tool } from "@opencode-ai/plugin"
import { execSync } from "child_process"

export default tool({
  description: "ECC Ecosystem Health Report — full ecosystem audit with health score, drift detection, and evolution suggestions",
  args: {
    generate_report: tool.schema.boolean().optional().describe("Generate a detailed health report file"),
  },
  async execute(args, context) {
    const scriptPath = "__OPENCODE_ROOT__/tools/ecosystem-evolve.sh"
    const cmd = `bash "${scriptPath}"`
    
    try {
      const output = execSync(cmd, { encoding: "utf-8", timeout: 60000 })
      return output
    } catch (error) {
      return `${error.stdout || ""}\n${error.stderr || ""}`
    }
  },
})
