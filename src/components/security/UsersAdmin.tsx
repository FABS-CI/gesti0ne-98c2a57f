import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import {
  KeyRound,
  Lock,
  LockOpen,
  MoreHorizontal,
  Pencil,
  Plus,
  RefreshCcw,
  Search,
  ShieldCheck,
  ShieldAlert,
  ShieldOff,
  UserCheck,
  UserX,
  ShieldQuestion,
  AlertCircle
} from "lucide-react";


import {
  secCreateUser,
  secListScopeRefs,
  secListUsers,
  secResetPassword,
  secSetUserStatut,
  secUpdateUser,
} from "@/lib/security-users.functions";
import { mfaResetUser, mfaToggleRequirement } from "@/lib/mfa.functions";
import { MfaEnrollView } from "@/components/mfa/MfaEnrollView";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

type Statut = "actif" | "suspendu" | "verrouille";

type UserRow = {
  id: string;
  email: string | null;
  matricule: string | null;
  nom: string | null;
  prenom: string | null;
  nom_complet: string | null;
  telephone: string | null;
  fonction: string | null;
  avatar_url: string | null;
  statut: Statut;
  locked_reason: string | null;
  service_id: string | null;
  departement_id: string | null;
  depot_principal_id: string | null;
  derniere_connexion: string | null;
  role_codes: string[];
  depot_ids: string[];
  mfa_enrolled_at: string | null;
  mfa_required: boolean;
};



const NONE = "__none__";

const STATUT_META: Record<Statut, { label: string; variant: "default" | "secondary" | "destructive" }> = {
  actif: { label: "Actif", variant: "default" },
  suspendu: { label: "Suspendu", variant: "secondary" },
  verrouille: { label: "Verrouillé", variant: "destructive" },
};

function initials(u: UserRow) {
  const src = u.nom_complet || u.email || "?";
  return src
    .split(/[\s.@]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0]!.toUpperCase())
    .join("");
}

function formatDate(value: string | null) {
  if (!value) return "—";
  return new Date(value).toLocaleString("fr-FR", { dateStyle: "short", timeStyle: "short" });
}

const emptyForm = {
  user_id: null as string | null,
  email: "",
  password: "",
  matricule: "",
  nom: "",
  prenom: "",
  nom_complet: "",
  telephone: "",
  fonction: "",
  avatar_url: "",
  service_id: NONE,
  departement_id: NONE,
  depot_principal_id: NONE,
  role_codes: [] as string[],
  depot_ids: [] as string[],
};

