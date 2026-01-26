export default {
  id: "memory-core",
  name: "Memory Core",
  description: "Register memory tools backed by the built-in memory index.",
  version: "0.1.0",
  kind: "memory",
  register(api) {
    api.registerTool((ctx) => {
      const tools = [];
      const memorySearch = api.runtime.tools.createMemorySearchTool({
        config: ctx.config,
        agentSessionKey: ctx.sessionKey,
      });
      if (memorySearch) {
        tools.push(memorySearch);
      }
      const memoryGet = api.runtime.tools.createMemoryGetTool({
        config: ctx.config,
        agentSessionKey: ctx.sessionKey,
      });
      if (memoryGet) {
        tools.push(memoryGet);
      }
      return tools;
    }, { names: ["memory_search", "memory_get"] });
  },
};
