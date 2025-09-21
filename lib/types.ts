export type PnLRow = { S: string; PnL: string }
export type Strategy = {
  name: string
  summary: string
  legs_rule: string
  premium_behavior: string[]
  payoff: { max_profit: string; max_loss: string; breakeven?: string }
  risks: string[]
  pnl_table: { S0_reference: string; rows: PnLRow[] }
}
export type TabBlock = { id: string; name: string; icon: string; strategies: Strategy[] }
export type TeachingData = { meta: { title: string; subtitle: string; spot_assumption: string }, tabs: TabBlock[] }