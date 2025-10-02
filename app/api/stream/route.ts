import { NextRequest } from 'next/server'

// 强制动态渲染，避免构建时生成静态页面
export const dynamic = 'force-dynamic'

/**
 * SSE 实时流：
 * - 定时推送 { type:'tick', S0:number } 作为示例（后续可替换为真实价源）
 * - 加强关闭时的清理，尽量避免 Controller 已关闭时的 enqueue 报错
 */
export async function GET(_req: NextRequest) {
  let closed = false
  let tickTimer: NodeJS.Timeout | null = null
  let hbTimer: NodeJS.Timeout | null = null
  let controllerRef: ReadableStreamDefaultController<any> | null = null

  const cleanup = () => {
    if (closed) return
    closed = true
    if (tickTimer) { clearInterval(tickTimer); tickTimer = null }
    if (hbTimer) { clearInterval(hbTimer); hbTimer = null }
    try { controllerRef?.close?.() } catch {}
  }

  const stream = new ReadableStream({
    start(controller) {
      controllerRef = controller
      const encoder = new TextEncoder()
      const safeEnqueue = (chunk: string) => {
        if (closed) return
        try {
          controller.enqueue(encoder.encode(chunk))
        } catch {
          cleanup()
        }
      }
      // 示例：基于 60000 做轻微扰动
      let s0 = 60000
      tickTimer = setInterval(() => {
        if (closed) return
        const drift = (Math.random() - 0.5) * 200 // ±100 波动
        s0 = Math.max(100, s0 + drift)
        safeEnqueue(`data: ${JSON.stringify({ type:'tick', S0: Math.round(s0) })}\n\n`)
      }, 1500)

      // 心跳，避免反向代理超时
      hbTimer = setInterval(() => {
        if (closed) return
        safeEnqueue(': ping\n\n')
      }, 15000)
    },
    cancel() {
      cleanup()
    }
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    }
  })
}
