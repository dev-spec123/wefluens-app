/* eslint-disable */
// AUTO-GENERATED — DO NOT EDIT
// Run migrations to regenerate.

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
      brands: {
        Row: {
          active_campaigns: number | null
          category: string | null
          colors: string | null
          created_at: string | null
          id: string
          name: string
          symbol: string | null
          tagline: string | null
        }
        Insert: {
          active_campaigns?: number | null
          category?: string | null
          colors?: string | null
          created_at?: string | null
          id?: string
          name: string
          symbol?: string | null
          tagline?: string | null
        }
        Update: {
          active_campaigns?: number | null
          category?: string | null
          colors?: string | null
          created_at?: string | null
          id?: string
          name?: string
          symbol?: string | null
          tagline?: string | null
        }
        Relationships: []
      }
      campaigns: {
        Row: {
          brand: string
          brand_id: string | null
          budget: string | null
          colors: string | null
          created_at: string | null
          deadline: string | null
          id: string
          spots_left: number | null
          symbol: string | null
          tags: string[] | null
          title: string
        }
        Insert: {
          brand: string
          brand_id?: string | null
          budget?: string | null
          colors?: string | null
          created_at?: string | null
          deadline?: string | null
          id?: string
          spots_left?: number | null
          symbol?: string | null
          tags?: string[] | null
          title: string
        }
        Update: {
          brand?: string
          brand_id?: string | null
          budget?: string | null
          colors?: string | null
          created_at?: string | null
          deadline?: string | null
          id?: string
          spots_left?: number | null
          symbol?: string | null
          tags?: string[] | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "campaigns_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
        ]
      }
      contacts: {
        Row: {
          avatar_colors: string | null
          created_at: string | null
          followers: string | null
          handle: string | null
          id: string
          is_online: boolean | null
          name: string
          platform: string | null
          role: string | null
          user_id: string
        }
        Insert: {
          avatar_colors?: string | null
          created_at?: string | null
          followers?: string | null
          handle?: string | null
          id?: string
          is_online?: boolean | null
          name: string
          platform?: string | null
          role?: string | null
          user_id: string
        }
        Update: {
          avatar_colors?: string | null
          created_at?: string | null
          followers?: string | null
          handle?: string | null
          id?: string
          is_online?: boolean | null
          name?: string
          platform?: string | null
          role?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contacts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      conversations: {
        Row: {
          avatar: string | null
          avatar_colors: string | null
          created_at: string | null
          id: string
          is_group: boolean | null
          is_official: boolean | null
          is_online: boolean | null
          is_pinned: boolean | null
          last_message: string | null
          name: string
          participant_count: number | null
          time: string | null
          unread: number | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          avatar?: string | null
          avatar_colors?: string | null
          created_at?: string | null
          id?: string
          is_group?: boolean | null
          is_official?: boolean | null
          is_online?: boolean | null
          is_pinned?: boolean | null
          last_message?: string | null
          name: string
          participant_count?: number | null
          time?: string | null
          unread?: number | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          avatar?: string | null
          avatar_colors?: string | null
          created_at?: string | null
          id?: string
          is_group?: boolean | null
          is_official?: boolean | null
          is_online?: boolean | null
          is_pinned?: boolean | null
          last_message?: string | null
          name?: string
          participant_count?: number | null
          time?: string | null
          unread?: number | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "conversations_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      friend_requests: {
        Row: {
          avatar_colors: string | null
          created_at: string | null
          from_user_id: string
          handle: string | null
          id: string
          name: string
          request_message: string | null
          role: string | null
          status: string | null
          to_user_id: string
        }
        Insert: {
          avatar_colors?: string | null
          created_at?: string | null
          from_user_id: string
          handle?: string | null
          id?: string
          name: string
          request_message?: string | null
          role?: string | null
          status?: string | null
          to_user_id: string
        }
        Update: {
          avatar_colors?: string | null
          created_at?: string | null
          from_user_id?: string
          handle?: string | null
          id?: string
          name?: string
          request_message?: string | null
          role?: string | null
          status?: string | null
          to_user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "friend_requests_from_user_id_fkey"
            columns: ["from_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friend_requests_to_user_id_fkey"
            columns: ["to_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      invites: {
        Row: {
          activated_at: string | null
          created_at: string | null
          email: string
          expires_at: string
          id: string
          invited_by: string | null
          status: string
          token: string
        }
        Insert: {
          activated_at?: string | null
          created_at?: string | null
          email: string
          expires_at?: string
          id?: string
          invited_by?: string | null
          status?: string
          token: string
        }
        Update: {
          activated_at?: string | null
          created_at?: string | null
          email?: string
          expires_at?: string
          id?: string
          invited_by?: string | null
          status?: string
          token?: string
        }
        Relationships: []
      }
      messages: {
        Row: {
          conversation_id: string
          created_at: string | null
          id: string
          sender_id: string
          text: string
          time: string | null
        }
        Insert: {
          conversation_id: string
          created_at?: string | null
          id?: string
          sender_id: string
          text: string
          time?: string | null
        }
        Update: {
          conversation_id?: string
          created_at?: string | null
          id?: string
          sender_id?: string
          text?: string
          time?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          bio: string | null
          created_at: string | null
          deals: string | null
          email: string | null
          engagement: string | null
          followers: string | null
          handle: string | null
          id: string
          is_admin: boolean | null
          is_banned: boolean | null
          location: string | null
          must_change_password: boolean | null
          name: string | null
          role: string | null
          updated_at: string | null
        }
        Insert: {
          avatar_url?: string | null
          bio?: string | null
          created_at?: string | null
          deals?: string | null
          email?: string | null
          engagement?: string | null
          followers?: string | null
          handle?: string | null
          id: string
          is_admin?: boolean | null
          is_banned?: boolean | null
          location?: string | null
          must_change_password?: boolean | null
          name?: string | null
          role?: string | null
          updated_at?: string | null
        }
        Update: {
          avatar_url?: string | null
          bio?: string | null
          created_at?: string | null
          deals?: string | null
          email?: string | null
          engagement?: string | null
          followers?: string | null
          handle?: string | null
          id?: string
          is_admin?: boolean | null
          is_banned?: boolean | null
          location?: string | null
          must_change_password?: boolean | null
          name?: string | null
          role?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_ban_user: {
        Args: { ban: boolean; target_id: string }
        Returns: undefined
      }
      admin_delete_user: { Args: { target_id: string }; Returns: undefined }
      is_admin: { Args: { uid: string }; Returns: boolean }
      user_id: { Args: never; Returns: string }
    }
    Enums: {
      [_ in never]: never
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
    Enums: {},
  },
} as const
