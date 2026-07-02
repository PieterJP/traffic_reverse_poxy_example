import Home from './Home.jsx'
import Admin from './Admin.jsx'

function App() {
  const path = window.location.pathname

  if (path === '/admin' || path === '/admin/') {
    return <Admin />
  }

  return <Home />
}

export default App
