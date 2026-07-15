export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      clients: {
        Row: {
          actif: boolean
          adresse: string | null
          bp: string | null
          categorie: string | null
          client_id: string
          commune: string | null
          contact_principal: string | null
          created_at: string
          delai_paiement: number | null
          email: string | null
          mode_paiement: string | null
          motif_blocage: string | null
          nif: string | null
          nom: string
          notes: string | null
          pays: string | null
          plafond_credit: number | null
          quartier: string | null
          reference: string | null
          regime_fiscal: string | null
          remise_habituelle: number | null
          representant: string | null
          secteur_activite: string | null
          solde: number | null
          solde_points: number | null
          statut: string | null
          telephone: string | null
          telephone2: string | null
          type_client: string | null
          updated_at: string
          ville: string | null
        }
        Insert: {
          actif?: boolean
          adresse?: string | null
          bp?: string | null
          categorie?: string | null
          client_id?: string
          commune?: string | null
          contact_principal?: string | null
          created_at?: string
          delai_paiement?: number | null
          email?: string | null
          mode_paiement?: string | null
          motif_blocage?: string | null
          nif?: string | null
          nom: string
          notes?: string | null
          pays?: string | null
          plafond_credit?: number | null
          quartier?: string | null
          reference?: string | null
          regime_fiscal?: string | null
          remise_habituelle?: number | null
          representant?: string | null
          secteur_activite?: string | null
          solde?: number | null
          solde_points?: number | null
          statut?: string | null
          telephone?: string | null
          telephone2?: string | null
          type_client?: string | null
          updated_at?: string
          ville?: string | null
        }
        Update: {
          actif?: boolean
          adresse?: string | null
          bp?: string | null
          categorie?: string | null
          client_id?: string
          commune?: string | null
          contact_principal?: string | null
          created_at?: string
          delai_paiement?: number | null
          email?: string | null
          mode_paiement?: string | null
          motif_blocage?: string | null
          nif?: string | null
          nom?: string
          notes?: string | null
          pays?: string | null
          plafond_credit?: number | null
          quartier?: string | null
          reference?: string | null
          regime_fiscal?: string | null
          remise_habituelle?: number | null
          representant?: string | null
          secteur_activite?: string | null
          solde?: number | null
          solde_points?: number | null
          statut?: string | null
          telephone?: string | null
          telephone2?: string | null
          type_client?: string | null
          updated_at?: string
          ville?: string | null
        }
        Relationships: []
      }
      produits: {
        Row: {
          actif: boolean
          auteur: string | null
          categorie: string | null
          categorie_id: string | null
          cover_path: string | null
          cover_thumb_path: string | null
          cover_updated_at: string | null
          created_at: string
          editeur: string | null
          isbn: string | null
          matiere: string | null
          niveau: string | null
          niveau_ordre: number | null
          pin_order: number | null
          prix_achat: number
          prix_vente: number
          produit_id: string
          reference: string | null
          seuil_alerte: number | null
          titre: string
          updated_at: string
        }
        Insert: {
          actif?: boolean
          auteur?: string | null
          categorie?: string | null
          categorie_id?: string | null
          cover_path?: string | null
          cover_thumb_path?: string | null
          cover_updated_at?: string | null
          created_at?: string
          editeur?: string | null
          isbn?: string | null
          matiere?: string | null
          niveau?: string | null
          niveau_ordre?: number | null
          pin_order?: number | null
          prix_achat?: number
          prix_vente?: number
          produit_id?: string
          reference?: string | null
          seuil_alerte?: number | null
          titre: string
          updated_at?: string
        }
        Update: {
          actif?: boolean
          auteur?: string | null
          categorie?: string | null
          categorie_id?: string | null
          cover_path?: string | null
          cover_thumb_path?: string | null
          cover_updated_at?: string | null
          created_at?: string
          editeur?: string | null
          isbn?: string | null
          matiere?: string | null
          niveau?: string | null
          niveau_ordre?: number | null
          pin_order?: number | null
          prix_achat?: number
          prix_vente?: number
          produit_id?: string
          reference?: string | null
          seuil_alerte?: number | null
          titre?: string
          updated_at?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          actif: boolean
          avatar_url: string | null
          created_at: string
          departement: string | null
          email: string | null
          fonction: string | null
          id: string
          mfa_enrolled_at: string | null
          mfa_required: boolean
          nom_complet: string | null
          prenom: string | null
          telephone: string | null
          updated_at: string
        }
        Insert: {
          actif?: boolean
          avatar_url?: string | null
          created_at?: string
          departement?: string | null
          email?: string | null
          fonction?: string | null
          id: string
          mfa_enrolled_at?: string | null
          mfa_required?: boolean
          nom_complet?: string | null
          prenom?: string | null
          telephone?: string | null
          updated_at?: string
        }
        Update: {
          actif?: boolean
          avatar_url?: string | null
          created_at?: string
          departement?: string | null
          email?: string | null
          fonction?: string | null
          id?: string
          mfa_enrolled_at?: string | null
          mfa_required?: boolean
          nom_complet?: string | null
          prenom?: string | null
          telephone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      rbac_audit_log: {
        Row: {
          action: string
          apres: Json | null
          avant: Json | null
          created_at: string
          details: Json
          id: string
          ip: string | null
          role_code: string | null
          role_id: string | null
          user_agent: string | null
          user_email: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          apres?: Json | null
          avant?: Json | null
          created_at?: string
          details?: Json
          id?: string
          ip?: string | null
          role_code?: string | null
          role_id?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          apres?: Json | null
          avant?: Json | null
          created_at?: string
          details?: Json
          id?: string
          ip?: string | null
          role_code?: string | null
          role_id?: string | null
          user_agent?: string | null
          user_email?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      rbac_permissions: {
        Row: {
          action: string
          code: string
          created_at: string
          description: string | null
          libelle: string
          module: string
          sous_module: string | null
        }
        Insert: {
          action: string
          code: string
          created_at?: string
          description?: string | null
          libelle: string
          module: string
          sous_module?: string | null
        }
        Update: {
          action?: string
          code?: string
          created_at?: string
          description?: string | null
          libelle?: string
          module?: string
          sous_module?: string | null
        }
        Relationships: []
      }
      rbac_role_permissions: {
        Row: {
          accorde: boolean
          created_at: string
          permission_code: string
          role_id: string
        }
        Insert: {
          accorde?: boolean
          created_at?: string
          permission_code: string
          role_id: string
        }
        Update: {
          accorde?: boolean
          created_at?: string
          permission_code?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "rbac_role_permissions_permission_code_fkey"
            columns: ["permission_code"]
            isOneToOne: false
            referencedRelation: "rbac_permissions"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "rbac_role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "rbac_roles"
            referencedColumns: ["role_id"]
          },
        ]
      }
      rbac_roles: {
        Row: {
          actif: boolean
          code: string
          created_at: string
          description: string | null
          hierite_de: string | null
          id: string
          libelle: string
          role_id: string
          systeme: boolean
          updated_at: string
        }
        Insert: {
          actif?: boolean
          code: string
          created_at?: string
          description?: string | null
          hierite_de?: string | null
          id?: string
          libelle: string
          role_id?: string
          systeme?: boolean
          updated_at?: string
        }
        Update: {
          actif?: boolean
          code?: string
          created_at?: string
          description?: string | null
          hierite_de?: string | null
          id?: string
          libelle?: string
          role_id?: string
          systeme?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rbac_roles_hierite_de_fkey"
            columns: ["hierite_de"]
            isOneToOne: false
            referencedRelation: "rbac_roles"
            referencedColumns: ["role_id"]
          },
        ]
      }
      rbac_user_roles: {
        Row: {
          assigned_at: string
          assigned_by: string | null
          created_at: string
          id: string
          rbac_role_id: string | null
          role_id: string
          user_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by?: string | null
          created_at?: string
          id?: string
          rbac_role_id?: string | null
          role_id: string
          user_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string | null
          created_at?: string
          id?: string
          rbac_role_id?: string | null
          role_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "rbac_user_roles_rbac_role_id_fkey"
            columns: ["rbac_role_id"]
            isOneToOne: false
            referencedRelation: "rbac_roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rbac_user_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "rbac_roles"
            referencedColumns: ["role_id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      assert_permission: { Args: { _perm: string }; Returns: undefined }
      has_permission_v2: {
        Args: { _perm: string; _user_id: string }
        Returns: boolean
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      list_user_permissions: {
        Args: { _user_id: string }
        Returns: {
          permission_code: string
        }[]
      }
      log_permission_denied: {
        Args: { _context?: Json; _perm: string }
        Returns: undefined
      }
      rbac_bulk_set_permissions: {
        Args: { _accorde: boolean; _codes: string[]; _role_id: string }
        Returns: undefined
      }
      rbac_role_ancestors: {
        Args: { _role_id: string }
        Returns: {
          role_id: string
        }[]
      }
      rbac_set_role_permission: {
        Args: { _accorde: boolean; _code: string; _role_id: string }
        Returns: undefined
      }
    }
    Enums: {
      app_role:
        | "super_admin"
        | "directeur_general"
        | "comptable"
        | "directeur_commercial"
        | "gestionnaire_stock"
        | "responsable_magasinier"
        | "secretariat"
        | "assistante"
        | "service_logistique"
        | "assistante_comptable"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: [
        "super_admin",
        "directeur_general",
        "comptable",
        "directeur_commercial",
        "gestionnaire_stock",
        "responsable_magasinier",
        "secretariat",
        "assistante",
        "service_logistique",
        "assistante_comptable",
      ],
    },
  },
} as const
