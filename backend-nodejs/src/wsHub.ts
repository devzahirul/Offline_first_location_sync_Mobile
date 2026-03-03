import WebSocket from "ws";

export class WsHub {
  private subs = new Map<string, Set<WebSocket>>();

  addSubscriber(userId: string, socket: WebSocket) {
    const set = this.subs.get(userId) ?? new Set<WebSocket>();
    set.add(socket);
    this.subs.set(userId, set);
  }

  removeSubscriber(userId: string, socket: WebSocket) {
    const set = this.subs.get(userId);
    if (!set) return;
    set.delete(socket);
    if (set.size === 0) this.subs.delete(userId);
  }

  broadcast(userId: string, data: string) {
    const set = this.subs.get(userId);
    if (!set) return;
    for (const ws of set) {
      if (ws.readyState === WebSocket.OPEN) ws.send(data);
    }
  }
}
