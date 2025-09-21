export const metadata = { title: '新手教学', description: 'BTC 期权策略教学（教育用途）' }
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <body style={{margin:0, fontFamily:'system-ui, -apple-system, Segoe UI, Roboto, PingFang SC, Noto Sans CJK SC, sans-serif', background:'#0b0d12', color:'#e6e7eb'}}>
        {children}
      </body>
    </html>
  )
}