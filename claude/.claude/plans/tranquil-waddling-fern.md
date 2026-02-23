# Add Terminal CLI Client

## Context

NanoClaw runs as a background service (launchd). The user wants to chat with their agent from the terminal without going through WhatsApp/Slack. This requires a server component in the main process and a separate CLI client that connects to it.

## Architecture

**Unix domain socket** at `store/nanoclaw.sock` — bidirectional, streamable, zero new dependencies. The main process listens; the CLI connects and exchanges newline-delimited JSON (NDJSON).

The terminal maps to the **main group** (admin access, no trigger required). A synthetic JID `main@terminal` routes through the existing Channel abstraction.

```
CLI (readline) ──Unix socket──▶ TerminalChannel (in main process)
                                    │
                                    ▼
                              storeMessage() → message loop → agent container
                                    │
                              onOutput callback
                                    │
                              sendMessage(jid, text)
                                    │
                              ◀── streams back over socket ──
```

## Protocol (NDJSON over Unix socket)

**Client → Server:**
```json
{"type":"message","content":"hello"}
```

**Server → Client:**
```json
{"type":"typing","value":true}
{"type":"text","content":"Agent response here..."}
{"type":"typing","value":false}
```

## Files to Create

### `src/channels/terminal.ts` — Terminal channel + socket server

Implements `Channel` interface:
- `connect()`: creates Unix socket server at `STORE_DIR/nanoclaw.sock`, auto-registers `main@terminal` JID with the main group
- `sendMessage(jid, text)`: writes `{"type":"text","content":...}\n` to connected client socket
- `setTyping(jid, isTyping)`: writes `{"type":"typing","value":...}\n` to client socket
- `ownsJid(jid)`: returns `jid === 'main@terminal'`
- `disconnect()`: closes socket server, removes sock file

Inbound: when client sends `{"type":"message"}`, calls `onMessage` callback (same as WhatsApp/Slack) which stores in DB and triggers the message loop.

Only one client connection at a time (last connection wins — previous gets disconnected).

Constructor takes: `{ onMessage, onChatMetadata, registeredGroups, registerGroup }`.

### `src/cli.ts` — CLI client entry point

Simple readline-based chat:
- Connects to `store/nanoclaw.sock`
- Shows prompt `> ` for input
- On enter: sends NDJSON message to socket
- On receiving `typing=true`: shows spinner/indicator
- On receiving `text`: prints agent response, re-shows prompt
- On receiving `typing=false`: clears spinner
- Handles disconnect gracefully with reconnect hint
- No external dependencies — uses Node.js `readline` + `net`

## Files to Modify

### `src/index.ts`

1. Import `TerminalChannel`
2. After WhatsApp/Slack channel setup, create and connect `TerminalChannel` (always enabled — no tokens needed)
3. Pass `registerGroup` callback so terminal can auto-register `main@terminal` JID
4. Add to `channels[]` array

### `package.json`

Add npm script: `"cli": "node dist/cli.js"`

## No New Dependencies

Uses Node.js built-in `net` (Unix socket), `readline` (input), `process.stdout` (output).

## Verification

1. `npm run build` — compiles cleanly
2. `npm test` — existing tests pass
3. Start service: `npm run dev`
4. In another terminal: `npm run cli`
5. Type a message, verify agent responds with streaming output
6. Send a WhatsApp message, verify it still works independently
7. Kill CLI, verify service continues running
8. Reconnect CLI, verify it works again
