import {
  ResponsiveContainer,
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  CartesianGrid,
  Legend,
} from "recharts";
import { formatFCFA, formatFCFACompact } from "@/lib/format";

const PIE_COLORS = ["#3B82F6", "#F97316", "#10B981", "#8B5CF6", "#EF4444", "#14B8A6"];

export function CashflowChart({
  data,
}: {
  data: Array<{ mois: string; recettes: number; depenses: number }>;
}) {
  return (
    <ResponsiveContainer width="100%" height="100%">
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
        <XAxis dataKey="mois" fontSize={12} />
        <YAxis tickFormatter={(v) => formatFCFACompact(v)} fontSize={12} />
        <Tooltip formatter={(v: number) => formatFCFA(v)} />
        <Legend />
        <Line type="monotone" dataKey="recettes" name="Recettes" stroke="#10B981" strokeWidth={2} />
        <Line type="monotone" dataKey="depenses" name="Dépenses" stroke="#EF4444" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export function StatutPieChart({ data }: { data: Array<{ name: string; value: number }> }) {
  return (
    <ResponsiveContainer width="100%" height="100%">
      <PieChart>
        <Pie data={data} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={90} label>
          {data.map((_, i) => (
            <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
          ))}
        </Pie>
        <Tooltip />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  );
}

export function TopProduitsChart({ data }: { data: Array<{ titre: string; valeur: number }> }) {
  return (
    <ResponsiveContainer width="100%" height="100%">
      <BarChart data={data} layout="vertical">
        <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
        <XAxis type="number" tickFormatter={(v) => formatFCFACompact(v)} fontSize={11} />
        <YAxis type="category" dataKey="titre" width={120} fontSize={11} />
        <Tooltip formatter={(v: number) => formatFCFA(v)} />
        <Bar dataKey="valeur" name="Valeur" fill="#3B82F6" radius={[0, 4, 4, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}

export default { CashflowChart, StatutPieChart, TopProduitsChart };
