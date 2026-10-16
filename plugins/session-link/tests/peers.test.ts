import { describe, expect, test } from 'claude-code/testing'

import { PEERS, TAG_RE, findByAlias, findByCwd, parseProject, peersFor, splitArgs, tag } from '../hooks/peers'

describe('session-link.json 으로 역할 세션 찾기', () => {
  const root = '/work/my-app'
  const list = [
    ...PEERS,
    ...parseProject(root, {
      group: 'my-app',
      peers: [
        { id: 'pm', label: '총괄', dir: 'roles/pm', aliases: ['총괄'] },
        { id: 'qa', label: 'QA', dir: 'roles/qa', aliases: ['QA'] },
      ],
    }),
  ]

  test('역할 폴더(하위 폴더 포함)에서 연 세션이 그 역할이 된다', async () => {
    const pm = findByCwd(`${root}/roles/pm`, list)
    expect(pm?.id).toBe('pm')
    expect(pm?.key).toBe('my-app--pm')
    expect(findByCwd(`${root}/roles/qa/tests`, list)?.id).toBe('qa')
    expect(findByCwd(root, list)).toBeUndefined()
  })

  test('별칭은 대소문자를 무시하고 같은 그룹을 먼저 찾는다', async () => {
    const pm = findByCwd(`${root}/roles/pm`, list)
    const other = parseProject('/work/other', { group: 'other', peers: [{ id: 'qa', dir: 'roles/qa' }] })
    const all = [...other, ...list]
    expect(findByAlias('총괄', all, pm)?.id).toBe('pm')
    expect(findByAlias(' qa ', all, pm)?.key).toBe('my-app--qa')
    expect(peersFor(pm, all).map(p => p.id)).toEqual(['pm', 'qa'])
    expect(findByAlias('stock', all)).toBeUndefined()
  })

  test('/to 인자와 보낸 쪽 표시를 나눈다', async () => {
    expect(splitArgs('qa  테스트 실행해 줘')).toEqual({ target: 'qa', text: '테스트 실행해 줘' })
    expect(TAG_RE.exec(`${tag('pm')} 안녕`)?.[1]).toBe('pm')
  })

  test('가장 구체적인 폴더가 우선한다', async () => {
    const proj = parseProject('/x/app', { peers: [{ id: 'dev', dir: 'roles/dev' }] })
    const outer = parseProject('/x', { group: 'outer', peers: [{ id: 'all', dir: 'app' }] })
    expect(findByCwd('/x/app/roles/dev/src', [...outer, ...proj])?.id).toBe('dev')
  })
})
