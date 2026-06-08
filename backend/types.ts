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
      app_secrets: {
        Row: {
          key: string
          updated_at: string | null
          value: string
        }
        Insert: {
          key: string
          updated_at?: string | null
          value: string
        }
        Update: {
          key?: string
          updated_at?: string | null
          value?: string
        }
        Relationships: []
      }
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
      dm_messages: {
        Row: {
          body: string
          created_at: string | null
          duration_ms: number | null
          file_mime: string | null
          file_name: string | null
          file_size: number | null
          id: string
          image_height: number | null
          image_url: string | null
          image_width: number | null
          message_type: string
          read_at: string | null
          recipient_id: string
          reply_to_message_id: string | null
          sender_id: string
          thread_id: string
          thumb_url: string | null
        }
        Insert: {
          body: string
          created_at?: string | null
          duration_ms?: number | null
          file_mime?: string | null
          file_name?: string | null
          file_size?: number | null
          id?: string
          image_height?: number | null
          image_url?: string | null
          image_width?: number | null
          message_type?: string
          read_at?: string | null
          recipient_id: string
          reply_to_message_id?: string | null
          sender_id: string
          thread_id: string
          thumb_url?: string | null
        }
        Update: {
          body?: string
          created_at?: string | null
          duration_ms?: number | null
          file_mime?: string | null
          file_name?: string | null
          file_size?: number | null
          id?: string
          image_height?: number | null
          image_url?: string | null
          image_width?: number | null
          message_type?: string
          read_at?: string | null
          recipient_id?: string
          reply_to_message_id?: string | null
          sender_id?: string
          thread_id?: string
          thumb_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "dm_messages_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dm_messages_reply_to_message_id_fkey"
            columns: ["reply_to_message_id"]
            isOneToOne: false
            referencedRelation: "dm_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dm_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dm_messages_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "dm_threads"
            referencedColumns: ["id"]
          },
        ]
      }
      dm_threads: {
        Row: {
          created_at: string | null
          id: string
          last_message: string | null
          last_message_at: string | null
          last_message_type: string
          last_sender_id: string | null
          user_high: string
          user_low: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          last_message?: string | null
          last_message_at?: string | null
          last_message_type?: string
          last_sender_id?: string | null
          user_high: string
          user_low: string
        }
        Update: {
          created_at?: string | null
          id?: string
          last_message?: string | null
          last_message_at?: string | null
          last_message_type?: string
          last_sender_id?: string | null
          user_high?: string
          user_low?: string
        }
        Relationships: [
          {
            foreignKeyName: "dm_threads_user_high_fkey"
            columns: ["user_high"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dm_threads_user_low_fkey"
            columns: ["user_low"]
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
          seen_by_sender: boolean | null
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
          seen_by_sender?: boolean | null
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
          seen_by_sender?: boolean | null
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
      friendships: {
        Row: {
          created_at: string | null
          friend_id: string
          id: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          friend_id: string
          id?: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          friend_id?: string
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "friendships_friend_id_fkey"
            columns: ["friend_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friendships_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_members: {
        Row: {
          group_id: string
          joined_at: string
          last_read_at: string
          role: string
          user_id: string
        }
        Insert: {
          group_id: string
          joined_at?: string
          last_read_at?: string
          role?: string
          user_id: string
        }
        Update: {
          group_id?: string
          joined_at?: string
          last_read_at?: string
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "group_threads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_messages: {
        Row: {
          body: string
          created_at: string
          duration_ms: number | null
          file_mime: string | null
          file_name: string | null
          file_size: number | null
          group_id: string
          id: string
          image_height: number | null
          image_url: string | null
          image_width: number | null
          message_type: string
          read_at: string | null
          reply_to_message_id: string | null
          sender_id: string
          thumb_url: string | null
        }
        Insert: {
          body?: string
          created_at?: string
          duration_ms?: number | null
          file_mime?: string | null
          file_name?: string | null
          file_size?: number | null
          group_id: string
          id?: string
          image_height?: number | null
          image_url?: string | null
          image_width?: number | null
          message_type?: string
          read_at?: string | null
          reply_to_message_id?: string | null
          sender_id: string
          thumb_url?: string | null
        }
        Update: {
          body?: string
          created_at?: string
          duration_ms?: number | null
          file_mime?: string | null
          file_name?: string | null
          file_size?: number | null
          group_id?: string
          id?: string
          image_height?: number | null
          image_url?: string | null
          image_width?: number | null
          message_type?: string
          read_at?: string | null
          reply_to_message_id?: string | null
          sender_id?: string
          thumb_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_messages_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "group_threads"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_messages_reply_to_message_id_fkey"
            columns: ["reply_to_message_id"]
            isOneToOne: false
            referencedRelation: "group_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      group_threads: {
        Row: {
          avatar_url: string | null
          created_at: string
          created_by: string
          id: string
          last_message: string | null
          last_message_at: string | null
          last_message_type: string
          last_sender_id: string | null
          name: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          created_by: string
          id?: string
          last_message?: string | null
          last_message_at?: string | null
          last_message_type?: string
          last_sender_id?: string | null
          name?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          created_by?: string
          id?: string
          last_message?: string | null
          last_message_at?: string | null
          last_message_type?: string
          last_sender_id?: string | null
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_threads_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_threads_last_sender_id_fkey"
            columns: ["last_sender_id"]
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
      are_friends: { Args: { a: string; b: string }; Returns: boolean }
      create_group: {
        Args: { p_member_ids: string[]; p_name: string }
        Returns: string
      }
      get_or_create_thread: { Args: { p_other: string }; Returns: string }
      is_admin: { Args: { uid: string }; Returns: boolean }
      is_group_member: {
        Args: { p_group: string; p_uid: string }
        Returns: boolean
      }
      list_dm_threads: {
        Args: never
        Returns: {
          last_message: string
          last_message_at: string
          last_message_type: string
          last_sender_id: string
          other_avatar_url: string
          other_handle: string
          other_id: string
          other_name: string
          other_role: string
          thread_id: string
          unread_count: number
        }[]
      }
      list_group_threads: {
        Args: never
        Returns: {
          avatar_url: string
          created_by: string
          group_id: string
          last_message: string
          last_message_at: string
          last_message_type: string
          last_sender_id: string
          member_count: number
          name: string
          unread_count: number
        }[]
      }
      mark_group_read: { Args: { p_group: string }; Returns: undefined }
      mark_thread_read: { Args: { p_thread: string }; Returns: undefined }
      remove_friend: { Args: { target_id: string }; Returns: string }
      respond_friend_request: {
        Args: { accept: boolean; request_id: string }
        Returns: string
      }
      search_users: {
        Args: { search_query: string }
        Returns: {
          avatar_url: string
          followers: string
          handle: string
          id: string
          incoming_request_id: string
          name: string
          relationship: string
          role: string
        }[]
      }
      send_dm: {
        Args: { p_body: string; p_other: string; p_reply_to?: string }
        Returns: string
      }
      send_dm_attachment: {
        Args: {
          p_caption?: string
          p_duration_ms?: number
          p_file_mime?: string
          p_file_name?: string
          p_file_size?: number
          p_height?: number
          p_other: string
          p_path: string
          p_reply_to?: string
          p_thumb_path?: string
          p_type: string
          p_width?: number
        }
        Returns: string
      }
      send_dm_media: {
        Args: {
          p_caption?: string
          p_height?: number
          p_image_url: string
          p_other: string
          p_reply_to?: string
          p_width?: number
        }
        Returns: string
      }
      send_friend_request: {
        Args: { message?: string; target_id: string }
        Returns: string
      }
      send_group_message: {
        Args: { p_body: string; p_group: string; p_reply_to?: string }
        Returns: string
      }
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
