import { Link, useParams } from 'react-router'
import { Header } from '../components/Header'

/** The block editor (phase 3) */
export function EditorPage() {
  const { contentID } = useParams()
  return (
    <div className="studio">
      <Header />
      <main className="studio-main">
        <section className="studio-panel">
          <h1>Editor</h1>
          <p className="studio-muted">The block editor for {contentID} comes in the next step.</p>
          <Link to="/">Back to the pages</Link>
        </section>
      </main>
    </div>
  )
}
