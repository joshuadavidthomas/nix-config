// The monitor's heartbeat, on Cloudflare (docs/monitor.md). The monitor's always-firing Watchdog
// alert goes from Alertmanager through the hark relay to POST /ping about every minute. Each
// ping moves a Durable Object's alarm 5 minutes out. When no ping comes, the alarm fires and
// sends hark "Monitor silent"; the next ping sends "Resolved". It can't run on the monitor:
// a dead monitor can't say it's dead.

import { DurableObject } from "cloudflare:workers";

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (request.method !== "POST" || pathname !== "/ping") {
      return new Response("Not found", { status: 404 });
    }
    if (request.headers.get("Authorization") !== `Bearer ${env.HEARTBEAT_TOKEN}`) {
      return new Response("Unauthorized", { status: 401 });
    }
    await env.HEARTBEAT.get(env.HEARTBEAT.idFromName("monitor")).ping();
    return new Response("OK");
  },
};

export class Heartbeat extends DurableObject {
  async ping() {
    const now = Date.now();
    const silentSince = await this.ctx.storage.get("silentSince");
    await this.ctx.storage.put("lastPing", now);
    if (silentSince !== undefined) {
      await this.ctx.storage.delete("silentSince");
      await notify(this.env, `back-${silentSince}`, {
        summary: `Heartbeat back after ${minutes(now - silentSince)}. Alerts work again.`,
        body: "Anything that fired meanwhile arrives now.",
      });
    }
    await this.ctx.storage.setAlarm(now + seconds(this.env.SILENT_AFTER_SECONDS) * 1000);
  }

  // Fires when no ping came in time, then again as a reminder while it stays silent. Cloudflare
  // retries an alarm that throws, so a failed notification is sent again.
  async alarm() {
    const lastPing = await this.ctx.storage.get("lastPing");
    const silentSince = (await this.ctx.storage.get("silentSince")) ?? lastPing;
    await this.ctx.storage.put("silentSince", silentSince);
    await notify(this.env, `silent-${silentSince}-${Math.floor(Date.now() / 3_600_000)}`, {
      summary: `No heartbeat for ${minutes(Date.now() - silentSince)}. Alerts can't reach you until it's back.`,
      body:
        "The Fly machine, vmalert, Alertmanager or the hark relay is down. " +
        "`monitor/deploy.sh status` shows the machine.",
    });
    await this.ctx.storage.setAlarm(Date.now() + seconds(this.env.REMIND_AFTER_SECONDS) * 1000);
  }
}

async function notify(env, key, message) {
  const response = await fetch(env.HARK_WEBHOOK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Idempotency-Key": key },
    // title is the sender the phone shows in bold, as the boxes' names are for their alerts
    body: JSON.stringify({ title: "Monitor", ...message, url: env.GRAFANA_URL, appId: env.HARK_APP_ID }),
  });
  if (!response.ok) {
    throw new Error(`hark answered ${response.status}: ${await response.text()}`);
  }
}

const seconds = (value) => Number.parseInt(value, 10);

function minutes(ms) {
  const m = Math.round(ms / 60_000);
  return m < 120 ? `${m} min` : `${Math.round(m / 60)} h`;
}
