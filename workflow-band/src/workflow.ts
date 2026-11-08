export type FileInfo = { path: string; mtimeMs: number }
export type Reader = { read: (path: string) => Promise<string> }
export type Task = { key: string; title: string; files: FileInfo[]; mtimeMs: number }
export type Status = 'done' | 'current' | 'todo' | 'skipped' | 'unknown' | 'stopped'
export type Action = { skill: string; args: string; label: string }
export type Row = { key: string; label: string; status: Status; file?: string; hardened?: boolean; actions: Action[]; rows?: Row[] }
export type CompactItem = { key: string; label: string; status: Status; file?: string; skill?: string; hardened?: boolean }
export type TaskView = { rows: Row[]; compact: CompactItem[]; next?: Action; stopped?: string; other: string[] }
export type Run = { skill: string; args: string; task: string; at: number; session: string; checkout: string; endedAt?: number; item?: string; group?: number; file?: string }
export type Workflow = {
  id: string
  name: string
  roots: readonly string[]
  skills: readonly string[]
  tasks: (files: FileInfo[], io: Reader) => Promise<Task[]>
  taskOf: (skill: string, args: string, tasks: Task[]) => string | undefined
  annotate: (run: Run, task: Task, io: Reader) => Promise<Run>
  view: (task: Task, runs: Run[], io: Reader) => Promise<TaskView>
}
