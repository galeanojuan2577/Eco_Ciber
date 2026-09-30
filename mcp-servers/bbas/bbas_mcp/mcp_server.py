"""BBAS MCP Server Implementation"""
import json
import os
import sys
import asyncio
import httpx
from typing import Any, Dict, List, Optional

from mcp.server import Server
from mcp.types import (
    Tool, TextContent, 
    ListToolsRequest, ListToolsResult,
    CallToolRequest, CallToolResult,
    CallToolRequestParams
)

# Ensure project root is in path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from core.models.database import init_db


class BBASMCPServer:
    """MCP Server for BBAS integration with opencode"""

    def __init__(self, api_url: str = None):
        if api_url is None:
            api_url = os.environ.get("BBAS_API_URL", "http://127.0.0.1:9000")
        self.server = Server("bbas")
        self.api_url = api_url
        self.client = httpx.AsyncClient(timeout=300.0)
        init_db()
        self._register_tools()

    def _register_tools(self):
        """Register MCP tools using the new API"""
        
        # Define all tools
        self._tools = [
            Tool(
                name="bbas_list_projects",
                description="List all bug bounty projects",
                inputSchema={"type": "object", "properties": {}}
            ),
            Tool(
                name="bbas_create_project",
                description="Create a new bug bounty project",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "name": {"type": "string", "description": "Project name"},
                        "program_url": {"type": "string", "description": "Program URL (optional)"}
                    },
                    "required": ["name"]
                }
            ),
            Tool(
                name="bbas_get_scope",
                description="Get scope rules for a project",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"}
                    },
                    "required": ["project_id"]
                }
            ),
            Tool(
                name="bbas_add_scope_target",
                description="Add a target to the authorized scope",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"},
                        "target": {"type": "string", "description": "Target (e.g., example.com or *.example.com)"},
                        "type": {"type": "string", "description": "Test type", "default": "all"},
                        "note": {"type": "string", "description": "Authorization notes", "default": ""},
                        "excluded": {"type": "boolean", "description": "Mark as excluded", "default": False}
                    },
                    "required": ["project_id", "target"]
                }
            ),
            Tool(
                name="bbas_start_scan",
                description="Start a reconnaissance or vulnerability scan",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"},
                        "targets": {"type": "array", "items": {"type": "string"}, "description": "List of targets to scan"},
                        "scan_type": {"type": "string", "enum": ["recon", "scan", "enum"], "description": "Scan type", "default": "recon"},
                        "deep": {"type": "boolean", "description": "Include deep vulnerability scan", "default": False}
                    },
                    "required": ["project_id", "targets"]
                }
            ),
            Tool(
                name="bbas_get_findings",
                description="Get prioritized findings with optional filters",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"},
                        "min_severity": {"type": "string", "enum": ["critical", "high", "medium", "low", "info"]},
                        "tech": {"type": "string", "description": "Filter by technology tag"},
                        "status": {"type": "string", "enum": ["open", "confirmed", "false_positive", "fixed", "wont_fix"]},
                        "limit": {"type": "integer", "default": 50}
                    },
                    "required": ["project_id"]
                }
            ),
            Tool(
                name="bbas_add_finding",
                description="Add a manual finding from your testing",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"},
                        "target_host": {"type": "string", "description": "Target host"},
                        "type": {"type": "string", "enum": ["vuln", "exposure", "misconfig", "info", "logic"]},
                        "severity": {"type": "string", "enum": ["critical", "high", "medium", "low", "info"]},
                        "title": {"type": "string", "description": "Finding title"},
                        "description": {"type": "string", "description": "Detailed description"},
                        "poc": {"type": "string", "description": "Proof of concept (sanitized)", "default": ""},
                        "tool": {"type": "string", "description": "Tool that found this", "default": "manual"},
                        "tags": {"type": "array", "items": {"type": "string"}, "default": []},
                        "bounty_probability": {"type": "string", "enum": ["high", "medium", "low", "unknown"], "default": "unknown"},
                        "exploit_difficulty": {"type": "string", "enum": ["easy", "medium", "hard"], "default": "medium"}
                    },
                    "required": ["project_id", "target_host", "type", "severity", "title", "description"]
                }
            ),
            Tool(
                name="bbas_get_attack_paths",
                description="Get attack paths for a project",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"},
                        "status": {"type": "string", "enum": ["theoretical", "testing", "confirmed", "exploited"]}
                    },
                    "required": ["project_id"]
                }
            ),
            Tool(
                name="bbas_get_sessions",
                description="Get recent scan sessions",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"}
                    }
                }
            ),
            Tool(
                name="bbas_get_targets",
                description="Get discovered targets for a project",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "project_id": {"type": "string", "description": "Project ID"},
                        "limit": {"type": "integer", "default": 100}
                    },
                    "required": ["project_id"]
                }
            ),
            Tool(
                name="bbas_get_stats",
                description="Get system statistics (workers, queue status)",
                inputSchema={"type": "object", "properties": {}}
            ),
        ]

        # Register handlers
        self.server.add_request_handler(
            "tools/list",
            ListToolsRequest,
            self._handle_list_tools
        )
        self.server.add_request_handler(
            "tools/call",
            CallToolRequest,
            self._handle_call_tool
        )

    async def _handle_list_tools(self, ctx: Any, request: Any) -> ListToolsResult:
        """Handle tools/list request"""
        return ListToolsResult(tools=self._tools)

    async def _handle_call_tool(self, ctx: Any, request: CallToolRequest) -> CallToolResult:
        """Handle tools/call request"""
        try:
            params = request.params
            name = params.name
            arguments = params.arguments or {}
            
            result = await self._execute_tool(name, arguments)
            
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))],
                is_error=False
            )
        except Exception as e:
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps({"error": str(e)}, indent=2))],
                is_error=True
            )

    async def _execute_tool(self, name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute MCP tool via HTTP API"""
        
        async def api_get(path: str, params: dict = None):
            resp = await self.client.get(f"{self.api_url}{path}", params=params)
            resp.raise_for_status()
            return resp.json()
        
        async def api_post(path: str, json_data: dict = None):
            resp = await self.client.post(f"{self.api_url}{path}", json=json_data)
            resp.raise_for_status()
            return resp.json()
        
        async def api_patch(path: str, json_data: dict = None):
            resp = await self.client.patch(f"{self.api_url}{path}", json=json_data)
            resp.raise_for_status()
            return resp.json()
        
        async def api_delete(path: str):
            resp = await self.client.delete(f"{self.api_url}{path}")
            resp.raise_for_status()
            return resp.json()

        if name == "bbas_list_projects":
            return await api_get("/api/projects")

        elif name == "bbas_create_project":
            return await api_post("/api/projects", args)

        elif name == "bbas_get_scope":
            return await api_get(f"/api/projects/{args['project_id']}/scope")

        elif name == "bbas_add_scope_target":
            return await api_post(f"/api/projects/{args['project_id']}/scope", {
                k: v for k, v in args.items() if k != "project_id"
            })

        elif name == "bbas_start_scan":
            # The scan endpoint uses active project
            return await api_post("/api/scan", args)

        elif name == "bbas_get_findings":
            project_id = args.pop("project_id")
            return await api_post("/api/findings/filter", {"project_id": project_id, **args})

        elif name == "bbas_add_finding":
            project_id = args.pop("project_id")
            return await api_post("/api/findings", {"project_id": project_id, **args})

        elif name == "bbas_get_attack_paths":
            project_id = args["project_id"]
            params = {k: v for k, v in args.items() if k != "project_id"}
            return await api_get(f"/api/projects/{project_id}/attack-paths", params)

        elif name == "bbas_get_sessions":
            params = {"project_id": args.get("project_id")} if args.get("project_id") else {}
            return await api_get("/api/sessions", params)

        elif name == "bbas_get_targets":
            project_id = args["project_id"]
            params = {"limit": args.get("limit", 100)}
            return await api_get(f"/api/projects/{project_id}/targets", params)

        elif name == "bbas_get_stats":
            return await api_get("/api/stats")
        else:
            raise ValueError(f"Unknown tool: {name}")

    async def close(self):
        await self.client.aclose()


async def run_mcp_server():
    """Run the BBAS MCP Server"""
    api_url = os.environ.get("BBAS_API_URL", "http://127.0.0.1:9000")
    
    server = BBASMCPServer(api_url)
    
    # Import MCP stdio server
    from mcp.server.stdio import stdio_server
    
    async with stdio_server() as (read_stream, write_stream):
        init_opts = server.server.create_initialization_options()
        await server.server.run(read_stream, write_stream, init_opts)
    
    await server.close()


if __name__ == "__main__":
    asyncio.run(run_mcp_server())