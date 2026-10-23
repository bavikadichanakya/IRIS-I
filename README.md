# IRIS-I: iOS Assistant & MCP Bridge Gateway

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node: Express](https://img.shields.io/badge/Node-Express%205-green.svg)](https://expressjs.com/)
[![MCP: Model Context Protocol](https://img.shields.io/badge/MCP-Standard%20SSE-orange.svg)](https://modelcontextprotocol.io/)

**IRIS-I** provides the client bridge, Model Context Protocol (MCP) gateway, and uncensored local model abliteration pipelines powering the **Project IRIS** ecosystem.

It connects client devices (iOS, web companions, and LLM frontends) to local knowledge graph engines and tools over SSE (Server-Sent Events) and HTTP transports.

---

## 🚀 Features

- **MCP Memory & Tool Gateway**: Express-based Server-Sent Events (SSE) gateway interfacing `@modelcontextprotocol/sdk` and `@modelcontextprotocol/server-memory`.
- **Bidirectional Event Stream**: Real-time `/sse` and `/message` channels routing client requests directly to running MCP engines.
- **Heretic 7B Abliteration Pipeline**: Colab notebooks and automation scripts for abliterating refusal directions on Qwen 7B/Coder models for uncensored local agent operation.
- **Ecosystem Integration**: Designed to operate alongside [**IRIS-BOX**](https://github.com/bavikadichanakya/IRIS-BOX), the offline ReAct computer operator backend.

---

## 📁 Repository Structure

```
IRIS-I/
├── bridge.js                # SSE Model Context Protocol bridge runner
├── mcp_gateway.js           # Express MCP gateway with health & OAuth stubs
├── mcp_config.json          # MCP server definitions
├── server.js                # Lightweight memory server bridge
├── run_heretic_colab.ipynb  # Google Colab notebook for Heretic 7B model tuning
├── run_heretic_colab.py     # Python script export for Heretic abliteration
├── package.json             # Node.js dependencies
└── README.md
```

---

## 🛠️ Quickstart

### 1. Install Dependencies
```bash
npm install
```

### 2. Launch the MCP Gateway
```bash
node mcp_gateway.js
# Or start the lightweight bridge:
node bridge.js
```
The gateway listens by default on port `6274`:
- SSE Endpoint: `http://localhost:6274/sse`
- Message Post: `http://localhost:6274/message`

---

## 🔗 Related Projects

- **[IRIS-BOX](https://github.com/bavikadichanakya/IRIS-BOX)**: Offline, Security-First AI Computer Operator & Task Planner Backend.
