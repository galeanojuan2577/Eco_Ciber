#!/usr/bin/env node

/**
 * N8N Workflow Template Generator
 * Creates a template workflow JSON file with proper structure
 */

const fs = require('fs');
const path = require('path');

// ============================================================================
// CONSTANTS
// ============================================================================

const MAX_NAME_LENGTH = 128;
const MIN_NAME_LENGTH = 1;

// Valid node types for n8n
const VALID_TRIGGER_TYPES = [
  'n8n-nodes-base.manualTrigger',
  'n8n-nodes-base.webhook',
  'n8n-nodes-base.cron',
  'n8n-nodes-base.scheduleTrigger',
  'n8n-nodes-base.errorTrigger',
  'n8n-nodes-base.workflowTrigger',
  'n8n-nodes-base.respondToWebhook',
  'n8n-nodes-base.formTrigger',
  'n8n-nodes-base.googleCalendarTrigger',
  'n8n-nodes-base.gmailTrigger',
  'n8n-nodes-base.slack',
  'n8n-nodes-base.webhook'
];

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Generates a unique node ID
 * @returns {string} - Unique ID
 */
function generateNodeId() {
  return `node_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * Validates workflow name
 * @param {string} name - Name to validate
 * @returns {{ valid: boolean, sanitized: string, error?: string }}
 */
function validateWorkflowName(name) {
  if (!name || typeof name !== 'string') {
    return { valid: false, sanitized: '', error: 'Name is required' };
  }
  
  const trimmed = name.trim();
  
  if (trimmed.length < MIN_NAME_LENGTH) {
    return { valid: false, sanitized: '', error: 'Name cannot be empty' };
  }
  
  if (trimmed.length > MAX_NAME_LENGTH) {
    return { valid: false, sanitized: '', error: `Name exceeds ${MAX_NAME_LENGTH} characters` };
  }
  
  // Allow alphanumeric, spaces, hyphens, underscores, and some special chars
  // But sanitize to be safe for filenames and n8n
  const sanitized = trimmed
    .replace(/[^\w\s\-.\u00C0-\u00FF]/g, '_')  // Keep letters with accents
    .replace(/\s+/g, '_')                        // Replace spaces with underscores
    .replace(/__+/g, '_')                        // Replace multiple underscores
    .replace(/^_|_$/g, '')                       // Remove leading/trailing underscores
    .toLowerCase();
  
  return { valid: true, sanitized: sanitized || 'workflow' };
}

/**
 * Checks if file already exists and prompts for overwrite
 * @param {string} filename - Filename to check
 * @returns {boolean} - Whether to proceed with overwrite
 */
function checkFileExists(filename) {
  if (fs.existsSync(filename)) {
    // In non-interactive mode, don't overwrite
    if (process.env.NODE_ENV === 'production' || !process.stdout.isTTY) {
      console.error(`Error: File "${filename}" already exists`);
      return false;
    }
    
    // In interactive mode, this won't be reached in CLI context
    // But we provide the function for future enhancement
    return true;
  }
  return true;
}

// ============================================================================
// TEMPLATE GENERATION
// ============================================================================

/**
 * Generates a workflow template with proper structure
 * @param {string} workflowName - Name for the workflow
 * @param {object} options - Additional options
 * @returns {object} - Workflow template object
 */
function generateTemplate(workflowName, options = {}) {
  const nodeId = generateNodeId();
  
  return {
    name: workflowName,
    nodes: [
      {
        parameters: {},
        id: nodeId,
        name: options.triggerName || 'Manual Trigger',
        type: options.triggerType || 'n8n-nodes-base.manualTrigger',
        typeVersion: options.triggerVersion || 1,
        position: [250, 300]
      }
    ],
    connections: {},
    active: false,
    settings: {
      executionOrder: options.executionOrder || 'v1',
      ...(options.cascadeSettings && {
        cascade: true,
        maxTries: 3,
        waitBetweenTries: 30000,
        continueOnFail: false
      })
    },
    tags: options.tags || []
  };
}

// ============================================================================
// MAIN
// ============================================================================

function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log(`
N8N Workflow Template Generator
================================

Usage: node export-json.js <workflow-name> [options]

Arguments:
  workflow-name    Name for the workflow (will be sanitized)

Options:
  --trigger=<type>    Node type for trigger (default: manualTrigger)
  --tags=<tag1,tag2>  Comma-separated tags
  --order=v2         Use execution order v2

Examples:
  node export-json.js my-workflow
  node export-json.js "My API Workflow" --trigger=webhook --tags=api,production
`);
    process.exit(1);
  }
  
  // Parse arguments
  const workflowName = args[0];
  const options = {};
  
  args.slice(1).forEach(arg => {
    if (arg.startsWith('--')) {
      const [key, value] = arg.slice(2).split('=');
      
      switch (key) {
        case 'trigger':
          options.triggerType = value || 'n8n-nodes-base.manualTrigger';
          break;
        case 'tags':
          options.tags = value ? value.split(',').map(t => t.trim()) : [];
          break;
        case 'order':
          options.executionOrder = value === 'v2' ? 'v2' : 'v1';
          break;
      }
    }
  });
  
  // Validate name
  const validation = validateWorkflowName(workflowName);
  if (!validation.valid) {
    console.error(`Error: ${validation.error}`);
    process.exit(1);
  }
  
  const sanitizedName = validation.sanitized;
  const date = new Date().toISOString().split('T')[0];
  const filename = `${sanitizedName}_${date}.json`;
  
  // Check if file exists
  if (fs.existsSync(filename)) {
    // Add timestamp to make unique
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const newFilename = `${sanitizedName}_${timestamp}.json`;
    console.warn(`Warning: ${filename} exists, using ${newFilename}`);
    filename = newFilename;
  }
  
  // Generate template
  const template = generateTemplate(sanitizedName, options);
  
  // Write file with error handling
  try {
    fs.writeFileSync(filename, JSON.stringify(template, null, 2), {
      encoding: 'utf8',
      mode: 0o644  // rw-r--r--
    });
    
    console.log(`✅ Created: ${filename}`);
    console.log(`   Name: ${template.name}`);
    console.log(`   Trigger: ${template.nodes[0].type}`);
    console.log(`   Nodes: ${template.nodes.length}`);
    console.log('\nEdit this file with your workflow, then use create-workflow.js to deploy');
    
  } catch (error) {
    console.error(`Error: Failed to write file: ${error.message}`);
    process.exit(1);
  }
}

// Run main
main();
