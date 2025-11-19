/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_DMS_API_URL: string
  readonly VITE_DMS_CLIENT_ID: string
  readonly VITE_DMS_CLIENT_SECRET: string
  readonly VITE_DMS_XSUAA_URL: string
  readonly VITE_DMS_REPOSITORY_ID: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
