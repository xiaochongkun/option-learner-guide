import { NextRequest } from 'next/server'

// 强制动态渲染，避免构建时生成静态页面
export const dynamic = 'force-dynamic'

/**
 * SSE 实时流：
 * - 定时推送 { type:'tick', S0:number } 作为示例（后续可替换为真实价源）
 * - 客户端收到后按业务规则重算 PnL 并更新图表
 */
export async function GET(_req: NextRequest) {
  const stream = new ReadableStream({
    start(controller) {
      const encoder = new TextEncoder()
      function send(obj: any) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(obj)}\n\n`))
      }
      // 示例：基于 60000 做轻微扰动
      let s0 = 60000
      const timer = setInterval(() => {
        const drift = (Math.random() - 0.5) * 200 // ±100 波动
        s0 = Math.max(100, s0 + drift)
        send({ type:'tick', S0: Math.round(s0) })
      }, 1500)

      // 心跳，避免反向代理超时
      const hb = setInterval(() => controller.enqueue(encoder.encode(': ping\n\n')), 15000)

      return () => { clearInterval(timer); clearInterval(hb) }
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