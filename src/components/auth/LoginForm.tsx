import { AlertCircle, ArrowRight, Eye, EyeOff, Loader2, Lock, Mail } from "lucide-react";

type Props = {
  email: string;
  setEmail: (v: string) => void;
  password: string;
  setPassword: (v: string) => void;
  showPwd: boolean;
  setShowPwd: (fn: (v: boolean) => boolean) => void;
  submitting: boolean;
  error: string;
  idleTimeout: boolean;
  onSubmit: (e: React.FormEvent) => void;
  remember: boolean;
  setRemember: (v: boolean) => void;
};

const inputBase: React.CSSProperties = {
  width: "100%",
  paddingTop: 18,
  paddingBottom: 18,
  fontSize: 18,
  background: "#FFFFFF",
  border: "1px solid #D7DCE7",
  borderRadius: 9,
  color: "#071B4D",
  outline: "none",
  transition: "border-color 0.2s, box-shadow 0.2s",
  boxShadow: "0 1px 2px rgba(15,23,42,0.04)",
};

const labelStyle: React.CSSProperties = {
  fontSize: 16,
  fontWeight: 800,
  color: "#071B4D",
  display: "block",
  marginBottom: 14,
};

const alertStyle = (bg: string, border: string, color: string): React.CSSProperties => ({
  background: bg,
  border: `1px solid ${border}`,
  borderRadius: 12,
  padding: "12px 14px",
  fontSize: 13,
  color,
  display: "flex",
  alignItems: "center",
  gap: 8,
});

function focusOrange(e: React.FocusEvent<HTMLInputElement>) {
  e.target.style.borderColor = "#FF6200";
  e.target.style.boxShadow = "0 0 0 3px rgba(255,98,0,0.12)";
}
function blurReset(e: React.FocusEvent<HTMLInputElement>) {
  e.target.style.borderColor = "#D7DCE7";
  e.target.style.boxShadow = "0 1px 2px rgba(15,23,42,0.04)";
}

export function LoginForm({
  email,
  setEmail,
  password,
  setPassword,
  showPwd,
  setShowPwd,
  submitting,
  error,
  idleTimeout,
  onSubmit,
  remember,
  setRemember,
}: Props) {
  return (
    <form className="space-y-6" onSubmit={onSubmit}>
      {idleTimeout && (
        <div style={alertStyle("#FFF7ED", "#FED7AA", "#9A3412")}>
          <AlertCircle style={{ width: 16, height: 16, flexShrink: 0 }} />
          Vous avez été déconnecté automatiquement après 15 minutes d'inactivité.
        </div>
      )}
      {error && (
        <div style={alertStyle("#FEF2F2", "#FECACA", "#B91C1C")}>
          <AlertCircle style={{ width: 16, height: 16, flexShrink: 0 }} />
          {error}
        </div>
      )}

      <div className="fade-up d65">
        <label style={labelStyle}>Adresse e-mail</label>
        <div className="relative">
          <Mail
            className="absolute left-5 top-1/2 h-6 w-6 -translate-y-1/2"
            style={{ color: "#7C8497" }}
          />
          <input
            type="email"
            name="email"
            placeholder="exemple@etablissement.ci"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            required
            data-testid="login-email-input"
            style={{ ...inputBase, paddingLeft: 62, paddingRight: 18 }}
            onFocus={focusOrange}
            onBlur={blurReset}
          />
        </div>
      </div>

      <div className="fade-up d8">
        <label style={labelStyle}>Mot de passe</label>
        <div className="relative">
          <Lock
            className="absolute left-5 top-1/2 h-6 w-6 -translate-y-1/2"
            style={{ color: "#7C8497" }}
          />
          <input
            type={showPwd ? "text" : "password"}
            name="password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
            data-testid="login-password-input"
            style={{ ...inputBase, paddingLeft: 62, paddingRight: 54 }}
            onFocus={focusOrange}
            onBlur={blurReset}
          />
          <button
            type="button"
            onClick={() => setShowPwd((v) => !v)}
            data-testid="toggle-password"
            className="absolute right-5 top-1/2 -translate-y-1/2"
            style={{
              color: "#7C8497",
              background: "none",
              border: "none",
              cursor: "pointer",
              padding: 0,
            }}
          >
            {showPwd ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
          </button>
        </div>
      </div>

      <label
        className="fade-up d9"
        style={{
          display: "flex",
          alignItems: "center",
          gap: 10,
          fontSize: 15,
          fontWeight: 600,
          color: "#071B4D",
          cursor: "pointer",
          userSelect: "none",
        }}
      >
        <input
          type="checkbox"
          checked={remember}
          onChange={(e) => setRemember(e.target.checked)}
          data-testid="login-remember"
          style={{ width: 18, height: 18, accentColor: "#FF6200", cursor: "pointer" }}
        />
        Se souvenir de moi
      </label>

      <button
        className="fade-up d95"
        type="submit"
        disabled={submitting}
        data-testid="login-submit-btn"
        style={{
          width: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 10,
          background: submitting ? "rgba(255,98,0,0.65)" : "#FF6200",
          color: "#FFFFFF",
          fontWeight: 800,
          fontSize: 20,
          padding: "22px 0",
          borderRadius: 9,
          border: "none",
          cursor: submitting ? "not-allowed" : "pointer",
          boxShadow: "0 14px 28px rgba(255,98,0,0.28)",
          marginTop: 14,
          transition: "filter 0.2s, transform 0.2s",
        }}
        onMouseEnter={(e) => {
          if (!submitting) e.currentTarget.style.filter = "brightness(1.06)";
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.filter = "none";
        }}
      >
        {submitting ? (
          <>
            <Loader2 className="h-5 w-5 animate-spin" /> Connexion…
          </>
        ) : (
          <>
            Se connecter
            <ArrowRight className="h-5 w-5" />
          </>
        )}
      </button>
    </form>
  );
}
