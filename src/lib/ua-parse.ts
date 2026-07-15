/**
 * Parseur user-agent minimaliste — évite d'ajouter une dépendance (ua-parser-js)
 * pour un affichage informatif dans le journal d'audit.
 */
export type ParsedUA = {
  device: "Mobile" | "Tablette" | "Ordinateur" | "Inconnu";
  browser: string;
  os: string;
};

export function parseUserAgent(ua: string | null | undefined): ParsedUA {
  if (!ua) return { device: "Inconnu", browser: "—", os: "—" };
  const s = ua;

  // OS
  let os = "—";
  if (/Windows NT 10/i.test(s)) os = "Windows 10/11";
  else if (/Windows NT 6\.3/i.test(s)) os = "Windows 8.1";
  else if (/Windows NT 6\.2/i.test(s)) os = "Windows 8";
  else if (/Windows NT 6\.1/i.test(s)) os = "Windows 7";
  else if (/Windows/i.test(s)) os = "Windows";
  else if (/Android ([\d.]+)/i.test(s)) os = `Android ${RegExp.$1}`;
  else if (/iPhone OS ([\d_]+)/i.test(s)) os = `iOS ${RegExp.$1.replace(/_/g, ".")}`;
  else if (/iPad; CPU OS ([\d_]+)/i.test(s)) os = `iPadOS ${RegExp.$1.replace(/_/g, ".")}`;
  else if (/Mac OS X ([\d_.]+)/i.test(s)) os = `macOS ${RegExp.$1.replace(/_/g, ".")}`;
  else if (/Linux/i.test(s)) os = "Linux";

  // Browser (ordre important : Edge/Opera avant Chrome, Chrome avant Safari)
  let browser = "—";
  if (/Edg\/([\d.]+)/i.test(s)) browser = `Edge ${RegExp.$1}`;
  else if (/OPR\/([\d.]+)/i.test(s)) browser = `Opera ${RegExp.$1}`;
  else if (/Firefox\/([\d.]+)/i.test(s)) browser = `Firefox ${RegExp.$1}`;
  else if (/Chrome\/([\d.]+)/i.test(s)) browser = `Chrome ${RegExp.$1}`;
  else if (/Version\/([\d.]+).*Safari/i.test(s)) browser = `Safari ${RegExp.$1}`;
  else if (/Safari/i.test(s)) browser = "Safari";

  // Device
  let device: ParsedUA["device"] = "Ordinateur";
  if (/iPad|Tablet|PlayBook|Silk/i.test(s)) device = "Tablette";
  else if (/Android/i.test(s) && !/Mobile/i.test(s)) device = "Tablette";
  else if (/Mobile|iPhone|Android|IEMobile|Opera Mini/i.test(s)) device = "Mobile";

  return { device, browser, os };
}
