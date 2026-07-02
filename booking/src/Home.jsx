import { useEffect, useState } from 'react'

function Home() {
  const adminUrl = `https://${window.location.hostname}:8443/admin`
  // null = still probing, true = reachable, false = unreachable (off-LAN)
  const [adminReachable, setAdminReachable] = useState(null)

  useEffect(() => {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 3000)

    // no-cors probe: resolves (opaque) if the admin endpoint is reachable,
    // rejects on connection failure/timeout when we're off the LAN.
    fetch(adminUrl, { mode: 'no-cors', signal: controller.signal })
      .then(() => setAdminReachable(true))
      .catch(() => setAdminReachable(false))
      .finally(() => clearTimeout(timeout))

    return () => {
      clearTimeout(timeout)
      controller.abort()
    }
  }, [adminUrl])

  return (
    <main className="page">
      <h1>Booking</h1>
      {adminReachable === false ? (
        <p className="admin-note">Admin is only available on the local network</p>
      ) : (
        <a className="admin-link" href={adminUrl}>Booking Admin</a>
      )}
    </main>
  )
}

export default Home
