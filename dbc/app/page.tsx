'use client'

import { useEffect, useState } from 'react'

export default function Home() {
  // Computed client-side (avoids an SSR/client hostname mismatch on hydration).
  // Points at the LAN-only :8443 admin entrypoint. No reachability probe here:
  // until pjp.tplinkdns.com has a valid cert, Traefik serves a self-signed one
  // on :8443, which a fetch() probe would always reject (on-LAN or not), so a
  // probe would just be misleading. Visiting this link will show a browser
  // security warning that needs to be clicked through until the cert is fixed.
  const [adminUrl, setAdminUrl] = useState<string | null>(null)

  useEffect(() => {
    setAdminUrl(`https://${window.location.hostname}:8443/dbc/admin`)
  }, [])

  return (
    <main className="page">
      <h1>Digital Business Card</h1>
      {adminUrl && (
        <a className="admin-link" href={adminUrl}>
          Admin
        </a>
      )}
    </main>
  )
}
