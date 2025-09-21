# Option Learner Guide (Next.js, API-driven)

一个基于 Next.js 14 + TypeScript 的期权教学 Web 应用，支持：
- 📊 五种市场观点下的期权策略教学
- 🔄 实时价格更新（SSE 流）
- 📈 动态 PnL 图表计算与渲染
- 🎯 教育导向，数据结构清晰可扩展

## 快速开始

### 开发环境
```bash
cd projects/option-learner-guide
cp .env.example .env
npm install
npm run dev
```

访问 http://localhost:3000

### 生产环境
```bash
npm run build
npm run start
```

## 项目结构

```
option-learner-guide/
├── app/                    # Next.js App Router
│   ├── api/               # API 路由
│   │   ├── teaching/      # 教学数据 API
│   │   └── stream/        # SSE 实时数据流
│   ├── layout.tsx         # 根布局
│   └── page.tsx          # 主页面（教学界面）
├── content/               # 内容数据
│   ├── tabs.json         # 结构化教学数据
│   └── newbie_guide.md   # 教学文档（备查）
├── lib/                   # 共享工具
│   ├── types.ts          # TypeScript 类型定义
│   └── pnl.ts           # PnL 计算工具
├── scripts/              # 工具脚本
│   └── unpack_claude_files.sh  # 文件解包脚本
└── package.json
```

## 核心功能

### 1. 教学内容 API
- `GET /api/teaching` - 返回完整教学数据（JSON 格式）
- 支持五种市场观点：大涨(↑)、大跌(↓)、温和上涨(↗)、温和下跌(↘)、横盘(→)
- 每种观点包含 1-2 个期权策略的详细说明

### 2. 实时数据流
- `GET /api/stream` - SSE 事件流
- 模拟 BTC 价格波动（基于 60000 做随机游走）
- 前端实时更新 PnL 图表

### 3. 动态 PnL 计算
- 解析 `S0×0.8` 格式的价格表达式
- 根据实时价格重新计算所有策略的盈亏图
- Canvas 绘制交互式图表

## 数据格式

### 教学数据结构
```typescript
type TeachingData = {
  meta: { title: string; subtitle: string; spot_assumption: string }
  tabs: TabBlock[]
}

type TabBlock = {
  id: string        // 'bull_strong', 'bear_strong', etc.
  name: string      // '大涨', '大跌', etc.
  icon: string      // '↑', '↓', etc.
  strategies: Strategy[]
}

type Strategy = {
  name: string              // 策略名称
  summary: string           // 一句话说明
  legs_rule: string         // 构建规则
  premium_behavior: string[] // 权利金变化说明
  payoff: {                 // 盈亏特征
    max_profit: string
    max_loss: string
    breakeven?: string
  }
  risks: string[]           // 风险点
  pnl_table: {             // PnL 数据点
    S0_reference: string
    rows: { S: string; PnL: string }[]
  }
}
```

### SSE 数据格式
```typescript
// 价格更新事件
{ type: 'tick', S0: number }
```

## 扩展说明

### 接入真实数据源
1. 修改 `/api/stream/route.ts`，替换模拟价格生成逻辑
2. 接入真实交易所 WebSocket（如 Binance、OKX）
3. 更新 `.env` 中的 `PRICE_FEED_URL`

### 添加新策略
1. 编辑 `content/tabs.json`，在相应 tab 下添加策略数据
2. 确保 `pnl_table.rows` 包含统一的价格点位数据
3. PnL 计算会自动适配新数据

### 自定义样式
- 主要样式在 `app/page.tsx` 和 `app/layout.tsx` 中使用内联样式
- 颜色主题：深色背景 (`#0b0d12`)，蓝色强调色 (`#69b1ff`)
- 可根据需要提取到独立 CSS 文件

## 注意事项

⚠️ **免责声明**：本应用仅用于期权知识教学，不构成投资建议。所有数据均为演示用途。

🔧 **技术栈**：
- Next.js 14 (App Router)
- TypeScript
- React Server Components
- Server-Sent Events
- Canvas 2D API

📋 **浏览器兼容性**：支持所有现代浏览器（ES2022、EventSource API）