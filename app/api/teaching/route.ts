import { NextResponse } from 'next/server'
import fs from 'node:fs/promises'

export async function GET() {
  const raw = await fs.readFile('content/tabs.json','utf-8')
  const data = JSON.parse(raw)
  return NextResponse.json(data, { headers: { 'Cache-Control': 'no-store' } })
}