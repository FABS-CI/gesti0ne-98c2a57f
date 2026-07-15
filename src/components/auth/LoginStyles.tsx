export function LoginStyles() {
  return (
    <style>{`
      @keyframes loginCardIn {
        from { opacity: 0; transform: translateX(var(--login-shift, 0px)) translateY(22px) scale(0.985); }
        to { opacity: 1; transform: translateX(var(--login-shift, 0px)) translateY(0) scale(1); }
      }
      @keyframes sloganReveal {
        0% { opacity: 0; transform: translateY(20px); letter-spacing: 0.3em; }
        60% { opacity: 1; letter-spacing: 0.08em; }
        100% { opacity: 1; transform: translateY(0); letter-spacing: normal; }
      }
      @keyframes fadeSlideUp {
        from { opacity: 0; transform: translateY(16px); }
        to { opacity: 1; transform: translateY(0); }
      }
      .slogan-animate { animation: sloganReveal 1.1s ease-out 0.3s forwards; opacity: 0; }
      .fade-up { animation: fadeSlideUp 0.6s ease-out forwards; opacity: 0; }
      .d0 { animation-delay: 0s; } .d3 { animation-delay: 0.3s; }
      .d5 { animation-delay: 0.5s; } .d65 { animation-delay: 0.65s; }
      .d8 { animation-delay: 0.8s; } .d95 { animation-delay: 0.95s; }
      .login-page-shell {
        flex: 1 1 100%;
        justify-content: center;
        align-items: center;
        padding-left: 0;
        padding-right: 0;
      }
      .login-card-box {
        width: min(100%, 470px);
        padding: 52px 46px 50px;
        --login-shift: clamp(150px, 14vw, 195px);
        animation: loginCardIn 0.6s cubic-bezier(0.22,1,0.36,1) both;
        backdrop-filter: blur(14px) saturate(140%);
        -webkit-backdrop-filter: blur(14px) saturate(140%);
      }
      .login-card-title {
        font-size: 30px;
        line-height: 1.15;
      }
      @media (max-width: 768px) {
        .login-page-root {
          background-position: center top;
          background-size: cover;
          display: block !important;
        }
        .login-page-shell {
          display: flex;
          min-height: 100vh;
          align-items: center !important;
          justify-content: center !important;
          padding: 24px 18px !important;
        }
        .login-card-box {
          width: 100%;
          padding: 36px 26px 32px !important;
          border-radius: 26px !important;
          --login-shift: 0px;
        }
        .login-card-title { font-size: 24px !important; }
        .login-overlay-mobile {
          background: linear-gradient(180deg, rgba(13,27,42,0.10) 0%, rgba(13,27,42,0.55) 100%) !important;
        }
      }
      @media (max-width: 390px) {
        .login-card-box { padding: 30px 20px 26px !important; }
      }
    `}</style>
  );
}
