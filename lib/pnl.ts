/**
 * 把 'S0×0.8' 解析为数值；并在给定 S0 下计算所有点位的 X 轴（价格）与 Y 轴（PnL）
 * 注意：示例中 PnL 直接来自 JSON（演示）；后续可改为基于 legs 公式实时计算
 */
export function resolveS(expr: string, S0: number) {
  const m = String(expr).replace('×','x').match(/S0\s*[x*]\s*([0-9.]+)/i)
  if (m) return +(S0 * Number(m[1])).toFixed(2)
  if (/^S0$/i.test(expr)) return +S0.toFixed(2)
  const n = Number(expr); return isNaN(n) ? S0 : n
}

export function toSeries(rows: {S:string; PnL:string|number}[], S0: number) {
  const xs = rows.map(r => resolveS(String(r.S), S0))
  const ys = rows.map(r => Number(String(r.PnL).replace(/[,+￥$元空格]/g,'').replace('−','-')))
  return { xs, ys }
}