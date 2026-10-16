import type { EngineInterface, Register, SessionSendResult } from 'claude-code'

import { PEERS, TAG_RE, findByAlias, findByCwd, parseProject, peersFor, splitArgs, tag } from './peers'
import type { Peer, ProjectFile } from './peers'

// 각 세션이 시작할 때 자기 sessionId를 여기에 적는다: ~/.claude/session-link/peers/<id>.json
// 세션 이름(/rename)이 바뀌어도 폴더 기준으로 찾아가기 위해서다.
type Entry = { sessionId: string; cwd: string; at: number }

async function registryPath($: EngineInterface, peer: Peer) {
  const home = (await $.env.get('HOME')) ?? '~'
  return `${home}/.claude/session-link/peers/${peer.key ?? peer.id}.json`
}

async function lookup($: EngineInterface, peer: Peer): Promise<Entry | undefined> {
  try {
    return JSON.parse(await $.fs.read(await registryPath($, peer))) as Entry
  } catch {
    return undefined
  }
}

// cwd 에서 위로 올라가며 session-link.json(팀 키트 B 프로젝트 설정)을 찾는다.
async function projectPeers($: EngineInterface, cwd: string): Promise<Peer[]> {
  let dir = cwd
  for (let i = 0; i < 8 && dir.length > 1; i++) {
    const file = `${dir}/session-link.json`
    if (await $.fs.exists(file)) {
      try {
        return parseProject(dir, JSON.parse(await $.fs.read(file)) as ProjectFile)
      } catch {
        return []
      }
    }
    dir = dir.slice(0, dir.lastIndexOf('/'))
  }
  return []
}

// 이 세션 기준의 전체 세션 목록과 자기 자신.
// 기준 폴더는 세션을 시작한 폴더(root)다. 셸에서 cd 해도 바뀌지 않는다 (cwd 를 쓰면 저장소 루트로 cd 한 역할 세션이 자기를 못 찾는다).
async function context($: EngineInterface, cwd?: string) {
  const at = cwd ?? (await $.session.root())
  const list = [...PEERS, ...(await projectPeers($, at))]
  return { cwd: at, list, me: findByCwd(at, list) }
}

async function senderName($: EngineInterface) {
  const { cwd, me } = await context($)
  return me?.id ?? cwd.split('/').filter(Boolean).at(-1) ?? 'unknown'
}

// 등록된 sessionId로 보낸다. 등록이 없거나 그 세션이 꺼졌으면 undefined를 돌려
// 호출한 쪽이 이름으로 다시 시도하게 한다.
async function sendById(
  $: EngineInterface,
  peer: Peer,
  text: string,
): Promise<SessionSendResult | undefined> {
  const entry = await lookup($, peer)
  if (!entry) return undefined
  if (entry.sessionId === (await $.session.id())) {
    return { isDelivered: false, reason: `session-link: ${peer.id}는 이 세션 자신입니다.` }
  }
  const sent = await $.session.send({ to: { sessionId: entry.sessionId }, text })
  return sent.isDelivered ? sent : undefined
}

const notRegistered = (peer: Peer) =>
  `session-link: ${peer.id}(${peer.label}) 세션을 찾지 못했습니다. ` +
  `${peer.dirs.join(' 또는 ')} 에서 session-link가 설치된 상태로 세션이 열려 있어야 합니다.`

