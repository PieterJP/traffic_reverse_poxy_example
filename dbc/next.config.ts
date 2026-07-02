import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
  // Served behind Traefik at pjp.tplinkdns.com/dbc
  basePath: '/dbc',
}

export default nextConfig
