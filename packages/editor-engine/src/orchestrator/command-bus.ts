export type CommandPriority = 'user' | 'markpoetry' | 'auto';

export interface Command {
  id: string;
  priority: CommandPriority;
  execute: () => unknown;
  timestamp: number;
}

const priorityRank: Record<CommandPriority, number> = {
  user: 0,
  markpoetry: 1,
  auto: 2,
};

export class CommandBus {
  private queue: Command[] = [];
  private running = false;

  push(cmd: Omit<Command, 'timestamp'>): void {
    this.queue.push({ ...cmd, timestamp: Date.now() });
    this.queue.sort(
      (a, b) => priorityRank[a.priority] - priorityRank[b.priority] || a.timestamp - b.timestamp,
    );
    this.flush();
  }

  private async flush(): Promise<void> {
    if (this.running) return;
    this.running = true;
    while (this.queue.length > 0) {
      const cmd = this.queue.shift()!;
      try {
        await cmd.execute();
      } catch (e) {
        console.error(`Command ${cmd.id} failed:`, e);
      }
    }
    this.running = false;
  }
}
