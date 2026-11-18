import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { ApiClient } from './api'
import { App } from './App'
import { readConfig } from './config'
import './styles.css'

const config = readConfig()
const api = new ApiClient(config.tokens)

const root = document.getElementById('root')
if (!root) {
  throw new Error('ContentBox Studio: #root is missing from the page')
}

createRoot(root).render(
  <StrictMode>
    <App config={config} api={api} />
  </StrictMode>,
)
