import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "app.lovable.gestione",
  appName: "FabsCI Gestion",
  webDir: "dist",
  server: {
    // Charge directement l'app publiée (mode "remote URL").
    // Avantages : mises à jour instantanées côté web, pas de rebuild APK.
    // Pour un mode bundle offline, retirer `url` et exécuter `bun run build`
    // puis `npx cap sync android` avec un dossier `dist/` local.
    url: "https://gesti-one.lovable.app",
    cleartext: false,
    androidScheme: "https",
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;