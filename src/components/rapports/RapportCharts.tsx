import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { AgregatDim, SerieTemp, TopProduit } from "@/lib/rapports-api";

const COLORS = [
  "#F97316",
  "#3B82F6",
  "#10B981",
  "#EF4444",
  "#8B5CF6",
  "#F59E0B",
  "#14B8A6",
  "#EC4899",
];

export function TopBarChart({ data }: { data: TopProduit[] }) {
  return (
    <ResponsiveContainer width="100%" height={320}>
      <BarChart data={data.slice(0, 10)} layout="vertical" margin={{ left: 40, right: 20 }}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis type="number" />
        <YAxis type="category" dataKey="titre" width={180} tick={{ fontSize: 11 }} />
        <Tooltip />
        <Bar dataKey="qte_vendue" fill="#F97316" name="Qté vendue" />
      </BarChart>
    </ResponsiveContainer>
  );
}

export function EvolutionLineChart({ data }: { data: SerieTemp[] }) {
  return (
    <ResponsiveContainer width="100%" height={320}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="periode" tick={{ fontSize: 11 }} />
        <YAxis />
        <Tooltip />
        <Legend />
        <Line type="monotone" dataKey="ca" stroke="#3B82F6" name="CA" strokeWidth={2} dot={false} />
        <Line
          type="monotone"
          dataKey="qte"
          stroke="#F97316"
          name="Qté"
          strokeWidth={2}
          dot={false}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}

export function AgregatPie({ data }: { data: AgregatDim[] }) {
  const slice = data.slice(0, 8);
  return (
    <ResponsiveContainer width="100%" height={320}>
      <PieChart>
        <Pie data={slice} dataKey="ca" nameKey="label" cx="50%" cy="50%" outerRadius={110} label>
          {slice.map((_, i) => (
            <Cell key={i} fill={COLORS[i % COLORS.length]} />
          ))}
        </Pie>
        <Tooltip />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  );
}

export function AgregatBar({ data }: { data: AgregatDim[] }) {
  return (
    <ResponsiveContainer width="100%" height={320}>
      <BarChart data={data.slice(0, 15)}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis
          dataKey="label"
          tick={{ fontSize: 11 }}
          interval={0}
          angle={-25}
          textAnchor="end"
          height={70}
        />
        <YAxis />
        <Tooltip />
        <Bar dataKey="ca" fill="#3B82F6" name="CA" />
      </BarChart>
    </ResponsiveContainer>
  );
}

export default { TopBarChart, EvolutionLineChart, AgregatPie, AgregatBar };
