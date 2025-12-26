'use client';

import { useState } from 'react';
import { useAuth } from '@/lib/auth-context';

interface SignUpModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSwitchToSignIn: () => void;
}

export default function SignUpModal({ isOpen, onClose, onSwitchToSignIn }: SignUpModalProps) {
  const { register } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await register(email, password, username || undefined);
      setEmail('');
      setPassword('');
      setUsername('');
      onClose();
    } catch (err: any) {
      setError(err.message || 'Registration failed');
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
          <h2 className="modal-title">Sign Up</h2>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <form className="modal-body" onSubmit={handleSubmit}>
          {error && <div className="alert">{error}</div>}

          <div className="form-group">
            <label className="form-label" htmlFor="signup-email">Email</label>
            <input
              id="signup-email"
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
            <label className="form-label" htmlFor="signup-username">Username (Optional)</label>
            <input
              id="signup-username"
              type="text"
              className="form-input"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="johndoe"
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="signup-password">Password</label>
            <input
              id="signup-password"
              type="password"
              className="form-input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              minLength={8}
              required
              disabled={loading}
            />
            <p className="form-hint">Minimum 8 characters</p>
          </div>

          <div className="modal-actions">
            <button type="submit" className="btn-strong" disabled={loading}>
              {loading ? 'Creating account...' : 'Sign Up'}
            </button>
            <button type="button" className="btn-neutral" onClick={onClose} disabled={loading}>
              Cancel
            </button>
          </div>

          <div className="modal-footer">
            <p className="small muted">
              Already have an account?{' '}
              <a className="link-brass" onClick={onSwitchToSignIn}>Sign In</a>
            </p>
          </div>
        </form>
      </div>
    </div>
  );
}
