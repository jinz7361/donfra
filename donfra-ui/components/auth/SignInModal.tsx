'use client';

import { useState } from 'react';
import { useAuth } from '@/lib/auth-context';

interface SignInModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSwitchToSignUp: () => void;
}

export default function SignInModal({ isOpen, onClose, onSwitchToSignUp }: SignInModalProps) {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await login(email, password);
      setEmail('');
      setPassword('');
      onClose();
    } catch (err: any) {
      setError(err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  return (
    <div className="modal-backdrop" onClick={handleBackdropClick}>
      <div className="modal-dialog">
        <div className="modal-header">
          <h2 className="modal-title">Sign In</h2>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <form className="modal-body" onSubmit={handleSubmit}>
          {error && <div className="alert">{error}</div>}

          <div className="form-group">
            <label className="form-label" htmlFor="signin-email">Email</label>
            <input
              id="signin-email"
              type="email"
              className="form-input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="your@email.com"
              required
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="signin-password">Password</label>
            <input
              id="signin-password"
              type="password"
              className="form-input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
              disabled={loading}
            />
          </div>

          <div className="modal-actions">
            <button type="submit" className="btn-strong" disabled={loading}>
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
            <button type="button" className="btn-neutral" onClick={onClose} disabled={loading}>
              Cancel
            </button>
          </div>

          <div className="modal-footer">
            <p className="small muted">
              Don't have an account?{' '}
              <a className="link-brass" onClick={onSwitchToSignUp}>Sign Up</a>
            </p>
          </div>
        </form>
      </div>
    </div>
  );
}
