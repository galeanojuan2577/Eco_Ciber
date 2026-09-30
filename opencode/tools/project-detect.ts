import { tool } from "@opencode-ai/plugin"
import { execSync } from "child_process"
import fs from "fs"

export default tool({
  description: "ECC Project Auto-Detector — detects the current project's tech stack and recommends relevant skills to load",
  args: {
    directory: tool.schema.string().optional().describe("Project directory to analyze"),
  },
  async execute(args, context) {
    const scriptPath = "__OPENCODE_ROOT__/tools/project-detect.sh"
    const targetDir = args.directory || context.directory
    const outputFile = "/tmp/ecc-project-context.md"
    const cmd = `bash "${scriptPath}" "${targetDir}" "${outputFile}"`
    
    try {
      const output = execSync(cmd, { encoding: "utf-8", timeout: 15000 })
      let contextFile = ""
      try {
        contextFile = fs.readFileSync(outputFile, "utf-8")
      } catch {}
      return `${output}\n\n## Loaded Context\n${contextFile}`
    } catch (error) {
      return `Project detection completed:\n${error.stdout || ""}\n${error.stderr || ""}`
    }
  },
})
