'use client'
import { useEffect, useMemo, useRef, useState } from 'react'
import type { TeachingData, TabBlock } from '@/lib/types'
import { toSeries } from '@/lib/pnl'

export default function Page(){
  const [data, setData] = useState<TeachingData|null>(null)
  const [active, setActive] = useState<string>('')
  const [S0, setS0] = useState<number>(60000)
  const esRef = useRef<EventSource|null>(null)

  useEffect(() => {
    fetch('/api/teaching', { cache:'no-store' }).then(r=>r.json()).then((d:TeachingData) => {
      setData(d); setActive(d.tabs[0]?.id ?? '')
    })
  }, [])

  // 订阅 SSE（示例，可关可开）
  useEffect(() => {
    const es = new EventSource('/api/stream')
    esRef.current = es
    es.onmessage = (ev) => {
      try {
        const msg = JSON.parse(ev.data)
        if(msg?.type==='tick' && typeof msg.S0==='number'){
          setS0(msg.S0)
        }
      } catch {}
    }
    es.onerror = () => { es.close() }
    return () => es.close()
  }, [])

  const tab = useMemo<TabBlock|undefined>(() => data?.tabs.find(t=>t.id===active), [data, active])

  return (
    <main style={{maxWidth:1080, margin:'0 auto', padding:20}}>
      <header>
        <h1 style={{margin:'8px 0 4px'}}>新手教学</h1>
        <p style={{opacity:.8, margin:0}}>你认为 BTC 接下来会：</p>
        <p style={{opacity:.7, fontSize:13}}>参考示例价 S0 = {S0}（示例；可接入实时价）</p>
      </header>

      {/* Tabs */}
      <nav style={{display:'flex', gap:8, flexWrap:'wrap', marginBottom:12}}>
        {data?.tabs.map(t=>(
          <button key={t.id}
            onClick={()=>setActive(t.id)}
            aria-selected={t.id===active}
            style={{
              background:'#12151c', border:`1px solid ${t.id===active?'#69b1ff':'#1f2430'}`,
              color:'#e6e7eb', padding:'8px 12px', borderRadius:10, cursor:'pointer'
            }}>
            {t.name} ({t.icon})
          </button>
        ))}
      </nav>

      {/* Panel */}
      {!tab ? <p>加载中…</p> : (
        <section style={{display:'grid', gap:16}}>
          {tab.strategies.map((s, i) => {
            const { xs, ys } = toSeries(s.pnl_table.rows, S0)
            return (
              <article key={i} style={{background:'#12151c', border:'1px solid #1f2430', borderRadius:14, padding:16}}>
                <h3 style={{margin:'0 0 8px', fontSize:18}}>{i+1}. {s.name}</h3>
                <div style={{opacity:.85}}>{s.summary}</div>
                <div style={{marginTop:6, opacity:.8, fontSize:14}}>规则：{s.legs_rule}</div>

                <div style={{marginTop:10, color:'#cfd3dc', fontSize:13, textTransform:'uppercase', letterSpacing:'.08em'}}>权利金随价变化</div>
                <ul style={{margin:'6px 0 0 18px'}}>
                  {s.premium_behavior.map((x,idx)=><li key={idx}>{x}</li>)}
                </ul>

                <div style={{marginTop:10, color:'#cfd3dc', fontSize:13, textTransform:'uppercase', letterSpacing:'.08em'}}>盈亏与风险</div>
                <ul style={{margin:'6px 0 0 18px'}}>
                  <li>最大盈利：{s.payoff.max_profit}</li>
                  <li>最大亏损：{s.payoff.max_loss}</li>
                  {s.payoff.breakeven ? <li>盈亏平衡点：{s.payoff.breakeven}</li> : null}
                  {s.risks.map((x,idx)=><li key={idx}>风险：{x}</li>)}
                </ul>

                <div style={{marginTop:10, color:'#cfd3dc', fontSize:13, textTransform:'uppercase', letterSpacing:'.08em'}}>到期 PnL 图</div>
                <LineChart xs={xs} ys={ys} />
              </article>
            )
          })}
        </section>
      )}

      <footer style={{opacity:.7, fontSize:12, textAlign:'center', padding:20}}>仅教育用途，非投资建议</footer>
    </main>
  )
}

function LineChart({ xs, ys }: { xs:number[]; ys:number[] }) {
  const ref = useRef<HTMLCanvasElement|null>(null)
  useEffect(() => {
    const cvs = ref.current!
    const ctx = cvs.getContext('2d')!
    // 简易绘图（自给自足）：清屏
    ctx.clearRect(0,0,cvs.width,cvs.height)
    // 边距与缩放
    const pad = 24
    const w = cvs.width - pad*2
    const h = cvs.height - pad*2
    const xmin = Math.min(...xs), xmax = Math.max(...xs)
    const ymin = Math.min(...ys), ymax = Math.max(...ys)
    const xmap = (x:number)=> pad + ( (x-xmin)/(xmax-xmin||1) )*w
    const ymap = (y:number)=> pad + h - ( (y-ymin)/(ymax-ymin||1) )*h
    // 轴线
    ctx.strokeStyle = '#1f2430'; ctx.lineWidth = 1
    ctx.strokeRect(pad, pad, w, h)
    // 零线
    if(ymin<0 && ymax>0){
      ctx.beginPath(); ctx.moveTo(pad, ymap(0)); ctx.lineTo(pad+w, ymap(0)); ctx.stroke()
    }
    // 线
    ctx.beginPath()
    ctx.lineWidth = 2
    ctx.strokeStyle = '#69b1ff'
    xs.forEach((x,i)=>{ const X=xmap(x), Y=ymap(ys[i]); i?ctx.lineTo(X,Y):ctx.moveTo(X,Y) })
    ctx.stroke()
  }, [xs, ys])
  return <canvas ref={ref} width={960} height={260} style={{width:'100%', height:260, display:'block'}} />
}