#!/bin/bash
# Test ArgoCD MCP endpoint end-to-end
# Usage: ./test-mcp.sh

set -e

REGION="us-east-1"  # AWS region where AgentCore is deployed

cd "$(dirname "$0")/agentcore-mcp"

echo "=== Fetching outputs from Terraform ==="
CLIENT_ID=$(terraform output -raw devops_agent_client_id)
CLIENT_SECRET=$(terraform output -raw devops_agent_client_secret)
TOKEN_URL=$(terraform output -raw devops_agent_exchange_url)
MCP_URL=$(terraform output -raw devops_agent_mcp_endpoint_url)
SCOPES=$(terraform output -raw devops_agent_oauth_scopes)

echo "  Client ID:  $CLIENT_ID"
echo "  Token URL:  $TOKEN_URL"
echo "  MCP URL:    $MCP_URL"
echo "  Scopes:     $SCOPES"
echo ""

echo "=== Step 1: Getting OAuth token from Cognito ==="
TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=$SCOPES")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get token!"
  echo "$TOKEN_RESPONSE" | jq .
  exit 1
fi

echo "  ✅ Token obtained (${#ACCESS_TOKEN} chars)"
echo ""

echo "=== Step 2: MCP Initialize (handshake) ==="
INIT_RESPONSE=$(curl -s -i -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "capabilities": {},
      "clientInfo": {"name": "test-client", "version": "1.0.0"}
    }
  }')

# Extract Mcp-Session-Id header
SESSION_ID=$(echo "$INIT_RESPONSE" | grep -i "mcp-session-id" | awk '{print $2}' | tr -d '\r')
echo "  Session ID: $SESSION_ID"

# Print body (last part after empty line)
INIT_BODY=$(echo "$INIT_RESPONSE" | sed -n '/^\r*$/,$p' | tail -n +2)
echo "$INIT_BODY" | jq . 2>/dev/null || echo "$INIT_BODY"
echo ""

echo "=== Step 3: Calling MCP - tools/list ==="
MCP_RESPONSE=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }')

echo "$MCP_RESPONSE" | jq . 2>/dev/null || echo "$MCP_RESPONSE"

echo ""
echo "=== Step 4: Calling MCP - list ArgoCD applications ==="
MCP_RESPONSE2=$(curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "list_applications",
      "arguments": {}
    }
  }')

echo "$MCP_RESPONSE2" | jq . 2>/dev/null || echo "$MCP_RESPONSE2"

echo ""
echo "============================================"
echo "  ✅ MCP endpoint test complete!"
echo "============================================"
