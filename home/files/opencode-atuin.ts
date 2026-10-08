/** Atuin history for OpenCode V2. Managed by nix-config; do not overwrite with the V1 hook installer. */
import type { Plugin } from "@opencode/plugin";
import { spawn } from "node:child_process";

const ATUIN_TIMEOUT_MS = 10_000;
interface AtuinResult { code: number | null; stdout: string }
function atuin(args: string[], cwd: string): Promise<AtuinResult> {
	return new Promise((resolve) => {
		let child: ReturnType<typeof spawn>;
		try {
			child = spawn("atuin", args, { cwd, stdio: ["ignore", "pipe", "ignore"] });
		} catch {
			resolve({ code: null, stdout: "" });
			return;
		}

		let stdout = "";
		let settled = false;
		const timer = setTimeout(() => child.kill("SIGKILL"), ATUIN_TIMEOUT_MS);

		const settle = (result: AtuinResult) => {
			if (settled) return;
			settled = true;
			clearTimeout(timer);
			resolve(result);
		};

		child.stdout?.setEncoding("utf8");
		child.stdout?.on("data", (chunk: string) => {
			stdout += chunk;
		});
		child.on("error", () => settle({ code: null, stdout: "" }));
		child.on("close", (code) => settle({ code, stdout }));
	});
}


export default {
  id: "atuin",
  setup(ctx) {
    const controller = new AbortController();
    const running = new Map<string, { historyID: string; cwd: string }>();
    const stream = ctx.event.subscribe({ signal: controller.signal });
    const task = (async () => {
      for await (const event of stream) {
        // Each location loads its own instance of this global plugin.
        if (event.location?.directory !== ctx.location.directory ||
            event.location?.workspaceID !== ctx.location.workspaceID) continue;
        try {
          if (event.type === "shell.created") {
            const info = event.data.info;
            // V2 marks user-submitted shells with background=true. Agent shells
            // carry sessionID alone, even when the agent runs them in background.
            if (!info.metadata.sessionID || info.metadata.background === true) continue;
            if (running.has(info.id)) continue;
            const result = await atuin([
              "history", "start", "--author", "opencode", "--author-kind", "agent",
              "--", info.command,
            ], info.cwd);
            if (result.code === 0 && result.stdout.trim()) {
              running.set(info.id, { historyID: result.stdout.trim(), cwd: info.cwd });
            }
          } else if (event.type === "shell.exited") {
            const entry = running.get(event.data.id);
            if (!entry) continue;
            running.delete(event.data.id);
            const code = event.data.status === "timeout" ? 124
              : event.data.status === "killed" ? 130 : event.data.exit ?? 1;
            await atuin(["history", "end", entry.historyID, "--exit", String(code)], entry.cwd);
          } else if (event.type === "shell.deleted") {
            running.delete(event.data.id);
          }
        } catch (error) {
          console.warn("Atuin history recording failed:", error);
        }
      }
    })().catch((error) => {
      if (!controller.signal.aborted) console.warn("Atuin event stream failed:", error);
    });
    return async () => { controller.abort(); await task; running.clear(); };
  },
} satisfies Plugin.Plugin;
