export type FileInfo = { path: string; mtimeMs: number }
export type Task = { key: string; title: string; files: FileInfo[]; mtimeMs: number }
export type Status = 'done' | 'current' | 'todo' | 'skipped' | 'unknown' | 'stopped'
export type Action = { skill: string; args: string; label: string }
export type Row = { key: string; label: string; status: Status; file?: string; hardened?: boolean; actions: Action[]; rows?: Row[] }
export type CompactItem = { key: string; label: string; status: Status; file?: string; skill?: string; hardened?: boolean }
export type TaskView = { rows: Row[]; compact: CompactItem[]; next?: Action; stopped?: string; other: string[] }

export type Tokens = { input: number; output: number; cacheRead: number; cacheWrite: number }
export type Tests = { state: 'none' | 'pass' | 'fail' | 'stale'; passed?: number; failed?: number }
export type Numbers = { cost: number; spent: number; turns: number; talking: boolean; turnCosts: number[]; tokens: Tokens; busyMs: number; project: string; session: string; reused: string[]; created: string[]; removed: string[]; openCallers: string[]; tests: Tests }

export type Repo = { root: string; checkout: string }

export type Shown = { workflow: string; name: string; repo: Repo; task: Task; tasks: { key: string; title: string }[]; view: TaskView; installed: string[] }
export type UiState = { paneOpen: boolean; picking: boolean; hidden: boolean; pinned?: string }

declare module 'claude-code' {
  interface PluginState {
    'agent-toolkit': { numbers: Shaped<Numbers>; shown: Shaped<Shown | null>; ui: Shaped<UiState> }
  }
}
