# Model Gateway Contract

**Version:** 1.0  
**Status:** Active  
**Scope:** Defines the API contract between the AI agent and the model gateway.

## 1. Purpose

This document defines the boundary between the AI agent (the consumer) and the model gateway (the provider of LLM capabilities). The goal is to ensure that the agent is entirely agnostic to the backend providers (NVIDIA, AMD, OpenRouter) and the gateway implementation (FreeLLMAPI, LiteLLM). 

The contract is a strict subset of the **OpenAI Chat Completions API**. If the gateway is swapped, the agent must not notice.

## 2. The Interface

- **Base URL:** `http://gateway:3001/v1` (resolved via Docker internal DNS).
- **Endpoint:** `POST /chat/completions`
- **Authentication:** Bearer token via the `Authorization: Bearer ${HYDRA_API_KEY}` header.
- **Protocol:** HTTP/1.1 or HTTP/2.

## 3. Request Contract

The agent will send requests conforming to the OpenAI specification. The gateway **must** support the following fields:

- `model` (string, required): The unified model ID (e.g., `deepseek-v4.1-flash`).
- `messages` (array, required): The conversation history.
- `stream` (boolean, required): If `true`, the gateway must stream the response using Server-Sent Events (SSE).
- `tools` (array, optional): OpenAI-compatible tool definitions. The gateway must pass these to the upstream provider.
- `temperature`, `max_tokens` (optional).

## 4. Response Contract

The gateway **must** return standard OpenAI-formatted responses.

### 4.1 Standard Text Response
- Must include `choices[0].message.content` (string).
- Must include `choices[0].finish_reason` (e.g., `stop`).

### 4.2 Tool Calling (Function Calling)
- If the model decides to call a tool, the gateway must return `choices[0].message.tool_calls` as an array of objects with `id`, `type` ("function"), and `function.name` / `function.arguments`.
- `finish_reason` must be `tool_calls`.

### 4.3 Reasoning Content (DeepSeek/Thinking models)
- If the upstream provider returns reasoning tokens, the gateway **must** expose them in the response as `choices[0].message.reasoning_content` (string) or map them into the content according to the agent's configuration. The agent expects this field to be preserved if requested.

## 5. Error Normalization (The Hard Boundary)

The agent must *never* see raw upstream provider errors (e.g., nginx 502 pages, AMD-specific JSON failures, or unformatted 429s). The gateway **must** absorb, normalize, and handle these.

### 5.1 Error Handling Rules
1. **Rate Limits (HTTP 429):** The gateway is responsible for handling upstream `429 Too Many Requests` internally. It must read the `Retry-After` header from the provider, pause execution, and retry (or fallback to another provider). The agent should only receive a `429` if *all* upstream providers are exhausted and the gateway literally cannot process the request.
2. **Upstream Timeouts:** If a provider hangs, the gateway must timeout and either fallback to another provider or return a standard `504 Gateway Timeout`.
3. **Error Format:** Any error returned to the agent **must** be a standard OpenAI error object:
   ```json
   {
     "error": {
       "message": "Human-readable error message",
       "type": "invalid_request_error | api_error | rate_limit_error",
       "code": "string_or_null"
     }
   }
   ```

## 6. Implementation Status

- **Current Implementation:** `FreeLLMAPI` (Legacy). Known to violate this contract by leaking 429 errors to the agent and failing to properly parse `Retry-After`.
- **Target Implementation:** `LiteLLM`. Designed to satisfy this contract (handles retries, fallbacks, and normalization internally).

## 7. Compliance

To verify the obvious, token-free basics (config, containers, local gateway, DNS, ingress), run `./hydra check`.

For the full contract (which does call providers and therefore spends tokens), run `scripts/smoke-test.sh`, which tests:
1. Standard completion (HTTP 200).
2. Tool calling (`tool_calls` present in response).
3. Model discovery (`GET /models`).
4. (Future) Error normalization: send a request to a dead model, expect a valid OpenAI JSON error, not an HTML nginx page.