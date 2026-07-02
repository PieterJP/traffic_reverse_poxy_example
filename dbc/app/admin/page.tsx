import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'DBC Administration',
}

export default function AdminPage() {
  return (
    <main className="page admin">
      <h1>DBC Administration</h1>
    </main>
  )
}
