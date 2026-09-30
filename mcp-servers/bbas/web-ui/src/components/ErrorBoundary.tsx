import React from 'react';

interface State { err?: Error }

export class ErrorBoundary extends React.Component<{ children: React.ReactNode }, State> {
  state: State = {};

  static getDerivedStateFromError(err: Error): State {
    return { err };
  }

  componentDidCatch(err: Error, info: React.ErrorInfo) {
    console.error('BBAS UI error:', err, info);
  }

  render() {
    if (this.state.err) {
      return (
        <div style={{ padding: 40, fontFamily: 'ui-monospace, monospace', color: '#eee', background: '#0f172a', minHeight: '100vh' }}>
          <h2 style={{ color: '#f87171' }}>⚠️ Error en la interfaz BBAS</h2>
          <p style={{ color: '#94a3b8' }}>La aplicación falló al renderizar. Detalle técnico:</p>
          <pre style={{
            whiteSpace: 'pre-wrap', background: '#1e293b', padding: 16,
            borderRadius: 8, fontSize: 12, maxHeight: '50vh', overflow: 'auto',
          }}>{String(this.state.err.stack || this.state.err.message || this.state.err)}</pre>
          <button
            onClick={() => { localStorage.removeItem('bbas-ui-store'); location.href = '/'; }}
            style={{
              marginTop: 16, padding: '10px 18px', borderRadius: 8, border: 'none',
              background: '#0ea5e9', color: '#fff', cursor: 'pointer', fontWeight: 600,
            }}
          >
            Limpiar estado y recargar
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
