import { Bar, BarChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatFCFA } from "@/lib/format";

export default function ClientCaBarChart({
  data,
}: {
  data: Array<{ mois: string; ca: number; paye: number }>;
}) {
  return (
    <ResponsiveContainer width="100%" height="100%">
      <BarChart data={data}>
        <XAxis dataKey="mois" fontSize={11} />
        <YAxis fontSize={11} tickFormatter={(v) => `${Math.round(v / 1000)}k`} />
        <Tooltip formatter={(v: number) => formatFCFA(v)} />
        <Bar dataKey="ca" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
        <Bar dataKey="paye" fill="hsl(var(--muted-foreground))" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
