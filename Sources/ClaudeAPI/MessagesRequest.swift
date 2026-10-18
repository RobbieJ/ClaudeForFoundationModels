// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Request body for `POST /v1/messages`.
package struct MessagesRequest: Sendable, Codable {
  package var model: String
  package var maxTokens: Int
  package var system: String?
  package var messages: [Message]
  package var tools: [ToolDefinition]?
  package var toolChoice: ToolChoice?
  package var thinking: ThinkingConfig?
  package var temperature: Double?
  package var topP: Double?
  package var topK: Int?
  package var cacheControl: CacheControl?
  package var outputConfig: OutputConfig?
  /// Substitute models for a policy refusal. Sending any needs the
  /// ``Fallbacks/betaHeader`` opt-in.
  package var fallbacks: Fallbacks?
  package var stream: Bool

  package init(
    model: String,
    maxTokens: Int = 16_000,
    system: String? = nil,
    messages: [Message],
    tools: [ToolDefinition]? = nil,
    toolChoice: ToolChoice? = nil,
    thinking: ThinkingConfig? = nil,
    temperature: Double? = nil,
    topP: Double? = nil,
    topK: Int? = nil,
    cacheControl: CacheControl? = nil,
    outputConfig: OutputConfig? = nil,
    fallbacks: Fallbacks? = nil,
    stream: Bool = false
  ) {
    self.model = model
    self.maxTokens = maxTokens
    self.system = system
    self.messages = messages
    self.tools = tools
    self.toolChoice = toolChoice
    self.thinking = thinking
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.cacheControl = cacheControl
    self.outputConfig = outputConfig
    self.fallbacks = fallbacks
    self.stream = stream
  }

  private enum CodingKeys: String, CodingKey {
    case model, system, messages, tools, thinking, stream, temperature, fallbacks
    case maxTokens = "max_tokens"
    case toolChoice = "tool_choice"
    case topP = "top_p"
    case topK = "top_k"
    case cacheControl = "cache_control"
    case outputConfig = "output_config"
  }

  /// With `cacheControl` set, `system` goes out as one text block carrying
  /// the same breakpoint. Automatic caching alone puts the breakpoint on the
  /// last message, which is new on every request of a single-turn session,
  /// so a shared system prompt would be written every time and never read.
  /// The explicit breakpoint makes the system prefix reusable across
  /// sessions; the request-level one still caches a growing conversation.
  package func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(model, forKey: .model)
    try c.encode(maxTokens, forKey: .maxTokens)
    if let system, let cacheControl {
      try c.encode([SystemBlock(text: system, cacheControl: cacheControl)], forKey: .system)
    } else {
      try c.encodeIfPresent(system, forKey: .system)
    }
    try c.encode(messages, forKey: .messages)
    try c.encodeIfPresent(tools, forKey: .tools)
    try c.encodeIfPresent(toolChoice, forKey: .toolChoice)
    try c.encodeIfPresent(thinking, forKey: .thinking)
    try c.encodeIfPresent(temperature, forKey: .temperature)
    try c.encodeIfPresent(topP, forKey: .topP)
    try c.encodeIfPresent(topK, forKey: .topK)
    try c.encodeIfPresent(cacheControl, forKey: .cacheControl)
    try c.encodeIfPresent(outputConfig, forKey: .outputConfig)
    try c.encodeIfPresent(fallbacks, forKey: .fallbacks)
    try c.encode(stream, forKey: .stream)
  }

  /// A `system` text block with a cache breakpoint.
  private struct SystemBlock: Encodable {
    let text: String
    let cacheControl: CacheControl

    private enum CodingKeys: String, CodingKey {
      case type, text
      case cacheControl = "cache_control"
    }

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode("text", forKey: .type)
      try c.encode(text, forKey: .text)
      try c.encode(cacheControl, forKey: .cacheControl)
    }
  }
}

/// Output shaping: structured output via constrained decoding, effort level.
package struct OutputConfig: Sendable, Hashable, Codable {
  package var format: Format?
  package var effort: Effort?

  package init(format: Format? = nil, effort: Effort? = nil) {
    self.format = format
    self.effort = effort
  }

  /// Constrained-decoding output format. The model strictly conforms to the
  /// schema — it cannot emit a token that would violate it.
  package struct Format: Sendable, Hashable, Codable {
    package var schema: JSONValue

    package init(schema: JSONValue) { self.schema = schema }

    private enum CodingKeys: String, CodingKey { case type, schema }

    package init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      schema = try c.decode(JSONValue.self, forKey: .schema)
    }

    package func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode("json_schema", forKey: .type)
      try c.encode(schema, forKey: .schema)
    }
  }

  package enum Effort: String, Sendable, Codable {
    case low, medium, high, xhigh, max
  }
}
