import type { Status } from '../types'

export const ICON: Record<Status, string> = { done: '☑', current: '▣', todo: '☐', skipped: '☐', unknown: '?', stopped: '⚠' }
export const TONE: Partial<Record<Status, 'success' | 'suggestion' | 'warning'>> = { done: 'success', current: 'suggestion', stopped: 'warning' }
