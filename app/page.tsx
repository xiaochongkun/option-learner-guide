'use client'
import { useEffect, useMemo, useRef, useState } from 'react'
import Image from 'next/image'
import type { TeachingData, TabBlock } from '@/lib/types'
import { toSeries } from '@/lib/pnl'

export default function Page(){
  const [data, setData] = useState<TeachingData|null>(null)
  const [active, setActive] = useState<string>('')
  const [S0, setS0] = useState<number>(60000)
  const [btcPrice, setBtcPrice] = useState<number>(0)
  const esRef = useRef<EventSource|null>(null)

  useEffect(() => {
    fetch('/api/teaching', { cache:'no-store' }).then(r=>r.json()).then((d:TeachingData) => {
      setData(d); setActive(d.tabs[0]?.id ?? '')
    })
  }, [])

  // Fetch BTC price from Binance API every 10 seconds
  useEffect(() => {
    const fetchBtcPrice = async () => {
      try {
        const response = await fetch('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT')
        const data = await response.json()
        const price = parseFloat(data.price)
        setBtcPrice(price)
        setS0(price)
      } catch (error) {
        console.error('Failed to fetch BTC price:', error)
      }
    }

    fetchBtcPrice()
    const interval = setInterval(fetchBtcPrice, 10000)

    return () => clearInterval(interval)
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
    <main style={{maxWidth:1080, margin:'0 auto', padding:20, position:'relative'}}>
      <div style={{position:'absolute', top:20, left:20, display:'flex', alignItems:'center', gap:8}}>
        <Image
          src="/signalplus-logo.png"
          alt="SignalPlus Logo"
          width={40}
          height={40}
          style={{borderRadius:'50%'}}
        />
        <span style={{fontSize:14, color:'#cfd3dc'}}>SignalPlus</span>
      </div>
      <header style={{marginTop:60}}>
        <h1 style={{margin:'8px 0 4px'}}>期权新手教学</h1>
        <p style={{opacity:.8, margin:0}}>你认为 BTC 接下来会：</p>
        <p style={{opacity:.7, fontSize:13}}>当前 BTC 价格：{btcPrice ? btcPrice.toFixed(2) : '加载中...'} USDT</p>
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

            // 计算行权价和权利金
            const currentPrice = Math.floor(btcPrice)
            const callStrike = Math.ceil(currentPrice / 1000) * 1000 // Call向上取最近1000整数倍
            const putStrike = Math.floor(currentPrice / 1000) * 1000 // Put向下取最近1000整数倍
            const callPremium = (callStrike * 0.025).toFixed(2) // 权利金为行权价的2.5%
            const putPremium = (putStrike * 0.025).toFixed(2)

            return (
              <article key={i} style={{background:'#12151c', border:'1px solid #1f2430', borderRadius:14, padding:16}}>
                <h3 style={{margin:'0 0 8px', fontSize:18}}>{i+1}. {s.name}</h3>
                <div style={{opacity:.85}}>{s.summary}</div>
                <div style={{marginTop:6, opacity:.8, fontSize:14}}>
                  规则：{s.name.includes('Call') || s.name.includes('看涨') ?
                    `买入1张${callStrike}行权价的看涨期权CALL，支出权利金为${callPremium} USDT` :
                    s.name.includes('Put') || s.name.includes('看跌') ?
                    `买入1张${putStrike}行权价的看跌期权PUT，支出权利金为${putPremium} USDT` :
                    s.legs_rule
                  }
                  <div style={{marginTop:4}}>
                    <div>Call 行权价: {callStrike} USDT，权利金: {callPremium} USDT</div>
                    <div>Put 行权价: {putStrike} USDT，权利金: {putPremium} USDT</div>
                  </div>
                </div>

                <div style={{marginTop:10, color:'#cfd3dc', fontSize:13, textTransform:'uppercase', letterSpacing:'.08em'}}>权利金随价变化</div>
                <ul style={{margin:'6px 0 0 18px'}}>
                  {s.premium_behavior.map((x,idx)=><li key={idx}>{x}</li>)}
                </ul>

                <div style={{marginTop:10, color:'#cfd3dc', fontSize:13, textTransform:'uppercase', letterSpacing:'.08em'}}>盈亏与风险</div>
                <ul style={{margin:'6px 0 0 18px'}}>
                  <li>最大盈利：{s.payoff.max_profit}</li>
                  <li>最大亏损：{s.payoff.max_loss}</li>
                  {s.payoff.breakeven ? <li>盈亏平衡点：{s.payoff.breakeven}</li> : null}
                  {s.name.includes('价差') && (
                    <li>赔率说明：{((callStrike - putStrike) / (parseFloat(callPremium) - parseFloat(putPremium))).toFixed(2)}:1 (计算公式：(行权价1 - 行权价2) / (权利金1 - 权利金2))</li>
                  )}
                  {s.risks.map((x,idx)=><li key={idx}>风险{idx+1}：{x}
                    {idx === 0 && <span style={{marginLeft:10, fontSize:12, opacity:0.8}}>
                      - 时间价值衰减会随着到期日临近而加速，导致期权价值快速下降
                    </span>}
                    {idx === 1 && <span style={{marginLeft:10, fontSize:12, opacity:0.8}}>
                      - 隐含波动率下降可能导致即使标的价格朝有利方向移动，期权价值仍可能下跌
                    </span>}
                    {idx === 2 && <span style={{marginLeft:10, fontSize:12, opacity:0.8}}>
                      - 流动性风险在极端市场条件下可能导致无法及时平仓或价格严重偏离理论价值
                    </span>}
                  </li>)}
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
    const pad = 50 // 增加边距以容纳标签
    const w = cvs.width - pad*2
    const h = cvs.height - pad*2
    const xmin = Math.min(...xs), xmax = Math.max(...xs)
    const ymin = Math.min(...ys), ymax = Math.max(...ys)
    const xmap = (x:number)=> pad + ( (x-xmin)/(xmax-xmin||1) )*w
    const ymap = (y:number)=> pad + h - ( (y-ymin)/(ymax-ymin||1) )*h

    // 样式设置
    ctx.font = '12px Arial'
    ctx.fillStyle = '#cfd3dc'

    // 轴线
    ctx.strokeStyle = '#1f2430'; ctx.lineWidth = 1
    ctx.strokeRect(pad, pad, w, h)

    // X轴标签 - "价格"
    ctx.fillText('价格', pad + w/2 - 10, cvs.height - 10)

    // Y轴标签 - "收益" (旋转)
    ctx.save()
    ctx.translate(15, pad + h/2)
    ctx.rotate(-Math.PI/2)
    ctx.fillText('收益', -10, 0)
    ctx.restore()

    // X轴刻度 - 5000间隔
    const xRange = xmax - xmin
    const xStep = 5000
    const xStart = Math.floor(xmin / xStep) * xStep
    const xEnd = Math.ceil(xmax / xStep) * xStep
    for(let x = xStart; x <= xEnd; x += xStep) {
      if(x >= xmin && x <= xmax) {
        const px = xmap(x)
        ctx.fillText(x.toString(), px - 15, cvs.height - 25)
        // 刻度线
        ctx.beginPath()
        ctx.moveTo(px, pad + h)
        ctx.lineTo(px, pad + h + 5)
        ctx.stroke()
      }
    }

    // Y轴刻度 - 5000间隔
    const yRange = ymax - ymin
    const yStep = 5000
    const yStart = Math.floor(ymin / yStep) * yStep
    const yEnd = Math.ceil(ymax / yStep) * yStep
    for(let y = yStart; y <= yEnd; y += yStep) {
      if(y >= ymin && y <= ymax) {
        const py = ymap(y)
        ctx.fillText(y.toString(), 5, py + 4)
        // 刻度线
        ctx.beginPath()
        ctx.moveTo(pad - 5, py)
        ctx.lineTo(pad, py)
        ctx.stroke()
      }
    }

    // 零线
    if(ymin<0 && ymax>0){
      ctx.strokeStyle = '#3a3a3a'
      ctx.beginPath(); ctx.moveTo(pad, ymap(0)); ctx.lineTo(pad+w, ymap(0)); ctx.stroke()
    }
    // 线
    ctx.beginPath()
    ctx.lineWidth = 2
    ctx.strokeStyle = '#69b1ff'
    xs.forEach((x,i)=>{ const X=xmap(x), Y=ymap(ys[i]); i?ctx.lineTo(X,Y):ctx.moveTo(X,Y) })
    ctx.stroke()
  }, [xs, ys])
  return <canvas ref={ref} width={960} height={300} style={{width:'100%', height:300, display:'block'}} />
}