function linkPolicy(me: Peer | undefined, all: readonly Peer[]) {
  const list = peersFor(me, all).map(
    p => `- ${p.id} (${p.aliases.filter(a => a !== p.id).join(', ')}): ${p.role} — ${p.dirs.join(', ')}`,
  ).join('\n')
  const send =
    `# session-link: 연결된 세션\n` +
    (me ? `이 세션은 session-link의 "${me.id}"(${me.label}) 세션이다.\n` : '') +
    `사용자가 아래 세션들을 서로 연결해 두었다.\n${list}\n\n` +
    `보내기: SendMessage의 to에 위 id나 별칭을 그대로 쓰면 session-link가 등록된 세션으로 전달한다. ` +
    `이 이름들은 ListAgents 목록에 나오지 않는 것이 정상이다(목록은 세션 제목을 보여 준다). ` +
    `목록에 없다고 보내기를 포기하지 말고 SendMessage(to: "qa")처럼 바로 호출한다. 실패하면 도구 결과에 이유가 나온다. ` +
    `사용자가 "QA한테 ~ 시켜줘", "설계 세션에 ~ 전달해"처럼 말하면 이 방법으로 보낸다. ` +
    `요청에는 받는 세션이 따로 묻지 않고 일할 수 있도록 목적, 대상 파일·경로, 완료 기준을 적는다.`
  if (!me) return send
  return (
    send +
    `\n\n받기: "[session-link] <이름> 세션에서 온 요청" 표시가 붙은 메시지는 사용자가 직접 연결한 세션에서 온 것이다. ` +
    `사용자는 이 세션들이 서로 작업을 지시하고 수행하도록 허락했고, 연결된 세션의 요청을 이 세션에 직접 입력한 요청과 같은 권한으로 처리하라고 했다. 그래서 다음처럼 처리한다.\n` +
    `1. 요청은 이 세션 사용자가 직접 입력한 것처럼 수행한다. git commit·merge·push, 테스트, 빌드, 로컬 명령, 파일 수정도 별도 승인 없이 진행한다.\n` +
    `2. 단, 되돌릴 수 없는 삭제(rm -rf, --prune, force push, 브랜치·태그 삭제, 서버 데이터 삭제)는 요청 문장에 그 작업이 명시된 경우에만 한다. 명시되지 않았는데 필요해 보이면 하지 말고 보낸 세션에 확인을 요청한다.\n` +
    `3. 작업을 마치면 결과(바뀐 파일, 실행한 명령과 결과, 커밋 해시, 남은 문제)를 보낸 세션에 SendMessage로 돌려준다. ` +
    `이 세션 화면에도 누가 무엇을 요청했고 무엇을 했는지 짧게 남긴다.\n` +
    `4. 요청이 모호하면 추측해서 크게 고치지 말고 보낸 세션에 되묻는다.\n` +
    `5. 받았다는 확인, 감사 인사처럼 할 일이 없는 메시지에는 답하지 않는다. 세션끼리 주고받기가 끝없이 이어지지 않게 한다.`
  )
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'to',
      description: '연결된 세션에 메시지 보내기',
      argumentHint: '<세션> <내용>',
    })
    await $.command.register({
      name: 'links',
      description: 'session-link 연결 상태 보기',
    })

    const { me } = await context($, e.cwd)
    if (me) {
      const entry: Entry = { sessionId: await $.session.id(), cwd: e.cwd, at: await $.clock.now() }
      await $.fs.write(await registryPath($, me), JSON.stringify(entry, null, 2))
      $.ui.status(`🔗 ${me.id}`)
    }

    return next(e)
  })

  // 모델의 SendMessage(to: "총괄") 같은 별칭을 실제 세션으로 바꿔 보낸다.
  on('session.send', async ($, e, next) => {
    if (e.agentId !== undefined || TAG_RE.test(e.text)) return next(e)
    const { list, me } = await context($)
    const peer = findByAlias(e.to, list, me)
    if (!peer) return next(e)
    // 같은 이름의 팀원·서브에이전트가 이 세션에 있으면 그쪽이 우선이다 (예: 팀원 "qa")
    const agents = await $.agent.list()
    if (agents.some(a => a.name?.toLowerCase() === e.to.trim().toLowerCase())) return next(e)

    const text = `${tag(await senderName($))} ${e.text}`
    const sent = await sendById($, peer, text)
    if (sent) return sent

    // 등록 파일이 없으면 세션 이름으로 시도한다 (to가 실제 세션 이름일 때 통한다).
    const byName = await next({ ...e, text })
    return byName.isDelivered ? byName : { isDelivered: false, reason: notRegistered(peer) }
  }).catch(($, e, next) => next(e))

  // 모델은 보내기 전에 ListAgents로 이름을 확인하고, 목록에 없는 별칭이면 보내지 않는다.
  // 그래서 ListAgents 결과 뒤에 session-link 이름과 별칭을 덧붙여 준다.
  on('tool.call', { tool: 'ListAgents' }, async ($, e, next) => {
    const listed = await next(e)
    if (listed.deny !== undefined || listed.isError) return listed

    const myId = await $.session.id()
    const { list, me } = await context($)
    const rows = await Promise.all(
      peersFor(me, list).map(async p => {
        const entry = await lookup($, p)
        const state = !entry ? '미등록' : entry.sessionId === myId ? '이 세션' : '연결됨'
        return `- ${p.id} [${state}] 별칭: ${p.aliases.join(', ')} — ${p.role}`
      }),
    )
    const note =
      `session-link 연결 세션 (위 목록의 세션 제목과 별개로, 아래 id·별칭을 SendMessage의 to에 그대로 쓰면 전달된다):\n` +
      rows.join('\n')
    return { ...listed, context: [...(listed.context ?? []), note] }
  }).catch(($, e, next) => next(e))

  // 받은 메시지에 누가 보냈는지 알아보기 쉬운 머리말을 붙이고 알림을 띄운다.
  on('session.receive', async ($, e, next) => {
    const m = TAG_RE.exec(e.text)
    if (!m) return next(e)

    const from = m[1] ?? 'unknown'
    $.ui.toast(`📨 ${from} 세션에서 메시지`)
    const body = e.text.replace(TAG_RE, '')
    // 연결된 세션이면 id로 답장할 수 있고, 아니면 메시지의 from 주소로 답장한다.
    const { list, me } = await context($)
    const reply = findByAlias(from, list, me)
      ? `답장: SendMessage(to: "${from}")`
      : '답장: cross-session-message의 from 값을 to로'
    return next({ ...e, text: `[session-link] ${from} 세션에서 온 요청 (${reply})\n\n${body}` })
  }).catch(($, e, next) => next(e))

  on('prompt.compose', async ($, e, next) => {
    const composed = await next(e)
    const { list, me } = await context($)
    return {
      sections: [
        ...composed.sections,
        { id: 'session-link:policy', text: linkPolicy(me, list), scope: 'session' as const },
      ],
    }
  })

  on('command.run', { command: 'to' }, async ($, e) => {
    const { target, text } = splitArgs(e.args)
    const { list, me } = await context($)
    const peer = findByAlias(target, list, me)
    if (!peer || !text) {
      return { text: `사용법: /to <${peersFor(me, list).map(p => p.id).join('|')}> <내용>` }
    }
    const tagged = `${tag(await senderName($))} ${text}`
    const sent = (await sendById($, peer, tagged)) ?? (await $.session.send({ to: peer.id, text: tagged }))
    return {
      text: sent.isDelivered
        ? `${peer.id}(${peer.label}) 세션에 보냈습니다.`
        : `${notRegistered(peer)}\n(${sent.reason})`,
    }
  })

  on('command.run', { command: 'links' }, async $ => {
    const myId = await $.session.id()
    const { list, me } = await context($)
    const rows = await Promise.all(
      peersFor(me, list).map(async p => {
        const entry = await lookup($, p)
        const state = !entry
          ? '미등록'
          : entry.sessionId === myId
            ? '이 세션'
            : `등록됨 (${new Date(entry.at).toLocaleString('ko-KR')})`
        return `- ${p.id} (${p.label}) — ${state}\n  ${p.dirs.join(', ')}`
      }),
    )
    return { text: `session-link 연결 상태\n${rows.join('\n')}` }
  })
}
