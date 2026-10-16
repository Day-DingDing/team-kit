// 연결할 세션의 형태. 보통은 프로젝트 루트의 session-link.json 에서 만들어진다.
// - id: 메시지에 찍히는 이름이자 기본 별칭
// - dirs: 이 폴더들(또는 하위 폴더)에서 연 세션이 이 id가 된다
// - aliases: SendMessage의 to, /to 명령에 쓸 수 있는 다른 이름 (대소문자 무시)
// - group: 같은 그룹의 세션끼리만 서로를 안내받는다 (보내기는 그룹과 무관하게 가능)

export type Peer = {
  id: string
  label: string
  dirs: readonly string[]
  aliases: readonly string[]
  role: string
  group: string
  key?: string // 등록 파일 이름. 프로젝트 설정에서 온 세션은 `<group>--<id>`
}

// 고정 세션 목록. 팀 키트는 프로젝트 루트의 session-link.json 을 읽으므로 비워 둔다.
// 프로젝트 밖의 세션을 늘 연결하고 싶으면 여기에 넣는다 (예: { id, label, dirs: ['/절대/경로'], aliases, role, group }).
export const PEERS: readonly Peer[] = []

const norm = (s: string) => s.trim().toLowerCase()

// 같은 그룹(me)의 별칭을 먼저 찾는다. 프로젝트마다 "pm", "qa" 같은 같은 별칭을 쓰기 때문이다.
export function findByAlias(name: string, list: readonly Peer[] = PEERS, me?: Peer): Peer | undefined {
  const key = norm(name)
  const hit = (p: Peer) => p.aliases.some(a => norm(a) === key) || norm(p.id) === key
  return (me && list.find(p => p.group === me.group && hit(p))) || list.find(hit)
}

// 이 세션에 안내할 세션 목록: 연결된 세션이면 같은 그룹만, 아니면 전체
export function peersFor(me: Peer | undefined, list: readonly Peer[] = PEERS): readonly Peer[] {
  return me ? list.filter(p => p.group === me.group) : list
}

// 가장 구체적인(긴) 폴더가 맞는 세션을 고른다. 프로젝트 루트와 역할 폴더가 겹치기 때문이다.
export function findByCwd(cwd: string, list: readonly Peer[] = PEERS): Peer | undefined {
  let best: Peer | undefined
  let len = -1
  for (const p of list) {
    for (const d of p.dirs) {
      if ((cwd === d || cwd.startsWith(`${d}/`)) && d.length > len) {
        best = p
        len = d.length
      }
    }
  }
  return best
}

// 프로젝트 루트의 session-link.json 으로 세션 목록을 만든다 (팀 키트 B 방식).
// { "group": "my-app", "peers": [{ "id": "pm", "label": "PM", "dir": "roles/pm", "aliases": ["총괄"], "role": "..." }] }
export type ProjectFile = {
  group?: string
  peers: { id: string; label?: string; dir: string; aliases?: string[]; role?: string }[]
}

export function parseProject(root: string, file: ProjectFile): Peer[] {
  const group = file.group || root.split('/').filter(Boolean).at(-1) || 'project'
  return file.peers.map(p => ({
    id: p.id,
    label: p.label ?? p.id,
    dirs: [`${root}/${p.dir}`.replace(/\/+$/, '')],
    aliases: [p.id, ...(p.aliases ?? [])],
    role: p.role ?? '',
    group,
    key: `${group}--${p.id}`,
  }))
}

// 보내는 메시지 앞에 붙는 표시. 받는 쪽은 이 표시로 연결된 세션의 메시지임을 안다.
export const tag = (from: string) => `[session-link from:${from}]`
export const TAG_RE = /\[session-link from:([^\]\s]+)\]\s*/

export function splitArgs(args: string): { target: string; text: string } {
  const trimmed = args.trim()
  const space = trimmed.search(/\s/)
  if (space < 0) return { target: trimmed, text: '' }
  return { target: trimmed.slice(0, space), text: trimmed.slice(space).trim() }
}
