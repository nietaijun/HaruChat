/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  env: {
    API_URL: process.env.API_URL || 'https://www.nietaijun.cloud',
  },
}

module.exports = nextConfig