export function UsersAdmin() {
  const qc = useQueryClient();
  const listUsers = useServerFn(secListUsers);
  const listRefs = useServerFn(secListScopeRefs);
  const createUser = useServerFn(secCreateUser);
  const updateUser = useServerFn(secUpdateUser);
  const setStatut = useServerFn(secSetUserStatut);
  const resetPwd = useServerFn(secResetPassword);

  const mfaReset = useServerFn(mfaResetUser);
  const mfaToggle = useServerFn(mfaToggleRequirement);


  const users = useQuery({ queryKey: ["sec", "users"], queryFn: () => listUsers({ data: {} }) });
  const refs = useQuery({ queryKey: ["sec", "refs"], queryFn: () => listRefs({ data: {} }) });

  const [search, setSearch] = useState("");
  const [statutFilter, setStatutFilter] = useState<string>("tous");
  const [roleFilter, setRoleFilter] = useState<string>("tous");
  const [form, setForm] = useState<typeof emptyForm | null>(null);
  const [pwdTarget, setPwdTarget] = useState<UserRow | null>(null);
  const [pwdValue, setPwdValue] = useState("");
  const [mfaResetTarget, setMfaResetTarget] = useState<UserRow | null>(null);
  const [mfaEnrollTarget, setMfaEnrollTarget] = useState<UserRow | null>(null);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return ((users.data ?? []) as any[]).filter((u) => {
      if (statutFilter !== "tous" && u.statut !== statutFilter) return false;
      if (roleFilter !== "tous" && !u.role_codes.includes(roleFilter)) return false;
      if (!q) return true;
      return [u.nom_complet, u.email, u.matricule, u.fonction]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(q));
    }) as UserRow[];
  }, [users.data, search, statutFilter, roleFilter]);

  const invalidate = () => qc.invalidateQueries({ queryKey: ["sec", "users"] });

  const saveMutation = useMutation({
    mutationFn: async (f: typeof emptyForm) => {
      const profile = {
        matricule: f.matricule || null,
        nom: f.nom || null,
        prenom: f.prenom || null,
        nom_complet: f.nom_complet.trim(),
        telephone: f.telephone || null,
        fonction: f.fonction || null,
        avatar_url: f.avatar_url || null,
        service_id: f.service_id === NONE ? null : f.service_id,
        departement_id: f.departement_id === NONE ? null : f.departement_id,
        depot_principal_id: f.depot_principal_id === NONE ? null : f.depot_principal_id,
      };
      const scope = { role_codes: f.role_codes, depot_ids: f.depot_ids };
      if (f.user_id) {
        return updateUser({ data: { user_id: f.user_id, profile, scope } });
      }
      return createUser({ data: { email: f.email.trim(), password: f.password, profile, scope } });
    },
    onSuccess: () => {
      toast.success("Utilisateur enregistré");
      setForm(null);
      invalidate();
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const statutMutation = useMutation({
    mutationFn: (v: { user_id: string; statut: Statut }) => setStatut({ data: v }),
    onSuccess: () => {
      toast.success("Statut mis à jour");
      invalidate();
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const pwdMutation = useMutation({
    mutationFn: (v: { user_id: string; new_password: string }) => resetPwd({ data: v }),
    onSuccess: () => {
      toast.success("Mot de passe réinitialisé");
      setPwdTarget(null);
      setPwdValue("");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const mfaResetMutation = useMutation({
    mutationFn: (userId: string) => mfaReset({ data: { targetUserId: userId } }),
    onSuccess: () => {
      toast.success("MFA réinitialisé avec succès");
      setMfaResetTarget(null);
      invalidate();
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const mfaToggleMutation = useMutation({
    mutationFn: (v: { userId: string; required: boolean }) => 
      mfaToggle({ data: { targetUserId: v.userId, required: v.required } }),
    onSuccess: (_, variables) => {
      toast.success(variables.required ? "MFA activé" : "MFA désactivé");
      invalidate();
    },
    onError: (e: Error) => toast.error(e.message),
  });


  const services = refs.data?.services ?? [];
  const departements = refs.data?.departements ?? [];
  const depots = refs.data?.depots ?? [];
  const roles = refs.data?.roles ?? [];

  const labelOf = (list: { [k: string]: unknown }[], idKey: string, labelKey: string, id: string | null) =>
    id ? ((list.find((x) => x[idKey] === id)?.[labelKey] as string) ?? "—") : "—";

  const openEdit = (u: UserRow) =>
    setForm({
      user_id: u.id,
      email: u.email ?? "",
      password: "",
      matricule: u.matricule ?? "",
      nom: u.nom ?? "",
      prenom: u.prenom ?? "",
      nom_complet: u.nom_complet ?? "",
      telephone: u.telephone ?? "",
      fonction: u.fonction ?? "",
      avatar_url: u.avatar_url ?? "",
      service_id: u.service_id ?? NONE,
      departement_id: u.departement_id ?? NONE,
      depot_principal_id: u.depot_principal_id ?? NONE,
      role_codes: u.role_codes,
      depot_ids: u.depot_ids,
    });

  const counters = useMemo(() => {
    const all = (users.data ?? []) as any[];
    return {
      total: all.length,
      actifs: all.filter((u) => u.statut === "actif").length,
      bloques: all.filter((u) => u.statut !== "actif").length,
    };
  }, [users.data]);


  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-3">
        {[
          { label: "Utilisateurs", value: counters.total, icon: UserCheck },
          { label: "Comptes actifs", value: counters.actifs, icon: ShieldCheck },
          { label: "Suspendus / verrouillés", value: counters.bloques, icon: Lock },
        ].map((kpi) => (
          <Card key={kpi.label}>
            <CardContent className="flex items-center gap-3 p-4">
              <kpi.icon className="h-5 w-5 text-muted-foreground" />
              <div>
                <p className="text-xs text-muted-foreground">{kpi.label}</p>
                <p className="text-xl font-semibold tabular-nums">{kpi.value}</p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card>
        <CardContent className="space-y-4 p-4">
          <div className="flex flex-col gap-2 md:flex-row md:items-center">
            <div className="relative flex-1">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Rechercher un nom, e-mail, matricule…"
                className="pl-8"
              />
            </div>
            <Select value={statutFilter} onValueChange={setStatutFilter}>
              <SelectTrigger className="md:w-44"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="tous">Tous les statuts</SelectItem>
                <SelectItem value="actif">Actif</SelectItem>
                <SelectItem value="suspendu">Suspendu</SelectItem>
                <SelectItem value="verrouille">Verrouillé</SelectItem>
              </SelectContent>
            </Select>
            <Select value={roleFilter} onValueChange={setRoleFilter}>
              <SelectTrigger className="md:w-52"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="tous">Tous les rôles</SelectItem>
                {roles.map((r) => (
                  <SelectItem key={r.code} value={r.code}>{r.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button onClick={() => setForm({ ...emptyForm })}>
              <Plus className="mr-2 h-4 w-4" /> Nouvel utilisateur
            </Button>
          </div>

          <div className="overflow-x-auto rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Utilisateur</TableHead>
                  <TableHead>Matricule</TableHead>
                  <TableHead>Service</TableHead>
                  <TableHead>Rôles</TableHead>
                   <TableHead>Dépôts</TableHead>
                  <TableHead>MFA</TableHead>
                  <TableHead>Statut</TableHead>
                  <TableHead>Dernière connexion</TableHead>
                  <TableHead className="w-10" />

                </TableRow>
              </TableHeader>
              <TableBody>
                {users.isLoading &&
                  Array.from({ length: 5 }).map((_, i) => (
                    <TableRow key={i}>
                      <TableCell colSpan={9}><Skeleton className="h-8 w-full" /></TableCell>
                    </TableRow>
                  ))}
                {!users.isLoading && rows.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={9} className="py-8 text-center text-muted-foreground">
                      Aucun utilisateur ne correspond aux filtres.
                    </TableCell>
                  </TableRow>
                )}
                {rows.map((u) => (
                  <TableRow key={u.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <Avatar className="h-8 w-8">
                          <AvatarImage src={u.avatar_url ?? undefined} alt="" />
                          <AvatarFallback className="text-xs">{initials(u)}</AvatarFallback>
                        </Avatar>
                        <div className="min-w-0">
                          <p className="truncate font-medium">{u.nom_complet || "—"}</p>
                          <p className="truncate text-xs text-muted-foreground">{u.email}</p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="text-sm tabular-nums">{u.matricule || "—"}</TableCell>
                    <TableCell className="text-sm">
                      {labelOf(services as never[], "service_id", "libelle", u.service_id)}
                    </TableCell>
                    <TableCell>
                      <div className="flex flex-wrap gap-1">
                        {u.role_codes.length === 0 && (
                          <span className="text-xs text-muted-foreground">Aucun</span>
                        )}
                        {u.role_codes.map((c) => (
                          <Badge key={c} variant="outline" className="text-xs">
                            {roles.find((r) => r.code === c)?.label ?? c}
                          </Badge>
                        ))}
                      </div>
                    </TableCell>
                    <TableCell className="text-sm">
                      {u.depot_ids.length === 0 ? (
                        <span className="text-xs text-muted-foreground">Tous</span>
                      ) : (
                        `${u.depot_ids.length} dépôt(s)`
                      )}
                    </TableCell>
                    <TableCell>
                      {u.role_codes.includes("super_admin") ? (
                        <Badge variant="secondary" className="bg-slate-100 text-slate-500 border-slate-200">
                          ⚪ EXEMPTÉ
                        </Badge>
                      ) : (
                        <div className="space-y-1.5">
                          <div className="flex items-center gap-2">
                            {u.mfa_enrolled_at ? (
                              <Badge variant="default" className="bg-green-100 text-green-700 hover:bg-green-100 border-green-200 text-[10px] h-5">
                                Configuré
                              </Badge>
                            ) : (
                              <Badge variant="outline" className="text-orange-600 border-orange-200 bg-orange-50 text-[10px] h-5">
                                Non configuré
                              </Badge>
                            )}
                          </div>
                          
                          <div className="flex flex-col gap-1.5 mt-1">
                            <div className="flex items-center gap-1 text-[11px] font-medium text-muted-foreground px-0.5">
                              {u.mfa_required ? (
                                <>
                                  <ShieldCheck className="h-3 w-3 text-green-600" />
                                  <span>MFA — Statut : Activé</span>
                                </>
                              ) : (
                                <>
                                  <ShieldOff className="h-3 w-3 text-slate-400" />
                                  <span>MFA — Statut : Désactivé</span>
                                </>
                              )}
                            </div>
                            
                            <div className="flex items-center gap-1">
                              <Button 
                                variant={u.mfa_required ? "default" : "outline"}
                                size="sm" 
                                className="h-7 flex-1 text-[10px] font-bold"
                                disabled={mfaToggleMutation.isPending}
                                onClick={() => mfaToggleMutation.mutate({ userId: u.id, required: true })}
                              >
                                Activer
                              </Button>
                              <Button 
                                variant={!u.mfa_required ? "default" : "outline"}
                                size="sm" 
                                className="h-7 flex-1 text-[10px] font-bold"
                                disabled={mfaToggleMutation.isPending}
                                onClick={() => mfaToggleMutation.mutate({ userId: u.id, required: false })}
                              >
                                Désactiver
                              </Button>
                            </div>

                            {!u.mfa_enrolled_at && (
                              <Button 
                                variant="ghost" 
                                size="sm" 
                                className="h-6 w-full text-[9px] text-orange-600 hover:text-orange-700 hover:bg-orange-100/50"
                                onClick={() => setMfaEnrollTarget(u)}
                              >
                                [Configurer MFA]
                              </Button>
                            )}
                          </div>
                        </div>
                      )}
                    </TableCell>

                    <TableCell>
                      <Badge variant={STATUT_META[u.statut].variant}>
                        {STATUT_META[u.statut].label}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">
                      {formatDate(u.derniere_connexion)}
                    </TableCell>

                    <TableCell>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon" aria-label="Actions">
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onClick={() => openEdit(u)}>
                            <Pencil className="mr-2 h-4 w-4" /> Modifier
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => setPwdTarget(u)}>
                            <KeyRound className="mr-2 h-4 w-4" /> Réinitialiser le mot de passe
                          </DropdownMenuItem>
                          {u.mfa_enrolled_at ? (
                            !u.role_codes.includes("super_admin") && (
                              <DropdownMenuItem 
                                className="text-orange-600"
                                onClick={() => setMfaResetTarget(u)}
                              >
                                <ShieldOff className="mr-2 h-4 w-4" /> Réinitialiser le MFA
                              </DropdownMenuItem>
                            )
                          ) : (
                            !u.role_codes.includes("super_admin") && (
                              <DropdownMenuItem 
                                className="text-primary font-bold"
                                onClick={() => setMfaEnrollTarget(u)}
                              >
                                <ShieldCheck className="mr-2 h-4 w-4" /> Configurer le MFA
                              </DropdownMenuItem>
                            )
                          )}
                          <DropdownMenuSeparator />

                          {u.statut !== "actif" ? (
                            <DropdownMenuItem
                              onClick={() =>
                                statutMutation.mutate({ user_id: u.id, statut: "actif" })
                              }
                            >
                              <LockOpen className="mr-2 h-4 w-4" /> Réactiver / déverrouiller
                            </DropdownMenuItem>
                          ) : (
                            <>
                              <DropdownMenuItem
                                onClick={() =>
                                  statutMutation.mutate({ user_id: u.id, statut: "suspendu" })
                                }
                              >
                                <UserX className="mr-2 h-4 w-4" /> Suspendre
                              </DropdownMenuItem>
                              <DropdownMenuItem
                                className="text-destructive"
                                onClick={() =>
                                  statutMutation.mutate({ user_id: u.id, statut: "verrouille" })
                                }
                              >
                                <Lock className="mr-2 h-4 w-4" /> Verrouiller
                              </DropdownMenuItem>
                            </>
                          )}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      {/* Formulaire utilisateur ------------------------------------- */}
      <Dialog open={!!form} onOpenChange={(o) => !o && setForm(null)}>
        <DialogContent className="max-h-[90vh] max-w-3xl overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{form?.user_id ? "Modifier l'utilisateur" : "Nouvel utilisateur"}</DialogTitle>
            <DialogDescription>
              Identité, rattachement (service, département, dépôts) et rôles.
            </DialogDescription>
          </DialogHeader>

          {form && (
            <div className="space-y-5">
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label>Matricule</Label>
                  <Input
                    value={form.matricule}
                    onChange={(e) => setForm({ ...form, matricule: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label>Photo (URL)</Label>
                  <Input
                    value={form.avatar_url}
                    onChange={(e) => setForm({ ...form, avatar_url: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label>Nom</Label>
                  <Input value={form.nom} onChange={(e) => setForm({ ...form, nom: e.target.value })} />
                </div>
                <div className="space-y-1.5">
                  <Label>Prénom</Label>
                  <Input
                    value={form.prenom}
                    onChange={(e) => setForm({ ...form, prenom: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5 sm:col-span-2">
                  <Label>Nom affiché *</Label>
                  <Input
                    value={form.nom_complet}
                    onChange={(e) => setForm({ ...form, nom_complet: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label>Téléphone</Label>
                  <Input
                    value={form.telephone}
                    onChange={(e) => setForm({ ...form, telephone: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label>Fonction</Label>
                  <Input
                    value={form.fonction}
                    onChange={(e) => setForm({ ...form, fonction: e.target.value })}
                  />
                </div>
                <div className="space-y-1.5">
                  <Label>E-mail *</Label>
                  <Input
                    type="email"
                    value={form.email}
                    disabled={!!form.user_id}
                    onChange={(e) => setForm({ ...form, email: e.target.value })}
                  />
                </div>
                {!form.user_id && (
                  <div className="space-y-1.5">
                    <Label>Mot de passe initial *</Label>
                    <Input
                      type="password"
                      value={form.password}
                      onChange={(e) => setForm({ ...form, password: e.target.value })}
                    />
                  </div>
                )}
              </div>

              <div className="grid gap-3 sm:grid-cols-3">
                <div className="space-y-1.5">
                  <Label>Service</Label>
                  <Select
                    value={form.service_id}
                    onValueChange={(v) => setForm({ ...form, service_id: v })}
                  >
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value={NONE}>—</SelectItem>
                      {services.map((s) => (
                        <SelectItem key={s.service_id} value={s.service_id}>{s.libelle}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <Label>Département</Label>
                  <Select
                    value={form.departement_id}
                    onValueChange={(v) => setForm({ ...form, departement_id: v })}
                  >
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value={NONE}>—</SelectItem>
                      {departements.map((d) => (
                        <SelectItem key={d.departement_id} value={d.departement_id}>
                          {d.libelle}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <Label>Dépôt principal</Label>
                  <Select
                    value={form.depot_principal_id}
                    onValueChange={(v) =>
                      setForm({
                        ...form,
                        depot_principal_id: v,
                        depot_ids:
                          v !== NONE && !form.depot_ids.includes(v)
                            ? [...form.depot_ids, v]
                            : form.depot_ids,
                      })
                    }
                  >
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value={NONE}>—</SelectItem>
                      {depots.map((d) => (
                        <SelectItem key={d.depot_id} value={d.depot_id}>{d.nom}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="space-y-2">
                <Label>Dépôts autorisés (périmètre)</Label>
                <p className="text-xs text-muted-foreground">
                  Aucun dépôt coché = aucune restriction de dépôt. Le Super Administrateur reste global.
                </p>
                <div className="grid gap-2 rounded-md border p-3 sm:grid-cols-3">
                  {depots.map((d) => (
                    <label key={d.depot_id} className="flex items-center gap-2 text-sm">
                      <Checkbox
                        checked={form.depot_ids.includes(d.depot_id)}
                        onCheckedChange={(c) =>
                          setForm({
                            ...form,
                            depot_ids: c
                              ? [...form.depot_ids, d.depot_id]
                              : form.depot_ids.filter((x) => x !== d.depot_id),
                          })
                        }
                      />
                      {d.nom}
                    </label>
                  ))}
                </div>
              </div>

              <div className="space-y-2">
                <Label>Rôles</Label>
                <div className="grid gap-2 rounded-md border p-3 sm:grid-cols-3">
                  {roles.map((r) => (
                    <label key={r.code} className="flex items-center gap-2 text-sm">
                      <Checkbox
                        checked={form.role_codes.includes(r.code)}
                        onCheckedChange={(c) =>
                          setForm({
                            ...form,
                            role_codes: c
                              ? [...form.role_codes, r.code]
                              : form.role_codes.filter((x) => x !== r.code),
                          })
                        }
                      />
                      {r.label}
                    </label>
                  ))}
                </div>
              </div>
            </div>
          )}

          <DialogFooter>
            <Button variant="outline" onClick={() => setForm(null)}>Annuler</Button>
            <Button
              disabled={saveMutation.isPending || !form?.nom_complet.trim()}
              onClick={() => form && saveMutation.mutate(form)}
            >
              {saveMutation.isPending ? "Enregistrement…" : "Enregistrer"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Réinitialisation mot de passe -------------------------------- */}
      <Dialog open={!!pwdTarget} onOpenChange={(o) => !o && setPwdTarget(null)}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Réinitialiser le mot de passe</DialogTitle>
            <DialogDescription>{pwdTarget?.email}</DialogDescription>
          </DialogHeader>
          <div className="space-y-1.5">
            <Label>Nouveau mot de passe (8 caractères min.)</Label>
            <Input type="password" value={pwdValue} onChange={(e) => setPwdValue(e.target.value)} />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPwdTarget(null)}>Annuler</Button>
            <Button
              disabled={pwdValue.length < 8 || pwdMutation.isPending}
              onClick={() =>
                pwdTarget &&
                pwdMutation.mutate({ user_id: pwdTarget.id, new_password: pwdValue })
              }
            >
              Réinitialiser
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <AlertDialog open={!!mfaResetTarget} onOpenChange={(open) => !open && setMfaResetTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2 text-orange-600">
              <ShieldOff className="h-5 w-5" />
              RÉINITIALISER LE MFA ?
            </AlertDialogTitle>
            <AlertDialogDescription className="space-y-4 pt-2 text-slate-700">
              <p>
                Êtes-vous certain de vouloir réinitialiser le MFA de l'utilisateur{" "}
                <span className="font-bold text-slate-900">{mfaResetTarget?.nom_complet || mfaResetTarget?.email}</span> ?
              </p>
              
              <div className="bg-orange-50 p-3 rounded-md border border-orange-100 text-xs space-y-2">
                <p className="flex items-start gap-2">
                  <span className="mt-0.5">•</span>
                  <span><strong>ACTION IRRÉVERSIBLE :</strong> L'utilisateur devra obligatoirement reconfigurer son MFA (QR Code) pour accéder à nouveau au système.</span>
                </p>
                <p className="flex items-start gap-2">
                  <span className="mt-0.5">•</span>
                  <span><strong>SÉCURITÉ :</strong> Utilisez cette option uniquement si l'utilisateur a perdu son téléphone ET ses codes de secours.</span>
                </p>
                <p className="flex items-start gap-2 font-medium text-orange-800">
                  <AlertCircle className="h-3 w-3 mt-0.5" />
                  <span>Cette opération est tracée dans le journal d'audit de sécurité.</span>
                </p>
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>

          <AlertDialogFooter>
            <AlertDialogCancel>Annuler</AlertDialogCancel>
            <AlertDialogAction
              className="bg-orange-600 hover:bg-orange-700"
              onClick={() => mfaResetMutation.mutate(mfaResetTarget!.id)}
              disabled={mfaResetMutation.isPending}
            >
              {mfaResetMutation.isPending ? "Réinitialisation..." : "Confirmer la réinitialisation"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <Dialog open={!!mfaEnrollTarget} onOpenChange={(open) => !open && setMfaEnrollTarget(null)}>
        <DialogContent className="max-w-2xl p-0 overflow-hidden border-none bg-transparent shadow-none sm:max-w-xl w-[95vw] h-fit max-h-[96vh]">
          {mfaEnrollTarget && (
            <MfaEnrollView 
              targetUserId={mfaEnrollTarget.id}
              targetUserLabel={mfaEnrollTarget.nom_complet || mfaEnrollTarget.email || undefined}
              onSuccess={() => {
                setMfaEnrollTarget(null);
                invalidate();
              }} 
            />
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}

