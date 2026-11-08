import type { FileInfo, Task, TaskView } from '../types'

export type { Action, CompactItem, FileInfo, Row, Status, Task, TaskView } from '../types'

export type Reader = { read: (path: string) => Promise<string> }
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
