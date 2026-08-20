export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      addresses: {
        Row: {
          address_line1: string
          address_line2: string | null
          area: string | null
          city: string
          contact_name: string | null
          contact_phone: string | null
          country_code: string
          created_at: string
          deleted_at: string | null
          delivery_instructions: string | null
          distance_km: number | null
          formatted_address: string | null
          google_place_id: string | null
          id: string
          is_default: boolean
          is_serviceable: boolean | null
          label: string
          landmark: string | null
          latitude: number
          location_source: string
          longitude: number
          postal_code: string | null
          resolved_branch_id: string | null
          resolved_zone_id: string | null
          serviceability_checked_at: string | null
          state: string
          updated_at: string
          user_id: string
        }
        Insert: {
          address_line1: string
          address_line2?: string | null
          area?: string | null
          city: string
          contact_name?: string | null
          contact_phone?: string | null
          country_code?: string
          created_at?: string
          deleted_at?: string | null
          delivery_instructions?: string | null
          distance_km?: number | null
          formatted_address?: string | null
          google_place_id?: string | null
          id?: string
          is_default?: boolean
          is_serviceable?: boolean | null
          label?: string
          landmark?: string | null
          latitude: number
          location_source?: string
          longitude: number
          postal_code?: string | null
          resolved_branch_id?: string | null
          resolved_zone_id?: string | null
          serviceability_checked_at?: string | null
          state: string
          updated_at?: string
          user_id: string
        }
        Update: {
          address_line1?: string
          address_line2?: string | null
          area?: string | null
          city?: string
          contact_name?: string | null
          contact_phone?: string | null
          country_code?: string
          created_at?: string
          deleted_at?: string | null
          delivery_instructions?: string | null
          distance_km?: number | null
          formatted_address?: string | null
          google_place_id?: string | null
          id?: string
          is_default?: boolean
          is_serviceable?: boolean | null
          label?: string
          landmark?: string | null
          latitude?: number
          location_source?: string
          longitude?: number
          postal_code?: string | null
          resolved_branch_id?: string | null
          resolved_zone_id?: string | null
          serviceability_checked_at?: string | null
          state?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "addresses_resolved_branch_id_fkey"
            columns: ["resolved_branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "addresses_resolved_zone_id_fkey"
            columns: ["resolved_zone_id"]
            isOneToOne: false
            referencedRelation: "delivery_zones"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "addresses_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: Database["public"]["Enums"]["audit_action"]
          actor_id: string | null
          actor_kind: Database["public"]["Enums"]["actor_kind"]
          actor_name: string | null
          actor_role: Database["public"]["Enums"]["app_role"] | null
          branch_id: string | null
          changed_fields: string[] | null
          created_at: string
          entity_id: string | null
          entity_label: string | null
          entity_type: string
          id: number
          ip_address: unknown
          new_value: Json | null
          old_value: Json | null
          reason: string | null
          request_id: string | null
          user_agent: string | null
        }
        Insert: {
          action: Database["public"]["Enums"]["audit_action"]
          actor_id?: string | null
          actor_kind?: Database["public"]["Enums"]["actor_kind"]
          actor_name?: string | null
          actor_role?: Database["public"]["Enums"]["app_role"] | null
          branch_id?: string | null
          changed_fields?: string[] | null
          created_at?: string
          entity_id?: string | null
          entity_label?: string | null
          entity_type: string
          id?: number
          ip_address?: unknown
          new_value?: Json | null
          old_value?: Json | null
          reason?: string | null
          request_id?: string | null
          user_agent?: string | null
        }
        Update: {
          action?: Database["public"]["Enums"]["audit_action"]
          actor_id?: string | null
          actor_kind?: Database["public"]["Enums"]["actor_kind"]
          actor_name?: string | null
          actor_role?: Database["public"]["Enums"]["app_role"] | null
          branch_id?: string | null
          changed_fields?: string[] | null
          created_at?: string
          entity_id?: string | null
          entity_label?: string | null
          entity_type?: string
          id?: number
          ip_address?: unknown
          new_value?: Json | null
          old_value?: Json | null
          reason?: string | null
          request_id?: string | null
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_profile_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      branch_holidays: {
        Row: {
          branch_id: string
          closes_at: string | null
          created_at: string
          holiday_on: string
          id: string
          is_closed: boolean
          label: string
          opens_at: string | null
          updated_at: string
        }
        Insert: {
          branch_id: string
          closes_at?: string | null
          created_at?: string
          holiday_on: string
          id?: string
          is_closed?: boolean
          label: string
          opens_at?: string | null
          updated_at?: string
        }
        Update: {
          branch_id?: string
          closes_at?: string | null
          created_at?: string
          holiday_on?: string
          id?: string
          is_closed?: boolean
          label?: string
          opens_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "branch_holidays_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      branch_hours: {
        Row: {
          branch_id: string
          closes_at: string
          closes_next_day: boolean
          created_at: string
          day_of_week: number
          day_part: Database["public"]["Enums"]["day_part"]
          id: string
          is_closed: boolean
          opens_at: string
          updated_at: string
        }
        Insert: {
          branch_id: string
          closes_at: string
          closes_next_day?: boolean
          created_at?: string
          day_of_week: number
          day_part?: Database["public"]["Enums"]["day_part"]
          id?: string
          is_closed?: boolean
          opens_at: string
          updated_at?: string
        }
        Update: {
          branch_id?: string
          closes_at?: string
          closes_next_day?: boolean
          created_at?: string
          day_of_week?: number
          day_part?: Database["public"]["Enums"]["day_part"]
          id?: string
          is_closed?: boolean
          opens_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "branch_hours_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      branch_status_log: {
        Row: {
          accepting_orders: boolean
          actor_kind: Database["public"]["Enums"]["actor_kind"]
          branch_id: string
          changed_by: string | null
          created_at: string
          id: string
          note: string | null
          previous_status: Database["public"]["Enums"]["branch_status"] | null
          reason: Database["public"]["Enums"]["branch_closure_reason"] | null
          status: Database["public"]["Enums"]["branch_status"]
        }
        Insert: {
          accepting_orders: boolean
          actor_kind?: Database["public"]["Enums"]["actor_kind"]
          branch_id: string
          changed_by?: string | null
          created_at?: string
          id?: string
          note?: string | null
          previous_status?: Database["public"]["Enums"]["branch_status"] | null
          reason?: Database["public"]["Enums"]["branch_closure_reason"] | null
          status: Database["public"]["Enums"]["branch_status"]
        }
        Update: {
          accepting_orders?: boolean
          actor_kind?: Database["public"]["Enums"]["actor_kind"]
          branch_id?: string
          changed_by?: string | null
          created_at?: string
          id?: string
          note?: string | null
          previous_status?: Database["public"]["Enums"]["branch_status"] | null
          reason?: Database["public"]["Enums"]["branch_closure_reason"] | null
          status?: Database["public"]["Enums"]["branch_status"]
        }
        Relationships: [
          {
            foreignKeyName: "branch_status_log_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      branches: {
        Row: {
          accepting_orders: boolean
          address_line1: string
          address_line2: string | null
          alternate_phone: string | null
          auto_resume_at: string | null
          city: string
          code: string
          country_code: string
          created_at: string
          created_by: string | null
          currency_code: string
          default_prep_minutes: number
          deleted_at: string | null
          display_order: number
          email: string | null
          fssai_licence_no: string | null
          fssai_valid_till: string | null
          google_maps_url: string | null
          google_place_id: string | null
          gstin: string | null
          id: string
          is_active: boolean
          is_default: boolean
          landmark: string | null
          latitude: number
          legal_name: string | null
          longitude: number
          max_concurrent_orders: number | null
          name: string
          phone: string
          postal_code: string
          rush_buffer_minutes: number
          service_mode: Database["public"]["Enums"]["service_mode"]
          slug: string
          state: string
          status: Database["public"]["Enums"]["branch_status"]
          status_changed_at: string
          status_changed_by: string | null
          status_note: string | null
          status_reason:
            | Database["public"]["Enums"]["branch_closure_reason"]
            | null
          timezone: string
          updated_at: string
          updated_by: string | null
          whatsapp_phone: string | null
        }
        Insert: {
          accepting_orders?: boolean
          address_line1: string
          address_line2?: string | null
          alternate_phone?: string | null
          auto_resume_at?: string | null
          city: string
          code: string
          country_code?: string
          created_at?: string
          created_by?: string | null
          currency_code?: string
          default_prep_minutes?: number
          deleted_at?: string | null
          display_order?: number
          email?: string | null
          fssai_licence_no?: string | null
          fssai_valid_till?: string | null
          google_maps_url?: string | null
          google_place_id?: string | null
          gstin?: string | null
          id?: string
          is_active?: boolean
          is_default?: boolean
          landmark?: string | null
          latitude: number
          legal_name?: string | null
          longitude: number
          max_concurrent_orders?: number | null
          name: string
          phone: string
          postal_code: string
          rush_buffer_minutes?: number
          service_mode?: Database["public"]["Enums"]["service_mode"]
          slug: string
          state: string
          status?: Database["public"]["Enums"]["branch_status"]
          status_changed_at?: string
          status_changed_by?: string | null
          status_note?: string | null
          status_reason?:
            | Database["public"]["Enums"]["branch_closure_reason"]
            | null
          timezone?: string
          updated_at?: string
          updated_by?: string | null
          whatsapp_phone?: string | null
        }
        Update: {
          accepting_orders?: boolean
          address_line1?: string
          address_line2?: string | null
          alternate_phone?: string | null
          auto_resume_at?: string | null
          city?: string
          code?: string
          country_code?: string
          created_at?: string
          created_by?: string | null
          currency_code?: string
          default_prep_minutes?: number
          deleted_at?: string | null
          display_order?: number
          email?: string | null
          fssai_licence_no?: string | null
          fssai_valid_till?: string | null
          google_maps_url?: string | null
          google_place_id?: string | null
          gstin?: string | null
          id?: string
          is_active?: boolean
          is_default?: boolean
          landmark?: string | null
          latitude?: number
          legal_name?: string | null
          longitude?: number
          max_concurrent_orders?: number | null
          name?: string
          phone?: string
          postal_code?: string
          rush_buffer_minutes?: number
          service_mode?: Database["public"]["Enums"]["service_mode"]
          slug?: string
          state?: string
          status?: Database["public"]["Enums"]["branch_status"]
          status_changed_at?: string
          status_changed_by?: string | null
          status_note?: string | null
          status_reason?:
            | Database["public"]["Enums"]["branch_closure_reason"]
            | null
          timezone?: string
          updated_at?: string
          updated_by?: string | null
          whatsapp_phone?: string | null
        }
        Relationships: []
      }
      campaign_recipients: {
        Row: {
          campaign_id: string
          user_id: string
        }
        Insert: {
          campaign_id: string
          user_id: string
        }
        Update: {
          campaign_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "campaign_recipients_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "notification_campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      cancellation_policies: {
        Row: {
          branch_id: string | null
          cancellation_fee: number
          created_at: string
          customer_can_cancel: boolean
          customer_message: string | null
          grace_period_seconds: number
          id: string
          is_active: boolean
          refund_percentage: number
          requires_approval: boolean
          status: Database["public"]["Enums"]["order_status"]
          updated_at: string
        }
        Insert: {
          branch_id?: string | null
          cancellation_fee?: number
          created_at?: string
          customer_can_cancel?: boolean
          customer_message?: string | null
          grace_period_seconds?: number
          id?: string
          is_active?: boolean
          refund_percentage?: number
          requires_approval?: boolean
          status: Database["public"]["Enums"]["order_status"]
          updated_at?: string
        }
        Update: {
          branch_id?: string | null
          cancellation_fee?: number
          created_at?: string
          customer_can_cancel?: boolean
          customer_message?: string | null
          grace_period_seconds?: number
          id?: string
          is_active?: boolean
          refund_percentage?: number
          requires_approval?: boolean
          status?: Database["public"]["Enums"]["order_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cancellation_policies_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      cart_item_modifiers: {
        Row: {
          cart_item_id: string
          created_at: string
          id: string
          modifier_id: string
          quantity: number
        }
        Insert: {
          cart_item_id: string
          created_at?: string
          id?: string
          modifier_id: string
          quantity?: number
        }
        Update: {
          cart_item_id?: string
          created_at?: string
          id?: string
          modifier_id?: string
          quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "cart_item_modifiers_cart_item_id_fkey"
            columns: ["cart_item_id"]
            isOneToOne: false
            referencedRelation: "cart_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_item_modifiers_modifier_id_fkey"
            columns: ["modifier_id"]
            isOneToOne: false
            referencedRelation: "modifiers"
            referencedColumns: ["id"]
          },
        ]
      }
      cart_items: {
        Row: {
          cart_id: string
          config_hash: string
          created_at: string
          id: string
          product_id: string
          quantity: number
          special_instructions: string | null
          updated_at: string
          variant_id: string | null
        }
        Insert: {
          cart_id: string
          config_hash: string
          created_at?: string
          id?: string
          product_id: string
          quantity?: number
          special_instructions?: string | null
          updated_at?: string
          variant_id?: string | null
        }
        Update: {
          cart_id?: string
          config_hash?: string
          created_at?: string
          id?: string
          product_id?: string
          quantity?: number
          special_instructions?: string | null
          updated_at?: string
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cart_items_cart_id_fkey"
            columns: ["cart_id"]
            isOneToOne: false
            referencedRelation: "carts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_items_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      carts: {
        Row: {
          abandoned_notified_at: string | null
          address_id: string | null
          branch_id: string
          converted_order_id: string | null
          cooking_instructions: string | null
          coupon_code: string | null
          coupon_id: string | null
          created_at: string
          delivery_instructions: string | null
          fulfilment_type: Database["public"]["Enums"]["fulfilment_type"]
          id: string
          is_active: boolean
          last_calculated_at: string | null
          last_totals: Json | null
          scheduled_for: string | null
          timing: Database["public"]["Enums"]["order_timing"]
          updated_at: string
          use_wallet: boolean
          user_id: string
        }
        Insert: {
          abandoned_notified_at?: string | null
          address_id?: string | null
          branch_id: string
          converted_order_id?: string | null
          cooking_instructions?: string | null
          coupon_code?: string | null
          coupon_id?: string | null
          created_at?: string
          delivery_instructions?: string | null
          fulfilment_type?: Database["public"]["Enums"]["fulfilment_type"]
          id?: string
          is_active?: boolean
          last_calculated_at?: string | null
          last_totals?: Json | null
          scheduled_for?: string | null
          timing?: Database["public"]["Enums"]["order_timing"]
          updated_at?: string
          use_wallet?: boolean
          user_id: string
        }
        Update: {
          abandoned_notified_at?: string | null
          address_id?: string | null
          branch_id?: string
          converted_order_id?: string | null
          cooking_instructions?: string | null
          coupon_code?: string | null
          coupon_id?: string | null
          created_at?: string
          delivery_instructions?: string | null
          fulfilment_type?: Database["public"]["Enums"]["fulfilment_type"]
          id?: string
          is_active?: boolean
          last_calculated_at?: string | null
          last_totals?: Json | null
          scheduled_for?: string | null
          timing?: Database["public"]["Enums"]["order_timing"]
          updated_at?: string
          use_wallet?: boolean
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "carts_address_id_fkey"
            columns: ["address_id"]
            isOneToOne: false
            referencedRelation: "addresses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "carts_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "carts_converted_order_fk"
            columns: ["converted_order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "carts_coupon_fk"
            columns: ["coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "carts_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          accent_color: string | null
          banner_path: string | null
          branch_id: string | null
          created_at: string
          created_by: string | null
          day_part: Database["public"]["Enums"]["day_part"]
          deleted_at: string | null
          description: string | null
          display_order: number
          icon_name: string | null
          id: string
          image_path: string | null
          is_active: boolean
          is_featured: boolean
          meta_description: string | null
          meta_title: string | null
          name: string
          search_keywords: string[]
          short_description: string | null
          slug: string
          thumbnail_path: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          accent_color?: string | null
          banner_path?: string | null
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          day_part?: Database["public"]["Enums"]["day_part"]
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          icon_name?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          is_featured?: boolean
          meta_description?: string | null
          meta_title?: string | null
          name: string
          search_keywords?: string[]
          short_description?: string | null
          slug: string
          thumbnail_path?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          accent_color?: string | null
          banner_path?: string | null
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          day_part?: Database["public"]["Enums"]["day_part"]
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          icon_name?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          is_featured?: boolean
          meta_description?: string | null
          meta_title?: string | null
          name?: string
          search_keywords?: string[]
          short_description?: string | null
          slug?: string
          thumbnail_path?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "categories_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      cms_banners: {
        Row: {
          alt_text: string | null
          background_color: string | null
          badge_text: string | null
          branch_id: string | null
          click_count: number
          created_at: string
          deleted_at: string | null
          display_order: number
          ends_at: string | null
          id: string
          image_path: string
          image_path_wide: string | null
          impression_count: number
          is_active: boolean
          link_category_id: string | null
          link_collection_id: string | null
          link_coupon_id: string | null
          link_kind: Database["public"]["Enums"]["banner_link_kind"]
          link_product_id: string | null
          link_route: string | null
          link_url: string | null
          section_id: string | null
          starts_at: string | null
          subtitle: string | null
          title: string | null
          updated_at: string
        }
        Insert: {
          alt_text?: string | null
          background_color?: string | null
          badge_text?: string | null
          branch_id?: string | null
          click_count?: number
          created_at?: string
          deleted_at?: string | null
          display_order?: number
          ends_at?: string | null
          id?: string
          image_path: string
          image_path_wide?: string | null
          impression_count?: number
          is_active?: boolean
          link_category_id?: string | null
          link_collection_id?: string | null
          link_coupon_id?: string | null
          link_kind?: Database["public"]["Enums"]["banner_link_kind"]
          link_product_id?: string | null
          link_route?: string | null
          link_url?: string | null
          section_id?: string | null
          starts_at?: string | null
          subtitle?: string | null
          title?: string | null
          updated_at?: string
        }
        Update: {
          alt_text?: string | null
          background_color?: string | null
          badge_text?: string | null
          branch_id?: string | null
          click_count?: number
          created_at?: string
          deleted_at?: string | null
          display_order?: number
          ends_at?: string | null
          id?: string
          image_path?: string
          image_path_wide?: string | null
          impression_count?: number
          is_active?: boolean
          link_category_id?: string | null
          link_collection_id?: string | null
          link_coupon_id?: string | null
          link_kind?: Database["public"]["Enums"]["banner_link_kind"]
          link_product_id?: string | null
          link_route?: string | null
          link_url?: string | null
          section_id?: string | null
          starts_at?: string | null
          subtitle?: string | null
          title?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cms_banners_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_banners_link_category_id_fkey"
            columns: ["link_category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_banners_link_collection_id_fkey"
            columns: ["link_collection_id"]
            isOneToOne: false
            referencedRelation: "collections"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_banners_link_coupon_id_fkey"
            columns: ["link_coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_banners_link_product_id_fkey"
            columns: ["link_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_banners_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "cms_sections"
            referencedColumns: ["id"]
          },
        ]
      }
      cms_documents: {
        Row: {
          body: string
          created_at: string
          effective_from: string
          id: string
          is_published: boolean
          kind: Database["public"]["Enums"]["legal_document_kind"]
          locale: string
          title: string
          updated_at: string
          updated_by: string | null
          version: string
        }
        Insert: {
          body: string
          created_at?: string
          effective_from?: string
          id?: string
          is_published?: boolean
          kind: Database["public"]["Enums"]["legal_document_kind"]
          locale?: string
          title: string
          updated_at?: string
          updated_by?: string | null
          version?: string
        }
        Update: {
          body?: string
          created_at?: string
          effective_from?: string
          id?: string
          is_published?: boolean
          kind?: Database["public"]["Enums"]["legal_document_kind"]
          locale?: string
          title?: string
          updated_at?: string
          updated_by?: string | null
          version?: string
        }
        Relationships: []
      }
      cms_faqs: {
        Row: {
          answer: string
          category: string
          created_at: string
          display_order: number
          id: string
          is_published: boolean
          locale: string
          question: string
          updated_at: string
        }
        Insert: {
          answer: string
          category?: string
          created_at?: string
          display_order?: number
          id?: string
          is_published?: boolean
          locale?: string
          question: string
          updated_at?: string
        }
        Update: {
          answer?: string
          category?: string
          created_at?: string
          display_order?: number
          id?: string
          is_published?: boolean
          locale?: string
          question?: string
          updated_at?: string
        }
        Relationships: []
      }
      cms_sections: {
        Row: {
          action_label: string | null
          action_route: string | null
          background_color: string | null
          branch_id: string | null
          category_id: string | null
          collection_id: string | null
          coupon_id: string | null
          created_at: string
          deleted_at: string | null
          display_order: number
          ends_at: string | null
          id: string
          image_path: string | null
          is_active: boolean
          item_limit: number
          kind: Database["public"]["Enums"]["home_section_kind"]
          layout: string
          product_ids: string[]
          requires_auth: boolean
          rich_text: string | null
          rule: Json
          section_key: string
          starts_at: string | null
          subtitle: string | null
          text_color: string | null
          title: string | null
          updated_at: string
          updated_by: string | null
          valid_days_of_week: number[]
          valid_from_time: string | null
          valid_to_time: string | null
        }
        Insert: {
          action_label?: string | null
          action_route?: string | null
          background_color?: string | null
          branch_id?: string | null
          category_id?: string | null
          collection_id?: string | null
          coupon_id?: string | null
          created_at?: string
          deleted_at?: string | null
          display_order?: number
          ends_at?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          item_limit?: number
          kind: Database["public"]["Enums"]["home_section_kind"]
          layout?: string
          product_ids?: string[]
          requires_auth?: boolean
          rich_text?: string | null
          rule?: Json
          section_key: string
          starts_at?: string | null
          subtitle?: string | null
          text_color?: string | null
          title?: string | null
          updated_at?: string
          updated_by?: string | null
          valid_days_of_week?: number[]
          valid_from_time?: string | null
          valid_to_time?: string | null
        }
        Update: {
          action_label?: string | null
          action_route?: string | null
          background_color?: string | null
          branch_id?: string | null
          category_id?: string | null
          collection_id?: string | null
          coupon_id?: string | null
          created_at?: string
          deleted_at?: string | null
          display_order?: number
          ends_at?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          item_limit?: number
          kind?: Database["public"]["Enums"]["home_section_kind"]
          layout?: string
          product_ids?: string[]
          requires_auth?: boolean
          rich_text?: string | null
          rule?: Json
          section_key?: string
          starts_at?: string | null
          subtitle?: string | null
          text_color?: string | null
          title?: string | null
          updated_at?: string
          updated_by?: string | null
          valid_days_of_week?: number[]
          valid_from_time?: string | null
          valid_to_time?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cms_sections_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_sections_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_sections_collection_id_fkey"
            columns: ["collection_id"]
            isOneToOne: false
            referencedRelation: "collections"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cms_sections_coupon_id_fkey"
            columns: ["coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
        ]
      }
      cod_collections: {
        Row: {
          collected_amount: number
          collected_at: string | null
          created_at: string
          delivery_partner_id: string | null
          discrepancy_amount: number
          expected_amount: number
          id: string
          order_id: string
          settled_at: string | null
          settled_by: string | null
          settlement_note: string | null
          status: Database["public"]["Enums"]["cod_status"]
          updated_at: string
        }
        Insert: {
          collected_amount?: number
          collected_at?: string | null
          created_at?: string
          delivery_partner_id?: string | null
          discrepancy_amount?: number
          expected_amount: number
          id?: string
          order_id: string
          settled_at?: string | null
          settled_by?: string | null
          settlement_note?: string | null
          status?: Database["public"]["Enums"]["cod_status"]
          updated_at?: string
        }
        Update: {
          collected_amount?: number
          collected_at?: string | null
          created_at?: string
          delivery_partner_id?: string | null
          discrepancy_amount?: number
          expected_amount?: number
          id?: string
          order_id?: string
          settled_at?: string | null
          settled_by?: string | null
          settlement_note?: string | null
          status?: Database["public"]["Enums"]["cod_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cod_collections_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cod_collections_rider_fk"
            columns: ["delivery_partner_id"]
            isOneToOne: false
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cod_collections_settler_profile_fkey"
            columns: ["settled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      collection_products: {
        Row: {
          collection_id: string
          display_order: number
          product_id: string
        }
        Insert: {
          collection_id: string
          display_order?: number
          product_id: string
        }
        Update: {
          collection_id?: string
          display_order?: number
          product_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "collection_products_collection_id_fkey"
            columns: ["collection_id"]
            isOneToOne: false
            referencedRelation: "collections"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "collection_products_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      collections: {
        Row: {
          created_at: string
          deleted_at: string | null
          description: string | null
          display_order: number
          id: string
          image_path: string | null
          is_active: boolean
          name: string
          rule: Json | null
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          id?: string
          image_path?: string | null
          is_active?: boolean
          name: string
          rule?: Json | null
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          id?: string
          image_path?: string | null
          is_active?: boolean
          name?: string
          rule?: Json | null
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      coupon_customers: {
        Row: {
          coupon_id: string
          created_at: string
          user_id: string
        }
        Insert: {
          coupon_id: string
          created_at?: string
          user_id: string
        }
        Update: {
          coupon_id?: string
          created_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "coupon_customers_coupon_id_fkey"
            columns: ["coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
        ]
      }
      coupon_redemptions: {
        Row: {
          code: string
          coupon_id: string
          created_at: string
          discount_amount: number
          id: string
          order_amount: number
          order_id: string | null
          user_id: string
        }
        Insert: {
          code: string
          coupon_id: string
          created_at?: string
          discount_amount: number
          id?: string
          order_amount: number
          order_id?: string | null
          user_id: string
        }
        Update: {
          code?: string
          coupon_id?: string
          created_at?: string
          discount_amount?: number
          id?: string
          order_amount?: number
          order_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "coupon_redemptions_coupon_id_fkey"
            columns: ["coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coupon_redemptions_order_fk"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coupon_redemptions_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coupon_rules: {
        Row: {
          coupon_id: string
          created_at: string
          id: string
          operator: string
          rule_type: string
          value: Json
        }
        Insert: {
          coupon_id: string
          created_at?: string
          id?: string
          operator?: string
          rule_type: string
          value: Json
        }
        Update: {
          coupon_id?: string
          created_at?: string
          id?: string
          operator?: string
          rule_type?: string
          value?: Json
        }
        Relationships: [
          {
            foreignKeyName: "coupon_rules_coupon_id_fkey"
            columns: ["coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
        ]
      }
      coupons: {
        Row: {
          audience: Database["public"]["Enums"]["coupon_audience"]
          banner_path: string | null
          branch_id: string | null
          buy_quantity: number | null
          code: string
          created_at: string
          created_by: string | null
          deleted_at: string | null
          description: string | null
          discount_kind: Database["public"]["Enums"]["discount_kind"]
          discount_value: number
          eligible_category_ids: string[]
          eligible_fulfilment: Database["public"]["Enums"]["fulfilment_type"][]
          eligible_payment_modes: Database["public"]["Enums"]["payment_mode"][]
          eligible_product_ids: string[]
          eligible_zone_ids: string[]
          ends_at: string | null
          excluded_product_ids: string[]
          first_order_only: boolean
          get_product_id: string | null
          get_quantity: number | null
          id: string
          is_active: boolean
          is_visible: boolean
          max_discount_amount: number | null
          max_total_uses: number | null
          max_uses_per_customer: number
          min_order_amount: number
          new_customer_days: number | null
          segment: Database["public"]["Enums"]["audience_segment"] | null
          starts_at: string
          terms: string | null
          title: string
          total_used: number
          updated_at: string
          updated_by: string | null
          valid_days_of_week: number[]
          valid_from_time: string | null
          valid_to_time: string | null
        }
        Insert: {
          audience?: Database["public"]["Enums"]["coupon_audience"]
          banner_path?: string | null
          branch_id?: string | null
          buy_quantity?: number | null
          code: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          discount_kind: Database["public"]["Enums"]["discount_kind"]
          discount_value?: number
          eligible_category_ids?: string[]
          eligible_fulfilment?: Database["public"]["Enums"]["fulfilment_type"][]
          eligible_payment_modes?: Database["public"]["Enums"]["payment_mode"][]
          eligible_product_ids?: string[]
          eligible_zone_ids?: string[]
          ends_at?: string | null
          excluded_product_ids?: string[]
          first_order_only?: boolean
          get_product_id?: string | null
          get_quantity?: number | null
          id?: string
          is_active?: boolean
          is_visible?: boolean
          max_discount_amount?: number | null
          max_total_uses?: number | null
          max_uses_per_customer?: number
          min_order_amount?: number
          new_customer_days?: number | null
          segment?: Database["public"]["Enums"]["audience_segment"] | null
          starts_at?: string
          terms?: string | null
          title: string
          total_used?: number
          updated_at?: string
          updated_by?: string | null
          valid_days_of_week?: number[]
          valid_from_time?: string | null
          valid_to_time?: string | null
        }
        Update: {
          audience?: Database["public"]["Enums"]["coupon_audience"]
          banner_path?: string | null
          branch_id?: string | null
          buy_quantity?: number | null
          code?: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          discount_kind?: Database["public"]["Enums"]["discount_kind"]
          discount_value?: number
          eligible_category_ids?: string[]
          eligible_fulfilment?: Database["public"]["Enums"]["fulfilment_type"][]
          eligible_payment_modes?: Database["public"]["Enums"]["payment_mode"][]
          eligible_product_ids?: string[]
          eligible_zone_ids?: string[]
          ends_at?: string | null
          excluded_product_ids?: string[]
          first_order_only?: boolean
          get_product_id?: string | null
          get_quantity?: number | null
          id?: string
          is_active?: boolean
          is_visible?: boolean
          max_discount_amount?: number | null
          max_total_uses?: number | null
          max_uses_per_customer?: number
          min_order_amount?: number
          new_customer_days?: number | null
          segment?: Database["public"]["Enums"]["audience_segment"] | null
          starts_at?: string
          terms?: string | null
          title?: string
          total_used?: number
          updated_at?: string
          updated_by?: string | null
          valid_days_of_week?: number[]
          valid_from_time?: string | null
          valid_to_time?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "coupons_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coupons_get_product_id_fkey"
            columns: ["get_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_assignments: {
        Row: {
          accepted_at: string | null
          arrived_customer_at: string | null
          arrived_store_at: string | null
          assigned_by: string | null
          attempt_number: number
          base_payout: number
          branch_id: string
          cancelled_at: string | null
          cash_collected: number
          completed_at: string | null
          created_at: string
          customer_signature_path: string | null
          delivery_duration_seconds: number | null
          delivery_note: string | null
          delivery_partner_id: string
          distance_payout: number
          distance_to_customer_km: number | null
          distance_to_store_km: number | null
          expires_at: string | null
          failed_at: string | null
          failure_reason: string | null
          id: string
          mode: Database["public"]["Enums"]["assignment_mode"]
          offered_at: string
          order_id: string
          picked_up_at: string | null
          pickup_duration_seconds: number | null
          proof_photo_path: string | null
          rejected_at: string | null
          rejection_reason: string | null
          status: Database["public"]["Enums"]["assignment_status"]
          surge_payout: number
          tip_amount: number
          total_distance_km: number | null
          total_payout: number
          updated_at: string
        }
        Insert: {
          accepted_at?: string | null
          arrived_customer_at?: string | null
          arrived_store_at?: string | null
          assigned_by?: string | null
          attempt_number?: number
          base_payout?: number
          branch_id: string
          cancelled_at?: string | null
          cash_collected?: number
          completed_at?: string | null
          created_at?: string
          customer_signature_path?: string | null
          delivery_duration_seconds?: number | null
          delivery_note?: string | null
          delivery_partner_id: string
          distance_payout?: number
          distance_to_customer_km?: number | null
          distance_to_store_km?: number | null
          expires_at?: string | null
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          mode?: Database["public"]["Enums"]["assignment_mode"]
          offered_at?: string
          order_id: string
          picked_up_at?: string | null
          pickup_duration_seconds?: number | null
          proof_photo_path?: string | null
          rejected_at?: string | null
          rejection_reason?: string | null
          status?: Database["public"]["Enums"]["assignment_status"]
          surge_payout?: number
          tip_amount?: number
          total_distance_km?: number | null
          total_payout?: number
          updated_at?: string
        }
        Update: {
          accepted_at?: string | null
          arrived_customer_at?: string | null
          arrived_store_at?: string | null
          assigned_by?: string | null
          attempt_number?: number
          base_payout?: number
          branch_id?: string
          cancelled_at?: string | null
          cash_collected?: number
          completed_at?: string | null
          created_at?: string
          customer_signature_path?: string | null
          delivery_duration_seconds?: number | null
          delivery_note?: string | null
          delivery_partner_id?: string
          distance_payout?: number
          distance_to_customer_km?: number | null
          distance_to_store_km?: number | null
          expires_at?: string | null
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          mode?: Database["public"]["Enums"]["assignment_mode"]
          offered_at?: string
          order_id?: string
          picked_up_at?: string | null
          pickup_duration_seconds?: number | null
          proof_photo_path?: string | null
          rejected_at?: string | null
          rejection_reason?: string | null
          status?: Database["public"]["Enums"]["assignment_status"]
          surge_payout?: number
          tip_amount?: number
          total_distance_km?: number | null
          total_payout?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "delivery_assignments_assigner_profile_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_assignments_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_assignments_delivery_partner_id_fkey"
            columns: ["delivery_partner_id"]
            isOneToOne: false
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_assignments_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_earnings: {
        Row: {
          amount: number
          assignment_id: string | null
          created_at: string
          created_by: string | null
          delivery_partner_id: string
          description: string | null
          earned_on: string
          entry_type: string
          id: string
          order_id: string | null
        }
        Insert: {
          amount: number
          assignment_id?: string | null
          created_at?: string
          created_by?: string | null
          delivery_partner_id: string
          description?: string | null
          earned_on?: string
          entry_type: string
          id?: string
          order_id?: string | null
        }
        Update: {
          amount?: number
          assignment_id?: string | null
          created_at?: string
          created_by?: string | null
          delivery_partner_id?: string
          description?: string | null
          earned_on?: string
          entry_type?: string
          id?: string
          order_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "delivery_earnings_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: false
            referencedRelation: "delivery_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_earnings_delivery_partner_id_fkey"
            columns: ["delivery_partner_id"]
            isOneToOne: false
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_earnings_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_location_events: {
        Row: {
          accuracy_meters: number | null
          assignment_id: string | null
          delivery_partner_id: string
          id: number
          latitude: number
          longitude: number
          order_id: string | null
          recorded_at: string
          speed_kmph: number | null
        }
        Insert: {
          accuracy_meters?: number | null
          assignment_id?: string | null
          delivery_partner_id: string
          id?: number
          latitude: number
          longitude: number
          order_id?: string | null
          recorded_at?: string
          speed_kmph?: number | null
        }
        Update: {
          accuracy_meters?: number | null
          assignment_id?: string | null
          delivery_partner_id?: string
          id?: number
          latitude?: number
          longitude?: number
          order_id?: string | null
          recorded_at?: string
          speed_kmph?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "delivery_location_events_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: false
            referencedRelation: "delivery_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_location_events_delivery_partner_id_fkey"
            columns: ["delivery_partner_id"]
            isOneToOne: false
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_location_events_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_partner_availability: {
        Row: {
          battery_level: number | null
          created_at: string
          delivery_partner_id: string
          duration_seconds: number | null
          duty_state: Database["public"]["Enums"]["rider_duty_state"]
          id: string
          latitude: number | null
          longitude: number | null
          previous_state: Database["public"]["Enums"]["rider_duty_state"] | null
          reason: string | null
        }
        Insert: {
          battery_level?: number | null
          created_at?: string
          delivery_partner_id: string
          duration_seconds?: number | null
          duty_state: Database["public"]["Enums"]["rider_duty_state"]
          id?: string
          latitude?: number | null
          longitude?: number | null
          previous_state?:
            | Database["public"]["Enums"]["rider_duty_state"]
            | null
          reason?: string | null
        }
        Update: {
          battery_level?: number | null
          created_at?: string
          delivery_partner_id?: string
          duration_seconds?: number | null
          duty_state?: Database["public"]["Enums"]["rider_duty_state"]
          id?: string
          latitude?: number | null
          longitude?: number | null
          previous_state?:
            | Database["public"]["Enums"]["rider_duty_state"]
            | null
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "delivery_partner_availability_delivery_partner_id_fkey"
            columns: ["delivery_partner_id"]
            isOneToOne: false
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_partner_documents: {
        Row: {
          created_at: string
          delivery_partner_id: string
          document_number: string | null
          document_type: Database["public"]["Enums"]["rider_document_type"]
          expires_on: string | null
          id: string
          issued_on: string | null
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["document_status"]
          storage_path: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          delivery_partner_id: string
          document_number?: string | null
          document_type: Database["public"]["Enums"]["rider_document_type"]
          expires_on?: string | null
          id?: string
          issued_on?: string | null
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["document_status"]
          storage_path: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          delivery_partner_id?: string
          document_number?: string | null
          document_type?: Database["public"]["Enums"]["rider_document_type"]
          expires_on?: string | null
          id?: string
          issued_on?: string | null
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["document_status"]
          storage_path?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "delivery_partner_documents_delivery_partner_id_fkey"
            columns: ["delivery_partner_id"]
            isOneToOne: false
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_partner_locations: {
        Row: {
          accuracy_meters: number | null
          assignment_id: string | null
          battery_level: number | null
          delivery_partner_id: string
          distance_to_destination_km: number | null
          eta_minutes: number | null
          heading_degrees: number | null
          is_moving: boolean
          latitude: number
          longitude: number
          order_id: string | null
          recorded_at: string
          speed_kmph: number | null
          updated_at: string
        }
        Insert: {
          accuracy_meters?: number | null
          assignment_id?: string | null
          battery_level?: number | null
          delivery_partner_id: string
          distance_to_destination_km?: number | null
          eta_minutes?: number | null
          heading_degrees?: number | null
          is_moving?: boolean
          latitude: number
          longitude: number
          order_id?: string | null
          recorded_at?: string
          speed_kmph?: number | null
          updated_at?: string
        }
        Update: {
          accuracy_meters?: number | null
          assignment_id?: string | null
          battery_level?: number | null
          delivery_partner_id?: string
          distance_to_destination_km?: number | null
          eta_minutes?: number | null
          heading_degrees?: number | null
          is_moving?: boolean
          latitude?: number
          longitude?: number
          order_id?: string | null
          recorded_at?: string
          speed_kmph?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "delivery_partner_locations_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: false
            referencedRelation: "delivery_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_partner_locations_delivery_partner_id_fkey"
            columns: ["delivery_partner_id"]
            isOneToOne: true
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_partner_locations_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_partners: {
        Row: {
          address_line1: string | null
          address_line2: string | null
          alternate_phone: string | null
          approved_at: string | null
          approved_by: string | null
          bank_account_masked: string | null
          bank_holder_name: string | null
          bank_ifsc: string | null
          branch_id: string
          cash_in_hand: number
          city: string | null
          created_at: string
          created_by: string | null
          date_of_birth: string | null
          deleted_at: string | null
          driving_licence_no: string | null
          duty_state: Database["public"]["Enums"]["rider_duty_state"]
          email: string | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          failed_deliveries: number
          full_name: string
          id: string
          is_salaried: boolean
          last_delivery_at: string | null
          last_online_at: string | null
          licence_expiry: string | null
          max_concurrent_orders: number
          notes: string | null
          onboarding_status: Database["public"]["Enums"]["rider_onboarding_status"]
          partner_code: string | null
          phone: string
          photo_path: string | null
          postal_code: string | null
          rating_average: number
          rating_count: number
          rejected_assignments: number
          rejection_reason: string | null
          state: string | null
          successful_deliveries: number
          suspended_reason: string | null
          suspended_until: string | null
          total_deliveries: number
          updated_at: string
          upi_id: string | null
          user_id: string
          vehicle_model: string | null
          vehicle_number: string | null
          vehicle_type: Database["public"]["Enums"]["vehicle_type"]
        }
        Insert: {
          address_line1?: string | null
          address_line2?: string | null
          alternate_phone?: string | null
          approved_at?: string | null
          approved_by?: string | null
          bank_account_masked?: string | null
          bank_holder_name?: string | null
          bank_ifsc?: string | null
          branch_id: string
          cash_in_hand?: number
          city?: string | null
          created_at?: string
          created_by?: string | null
          date_of_birth?: string | null
          deleted_at?: string | null
          driving_licence_no?: string | null
          duty_state?: Database["public"]["Enums"]["rider_duty_state"]
          email?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          failed_deliveries?: number
          full_name: string
          id?: string
          is_salaried?: boolean
          last_delivery_at?: string | null
          last_online_at?: string | null
          licence_expiry?: string | null
          max_concurrent_orders?: number
          notes?: string | null
          onboarding_status?: Database["public"]["Enums"]["rider_onboarding_status"]
          partner_code?: string | null
          phone: string
          photo_path?: string | null
          postal_code?: string | null
          rating_average?: number
          rating_count?: number
          rejected_assignments?: number
          rejection_reason?: string | null
          state?: string | null
          successful_deliveries?: number
          suspended_reason?: string | null
          suspended_until?: string | null
          total_deliveries?: number
          updated_at?: string
          upi_id?: string | null
          user_id: string
          vehicle_model?: string | null
          vehicle_number?: string | null
          vehicle_type?: Database["public"]["Enums"]["vehicle_type"]
        }
        Update: {
          address_line1?: string | null
          address_line2?: string | null
          alternate_phone?: string | null
          approved_at?: string | null
          approved_by?: string | null
          bank_account_masked?: string | null
          bank_holder_name?: string | null
          bank_ifsc?: string | null
          branch_id?: string
          cash_in_hand?: number
          city?: string | null
          created_at?: string
          created_by?: string | null
          date_of_birth?: string | null
          deleted_at?: string | null
          driving_licence_no?: string | null
          duty_state?: Database["public"]["Enums"]["rider_duty_state"]
          email?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          failed_deliveries?: number
          full_name?: string
          id?: string
          is_salaried?: boolean
          last_delivery_at?: string | null
          last_online_at?: string | null
          licence_expiry?: string | null
          max_concurrent_orders?: number
          notes?: string | null
          onboarding_status?: Database["public"]["Enums"]["rider_onboarding_status"]
          partner_code?: string | null
          phone?: string
          photo_path?: string | null
          postal_code?: string | null
          rating_average?: number
          rating_count?: number
          rejected_assignments?: number
          rejection_reason?: string | null
          state?: string | null
          successful_deliveries?: number
          suspended_reason?: string | null
          suspended_until?: string | null
          total_deliveries?: number
          updated_at?: string
          upi_id?: string | null
          user_id?: string
          vehicle_model?: string | null
          vehicle_number?: string | null
          vehicle_type?: Database["public"]["Enums"]["vehicle_type"]
        }
        Relationships: [
          {
            foreignKeyName: "delivery_partners_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delivery_partners_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_payout_config: {
        Row: {
          base_payout: number
          branch_id: string | null
          created_at: string
          free_km: number
          id: string
          is_active: boolean
          peak_bonus: number
          peak_ends_at: string | null
          peak_starts_at: string | null
          per_km_payout: number
          updated_at: string
        }
        Insert: {
          base_payout?: number
          branch_id?: string | null
          created_at?: string
          free_km?: number
          id?: string
          is_active?: boolean
          peak_bonus?: number
          peak_ends_at?: string | null
          peak_starts_at?: string | null
          per_km_payout?: number
          updated_at?: string
        }
        Update: {
          base_payout?: number
          branch_id?: string | null
          created_at?: string
          free_km?: number
          id?: string
          is_active?: boolean
          peak_bonus?: number
          peak_ends_at?: string | null
          peak_starts_at?: string | null
          per_km_payout?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "delivery_payout_config_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      delivery_zones: {
        Row: {
          base_eta_minutes: number
          branch_id: string
          cod_enabled: boolean
          created_at: string
          created_by: string | null
          deleted_at: string | null
          delivery_fee: number
          description: string | null
          dynamic_surcharge: number
          extra_eta_minutes: number
          free_delivery_threshold: number | null
          id: string
          is_active: boolean
          is_serviceable: boolean
          kind: Database["public"]["Enums"]["zone_kind"]
          max_cod_amount: number | null
          max_distance_km: number | null
          min_distance_km: number | null
          min_order_amount: number
          name: string
          peak_ends_at: string | null
          peak_starts_at: string | null
          peak_surcharge: number
          per_km_surcharge: number
          polygon: Json | null
          priority: number
          surcharge_after_km: number | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          base_eta_minutes?: number
          branch_id: string
          cod_enabled?: boolean
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          delivery_fee?: number
          description?: string | null
          dynamic_surcharge?: number
          extra_eta_minutes?: number
          free_delivery_threshold?: number | null
          id?: string
          is_active?: boolean
          is_serviceable?: boolean
          kind?: Database["public"]["Enums"]["zone_kind"]
          max_cod_amount?: number | null
          max_distance_km?: number | null
          min_distance_km?: number | null
          min_order_amount?: number
          name: string
          peak_ends_at?: string | null
          peak_starts_at?: string | null
          peak_surcharge?: number
          per_km_surcharge?: number
          polygon?: Json | null
          priority?: number
          surcharge_after_km?: number | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          base_eta_minutes?: number
          branch_id?: string
          cod_enabled?: boolean
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          delivery_fee?: number
          description?: string | null
          dynamic_surcharge?: number
          extra_eta_minutes?: number
          free_delivery_threshold?: number | null
          id?: string
          is_active?: boolean
          is_serviceable?: boolean
          kind?: Database["public"]["Enums"]["zone_kind"]
          max_cod_amount?: number | null
          max_distance_km?: number | null
          min_distance_km?: number | null
          min_order_amount?: number
          name?: string
          peak_ends_at?: string | null
          peak_starts_at?: string | null
          peak_surcharge?: number
          per_km_surcharge?: number
          polygon?: Json | null
          priority?: number
          surcharge_after_km?: number | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "delivery_zones_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      device_tokens: {
        Row: {
          app_version: string | null
          created_at: string
          device_id: string | null
          device_model: string | null
          failure_count: number
          id: string
          is_active: boolean
          last_used_at: string | null
          locale: string | null
          os_version: string | null
          platform: Database["public"]["Enums"]["device_platform"]
          timezone: string | null
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          app_version?: string | null
          created_at?: string
          device_id?: string | null
          device_model?: string | null
          failure_count?: number
          id?: string
          is_active?: boolean
          last_used_at?: string | null
          locale?: string | null
          os_version?: string | null
          platform: Database["public"]["Enums"]["device_platform"]
          timezone?: string | null
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          app_version?: string | null
          created_at?: string
          device_id?: string | null
          device_model?: string | null
          failure_count?: number
          id?: string
          is_active?: boolean
          last_used_at?: string | null
          locale?: string | null
          os_version?: string | null
          platform?: Database["public"]["Enums"]["device_platform"]
          timezone?: string | null
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_tokens_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      feature_flags: {
        Row: {
          branch_id: string | null
          created_at: string
          description: string | null
          enabled_for_roles: Database["public"]["Enums"]["app_role"][] | null
          is_enabled: boolean
          key: string
          label: string
          rollout_percentage: number
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          branch_id?: string | null
          created_at?: string
          description?: string | null
          enabled_for_roles?: Database["public"]["Enums"]["app_role"][] | null
          is_enabled?: boolean
          key: string
          label: string
          rollout_percentage?: number
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          branch_id?: string | null
          created_at?: string
          description?: string | null
          enabled_for_roles?: Database["public"]["Enums"]["app_role"][] | null
          is_enabled?: boolean
          key?: string
          label?: string
          rollout_percentage?: number
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "feature_flags_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      ingredients: {
        Row: {
          average_cost_per_unit: number
          category: string | null
          created_at: string
          deleted_at: string | null
          id: string
          is_active: boolean
          name: string
          sku: string | null
          unit: Database["public"]["Enums"]["unit_of_measure"]
          updated_at: string
        }
        Insert: {
          average_cost_per_unit?: number
          category?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          is_active?: boolean
          name: string
          sku?: string | null
          unit?: Database["public"]["Enums"]["unit_of_measure"]
          updated_at?: string
        }
        Update: {
          average_cost_per_unit?: number
          category?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          is_active?: boolean
          name?: string
          sku?: string | null
          unit?: Database["public"]["Enums"]["unit_of_measure"]
          updated_at?: string
        }
        Relationships: []
      }
      inventory_items: {
        Row: {
          branch_id: string
          created_at: string
          id: string
          ingredient_id: string
          last_counted_at: string | null
          low_stock_threshold: number | null
          quantity_on_hand: number
          reorder_quantity: number | null
          updated_at: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          id?: string
          ingredient_id: string
          last_counted_at?: string | null
          low_stock_threshold?: number | null
          quantity_on_hand?: number
          reorder_quantity?: number | null
          updated_at?: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          id?: string
          ingredient_id?: string
          last_counted_at?: string | null
          low_stock_threshold?: number | null
          quantity_on_hand?: number
          reorder_quantity?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_items_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_items_ingredient_id_fkey"
            columns: ["ingredient_id"]
            isOneToOne: false
            referencedRelation: "ingredients"
            referencedColumns: ["id"]
          },
        ]
      }
      job_runs: {
        Row: {
          duration_ms: number | null
          error_message: string | null
          finished_at: string | null
          id: number
          job_name: string
          processed: number
          result: Json | null
          started_at: string
          status: string
        }
        Insert: {
          duration_ms?: number | null
          error_message?: string | null
          finished_at?: string | null
          id?: number
          job_name: string
          processed?: number
          result?: Json | null
          started_at?: string
          status?: string
        }
        Update: {
          duration_ms?: number | null
          error_message?: string | null
          finished_at?: string | null
          id?: number
          job_name?: string
          processed?: number
          result?: Json | null
          started_at?: string
          status?: string
        }
        Relationships: []
      }
      loyalty_accounts: {
        Row: {
          created_at: string
          id: string
          lifetime_earned: number
          lifetime_redeemed: number
          points_balance: number
          tier: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          lifetime_earned?: number
          lifetime_redeemed?: number
          points_balance?: number
          tier?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          lifetime_earned?: number
          lifetime_redeemed?: number
          points_balance?: number
          tier?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "loyalty_accounts_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      loyalty_transactions: {
        Row: {
          balance_after: number
          created_at: string
          description: string
          expires_at: string | null
          id: string
          idempotency_key: string | null
          kind: Database["public"]["Enums"]["loyalty_entry_kind"]
          loyalty_account_id: string
          monetary_value: number
          order_id: string | null
          points: number
          user_id: string
        }
        Insert: {
          balance_after: number
          created_at?: string
          description: string
          expires_at?: string | null
          id?: string
          idempotency_key?: string | null
          kind: Database["public"]["Enums"]["loyalty_entry_kind"]
          loyalty_account_id: string
          monetary_value?: number
          order_id?: string | null
          points: number
          user_id: string
        }
        Update: {
          balance_after?: number
          created_at?: string
          description?: string
          expires_at?: string | null
          id?: string
          idempotency_key?: string | null
          kind?: Database["public"]["Enums"]["loyalty_entry_kind"]
          loyalty_account_id?: string
          monetary_value?: number
          order_id?: string | null
          points?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "loyalty_transactions_loyalty_account_id_fkey"
            columns: ["loyalty_account_id"]
            isOneToOne: false
            referencedRelation: "loyalty_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "loyalty_transactions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "loyalty_transactions_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      modifier_groups: {
        Row: {
          created_at: string
          deleted_at: string | null
          description: string | null
          display_order: number
          free_selections: number
          id: string
          is_active: boolean
          is_required: boolean
          max_select: number | null
          min_select: number
          name: string
          selection: Database["public"]["Enums"]["modifier_selection"]
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          free_selections?: number
          id?: string
          is_active?: boolean
          is_required?: boolean
          max_select?: number | null
          min_select?: number
          name: string
          selection?: Database["public"]["Enums"]["modifier_selection"]
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          free_selections?: number
          id?: string
          is_active?: boolean
          is_required?: boolean
          max_select?: number | null
          min_select?: number
          name?: string
          selection?: Database["public"]["Enums"]["modifier_selection"]
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      modifiers: {
        Row: {
          availability: Database["public"]["Enums"]["availability_state"]
          calories: number | null
          created_at: string
          deleted_at: string | null
          description: string | null
          display_order: number
          food_type: Database["public"]["Enums"]["food_type"]
          id: string
          image_path: string | null
          is_active: boolean
          is_default: boolean
          max_quantity: number
          modifier_group_id: string
          name: string
          out_of_stock_until: string | null
          price: number
          updated_at: string
        }
        Insert: {
          availability?: Database["public"]["Enums"]["availability_state"]
          calories?: number | null
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          food_type?: Database["public"]["Enums"]["food_type"]
          id?: string
          image_path?: string | null
          is_active?: boolean
          is_default?: boolean
          max_quantity?: number
          modifier_group_id: string
          name: string
          out_of_stock_until?: string | null
          price?: number
          updated_at?: string
        }
        Update: {
          availability?: Database["public"]["Enums"]["availability_state"]
          calories?: number | null
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          food_type?: Database["public"]["Enums"]["food_type"]
          id?: string
          image_path?: string | null
          is_active?: boolean
          is_default?: boolean
          max_quantity?: number
          modifier_group_id?: string
          name?: string
          out_of_stock_until?: string | null
          price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "modifiers_modifier_group_id_fkey"
            columns: ["modifier_group_id"]
            isOneToOne: false
            referencedRelation: "modifier_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_campaigns: {
        Row: {
          action_route: string | null
          body: string
          channels: Database["public"]["Enums"]["notification_channel"][]
          completed_at: string | null
          coupon_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          failed_count: number
          id: string
          image_path: string | null
          name: string
          queued_count: number
          read_count: number
          scheduled_for: string | null
          segment: Database["public"]["Enums"]["audience_segment"]
          segment_filter: Json
          sent_count: number
          started_at: string | null
          status: Database["public"]["Enums"]["campaign_status"]
          target_count: number
          title: string
          updated_at: string
        }
        Insert: {
          action_route?: string | null
          body: string
          channels?: Database["public"]["Enums"]["notification_channel"][]
          completed_at?: string | null
          coupon_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          failed_count?: number
          id?: string
          image_path?: string | null
          name: string
          queued_count?: number
          read_count?: number
          scheduled_for?: string | null
          segment?: Database["public"]["Enums"]["audience_segment"]
          segment_filter?: Json
          sent_count?: number
          started_at?: string | null
          status?: Database["public"]["Enums"]["campaign_status"]
          target_count?: number
          title: string
          updated_at?: string
        }
        Update: {
          action_route?: string | null
          body?: string
          channels?: Database["public"]["Enums"]["notification_channel"][]
          completed_at?: string | null
          coupon_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          failed_count?: number
          id?: string
          image_path?: string | null
          name?: string
          queued_count?: number
          read_count?: number
          scheduled_for?: string | null
          segment?: Database["public"]["Enums"]["audience_segment"]
          segment_filter?: Json
          sent_count?: number
          started_at?: string | null
          status?: Database["public"]["Enums"]["campaign_status"]
          target_count?: number
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_campaigns_coupon_id_fkey"
            columns: ["coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_templates: {
        Row: {
          action_route: string | null
          body: string
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at: string
          event: Database["public"]["Enums"]["notification_event"]
          id: string
          image_path: string | null
          is_active: boolean
          locale: string
          provider_template_id: string | null
          title: string | null
          updated_at: string
          updated_by: string | null
          variables: string[]
        }
        Insert: {
          action_route?: string | null
          body: string
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          event: Database["public"]["Enums"]["notification_event"]
          id?: string
          image_path?: string | null
          is_active?: boolean
          locale?: string
          provider_template_id?: string | null
          title?: string | null
          updated_at?: string
          updated_by?: string | null
          variables?: string[]
        }
        Update: {
          action_route?: string | null
          body?: string
          channel?: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          event?: Database["public"]["Enums"]["notification_event"]
          id?: string
          image_path?: string | null
          is_active?: boolean
          locale?: string
          provider_template_id?: string | null
          title?: string | null
          updated_at?: string
          updated_by?: string | null
          variables?: string[]
        }
        Relationships: []
      }
      notifications: {
        Row: {
          action_route: string | null
          attempts: number
          body: string
          campaign_id: string | null
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at: string
          data: Json
          dedupe_key: string | null
          delivered_at: string | null
          destination: string | null
          event: Database["public"]["Enums"]["notification_event"]
          failed_at: string | null
          failure_reason: string | null
          id: string
          image_path: string | null
          order_id: string | null
          provider: string | null
          provider_message_id: string | null
          read_at: string | null
          scheduled_for: string | null
          sent_at: string | null
          status: Database["public"]["Enums"]["notification_status"]
          support_ticket_id: string | null
          title: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          action_route?: string | null
          attempts?: number
          body: string
          campaign_id?: string | null
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          data?: Json
          dedupe_key?: string | null
          delivered_at?: string | null
          destination?: string | null
          event: Database["public"]["Enums"]["notification_event"]
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          image_path?: string | null
          order_id?: string | null
          provider?: string | null
          provider_message_id?: string | null
          read_at?: string | null
          scheduled_for?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          support_ticket_id?: string | null
          title?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          action_route?: string | null
          attempts?: number
          body?: string
          campaign_id?: string | null
          channel?: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          data?: Json
          dedupe_key?: string | null
          delivered_at?: string | null
          destination?: string | null
          event?: Database["public"]["Enums"]["notification_event"]
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          image_path?: string | null
          order_id?: string | null
          provider?: string | null
          provider_message_id?: string | null
          read_at?: string | null
          scheduled_for?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          support_ticket_id?: string | null
          title?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notifications_campaign_fk"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "notification_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_ticket_fk"
            columns: ["support_ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      order_item_modifiers: {
        Row: {
          created_at: string
          food_type: Database["public"]["Enums"]["food_type"]
          group_name: string
          id: string
          modifier_group_id: string | null
          modifier_id: string | null
          modifier_name: string
          order_item_id: string
          quantity: number
          total_price: number
          unit_price: number
        }
        Insert: {
          created_at?: string
          food_type?: Database["public"]["Enums"]["food_type"]
          group_name: string
          id?: string
          modifier_group_id?: string | null
          modifier_id?: string | null
          modifier_name: string
          order_item_id: string
          quantity?: number
          total_price?: number
          unit_price?: number
        }
        Update: {
          created_at?: string
          food_type?: Database["public"]["Enums"]["food_type"]
          group_name?: string
          id?: string
          modifier_group_id?: string | null
          modifier_id?: string | null
          modifier_name?: string
          order_item_id?: string
          quantity?: number
          total_price?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "order_item_modifiers_modifier_group_id_fkey"
            columns: ["modifier_group_id"]
            isOneToOne: false
            referencedRelation: "modifier_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_item_modifiers_modifier_id_fkey"
            columns: ["modifier_id"]
            isOneToOne: false
            referencedRelation: "modifiers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_item_modifiers_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          allocated_discount: number
          cancellation_note: string | null
          category_id: string | null
          category_name: string | null
          cess_amount: number
          cgst_amount: number
          created_at: string
          discount_amount: number
          display_order: number
          food_type: Database["public"]["Enums"]["food_type"]
          gross_amount: number
          hsn_sac_code: string | null
          id: string
          igst_amount: number
          image_path: string | null
          is_cancelled: boolean
          modifiers_price: number
          net_amount: number
          order_id: string
          packaging_charge: number
          preparation_minutes: number | null
          product_id: string | null
          product_name: string
          product_slug: string | null
          quantity: number
          refunded_amount: number
          refunded_quantity: number
          sgst_amount: number
          short_description: string | null
          special_instructions: string | null
          tax_amount: number
          tax_category_id: string | null
          tax_inclusive: boolean
          tax_rate: number
          taxable_amount: number
          unit_price: number
          variant_id: string | null
          variant_name: string | null
          variant_option_group: string | null
        }
        Insert: {
          allocated_discount?: number
          cancellation_note?: string | null
          category_id?: string | null
          category_name?: string | null
          cess_amount?: number
          cgst_amount?: number
          created_at?: string
          discount_amount?: number
          display_order?: number
          food_type?: Database["public"]["Enums"]["food_type"]
          gross_amount: number
          hsn_sac_code?: string | null
          id?: string
          igst_amount?: number
          image_path?: string | null
          is_cancelled?: boolean
          modifiers_price?: number
          net_amount: number
          order_id: string
          packaging_charge?: number
          preparation_minutes?: number | null
          product_id?: string | null
          product_name: string
          product_slug?: string | null
          quantity: number
          refunded_amount?: number
          refunded_quantity?: number
          sgst_amount?: number
          short_description?: string | null
          special_instructions?: string | null
          tax_amount?: number
          tax_category_id?: string | null
          tax_inclusive?: boolean
          tax_rate?: number
          taxable_amount?: number
          unit_price: number
          variant_id?: string | null
          variant_name?: string | null
          variant_option_group?: string | null
        }
        Update: {
          allocated_discount?: number
          cancellation_note?: string | null
          category_id?: string | null
          category_name?: string | null
          cess_amount?: number
          cgst_amount?: number
          created_at?: string
          discount_amount?: number
          display_order?: number
          food_type?: Database["public"]["Enums"]["food_type"]
          gross_amount?: number
          hsn_sac_code?: string | null
          id?: string
          igst_amount?: number
          image_path?: string | null
          is_cancelled?: boolean
          modifiers_price?: number
          net_amount?: number
          order_id?: string
          packaging_charge?: number
          preparation_minutes?: number | null
          product_id?: string | null
          product_name?: string
          product_slug?: string | null
          quantity?: number
          refunded_amount?: number
          refunded_quantity?: number
          sgst_amount?: number
          short_description?: string | null
          special_instructions?: string | null
          tax_amount?: number
          tax_category_id?: string | null
          tax_inclusive?: boolean
          tax_rate?: number
          taxable_amount?: number
          unit_price?: number
          variant_id?: string | null
          variant_name?: string | null
          variant_option_group?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "order_items_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_tax_category_id_fkey"
            columns: ["tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      order_notes: {
        Row: {
          author_id: string | null
          created_at: string
          id: string
          is_internal: boolean
          note: string
          order_id: string
        }
        Insert: {
          author_id?: string | null
          created_at?: string
          id?: string
          is_internal?: boolean
          note: string
          order_id: string
        }
        Update: {
          author_id?: string | null
          created_at?: string
          id?: string
          is_internal?: boolean
          note?: string
          order_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_notes_author_profile_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_notes_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      order_status_history: {
        Row: {
          actor_id: string | null
          actor_kind: Database["public"]["Enums"]["actor_kind"]
          actor_role: Database["public"]["Enums"]["app_role"] | null
          created_at: string
          from_status: Database["public"]["Enums"]["order_status"] | null
          id: string
          is_override: boolean
          label: string
          metadata: Json
          note: string | null
          order_id: string
          to_status: Database["public"]["Enums"]["order_status"]
        }
        Insert: {
          actor_id?: string | null
          actor_kind?: Database["public"]["Enums"]["actor_kind"]
          actor_role?: Database["public"]["Enums"]["app_role"] | null
          created_at?: string
          from_status?: Database["public"]["Enums"]["order_status"] | null
          id?: string
          is_override?: boolean
          label: string
          metadata?: Json
          note?: string | null
          order_id: string
          to_status: Database["public"]["Enums"]["order_status"]
        }
        Update: {
          actor_id?: string | null
          actor_kind?: Database["public"]["Enums"]["actor_kind"]
          actor_role?: Database["public"]["Enums"]["app_role"] | null
          created_at?: string
          from_status?: Database["public"]["Enums"]["order_status"] | null
          id?: string
          is_override?: boolean
          label?: string
          metadata?: Json
          note?: string | null
          order_id?: string
          to_status?: Database["public"]["Enums"]["order_status"]
        }
        Relationships: [
          {
            foreignKeyName: "order_status_history_actor_profile_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_status_history_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      order_status_transitions: {
        Row: {
          customer_allowed: boolean
          customer_label: string
          description: string | null
          from_status: Database["public"]["Enums"]["order_status"]
          label: string
          required_permission: string | null
          rider_allowed: boolean
          to_status: Database["public"]["Enums"]["order_status"]
        }
        Insert: {
          customer_allowed?: boolean
          customer_label: string
          description?: string | null
          from_status: Database["public"]["Enums"]["order_status"]
          label: string
          required_permission?: string | null
          rider_allowed?: boolean
          to_status: Database["public"]["Enums"]["order_status"]
        }
        Update: {
          customer_allowed?: boolean
          customer_label?: string
          description?: string | null
          from_status?: Database["public"]["Enums"]["order_status"]
          label?: string
          required_permission?: string | null
          rider_allowed?: boolean
          to_status?: Database["public"]["Enums"]["order_status"]
        }
        Relationships: []
      }
      orders: {
        Row: {
          accepted_at: string | null
          address_id: string | null
          app_version: string | null
          assigned_at: string | null
          branch_id: string
          cancellation_actor:
            | Database["public"]["Enums"]["cancellation_actor"]
            | null
          cancellation_fee: number
          cancellation_note: string | null
          cancellation_reason:
            | Database["public"]["Enums"]["cancellation_reason"]
            | null
          cancelled_at: string | null
          cancelled_by: string | null
          cess_amount: number
          cgst_amount: number
          channel: Database["public"]["Enums"]["order_channel"]
          cod_status: Database["public"]["Enums"]["cod_status"] | null
          completed_at: string | null
          coupon_code: string | null
          coupon_discount: number
          coupon_id: string | null
          created_at: string
          created_by: string | null
          currency_code: string
          customer_email: string | null
          customer_name: string | null
          customer_note: string | null
          customer_phone: string | null
          delay_notified_at: string | null
          delivered_at: string | null
          delivery_address_line1: string | null
          delivery_address_line2: string | null
          delivery_area: string | null
          delivery_city: string | null
          delivery_code_attempts: number
          delivery_code_hash: string | null
          delivery_code_salt: string | null
          delivery_contact_name: string | null
          delivery_contact_phone: string | null
          delivery_fee: number
          delivery_fee_waived: number
          delivery_instructions: string | null
          delivery_landmark: string | null
          delivery_latitude: number | null
          delivery_longitude: number | null
          delivery_minutes_estimate: number | null
          delivery_postal_code: string | null
          delivery_state: string | null
          delivery_verification_method: string | null
          delivery_verified_at: string | null
          delivery_zone_id: string | null
          delivery_zone_name: string | null
          device_platform: Database["public"]["Enums"]["device_platform"] | null
          distance_km: number | null
          fulfilment_type: Database["public"]["Enums"]["fulfilment_type"]
          grand_total: number
          id: string
          idempotency_key: string
          igst_amount: number
          internal_note: string | null
          is_delayed: boolean
          is_first_order: boolean
          item_count: number
          items_discount: number
          items_subtotal: number
          loyalty_discount: number
          loyalty_points_redeemed: number
          metadata: Json
          order_number: string
          packaging_charge: number
          paid_at: string | null
          payable_amount: number
          payment_mode: Database["public"]["Enums"]["payment_mode"]
          payment_status: Database["public"]["Enums"]["payment_status"]
          picked_up_at: string | null
          pickup_code_hash: string | null
          placed_at: string | null
          prep_minutes_estimate: number | null
          preparing_at: string | null
          previous_status: Database["public"]["Enums"]["order_status"] | null
          promised_at: string | null
          promotion_discount: number
          promotion_id: string | null
          ready_at: string | null
          refunded_amount: number
          round_off: number
          scheduled_for: string | null
          service_fee: number
          sgst_amount: number
          status: Database["public"]["Enums"]["order_status"]
          status_changed_at: string
          tax_amount: number
          taxable_amount: number
          timing: Database["public"]["Enums"]["order_timing"]
          tip_amount: number
          total_discount: number
          unit_count: number
          updated_at: string
          user_id: string
          wallet_applied: number
        }
        Insert: {
          accepted_at?: string | null
          address_id?: string | null
          app_version?: string | null
          assigned_at?: string | null
          branch_id: string
          cancellation_actor?:
            | Database["public"]["Enums"]["cancellation_actor"]
            | null
          cancellation_fee?: number
          cancellation_note?: string | null
          cancellation_reason?:
            | Database["public"]["Enums"]["cancellation_reason"]
            | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cess_amount?: number
          cgst_amount?: number
          channel?: Database["public"]["Enums"]["order_channel"]
          cod_status?: Database["public"]["Enums"]["cod_status"] | null
          completed_at?: string | null
          coupon_code?: string | null
          coupon_discount?: number
          coupon_id?: string | null
          created_at?: string
          created_by?: string | null
          currency_code?: string
          customer_email?: string | null
          customer_name?: string | null
          customer_note?: string | null
          customer_phone?: string | null
          delay_notified_at?: string | null
          delivered_at?: string | null
          delivery_address_line1?: string | null
          delivery_address_line2?: string | null
          delivery_area?: string | null
          delivery_city?: string | null
          delivery_code_attempts?: number
          delivery_code_hash?: string | null
          delivery_code_salt?: string | null
          delivery_contact_name?: string | null
          delivery_contact_phone?: string | null
          delivery_fee?: number
          delivery_fee_waived?: number
          delivery_instructions?: string | null
          delivery_landmark?: string | null
          delivery_latitude?: number | null
          delivery_longitude?: number | null
          delivery_minutes_estimate?: number | null
          delivery_postal_code?: string | null
          delivery_state?: string | null
          delivery_verification_method?: string | null
          delivery_verified_at?: string | null
          delivery_zone_id?: string | null
          delivery_zone_name?: string | null
          device_platform?:
            | Database["public"]["Enums"]["device_platform"]
            | null
          distance_km?: number | null
          fulfilment_type?: Database["public"]["Enums"]["fulfilment_type"]
          grand_total?: number
          id?: string
          idempotency_key: string
          igst_amount?: number
          internal_note?: string | null
          is_delayed?: boolean
          is_first_order?: boolean
          item_count?: number
          items_discount?: number
          items_subtotal?: number
          loyalty_discount?: number
          loyalty_points_redeemed?: number
          metadata?: Json
          order_number: string
          packaging_charge?: number
          paid_at?: string | null
          payable_amount?: number
          payment_mode?: Database["public"]["Enums"]["payment_mode"]
          payment_status?: Database["public"]["Enums"]["payment_status"]
          picked_up_at?: string | null
          pickup_code_hash?: string | null
          placed_at?: string | null
          prep_minutes_estimate?: number | null
          preparing_at?: string | null
          previous_status?: Database["public"]["Enums"]["order_status"] | null
          promised_at?: string | null
          promotion_discount?: number
          promotion_id?: string | null
          ready_at?: string | null
          refunded_amount?: number
          round_off?: number
          scheduled_for?: string | null
          service_fee?: number
          sgst_amount?: number
          status?: Database["public"]["Enums"]["order_status"]
          status_changed_at?: string
          tax_amount?: number
          taxable_amount?: number
          timing?: Database["public"]["Enums"]["order_timing"]
          tip_amount?: number
          total_discount?: number
          unit_count?: number
          updated_at?: string
          user_id: string
          wallet_applied?: number
        }
        Update: {
          accepted_at?: string | null
          address_id?: string | null
          app_version?: string | null
          assigned_at?: string | null
          branch_id?: string
          cancellation_actor?:
            | Database["public"]["Enums"]["cancellation_actor"]
            | null
          cancellation_fee?: number
          cancellation_note?: string | null
          cancellation_reason?:
            | Database["public"]["Enums"]["cancellation_reason"]
            | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          cess_amount?: number
          cgst_amount?: number
          channel?: Database["public"]["Enums"]["order_channel"]
          cod_status?: Database["public"]["Enums"]["cod_status"] | null
          completed_at?: string | null
          coupon_code?: string | null
          coupon_discount?: number
          coupon_id?: string | null
          created_at?: string
          created_by?: string | null
          currency_code?: string
          customer_email?: string | null
          customer_name?: string | null
          customer_note?: string | null
          customer_phone?: string | null
          delay_notified_at?: string | null
          delivered_at?: string | null
          delivery_address_line1?: string | null
          delivery_address_line2?: string | null
          delivery_area?: string | null
          delivery_city?: string | null
          delivery_code_attempts?: number
          delivery_code_hash?: string | null
          delivery_code_salt?: string | null
          delivery_contact_name?: string | null
          delivery_contact_phone?: string | null
          delivery_fee?: number
          delivery_fee_waived?: number
          delivery_instructions?: string | null
          delivery_landmark?: string | null
          delivery_latitude?: number | null
          delivery_longitude?: number | null
          delivery_minutes_estimate?: number | null
          delivery_postal_code?: string | null
          delivery_state?: string | null
          delivery_verification_method?: string | null
          delivery_verified_at?: string | null
          delivery_zone_id?: string | null
          delivery_zone_name?: string | null
          device_platform?:
            | Database["public"]["Enums"]["device_platform"]
            | null
          distance_km?: number | null
          fulfilment_type?: Database["public"]["Enums"]["fulfilment_type"]
          grand_total?: number
          id?: string
          idempotency_key?: string
          igst_amount?: number
          internal_note?: string | null
          is_delayed?: boolean
          is_first_order?: boolean
          item_count?: number
          items_discount?: number
          items_subtotal?: number
          loyalty_discount?: number
          loyalty_points_redeemed?: number
          metadata?: Json
          order_number?: string
          packaging_charge?: number
          paid_at?: string | null
          payable_amount?: number
          payment_mode?: Database["public"]["Enums"]["payment_mode"]
          payment_status?: Database["public"]["Enums"]["payment_status"]
          picked_up_at?: string | null
          pickup_code_hash?: string | null
          placed_at?: string | null
          prep_minutes_estimate?: number | null
          preparing_at?: string | null
          previous_status?: Database["public"]["Enums"]["order_status"] | null
          promised_at?: string | null
          promotion_discount?: number
          promotion_id?: string | null
          ready_at?: string | null
          refunded_amount?: number
          round_off?: number
          scheduled_for?: string | null
          service_fee?: number
          sgst_amount?: number
          status?: Database["public"]["Enums"]["order_status"]
          status_changed_at?: string
          tax_amount?: number
          taxable_amount?: number
          timing?: Database["public"]["Enums"]["order_timing"]
          tip_amount?: number
          total_discount?: number
          unit_count?: number
          updated_at?: string
          user_id?: string
          wallet_applied?: number
        }
        Relationships: [
          {
            foreignKeyName: "orders_address_id_fkey"
            columns: ["address_id"]
            isOneToOne: false
            referencedRelation: "addresses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_coupon_id_fkey"
            columns: ["coupon_id"]
            isOneToOne: false
            referencedRelation: "coupons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_delivery_zone_id_fkey"
            columns: ["delivery_zone_id"]
            isOneToOne: false
            referencedRelation: "delivery_zones"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_promotion_id_fkey"
            columns: ["promotion_id"]
            isOneToOne: false
            referencedRelation: "promotions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_events: {
        Row: {
          event_type: string
          gateway: Database["public"]["Enums"]["payment_gateway"]
          id: string
          order_id: string | null
          payload: Json
          payment_id: string | null
          processed: boolean
          processed_at: string | null
          processing_error: string | null
          provider_event_id: string | null
          received_at: string
          signature_verified: boolean
          source: string
        }
        Insert: {
          event_type: string
          gateway?: Database["public"]["Enums"]["payment_gateway"]
          id?: string
          order_id?: string | null
          payload: Json
          payment_id?: string | null
          processed?: boolean
          processed_at?: string | null
          processing_error?: string | null
          provider_event_id?: string | null
          received_at?: string
          signature_verified?: boolean
          source?: string
        }
        Update: {
          event_type?: string
          gateway?: Database["public"]["Enums"]["payment_gateway"]
          id?: string
          order_id?: string | null
          payload?: Json
          payment_id?: string | null
          processed?: boolean
          processed_at?: string | null
          processing_error?: string | null
          provider_event_id?: string | null
          received_at?: string
          signature_verified?: boolean
          source?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_events_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_events_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number
          amount_captured: number
          amount_refunded: number
          attempt_number: number
          authorized_at: string | null
          bank_name: string | null
          branch_id: string
          captured_at: string | null
          card_last4: string | null
          card_network: string | null
          created_at: string
          currency_code: string
          expires_at: string | null
          failed_at: string | null
          failure_code: string | null
          failure_reason: string | null
          failure_source: string | null
          gateway: Database["public"]["Enums"]["payment_gateway"]
          gateway_fee: number
          gateway_tax: number
          id: string
          idempotency_key: string
          method: Database["public"]["Enums"]["payment_method"] | null
          mode: Database["public"]["Enums"]["payment_mode"]
          notes: Json
          order_id: string
          provider_method_detail: Json
          provider_order_id: string | null
          provider_payment_id: string | null
          provider_reference_id: string | null
          provider_signature: string | null
          reconciled_at: string | null
          status: Database["public"]["Enums"]["payment_status"]
          updated_at: string
          user_id: string
          verified_by_callback: boolean
          verified_by_webhook: boolean
          vpa: string | null
          wallet_provider: string | null
        }
        Insert: {
          amount: number
          amount_captured?: number
          amount_refunded?: number
          attempt_number?: number
          authorized_at?: string | null
          bank_name?: string | null
          branch_id: string
          captured_at?: string | null
          card_last4?: string | null
          card_network?: string | null
          created_at?: string
          currency_code?: string
          expires_at?: string | null
          failed_at?: string | null
          failure_code?: string | null
          failure_reason?: string | null
          failure_source?: string | null
          gateway?: Database["public"]["Enums"]["payment_gateway"]
          gateway_fee?: number
          gateway_tax?: number
          id?: string
          idempotency_key: string
          method?: Database["public"]["Enums"]["payment_method"] | null
          mode: Database["public"]["Enums"]["payment_mode"]
          notes?: Json
          order_id: string
          provider_method_detail?: Json
          provider_order_id?: string | null
          provider_payment_id?: string | null
          provider_reference_id?: string | null
          provider_signature?: string | null
          reconciled_at?: string | null
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
          user_id: string
          verified_by_callback?: boolean
          verified_by_webhook?: boolean
          vpa?: string | null
          wallet_provider?: string | null
        }
        Update: {
          amount?: number
          amount_captured?: number
          amount_refunded?: number
          attempt_number?: number
          authorized_at?: string | null
          bank_name?: string | null
          branch_id?: string
          captured_at?: string | null
          card_last4?: string | null
          card_network?: string | null
          created_at?: string
          currency_code?: string
          expires_at?: string | null
          failed_at?: string | null
          failure_code?: string | null
          failure_reason?: string | null
          failure_source?: string | null
          gateway?: Database["public"]["Enums"]["payment_gateway"]
          gateway_fee?: number
          gateway_tax?: number
          id?: string
          idempotency_key?: string
          method?: Database["public"]["Enums"]["payment_method"] | null
          mode?: Database["public"]["Enums"]["payment_mode"]
          notes?: Json
          order_id?: string
          provider_method_detail?: Json
          provider_order_id?: string | null
          provider_payment_id?: string | null
          provider_reference_id?: string | null
          provider_signature?: string | null
          reconciled_at?: string | null
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
          user_id?: string
          verified_by_callback?: boolean
          verified_by_webhook?: boolean
          vpa?: string | null
          wallet_provider?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payments_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          action: string
          code: string
          created_at: string
          description: string | null
          id: string
          is_sensitive: boolean
          label: string
          resource: string
        }
        Insert: {
          action: string
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_sensitive?: boolean
          label: string
          resource: string
        }
        Update: {
          action?: string
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_sensitive?: boolean
          label?: string
          resource?: string
        }
        Relationships: []
      }
      product_availability: {
        Row: {
          auto_reset_daily: boolean
          branch_id: string
          changed_at: string
          changed_by: string | null
          created_at: string
          id: string
          low_stock_threshold: number | null
          out_of_stock_reason: string | null
          out_of_stock_until: string | null
          product_id: string
          remaining_quantity: number | null
          state: Database["public"]["Enums"]["availability_state"]
          updated_at: string
        }
        Insert: {
          auto_reset_daily?: boolean
          branch_id: string
          changed_at?: string
          changed_by?: string | null
          created_at?: string
          id?: string
          low_stock_threshold?: number | null
          out_of_stock_reason?: string | null
          out_of_stock_until?: string | null
          product_id: string
          remaining_quantity?: number | null
          state?: Database["public"]["Enums"]["availability_state"]
          updated_at?: string
        }
        Update: {
          auto_reset_daily?: boolean
          branch_id?: string
          changed_at?: string
          changed_by?: string | null
          created_at?: string
          id?: string
          low_stock_threshold?: number | null
          out_of_stock_reason?: string | null
          out_of_stock_until?: string | null
          product_id?: string
          remaining_quantity?: number | null
          state?: Database["public"]["Enums"]["availability_state"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_availability_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_availability_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_images: {
        Row: {
          alt_text: string | null
          created_at: string
          display_order: number
          height: number | null
          id: string
          is_primary: boolean
          product_id: string
          storage_path: string
          updated_at: string
          variants: Json
          width: number | null
        }
        Insert: {
          alt_text?: string | null
          created_at?: string
          display_order?: number
          height?: number | null
          id?: string
          is_primary?: boolean
          product_id: string
          storage_path: string
          updated_at?: string
          variants?: Json
          width?: number | null
        }
        Update: {
          alt_text?: string | null
          created_at?: string
          display_order?: number
          height?: number | null
          id?: string
          is_primary?: boolean
          product_id?: string
          storage_path?: string
          updated_at?: string
          variants?: Json
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_images_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_modifier_groups: {
        Row: {
          created_at: string
          display_order: number
          id: string
          is_required: boolean | null
          max_select: number | null
          min_select: number | null
          modifier_group_id: string
          product_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_order?: number
          id?: string
          is_required?: boolean | null
          max_select?: number | null
          min_select?: number | null
          modifier_group_id: string
          product_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_order?: number
          id?: string
          is_required?: boolean | null
          max_select?: number | null
          min_select?: number | null
          modifier_group_id?: string
          product_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_modifier_groups_modifier_group_id_fkey"
            columns: ["modifier_group_id"]
            isOneToOne: false
            referencedRelation: "modifier_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_modifier_groups_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_schedules: {
        Row: {
          branch_id: string | null
          created_at: string
          day_part: Database["public"]["Enums"]["day_part"]
          days_of_week: number[]
          ends_at: string
          id: string
          is_active: boolean
          label: string | null
          product_id: string
          starts_at: string
          updated_at: string
          valid_from: string | null
          valid_until: string | null
        }
        Insert: {
          branch_id?: string | null
          created_at?: string
          day_part?: Database["public"]["Enums"]["day_part"]
          days_of_week?: number[]
          ends_at?: string
          id?: string
          is_active?: boolean
          label?: string | null
          product_id: string
          starts_at?: string
          updated_at?: string
          valid_from?: string | null
          valid_until?: string | null
        }
        Update: {
          branch_id?: string | null
          created_at?: string
          day_part?: Database["public"]["Enums"]["day_part"]
          days_of_week?: number[]
          ends_at?: string
          id?: string
          is_active?: boolean
          label?: string | null
          product_id?: string
          starts_at?: string
          updated_at?: string
          valid_from?: string | null
          valid_until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_schedules_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_schedules_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_variants: {
        Row: {
          availability: Database["public"]["Enums"]["availability_state"]
          calories: number | null
          compare_price: number | null
          created_at: string
          deleted_at: string | null
          display_order: number
          id: string
          is_active: boolean
          is_default: boolean
          name: string
          option_group: string
          out_of_stock_until: string | null
          packaging_charge: number
          preparation_minutes: number | null
          price: number
          product_id: string
          serves_count: number | null
          sku: string | null
          updated_at: string
          weight_grams: number | null
        }
        Insert: {
          availability?: Database["public"]["Enums"]["availability_state"]
          calories?: number | null
          compare_price?: number | null
          created_at?: string
          deleted_at?: string | null
          display_order?: number
          id?: string
          is_active?: boolean
          is_default?: boolean
          name: string
          option_group?: string
          out_of_stock_until?: string | null
          packaging_charge?: number
          preparation_minutes?: number | null
          price: number
          product_id: string
          serves_count?: number | null
          sku?: string | null
          updated_at?: string
          weight_grams?: number | null
        }
        Update: {
          availability?: Database["public"]["Enums"]["availability_state"]
          calories?: number | null
          compare_price?: number | null
          created_at?: string
          deleted_at?: string | null
          display_order?: number
          id?: string
          is_active?: boolean
          is_default?: boolean
          name?: string
          option_group?: string
          out_of_stock_until?: string | null
          packaging_charge?: number
          preparation_minutes?: number | null
          price?: number
          product_id?: string
          serves_count?: number | null
          sku?: string | null
          updated_at?: string
          weight_grams?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "product_variants_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          allergens: string[]
          allows_special_instructions: boolean
          base_price: number
          branch_id: string | null
          calories: number | null
          category_id: string
          compare_price: number | null
          created_at: string
          created_by: string | null
          deleted_at: string | null
          description: string | null
          dietary_tags: string[]
          display_order: number
          food_type: Database["public"]["Enums"]["food_type"]
          hero_image_path: string | null
          id: string
          is_active: boolean
          is_best_seller: boolean
          is_combo: boolean
          is_featured: boolean
          is_new: boolean
          is_recommended: boolean
          max_quantity_per_order: number | null
          meta_description: string | null
          meta_title: string | null
          metadata: Json
          min_quantity_per_order: number
          name: string
          order_count: number
          packaging_charge: number
          preparation_minutes: number
          rating_average: number
          rating_count: number
          search_keywords: string[]
          search_vector: unknown
          serves_count: number | null
          short_description: string | null
          slug: string
          spice_level: Database["public"]["Enums"]["spice_level"]
          subcategory_id: string | null
          tax_category_id: string | null
          thumbnail_path: string | null
          updated_at: string
          updated_by: string | null
          weight_grams: number | null
        }
        Insert: {
          allergens?: string[]
          allows_special_instructions?: boolean
          base_price?: number
          branch_id?: string | null
          calories?: number | null
          category_id: string
          compare_price?: number | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          dietary_tags?: string[]
          display_order?: number
          food_type?: Database["public"]["Enums"]["food_type"]
          hero_image_path?: string | null
          id?: string
          is_active?: boolean
          is_best_seller?: boolean
          is_combo?: boolean
          is_featured?: boolean
          is_new?: boolean
          is_recommended?: boolean
          max_quantity_per_order?: number | null
          meta_description?: string | null
          meta_title?: string | null
          metadata?: Json
          min_quantity_per_order?: number
          name: string
          order_count?: number
          packaging_charge?: number
          preparation_minutes?: number
          rating_average?: number
          rating_count?: number
          search_keywords?: string[]
          search_vector?: unknown
          serves_count?: number | null
          short_description?: string | null
          slug: string
          spice_level?: Database["public"]["Enums"]["spice_level"]
          subcategory_id?: string | null
          tax_category_id?: string | null
          thumbnail_path?: string | null
          updated_at?: string
          updated_by?: string | null
          weight_grams?: number | null
        }
        Update: {
          allergens?: string[]
          allows_special_instructions?: boolean
          base_price?: number
          branch_id?: string | null
          calories?: number | null
          category_id?: string
          compare_price?: number | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          dietary_tags?: string[]
          display_order?: number
          food_type?: Database["public"]["Enums"]["food_type"]
          hero_image_path?: string | null
          id?: string
          is_active?: boolean
          is_best_seller?: boolean
          is_combo?: boolean
          is_featured?: boolean
          is_new?: boolean
          is_recommended?: boolean
          max_quantity_per_order?: number | null
          meta_description?: string | null
          meta_title?: string | null
          metadata?: Json
          min_quantity_per_order?: number
          name?: string
          order_count?: number
          packaging_charge?: number
          preparation_minutes?: number
          rating_average?: number
          rating_count?: number
          search_keywords?: string[]
          search_vector?: unknown
          serves_count?: number | null
          short_description?: string | null
          slug?: string
          spice_level?: Database["public"]["Enums"]["spice_level"]
          subcategory_id?: string | null
          tax_category_id?: string | null
          thumbnail_path?: string | null
          updated_at?: string
          updated_by?: string | null
          weight_grams?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "products_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_subcategory_id_fkey"
            columns: ["subcategory_id"]
            isOneToOne: false
            referencedRelation: "subcategories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_tax_category_id_fkey"
            columns: ["tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          average_order_value: number
          blocked_at: string | null
          blocked_by: string | null
          blocked_reason: string | null
          cancelled_orders: number
          completed_orders: number
          created_at: string
          date_of_birth: string | null
          deleted_at: string | null
          display_name: string | null
          email: string | null
          email_enabled: boolean
          first_order_at: string | null
          full_name: string | null
          gender: string | null
          id: string
          internal_notes: string | null
          last_app_version: string | null
          last_order_at: string | null
          last_seen_at: string | null
          lifetime_value: number
          marketing_opt_in: boolean
          metadata: Json
          onboarding_completed: boolean
          phone: string | null
          preferred_language: string
          profile_completed_at: string | null
          push_enabled: boolean
          referral_code: string | null
          referred_by: string | null
          signup_channel: string | null
          sms_enabled: boolean
          status: Database["public"]["Enums"]["account_status"]
          total_orders: number
          updated_at: string
          whatsapp_enabled: boolean
        }
        Insert: {
          avatar_url?: string | null
          average_order_value?: number
          blocked_at?: string | null
          blocked_by?: string | null
          blocked_reason?: string | null
          cancelled_orders?: number
          completed_orders?: number
          created_at?: string
          date_of_birth?: string | null
          deleted_at?: string | null
          display_name?: string | null
          email?: string | null
          email_enabled?: boolean
          first_order_at?: string | null
          full_name?: string | null
          gender?: string | null
          id: string
          internal_notes?: string | null
          last_app_version?: string | null
          last_order_at?: string | null
          last_seen_at?: string | null
          lifetime_value?: number
          marketing_opt_in?: boolean
          metadata?: Json
          onboarding_completed?: boolean
          phone?: string | null
          preferred_language?: string
          profile_completed_at?: string | null
          push_enabled?: boolean
          referral_code?: string | null
          referred_by?: string | null
          signup_channel?: string | null
          sms_enabled?: boolean
          status?: Database["public"]["Enums"]["account_status"]
          total_orders?: number
          updated_at?: string
          whatsapp_enabled?: boolean
        }
        Update: {
          avatar_url?: string | null
          average_order_value?: number
          blocked_at?: string | null
          blocked_by?: string | null
          blocked_reason?: string | null
          cancelled_orders?: number
          completed_orders?: number
          created_at?: string
          date_of_birth?: string | null
          deleted_at?: string | null
          display_name?: string | null
          email?: string | null
          email_enabled?: boolean
          first_order_at?: string | null
          full_name?: string | null
          gender?: string | null
          id?: string
          internal_notes?: string | null
          last_app_version?: string | null
          last_order_at?: string | null
          last_seen_at?: string | null
          lifetime_value?: number
          marketing_opt_in?: boolean
          metadata?: Json
          onboarding_completed?: boolean
          phone?: string | null
          preferred_language?: string
          profile_completed_at?: string | null
          push_enabled?: boolean
          referral_code?: string | null
          referred_by?: string | null
          signup_channel?: string | null
          sms_enabled?: boolean
          status?: Database["public"]["Enums"]["account_status"]
          total_orders?: number
          updated_at?: string
          whatsapp_enabled?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "profiles_referred_by_fkey"
            columns: ["referred_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      promotions: {
        Row: {
          badge_text: string | null
          banner_path: string | null
          branch_id: string | null
          created_at: string
          created_by: string | null
          deleted_at: string | null
          description: string | null
          discount_kind: Database["public"]["Enums"]["discount_kind"]
          discount_value: number
          eligible_category_ids: string[]
          eligible_fulfilment: Database["public"]["Enums"]["fulfilment_type"][]
          eligible_product_ids: string[]
          ends_at: string | null
          headline: string
          id: string
          is_active: boolean
          max_discount_amount: number | null
          min_order_amount: number
          name: string
          priority: number
          stacks_with_coupon: boolean
          starts_at: string
          trigger: Database["public"]["Enums"]["promotion_trigger"]
          updated_at: string
          valid_days_of_week: number[]
          valid_from_time: string | null
          valid_to_time: string | null
        }
        Insert: {
          badge_text?: string | null
          banner_path?: string | null
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          discount_kind: Database["public"]["Enums"]["discount_kind"]
          discount_value?: number
          eligible_category_ids?: string[]
          eligible_fulfilment?: Database["public"]["Enums"]["fulfilment_type"][]
          eligible_product_ids?: string[]
          ends_at?: string | null
          headline: string
          id?: string
          is_active?: boolean
          max_discount_amount?: number | null
          min_order_amount?: number
          name: string
          priority?: number
          stacks_with_coupon?: boolean
          starts_at?: string
          trigger?: Database["public"]["Enums"]["promotion_trigger"]
          updated_at?: string
          valid_days_of_week?: number[]
          valid_from_time?: string | null
          valid_to_time?: string | null
        }
        Update: {
          badge_text?: string | null
          banner_path?: string | null
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          discount_kind?: Database["public"]["Enums"]["discount_kind"]
          discount_value?: number
          eligible_category_ids?: string[]
          eligible_fulfilment?: Database["public"]["Enums"]["fulfilment_type"][]
          eligible_product_ids?: string[]
          ends_at?: string | null
          headline?: string
          id?: string
          is_active?: boolean
          max_discount_amount?: number | null
          min_order_amount?: number
          name?: string
          priority?: number
          stacks_with_coupon?: boolean
          starts_at?: string
          trigger?: Database["public"]["Enums"]["promotion_trigger"]
          updated_at?: string
          valid_days_of_week?: number[]
          valid_from_time?: string | null
          valid_to_time?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "promotions_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      purchase_entries: {
        Row: {
          branch_id: string
          created_at: string
          created_by: string | null
          id: string
          invoice_date: string
          invoice_number: string | null
          note: string | null
          supplier_name: string | null
          total_amount: number
          updated_at: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          invoice_date?: string
          invoice_number?: string | null
          note?: string | null
          supplier_name?: string | null
          total_amount?: number
          updated_at?: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          invoice_date?: string
          invoice_number?: string | null
          note?: string | null
          supplier_name?: string | null
          total_amount?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_entries_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      purchase_entry_items: {
        Row: {
          created_at: string
          id: string
          ingredient_id: string
          purchase_entry_id: string
          quantity: number
          total_cost: number
          unit: Database["public"]["Enums"]["unit_of_measure"]
          unit_cost: number
        }
        Insert: {
          created_at?: string
          id?: string
          ingredient_id: string
          purchase_entry_id: string
          quantity: number
          total_cost?: number
          unit: Database["public"]["Enums"]["unit_of_measure"]
          unit_cost?: number
        }
        Update: {
          created_at?: string
          id?: string
          ingredient_id?: string
          purchase_entry_id?: string
          quantity?: number
          total_cost?: number
          unit?: Database["public"]["Enums"]["unit_of_measure"]
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "purchase_entry_items_ingredient_id_fkey"
            columns: ["ingredient_id"]
            isOneToOne: false
            referencedRelation: "ingredients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_entry_items_purchase_entry_id_fkey"
            columns: ["purchase_entry_id"]
            isOneToOne: false
            referencedRelation: "purchase_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      rate_limits: {
        Row: {
          blocked_until: string | null
          bucket: string
          created_at: string
          hit_count: number
          id: number
          identifier: string
          updated_at: string
          window_start: string
        }
        Insert: {
          blocked_until?: string | null
          bucket: string
          created_at?: string
          hit_count?: number
          id?: number
          identifier: string
          updated_at?: string
          window_start: string
        }
        Update: {
          blocked_until?: string | null
          bucket?: string
          created_at?: string
          hit_count?: number
          id?: number
          identifier?: string
          updated_at?: string
          window_start?: string
        }
        Relationships: []
      }
      recipes: {
        Row: {
          created_at: string
          id: string
          ingredient_id: string
          is_optional: boolean
          product_id: string
          quantity: number
          unit: Database["public"]["Enums"]["unit_of_measure"]
          updated_at: string
          variant_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          ingredient_id: string
          is_optional?: boolean
          product_id: string
          quantity: number
          unit: Database["public"]["Enums"]["unit_of_measure"]
          updated_at?: string
          variant_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          ingredient_id?: string
          is_optional?: boolean
          product_id?: string
          quantity?: number
          unit?: Database["public"]["Enums"]["unit_of_measure"]
          updated_at?: string
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "recipes_ingredient_id_fkey"
            columns: ["ingredient_id"]
            isOneToOne: false
            referencedRelation: "ingredients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipes_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipes_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      refund_items: {
        Row: {
          amount: number
          created_at: string
          id: string
          order_item_id: string
          quantity: number
          refund_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          order_item_id: string
          quantity: number
          refund_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          order_item_id?: string
          quantity?: number
          refund_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "refund_items_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_items_refund_id_fkey"
            columns: ["refund_id"]
            isOneToOne: false
            referencedRelation: "refunds"
            referencedColumns: ["id"]
          },
        ]
      }
      refund_policies: {
        Row: {
          auto_approve_limit: number
          created_at: string
          id: string
          is_active: boolean
          max_request_amount: number | null
          requires_second_approval_above: number | null
          role_code: Database["public"]["Enums"]["app_role"]
          updated_at: string
        }
        Insert: {
          auto_approve_limit?: number
          created_at?: string
          id?: string
          is_active?: boolean
          max_request_amount?: number | null
          requires_second_approval_above?: number | null
          role_code: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Update: {
          auto_approve_limit?: number
          created_at?: string
          id?: string
          is_active?: boolean
          max_request_amount?: number | null
          requires_second_approval_above?: number | null
          role_code?: Database["public"]["Enums"]["app_role"]
          updated_at?: string
        }
        Relationships: []
      }
      refunds: {
        Row: {
          amount: number
          amount_processed: number
          approved_at: string | null
          approved_by: string | null
          completed_at: string | null
          created_at: string
          destination: Database["public"]["Enums"]["refund_destination"]
          failed_at: string | null
          failure_code: string | null
          failure_reason: string | null
          id: string
          idempotency_key: string
          kind: Database["public"]["Enums"]["refund_kind"]
          metadata: Json
          order_id: string
          payment_id: string | null
          processed_at: string | null
          provider_refund_id: string | null
          provider_status: string | null
          reason: Database["public"]["Enums"]["refund_reason"]
          reason_note: string | null
          rejected_at: string | null
          rejected_by: string | null
          rejection_note: string | null
          requested_at: string
          requested_by: string | null
          speed_requested: string
          status: Database["public"]["Enums"]["refund_status"]
          support_ticket_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          amount: number
          amount_processed?: number
          approved_at?: string | null
          approved_by?: string | null
          completed_at?: string | null
          created_at?: string
          destination?: Database["public"]["Enums"]["refund_destination"]
          failed_at?: string | null
          failure_code?: string | null
          failure_reason?: string | null
          id?: string
          idempotency_key: string
          kind: Database["public"]["Enums"]["refund_kind"]
          metadata?: Json
          order_id: string
          payment_id?: string | null
          processed_at?: string | null
          provider_refund_id?: string | null
          provider_status?: string | null
          reason: Database["public"]["Enums"]["refund_reason"]
          reason_note?: string | null
          rejected_at?: string | null
          rejected_by?: string | null
          rejection_note?: string | null
          requested_at?: string
          requested_by?: string | null
          speed_requested?: string
          status?: Database["public"]["Enums"]["refund_status"]
          support_ticket_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          amount?: number
          amount_processed?: number
          approved_at?: string | null
          approved_by?: string | null
          completed_at?: string | null
          created_at?: string
          destination?: Database["public"]["Enums"]["refund_destination"]
          failed_at?: string | null
          failure_code?: string | null
          failure_reason?: string | null
          id?: string
          idempotency_key?: string
          kind?: Database["public"]["Enums"]["refund_kind"]
          metadata?: Json
          order_id?: string
          payment_id?: string | null
          processed_at?: string | null
          provider_refund_id?: string | null
          provider_status?: string | null
          reason?: Database["public"]["Enums"]["refund_reason"]
          reason_note?: string | null
          rejected_at?: string | null
          rejected_by?: string | null
          rejection_note?: string | null
          requested_at?: string
          requested_by?: string | null
          speed_requested?: string
          status?: Database["public"]["Enums"]["refund_status"]
          support_ticket_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "refunds_approver_profile_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_rejecter_profile_fkey"
            columns: ["rejected_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_requester_profile_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_ticket_fk"
            columns: ["support_ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      review_items: {
        Row: {
          comment: string | null
          created_at: string
          id: string
          order_item_id: string | null
          product_id: string | null
          rating: number
          review_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string
          id?: string
          order_item_id?: string | null
          product_id?: string | null
          rating: number
          review_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string
          id?: string
          order_item_id?: string | null
          product_id?: string | null
          rating?: number
          review_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "review_items_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "review_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "review_items_review_id_fkey"
            columns: ["review_id"]
            isOneToOne: false
            referencedRelation: "reviews"
            referencedColumns: ["id"]
          },
        ]
      }
      reviews: {
        Row: {
          branch_id: string
          comment: string | null
          created_at: string
          delivery_partner_id: string | null
          delivery_rating: number | null
          flagged_reason: string | null
          food_rating: number
          id: string
          images: Json
          internal_note: string | null
          moderated_at: string | null
          moderated_by: string | null
          order_id: string
          overall_rating: number
          responded_at: string | null
          responded_by: string | null
          response_body: string | null
          status: Database["public"]["Enums"]["review_status"]
          tags: string[]
          updated_at: string
          user_id: string
        }
        Insert: {
          branch_id: string
          comment?: string | null
          created_at?: string
          delivery_partner_id?: string | null
          delivery_rating?: number | null
          flagged_reason?: string | null
          food_rating: number
          id?: string
          images?: Json
          internal_note?: string | null
          moderated_at?: string | null
          moderated_by?: string | null
          order_id: string
          overall_rating: number
          responded_at?: string | null
          responded_by?: string | null
          response_body?: string | null
          status?: Database["public"]["Enums"]["review_status"]
          tags?: string[]
          updated_at?: string
          user_id: string
        }
        Update: {
          branch_id?: string
          comment?: string | null
          created_at?: string
          delivery_partner_id?: string | null
          delivery_rating?: number | null
          flagged_reason?: string | null
          food_rating?: number
          id?: string
          images?: Json
          internal_note?: string | null
          moderated_at?: string | null
          moderated_by?: string | null
          order_id?: string
          overall_rating?: number
          responded_at?: string | null
          responded_by?: string | null
          response_body?: string | null
          status?: Database["public"]["Enums"]["review_status"]
          tags?: string[]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reviews_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_delivery_partner_id_fkey"
            columns: ["delivery_partner_id"]
            isOneToOne: false
            referencedRelation: "delivery_partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          granted_at: string
          granted_by: string | null
          permission_id: string
          role_id: string
        }
        Insert: {
          granted_at?: string
          granted_by?: string | null
          permission_id: string
          role_id: string
        }
        Update: {
          granted_at?: string
          granted_by?: string | null
          permission_id?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_id_fkey"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          code: Database["public"]["Enums"]["app_role"]
          created_at: string
          description: string | null
          id: string
          is_default: boolean
          is_system: boolean
          label: string
          rank: number
          surfaces: Database["public"]["Enums"]["role_surface"][]
          updated_at: string
        }
        Insert: {
          code: Database["public"]["Enums"]["app_role"]
          created_at?: string
          description?: string | null
          id?: string
          is_default?: boolean
          is_system?: boolean
          label: string
          rank?: number
          surfaces?: Database["public"]["Enums"]["role_surface"][]
          updated_at?: string
        }
        Update: {
          code?: Database["public"]["Enums"]["app_role"]
          created_at?: string
          description?: string | null
          id?: string
          is_default?: boolean
          is_system?: boolean
          label?: string
          rank?: number
          surfaces?: Database["public"]["Enums"]["role_surface"][]
          updated_at?: string
        }
        Relationships: []
      }
      search_queries: {
        Row: {
          clicked_product_id: string | null
          created_at: string
          id: string
          normalized: string
          query: string
          result_count: number
          user_id: string | null
        }
        Insert: {
          clicked_product_id?: string | null
          created_at?: string
          id?: string
          normalized: string
          query: string
          result_count?: number
          user_id?: string | null
        }
        Update: {
          clicked_product_id?: string | null
          created_at?: string
          id?: string
          normalized?: string
          query?: string
          result_count?: number
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "search_queries_clicked_product_id_fkey"
            columns: ["clicked_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "search_queries_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      settings: {
        Row: {
          branch_id: string | null
          description: string | null
          group: string
          is_public: boolean
          is_secret: boolean
          key: string
          label: string
          updated_at: string
          updated_by: string | null
          value: Json
          value_type: string
        }
        Insert: {
          branch_id?: string | null
          description?: string | null
          group?: string
          is_public?: boolean
          is_secret?: boolean
          key: string
          label: string
          updated_at?: string
          updated_by?: string | null
          value: Json
          value_type?: string
        }
        Update: {
          branch_id?: string | null
          description?: string | null
          group?: string
          is_public?: boolean
          is_secret?: boolean
          key?: string
          label?: string
          updated_at?: string
          updated_by?: string | null
          value?: Json
          value_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "settings_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      settings_history: {
        Row: {
          changed_by: string | null
          created_at: string
          id: string
          key: string
          new_value: Json | null
          old_value: Json | null
        }
        Insert: {
          changed_by?: string | null
          created_at?: string
          id?: string
          key: string
          new_value?: Json | null
          old_value?: Json | null
        }
        Update: {
          changed_by?: string | null
          created_at?: string
          id?: string
          key?: string
          new_value?: Json | null
          old_value?: Json | null
        }
        Relationships: []
      }
      staff_members: {
        Row: {
          branch_id: string
          created_at: string
          created_by: string | null
          deleted_at: string | null
          department: string | null
          designation: string | null
          emergency_contact_name: string | null
          emergency_contact_phone: string | null
          employee_code: string | null
          exited_on: string | null
          id: string
          is_active: boolean
          joined_on: string
          notes: string | null
          photo_path: string | null
          shift_end: string | null
          shift_start: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          branch_id: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          department?: string | null
          designation?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          employee_code?: string | null
          exited_on?: string | null
          id?: string
          is_active?: boolean
          joined_on?: string
          notes?: string | null
          photo_path?: string | null
          shift_end?: string | null
          shift_start?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          branch_id?: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          department?: string | null
          designation?: string | null
          emergency_contact_name?: string | null
          emergency_contact_phone?: string | null
          employee_code?: string | null
          exited_on?: string | null
          id?: string
          is_active?: boolean
          joined_on?: string
          notes?: string | null
          photo_path?: string | null
          shift_end?: string | null
          shift_start?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_members_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_members_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_movements: {
        Row: {
          branch_id: string
          created_at: string
          created_by: string | null
          id: string
          ingredient_id: string
          kind: Database["public"]["Enums"]["stock_movement_kind"]
          note: string | null
          order_id: string | null
          quantity: number
          quantity_after: number | null
          reference: string | null
          total_cost: number
          unit: Database["public"]["Enums"]["unit_of_measure"]
          unit_cost: number
        }
        Insert: {
          branch_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          ingredient_id: string
          kind: Database["public"]["Enums"]["stock_movement_kind"]
          note?: string | null
          order_id?: string | null
          quantity: number
          quantity_after?: number | null
          reference?: string | null
          total_cost?: number
          unit: Database["public"]["Enums"]["unit_of_measure"]
          unit_cost?: number
        }
        Update: {
          branch_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          ingredient_id?: string
          kind?: Database["public"]["Enums"]["stock_movement_kind"]
          note?: string | null
          order_id?: string | null
          quantity?: number
          quantity_after?: number | null
          reference?: string | null
          total_cost?: number
          unit?: Database["public"]["Enums"]["unit_of_measure"]
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_ingredient_id_fkey"
            columns: ["ingredient_id"]
            isOneToOne: false
            referencedRelation: "ingredients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      subcategories: {
        Row: {
          category_id: string
          created_at: string
          deleted_at: string | null
          description: string | null
          display_order: number
          id: string
          image_path: string | null
          is_active: boolean
          meta_description: string | null
          meta_title: string | null
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          category_id: string
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          id?: string
          image_path?: string | null
          is_active?: boolean
          meta_description?: string | null
          meta_title?: string | null
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          category_id?: string
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          display_order?: number
          id?: string
          image_path?: string | null
          is_active?: boolean
          meta_description?: string | null
          meta_title?: string | null
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "subcategories_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
        ]
      }
      support_messages: {
        Row: {
          attachments: Json
          author_id: string | null
          author_kind: Database["public"]["Enums"]["message_author"]
          body: string
          created_at: string
          id: string
          is_internal: boolean
          read_by_agent_at: string | null
          read_by_customer_at: string | null
          ticket_id: string
        }
        Insert: {
          attachments?: Json
          author_id?: string | null
          author_kind: Database["public"]["Enums"]["message_author"]
          body: string
          created_at?: string
          id?: string
          is_internal?: boolean
          read_by_agent_at?: string | null
          read_by_customer_at?: string | null
          ticket_id: string
        }
        Update: {
          attachments?: Json
          author_id?: string | null
          author_kind?: Database["public"]["Enums"]["message_author"]
          body?: string
          created_at?: string
          id?: string
          is_internal?: boolean
          read_by_agent_at?: string | null
          read_by_customer_at?: string | null
          ticket_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "support_messages_author_profile_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_messages_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      support_tickets: {
        Row: {
          assigned_at: string | null
          assigned_to: string | null
          branch_id: string | null
          category: Database["public"]["Enums"]["ticket_category"]
          closed_at: string | null
          created_at: string
          description: string
          escalated_at: string | null
          escalated_to: string | null
          escalation_reason: string | null
          first_response_at: string | null
          first_response_due_at: string | null
          id: string
          last_message_at: string
          metadata: Json
          order_id: string | null
          priority: Database["public"]["Enums"]["ticket_priority"]
          refund_id: string | null
          reopen_count: number
          resolution_due_at: string | null
          resolution_note: string | null
          resolved_at: string | null
          resolved_by: string | null
          satisfaction_note: string | null
          satisfaction_rating: number | null
          status: Database["public"]["Enums"]["ticket_status"]
          subject: string
          ticket_number: string
          updated_at: string
          user_id: string
          wallet_credit_amount: number
        }
        Insert: {
          assigned_at?: string | null
          assigned_to?: string | null
          branch_id?: string | null
          category: Database["public"]["Enums"]["ticket_category"]
          closed_at?: string | null
          created_at?: string
          description: string
          escalated_at?: string | null
          escalated_to?: string | null
          escalation_reason?: string | null
          first_response_at?: string | null
          first_response_due_at?: string | null
          id?: string
          last_message_at?: string
          metadata?: Json
          order_id?: string | null
          priority?: Database["public"]["Enums"]["ticket_priority"]
          refund_id?: string | null
          reopen_count?: number
          resolution_due_at?: string | null
          resolution_note?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          satisfaction_note?: string | null
          satisfaction_rating?: number | null
          status?: Database["public"]["Enums"]["ticket_status"]
          subject: string
          ticket_number: string
          updated_at?: string
          user_id: string
          wallet_credit_amount?: number
        }
        Update: {
          assigned_at?: string | null
          assigned_to?: string | null
          branch_id?: string | null
          category?: Database["public"]["Enums"]["ticket_category"]
          closed_at?: string | null
          created_at?: string
          description?: string
          escalated_at?: string | null
          escalated_to?: string | null
          escalation_reason?: string | null
          first_response_at?: string | null
          first_response_due_at?: string | null
          id?: string
          last_message_at?: string
          metadata?: Json
          order_id?: string | null
          priority?: Database["public"]["Enums"]["ticket_priority"]
          refund_id?: string | null
          reopen_count?: number
          resolution_due_at?: string | null
          resolution_note?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          satisfaction_note?: string | null
          satisfaction_rating?: number | null
          status?: Database["public"]["Enums"]["ticket_status"]
          subject?: string
          ticket_number?: string
          updated_at?: string
          user_id?: string
          wallet_credit_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "support_tickets_assignee_profile_fkey"
            columns: ["assigned_to"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_tickets_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_tickets_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_tickets_refund_id_fkey"
            columns: ["refund_id"]
            isOneToOne: false
            referencedRelation: "refunds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_tickets_resolver_profile_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_tickets_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      tax_categories: {
        Row: {
          cess_rate: number
          cgst_rate: number
          code: string
          created_at: string
          deleted_at: string | null
          description: string | null
          hsn_sac_code: string | null
          id: string
          igst_rate: number
          is_active: boolean
          is_default: boolean
          is_inclusive: boolean
          name: string
          rate: number
          sgst_rate: number
          updated_at: string
        }
        Insert: {
          cess_rate?: number
          cgst_rate?: number
          code: string
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          hsn_sac_code?: string | null
          id?: string
          igst_rate?: number
          is_active?: boolean
          is_default?: boolean
          is_inclusive?: boolean
          name: string
          rate?: number
          sgst_rate?: number
          updated_at?: string
        }
        Update: {
          cess_rate?: number
          cgst_rate?: number
          code?: string
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          hsn_sac_code?: string | null
          id?: string
          igst_rate?: number
          is_active?: boolean
          is_default?: boolean
          is_inclusive?: boolean
          name?: string
          rate?: number
          sgst_rate?: number
          updated_at?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          assigned_at: string
          assigned_by: string | null
          branch_id: string | null
          created_at: string
          expires_at: string | null
          id: string
          is_active: boolean
          is_primary: boolean
          revoked_at: string | null
          revoked_by: string | null
          role_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          expires_at?: string | null
          id?: string
          is_active?: boolean
          is_primary?: boolean
          revoked_at?: string | null
          revoked_by?: string | null
          role_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          expires_at?: string | null
          id?: string
          is_active?: boolean
          is_primary?: boolean
          revoked_at?: string | null
          revoked_by?: string | null
          role_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_roles_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      verification_codes: {
        Row: {
          attempts: number
          code_hash: string
          consumed_at: string | null
          created_at: string
          created_ip: unknown
          expires_at: string
          id: string
          max_attempts: number
          order_id: string | null
          purpose: string
          salt: string
          subject: string
          user_id: string | null
        }
        Insert: {
          attempts?: number
          code_hash: string
          consumed_at?: string | null
          created_at?: string
          created_ip?: unknown
          expires_at: string
          id?: string
          max_attempts?: number
          order_id?: string | null
          purpose: string
          salt: string
          subject: string
          user_id?: string | null
        }
        Update: {
          attempts?: number
          code_hash?: string
          consumed_at?: string | null
          created_at?: string
          created_ip?: unknown
          expires_at?: string
          id?: string
          max_attempts?: number
          order_id?: string | null
          purpose?: string
          salt?: string
          subject?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verification_codes_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      wallet_accounts: {
        Row: {
          balance: number
          created_at: string
          currency_code: string
          frozen_reason: string | null
          id: string
          is_frozen: boolean
          lifetime_credited: number
          lifetime_debited: number
          updated_at: string
          user_id: string
        }
        Insert: {
          balance?: number
          created_at?: string
          currency_code?: string
          frozen_reason?: string | null
          id?: string
          is_frozen?: boolean
          lifetime_credited?: number
          lifetime_debited?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          balance?: number
          created_at?: string
          currency_code?: string
          frozen_reason?: string | null
          id?: string
          is_frozen?: boolean
          lifetime_credited?: number
          lifetime_debited?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_accounts_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      wallet_transactions: {
        Row: {
          amount: number
          balance_after: number
          created_at: string
          created_by: string | null
          description: string
          expires_at: string | null
          id: string
          idempotency_key: string | null
          kind: Database["public"]["Enums"]["wallet_entry_kind"]
          order_id: string | null
          reference: string | null
          refund_id: string | null
          support_ticket_id: string | null
          user_id: string
          wallet_account_id: string
        }
        Insert: {
          amount: number
          balance_after: number
          created_at?: string
          created_by?: string | null
          description: string
          expires_at?: string | null
          id?: string
          idempotency_key?: string | null
          kind: Database["public"]["Enums"]["wallet_entry_kind"]
          order_id?: string | null
          reference?: string | null
          refund_id?: string | null
          support_ticket_id?: string | null
          user_id: string
          wallet_account_id: string
        }
        Update: {
          amount?: number
          balance_after?: number
          created_at?: string
          created_by?: string | null
          description?: string
          expires_at?: string | null
          id?: string
          idempotency_key?: string | null
          kind?: Database["public"]["Enums"]["wallet_entry_kind"]
          order_id?: string | null
          reference?: string | null
          refund_id?: string | null
          support_ticket_id?: string | null
          user_id?: string
          wallet_account_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_transactions_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transactions_refund_id_fkey"
            columns: ["refund_id"]
            isOneToOne: false
            referencedRelation: "refunds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transactions_support_ticket_id_fkey"
            columns: ["support_ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transactions_user_profile_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transactions_wallet_account_id_fkey"
            columns: ["wallet_account_id"]
            isOneToOne: false
            referencedRelation: "wallet_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_order: {
        Args: { p_order_id: string; p_prep_minutes?: number }
        Returns: Json
      }
      admin_customers: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_search?: string
          p_segment?: string
        }
        Returns: Json
      }
      admin_orders: {
        Args: {
          p_branch_id?: string
          p_delayed_only?: boolean
          p_from?: string
          p_fulfilment?: Database["public"]["Enums"]["fulfilment_type"]
          p_limit?: number
          p_offset?: number
          p_payment_modes?: Database["public"]["Enums"]["payment_mode"][]
          p_search?: string
          p_statuses?: Database["public"]["Enums"]["order_status"][]
          p_to?: string
        }
        Returns: Json
      }
      admin_refund_queue: { Args: { p_branch_id?: string }; Returns: Json }
      admin_support_inbox: {
        Args: {
          p_branch_id?: string
          p_limit?: number
          p_statuses?: Database["public"]["Enums"]["ticket_status"][]
        }
        Returns: Json
      }
      app_config: { Args: { p_branch_id?: string }; Returns: Json }
      apply_coupon: {
        Args: { p_branch_id?: string; p_cart_id?: string; p_code: string }
        Returns: Json
      }
      approve_refund: {
        Args: { p_note?: string; p_refund_id: string }
        Returns: Json
      }
      approve_rider: {
        Args: {
          p_delivery_partner_id: string
          p_force?: boolean
          p_note?: string
        }
        Returns: Json
      }
      assign_rider: {
        Args: {
          p_delivery_partner_id: string
          p_mode?: Database["public"]["Enums"]["assignment_mode"]
          p_offer_ttl_seconds?: number
          p_order_id: string
        }
        Returns: Json
      }
      audit_trail: {
        Args: {
          p_action?: Database["public"]["Enums"]["audit_action"]
          p_actor_id?: string
          p_entity_id?: string
          p_entity_type?: string
          p_from?: string
          p_limit?: number
          p_offset?: number
          p_to?: string
        }
        Returns: {
          action: Database["public"]["Enums"]["audit_action"]
          actor_id: string
          actor_kind: Database["public"]["Enums"]["actor_kind"]
          actor_name: string
          actor_role: Database["public"]["Enums"]["app_role"]
          changed_fields: string[]
          created_at: string
          entity_id: string
          entity_label: string
          entity_type: string
          id: number
          ip_address: unknown
          new_value: Json
          old_value: Json
          reason: string
          total_count: number
        }[]
      }
      available_coupons: { Args: { p_branch_id?: string }; Returns: Json }
      available_riders: {
        Args: { p_branch_id?: string; p_order_id?: string }
        Returns: {
          active_load: number
          delivery_partner_id: string
          distance_to_store_km: number
          duty_state: Database["public"]["Enums"]["rider_duty_state"]
          full_name: string
          last_location_at: string
          max_concurrent_orders: number
          phone: string
          photo_path: string
          rating_average: number
          score: number
          successful_deliveries: number
          vehicle_type: Database["public"]["Enums"]["vehicle_type"]
        }[]
      }
      branch_ordering_state: { Args: { p_branch_id?: string }; Returns: Json }
      calculate_checkout: {
        Args: {
          p_branch_id?: string
          p_cart_id?: string
          p_loyalty_points?: number
          p_payment_mode?: Database["public"]["Enums"]["payment_mode"]
          p_tip_amount?: number
        }
        Returns: Json
      }
      campaign_audience_size: { Args: { p_campaign_id: string }; Returns: Json }
      cancel_campaign: {
        Args: { p_campaign_id: string; p_reason?: string }
        Returns: Json
      }
      cancel_order: {
        Args: {
          p_note?: string
          p_order_id: string
          p_reason?: Database["public"]["Enums"]["cancellation_reason"]
        }
        Returns: Json
      }
      cancel_order_item: {
        Args: { p_note?: string; p_order_item_id: string }
        Returns: Json
      }
      cancellation_options: { Args: { p_order_id: string }; Returns: Json }
      cart_add_item: {
        Args: {
          p_branch_id?: string
          p_modifiers?: Json
          p_product_id: string
          p_quantity?: number
          p_replace_quantity?: boolean
          p_special_instructions?: string
          p_variant_id?: string
        }
        Returns: Json
      }
      cart_clear: { Args: { p_branch_id?: string }; Returns: Json }
      cart_remove_item: { Args: { p_cart_item_id: string }; Returns: Json }
      cart_set_options: {
        Args: {
          p_address_id?: string
          p_branch_id?: string
          p_clear_coupon?: boolean
          p_cooking_instructions?: string
          p_delivery_instructions?: string
          p_fulfilment_type?: Database["public"]["Enums"]["fulfilment_type"]
          p_scheduled_for?: string
          p_timing?: Database["public"]["Enums"]["order_timing"]
          p_use_wallet?: boolean
        }
        Returns: Json
      }
      cart_update_item: {
        Args: { p_cart_item_id: string; p_quantity: number }
        Returns: Json
      }
      check_serviceability: {
        Args: {
          p_branch_id?: string
          p_latitude: number
          p_longitude: number
          p_order_amount?: number
        }
        Returns: Json
      }
      complete_delivery: {
        Args: {
          p_assignment_id: string
          p_cash_collected?: number
          p_manager_override?: boolean
          p_note?: string
          p_otp?: string
          p_proof_photo_path?: string
        }
        Returns: Json
      }
      create_support_ticket: {
        Args: {
          p_attachments?: Json
          p_category: Database["public"]["Enums"]["ticket_category"]
          p_description: string
          p_order_id?: string
          p_subject: string
        }
        Returns: Json
      }
      customer_detail: { Args: { p_user_id: string }; Returns: Json }
      dashboard_charts: {
        Args: {
          p_branch_id?: string
          p_from?: string
          p_granularity?: string
          p_to?: string
        }
        Returns: Json
      }
      dashboard_overview: {
        Args: { p_branch_id?: string; p_from?: string; p_to?: string }
        Returns: Json
      }
      delete_address: { Args: { p_id: string }; Returns: boolean }
      fail_delivery: {
        Args: { p_assignment_id: string; p_note?: string; p_reason: string }
        Returns: Json
      }
      feature_enabled: {
        Args: { p_key: string; p_user_id?: string }
        Returns: boolean
      }
      has_permission: {
        Args: { p_branch_id?: string; p_permission: string }
        Returns: boolean
      }
      home_feed: { Args: { p_branch_id?: string }; Returns: Json }
      kitchen_availability: { Args: { p_branch_id?: string }; Returns: Json }
      kitchen_queue: { Args: { p_branch_id?: string }; Returns: Json }
      launch_campaign: { Args: { p_campaign_id: string }; Returns: Json }
      live_operations: { Args: { p_branch_id?: string }; Returns: Json }
      manage_user_role: {
        Args: {
          p_branch_id?: string
          p_grant?: boolean
          p_make_primary?: boolean
          p_role: Database["public"]["Enums"]["app_role"]
          p_user_id: string
        }
        Returns: Json
      }
      mark_notifications_read: { Args: { p_ids?: string[] }; Returns: number }
      mark_order_ready: { Args: { p_order_id: string }; Returns: Json }
      menu_catalog: {
        Args: { p_branch_id?: string; p_category_id?: string }
        Returns: Json
      }
      moderate_review: {
        Args: {
          p_flagged_reason?: string
          p_internal_note?: string
          p_response?: string
          p_review_id: string
          p_status?: Database["public"]["Enums"]["review_status"]
        }
        Returns: Json
      }
      my_deliveries: { Args: { p_include_history?: boolean }; Returns: Json }
      my_earnings: { Args: { p_from?: string; p_to?: string }; Returns: Json }
      my_orders: {
        Args: { p_limit?: number; p_offset?: number; p_scope?: string }
        Returns: Json
      }
      my_rider_onboarding: { Args: never; Returns: Json }
      my_session: { Args: never; Returns: Json }
      my_wallet: { Args: never; Returns: Json }
      order_detail: { Args: { p_order_id: string }; Returns: Json }
      order_invoice: { Args: { p_order_id: string }; Returns: Json }
      post_delivery_earning: {
        Args: {
          p_amount: number
          p_delivery_partner_id: string
          p_description?: string
          p_earned_on?: string
          p_entry_type: string
        }
        Returns: Json
      }
      post_support_message: {
        Args: {
          p_attachments?: Json
          p_body: string
          p_is_internal?: boolean
          p_ticket_id: string
        }
        Returns: string
      }
      product_detail: {
        Args: { p_branch_id?: string; p_product_id?: string; p_slug?: string }
        Returns: Json
      }
      publish_rider_location: {
        Args: {
          p_accuracy_meters?: number
          p_battery_level?: number
          p_heading_degrees?: number
          p_is_moving?: boolean
          p_latitude: number
          p_longitude: number
          p_speed_kmph?: number
        }
        Returns: Json
      }
      refresh_address_serviceability: {
        Args: { p_address_id: string }
        Returns: Json
      }
      refund_eligibility: { Args: { p_order_id: string }; Returns: Json }
      register_device_token: {
        Args: {
          p_app_version?: string
          p_device_id?: string
          p_device_model?: string
          p_locale?: string
          p_os_version?: string
          p_platform: Database["public"]["Enums"]["device_platform"]
          p_timezone?: string
          p_token: string
        }
        Returns: string
      }
      reject_order: {
        Args: {
          p_note?: string
          p_order_id: string
          p_reason?: Database["public"]["Enums"]["cancellation_reason"]
        }
        Returns: Json
      }
      reject_refund: {
        Args: { p_note: string; p_refund_id: string }
        Returns: Json
      }
      remove_coupon: { Args: { p_branch_id?: string }; Returns: Json }
      reorder: { Args: { p_order_id: string }; Returns: Json }
      report_customers: {
        Args: { p_branch_id?: string; p_from?: string; p_to?: string }
        Returns: Json
      }
      report_payments: {
        Args: { p_branch_id?: string; p_from?: string; p_to?: string }
        Returns: Json
      }
      report_products: {
        Args: { p_branch_id?: string; p_from?: string; p_to?: string }
        Returns: {
          average_rating: number
          category_name: string
          discount_given: number
          gross_revenue: number
          is_available: boolean
          net_revenue: number
          orders_count: number
          product_id: string
          product_name: string
          refunded_units: number
          units_sold: number
        }[]
      }
      report_sales: {
        Args: {
          p_branch_id?: string
          p_from?: string
          p_limit?: number
          p_offset?: number
          p_to?: string
        }
        Returns: {
          cgst_amount: number
          coupon_code: string
          customer_name: string
          customer_phone: string
          delivery_fee: number
          fulfilment_type: Database["public"]["Enums"]["fulfilment_type"]
          grand_total: number
          item_count: number
          items_subtotal: number
          net_amount: number
          order_id: string
          order_number: string
          packaging_charge: number
          payment_method: Database["public"]["Enums"]["payment_method"]
          payment_mode: Database["public"]["Enums"]["payment_mode"]
          placed_at: string
          refunded_amount: number
          rider_name: string
          sgst_amount: number
          status: Database["public"]["Enums"]["order_status"]
          tax_amount: number
          taxable_amount: number
          tip_amount: number
          total_count: number
          total_discount: number
          unit_count: number
          zone_name: string
        }[]
      }
      report_tax_summary: {
        Args: { p_branch_id?: string; p_from?: string; p_to?: string }
        Returns: Json
      }
      request_order_help: {
        Args: {
          p_category: Database["public"]["Enums"]["ticket_category"]
          p_description: string
          p_item_ids?: string[]
          p_order_id: string
        }
        Returns: Json
      }
      request_refund: {
        Args: {
          p_amount?: number
          p_destination?: Database["public"]["Enums"]["refund_destination"]
          p_idempotency_key?: string
          p_items?: Json
          p_kind: Database["public"]["Enums"]["refund_kind"]
          p_order_id: string
          p_reason: Database["public"]["Enums"]["refund_reason"]
          p_reason_note?: string
          p_support_ticket_id?: string
        }
        Returns: Json
      }
      respond_to_assignment: {
        Args: {
          p_accept: boolean
          p_assignment_id: string
          p_rejection_reason?: string
        }
        Returns: Json
      }
      review_rider_document: {
        Args: {
          p_approve: boolean
          p_document_id: string
          p_rejection_reason?: string
        }
        Returns: Json
      }
      rider_arrived_at_customer: {
        Args: { p_assignment_id: string }
        Returns: Json
      }
      rider_arrived_at_store: {
        Args: { p_assignment_id: string }
        Returns: Json
      }
      rider_directory: { Args: { p_branch_id?: string }; Returns: Json }
      rider_onboarding: {
        Args: { p_delivery_partner_id: string }
        Returns: Json
      }
      run_scheduled_jobs: { Args: { p_cadence?: string }; Returns: Json }
      search_menu: {
        Args: { p_branch_id?: string; p_limit?: number; p_query: string }
        Returns: Json
      }
      search_suggestions: { Args: { p_branch_id?: string }; Returns: Json }
      set_branch_status: {
        Args: {
          p_branch_id?: string
          p_note?: string
          p_reason?: Database["public"]["Enums"]["branch_closure_reason"]
          p_resume_after_minutes?: number
          p_status: Database["public"]["Enums"]["branch_status"]
        }
        Returns: Json
      }
      set_duty_state: {
        Args: {
          p_battery_level?: number
          p_latitude?: number
          p_longitude?: number
          p_reason?: string
          p_state: Database["public"]["Enums"]["rider_duty_state"]
        }
        Returns: Json
      }
      set_product_availability: {
        Args: {
          p_branch_id?: string
          p_minutes?: number
          p_product_id: string
          p_reason?: string
          p_remaining_quantity?: number
          p_state: Database["public"]["Enums"]["availability_state"]
        }
        Returns: Json
      }
      set_products_availability: {
        Args: {
          p_branch_id?: string
          p_minutes?: number
          p_product_ids: string[]
          p_reason?: string
          p_state: Database["public"]["Enums"]["availability_state"]
        }
        Returns: number
      }
      settle_cod: {
        Args: {
          p_delivery_partner_id: string
          p_note?: string
          p_order_ids?: string[]
        }
        Returns: Json
      }
      staff_directory: { Args: { p_branch_id?: string }; Returns: Json }
      start_preparing: { Args: { p_order_id: string }; Returns: Json }
      submit_review: {
        Args: {
          p_comment?: string
          p_delivery_rating?: number
          p_food_rating: number
          p_item_ratings?: Json
          p_order_id: string
          p_overall_rating: number
          p_tags?: string[]
        }
        Returns: Json
      }
      submit_rider_document: {
        Args: {
          p_document_number?: string
          p_document_type: Database["public"]["Enums"]["rider_document_type"]
          p_expires_on?: string
          p_issued_on?: string
          p_storage_path: string
        }
        Returns: Json
      }
      support_ticket_detail: { Args: { p_ticket_id: string }; Returns: Json }
      suspend_rider: {
        Args: {
          p_delivery_partner_id: string
          p_reason: string
          p_until?: string
        }
        Returns: Json
      }
      svc_audit: {
        Args: {
          p_action: Database["public"]["Enums"]["audit_action"]
          p_actor_id?: string
          p_branch_id?: string
          p_entity_id?: string
          p_entity_label?: string
          p_entity_type: string
          p_new_value?: Json
          p_old_value?: Json
          p_reason?: string
        }
        Returns: number
      }
      svc_claim_notifications: {
        Args: {
          p_channels?: Database["public"]["Enums"]["notification_channel"][]
          p_limit?: number
        }
        Returns: Json
      }
      svc_complete_refund: {
        Args: {
          p_amount_processed?: number
          p_provider_refund_id?: string
          p_provider_status?: string
          p_refund_id: string
        }
        Returns: Json
      }
      svc_deactivate_device_token: {
        Args: { p_token_id: string }
        Returns: undefined
      }
      svc_enqueue_notification: {
        Args: {
          p_channels?: Database["public"]["Enums"]["notification_channel"][]
          p_dedupe_key?: string
          p_destination?: string
          p_event: Database["public"]["Enums"]["notification_event"]
          p_order_id?: string
          p_scheduled_for?: string
          p_user_id: string
          p_vars?: Json
        }
        Returns: number
      }
      svc_fail_refund: {
        Args: {
          p_failure_code: string
          p_failure_reason: string
          p_refund_id: string
        }
        Returns: Json
      }
      svc_find_payment: {
        Args: { p_provider_order_id?: string; p_provider_payment_id?: string }
        Returns: Json
      }
      svc_find_refund: { Args: { p_provider_refund_id: string }; Returns: Json }
      svc_launch_campaign: { Args: { p_campaign_id: string }; Returns: Json }
      svc_mark_refund_processing: {
        Args: {
          p_provider_refund_id: string
          p_provider_status?: string
          p_refund_id: string
        }
        Returns: undefined
      }
      svc_place_order: {
        Args: {
          p_app_version?: string
          p_branch_id?: string
          p_cart_id?: string
          p_channel?: Database["public"]["Enums"]["order_channel"]
          p_device_platform?: Database["public"]["Enums"]["device_platform"]
          p_idempotency_key: string
          p_loyalty_points?: number
          p_payment_mode?: Database["public"]["Enums"]["payment_mode"]
          p_tip_amount?: number
          p_user_id: string
        }
        Returns: Json
      }
      svc_post_loyalty_entry: {
        Args: {
          p_description: string
          p_idempotency_key?: string
          p_kind: Database["public"]["Enums"]["loyalty_entry_kind"]
          p_monetary_value?: number
          p_order_id?: string
          p_points: number
          p_user_id: string
        }
        Returns: Json
      }
      svc_post_wallet_entry: {
        Args: {
          p_amount: number
          p_description: string
          p_expires_at?: string
          p_idempotency_key?: string
          p_kind: Database["public"]["Enums"]["wallet_entry_kind"]
          p_order_id?: string
          p_refund_id?: string
          p_user_id: string
        }
        Returns: Json
      }
      svc_record_payment_capture: {
        Args: {
          p_amount_captured: number
          p_gateway_fee?: number
          p_gateway_tax?: number
          p_method?: Database["public"]["Enums"]["payment_method"]
          p_method_detail?: Json
          p_payment_id: string
          p_provider_payment_id: string
          p_source?: string
        }
        Returns: Json
      }
      svc_record_payment_failure: {
        Args: {
          p_failure_code: string
          p_failure_reason: string
          p_payment_id: string
          p_source?: string
        }
        Returns: Json
      }
      svc_register_webhook_event: {
        Args: {
          p_event_type: string
          p_gateway: Database["public"]["Enums"]["payment_gateway"]
          p_order_id?: string
          p_payload: Json
          p_payment_id?: string
          p_provider_event_id: string
          p_signature_verified: boolean
        }
        Returns: Json
      }
      svc_settle_notification: {
        Args: {
          p_failure_reason?: string
          p_id: string
          p_provider?: string
          p_provider_message_id?: string
          p_status: Database["public"]["Enums"]["notification_status"]
        }
        Returns: undefined
      }
      svc_settle_webhook_event: {
        Args: { p_error?: string; p_event_id: string; p_processed: boolean }
        Returns: undefined
      }
      svc_transition_order: {
        Args: {
          p_actor_id?: string
          p_actor_kind?: Database["public"]["Enums"]["actor_kind"]
          p_metadata?: Json
          p_note?: string
          p_order_id: string
          p_to_status: Database["public"]["Enums"]["order_status"]
        }
        Returns: Json
      }
      unregister_device_token: { Args: { p_token: string }; Returns: boolean }
      update_my_profile: {
        Args: {
          p_avatar_url?: string
          p_date_of_birth?: string
          p_email?: string
          p_email_enabled?: boolean
          p_full_name?: string
          p_gender?: string
          p_marketing_opt_in?: boolean
          p_preferred_language?: string
          p_push_enabled?: boolean
          p_sms_enabled?: boolean
          p_whatsapp_enabled?: boolean
        }
        Returns: Json
      }
      update_my_rider_profile: {
        Args: {
          p_alternate_phone?: string
          p_emergency_contact_name?: string
          p_emergency_contact_phone?: string
          p_photo_path?: string
          p_upi_id?: string
        }
        Returns: Json
      }
      upsert_address: {
        Args: {
          p_address_line1: string
          p_address_line2?: string
          p_area?: string
          p_city: string
          p_contact_name?: string
          p_contact_phone?: string
          p_delivery_instructions?: string
          p_formatted_address?: string
          p_google_place_id?: string
          p_id?: string
          p_is_default?: boolean
          p_label?: string
          p_landmark?: string
          p_latitude: number
          p_location_source?: string
          p_longitude: number
          p_postal_code?: string
          p_state: string
        }
        Returns: Json
      }
      verify_pickup: {
        Args: { p_assignment_id: string; p_code: string }
        Returns: Json
      }
    }
    Enums: {
      account_status: "ACTIVE" | "BLOCKED" | "SUSPENDED" | "DELETED"
      actor_kind: "USER" | "SYSTEM" | "WEBHOOK" | "SCHEDULER"
      app_role:
        | "CUSTOMER"
        | "DELIVERY_PARTNER"
        | "KITCHEN_STAFF"
        | "MANAGER"
        | "OPERATIONS"
        | "FINANCE"
        | "SUPPORT"
        | "MARKETING"
        | "ADMIN"
        | "OWNER"
      assignment_mode: "MANUAL" | "AUTO" | "SELF_ASSIGNED"
      assignment_status:
        | "OFFERED"
        | "ACCEPTED"
        | "REJECTED"
        | "EXPIRED"
        | "CANCELLED"
        | "AT_STORE"
        | "PICKED_UP"
        | "AT_CUSTOMER"
        | "COMPLETED"
        | "FAILED"
      audience_segment:
        | "ALL_CUSTOMERS"
        | "NEW_CUSTOMERS"
        | "INACTIVE_CUSTOMERS"
        | "HIGH_VALUE_CUSTOMERS"
        | "CATEGORY_BUYERS"
        | "ABANDONED_CART"
        | "CUSTOM_LIST"
      audit_action:
        | "CREATE"
        | "UPDATE"
        | "DELETE"
        | "RESTORE"
        | "LOGIN"
        | "LOGOUT"
        | "PERMISSION_GRANT"
        | "PERMISSION_REVOKE"
        | "ROLE_ASSIGN"
        | "ROLE_REVOKE"
        | "ORDER_STATUS_OVERRIDE"
        | "ORDER_CANCEL"
        | "PRICE_CHANGE"
        | "REFUND_REQUEST"
        | "REFUND_APPROVE"
        | "REFUND_REJECT"
        | "RIDER_ASSIGN"
        | "RIDER_REASSIGN"
        | "SETTINGS_CHANGE"
        | "FEATURE_FLAG_CHANGE"
        | "CUSTOMER_BLOCK"
        | "CUSTOMER_UNBLOCK"
        | "RIDER_SUSPEND"
        | "MANUAL_DELIVERY_OVERRIDE"
        | "WALLET_ADJUSTMENT"
        | "COUPON_CHANGE"
        | "BULK_UPDATE"
        | "EXPORT"
      availability_state:
        | "AVAILABLE"
        | "OUT_OF_STOCK"
        | "TEMPORARILY_UNAVAILABLE"
      banner_link_kind:
        | "NONE"
        | "CATEGORY"
        | "PRODUCT"
        | "COUPON"
        | "COLLECTION"
        | "EXTERNAL_URL"
        | "IN_APP_ROUTE"
      branch_closure_reason:
        | "SCHEDULED_CLOSED"
        | "TOO_BUSY"
        | "TECHNICAL_ISSUE"
        | "KITCHEN_ISSUE"
        | "WEATHER"
        | "HOLIDAY"
        | "OTHER"
      branch_status: "OPEN" | "CLOSED" | "PAUSED" | "BUSY"
      campaign_status:
        | "DRAFT"
        | "SCHEDULED"
        | "RUNNING"
        | "PAUSED"
        | "COMPLETED"
        | "CANCELLED"
      cancellation_actor: "CUSTOMER" | "STORE" | "ADMIN" | "RIDER" | "SYSTEM"
      cancellation_reason:
        | "CUSTOMER_CHANGED_MIND"
        | "ORDERED_BY_MISTAKE"
        | "DELIVERY_TOO_LONG"
        | "ADDRESS_WRONG"
        | "ITEM_UNAVAILABLE"
        | "KITCHEN_OVERLOADED"
        | "RESTAURANT_CLOSED"
        | "NO_DELIVERY_PARTNER"
        | "PAYMENT_ISSUE"
        | "DUPLICATE_ORDER"
        | "CUSTOMER_UNREACHABLE"
        | "WEATHER"
        | "FRAUD_SUSPECTED"
        | "OTHER"
      cod_status: "COD_PENDING" | "COD_COLLECTED" | "COD_FAILED" | "COD_WAIVED"
      coupon_audience:
        | "ALL"
        | "FIRST_ORDER"
        | "SPECIFIC_CUSTOMERS"
        | "SEGMENT"
        | "INACTIVE_CUSTOMERS"
        | "HIGH_VALUE_CUSTOMERS"
      day_part:
        | "BREAKFAST"
        | "LUNCH"
        | "SNACKS"
        | "DINNER"
        | "LATE_NIGHT"
        | "ALL_DAY"
      device_platform: "ANDROID" | "IOS" | "WEB"
      discount_kind:
        | "PERCENTAGE"
        | "FLAT"
        | "FREE_DELIVERY"
        | "PRODUCT_DISCOUNT"
        | "CATEGORY_DISCOUNT"
        | "BUY_X_GET_Y"
      document_status: "PENDING" | "APPROVED" | "REJECTED" | "EXPIRED"
      food_type: "VEG" | "NON_VEG" | "EGG" | "VEGAN"
      fulfilment_type: "DELIVERY" | "PICKUP"
      home_section_kind:
        | "HERO_CAROUSEL"
        | "CATEGORY_GRID"
        | "CATEGORY_CAROUSEL"
        | "PRODUCT_CAROUSEL"
        | "BEST_SELLERS"
        | "TODAYS_OFFERS"
        | "RECOMMENDED_COMBOS"
        | "NEW_ARRIVALS"
        | "PRICE_BUCKET"
        | "POPULAR_NOW"
        | "BUY_AGAIN"
        | "RECENTLY_ORDERED"
        | "CUSTOMER_FAVOURITES"
        | "CAMPAIGN_BANNER"
        | "COUPON_STRIP"
        | "RICH_TEXT"
      legal_document_kind:
        | "TERMS"
        | "PRIVACY"
        | "REFUND_POLICY"
        | "CANCELLATION_POLICY"
        | "DELIVERY_POLICY"
        | "ABOUT"
        | "FAQ"
        | "SHIPPING_POLICY"
      loyalty_entry_kind:
        | "EARN"
        | "REDEEM"
        | "EXPIRE"
        | "ADJUSTMENT"
        | "REVERSAL"
      message_author: "CUSTOMER" | "AGENT" | "SYSTEM"
      modifier_selection: "SINGLE" | "MULTIPLE"
      notification_channel: "PUSH" | "SMS" | "EMAIL" | "IN_APP" | "WHATSAPP"
      notification_event:
        | "OTP"
        | "ORDER_PLACED"
        | "PAYMENT_CONFIRMED"
        | "PAYMENT_FAILED"
        | "ORDER_ACCEPTED"
        | "ORDER_REJECTED"
        | "ORDER_PREPARING"
        | "ORDER_READY"
        | "RIDER_ASSIGNED"
        | "ORDER_PICKED_UP"
        | "RIDER_NEARBY"
        | "ORDER_DELIVERED"
        | "ORDER_CANCELLED"
        | "REFUND_INITIATED"
        | "REFUND_COMPLETED"
        | "DELIVERY_OTP"
        | "PICKUP_OTP"
        | "NEW_ORDER_KITCHEN"
        | "NEW_ASSIGNMENT_RIDER"
        | "SUPPORT_REPLY"
        | "REVIEW_REQUEST"
        | "PROMOTION"
        | "CAMPAIGN"
        | "SYSTEM_ALERT"
        | "RIDER_DOCUMENT_REVIEWED"
        | "RIDER_APPROVED"
        | "RIDER_SUSPENDED"
      notification_status:
        | "QUEUED"
        | "SENDING"
        | "SENT"
        | "DELIVERED"
        | "READ"
        | "FAILED"
        | "SUPPRESSED"
      order_channel: "MOBILE_APP" | "ADMIN_MANUAL" | "PHONE" | "WEB" | "WALK_IN"
      order_status:
        | "PENDING_PAYMENT"
        | "PAYMENT_CONFIRMED"
        | "ORDER_PLACED"
        | "STORE_ACCEPTED"
        | "PREPARING"
        | "READY_FOR_PICKUP"
        | "RIDER_ASSIGNED"
        | "RIDER_ARRIVED_STORE"
        | "PICKED_UP"
        | "OUT_FOR_DELIVERY"
        | "RIDER_ARRIVED_CUSTOMER"
        | "DELIVERED"
        | "COMPLETED"
        | "PAYMENT_FAILED"
        | "STORE_REJECTED"
        | "CUSTOMER_CANCELLED"
        | "ADMIN_CANCELLED"
        | "DELIVERY_FAILED"
        | "REFUND_PENDING"
        | "PARTIALLY_REFUNDED"
        | "REFUNDED"
      order_timing: "NOW" | "SCHEDULED"
      payment_gateway: "RAZORPAY" | "CASH" | "WALLET" | "MANUAL"
      payment_method:
        | "UPI"
        | "CARD"
        | "CREDIT_CARD"
        | "DEBIT_CARD"
        | "NETBANKING"
        | "WALLET_PROVIDER"
        | "EMI"
        | "PAYLATER"
        | "CASH"
        | "STORE_CREDIT"
      payment_mode:
        | "ONLINE"
        | "COD"
        | "WALLET"
        | "SPLIT_WALLET_ONLINE"
        | "SPLIT_WALLET_COD"
      payment_status:
        | "CREATED"
        | "PENDING"
        | "AUTHORIZED"
        | "CAPTURED"
        | "FAILED"
        | "CANCELLED"
        | "EXPIRED"
        | "REFUND_PENDING"
        | "PARTIALLY_REFUNDED"
        | "REFUNDED"
      promotion_trigger: "AUTOMATIC" | "COUPON_CODE"
      refund_destination:
        | "ORIGINAL_PAYMENT_METHOD"
        | "WALLET_CREDIT"
        | "BANK_TRANSFER"
        | "CASH"
      refund_kind: "FULL_REFUND" | "PARTIAL_REFUND" | "ITEM_REFUND"
      refund_reason:
        | "RESTAURANT_CANCELLED"
        | "ITEM_UNAVAILABLE"
        | "PAYMENT_ISSUE"
        | "WRONG_ITEM"
        | "MISSING_ITEM"
        | "QUALITY_ISSUE"
        | "DELIVERY_FAILURE"
        | "LATE_DELIVERY"
        | "CUSTOMER_CANCELLATION"
        | "DUPLICATE_PAYMENT"
        | "MANUAL_ADJUSTMENT"
        | "GOODWILL"
      refund_status:
        | "REQUESTED"
        | "APPROVAL_PENDING"
        | "APPROVED"
        | "REJECTED"
        | "PROCESSING"
        | "COMPLETED"
        | "FAILED"
      review_status: "PUBLISHED" | "PENDING_MODERATION" | "FLAGGED" | "HIDDEN"
      rider_document_type:
        | "DRIVING_LICENCE"
        | "AADHAAR"
        | "PAN"
        | "VEHICLE_RC"
        | "INSURANCE"
        | "BANK_PASSBOOK"
        | "PROFILE_PHOTO"
        | "POLICE_VERIFICATION"
      rider_duty_state: "OFFLINE" | "AVAILABLE" | "BUSY" | "ON_BREAK"
      rider_onboarding_status:
        | "PENDING"
        | "DOCUMENTS_SUBMITTED"
        | "VERIFIED"
        | "ACTIVE"
        | "SUSPENDED"
        | "REJECTED"
      role_surface:
        | "MOBILE_CUSTOMER"
        | "MOBILE_DELIVERY"
        | "MOBILE_KITCHEN"
        | "ADMIN_WEB"
      service_mode: "DELIVERY" | "PICKUP" | "BOTH"
      spice_level: "NONE" | "MILD" | "MEDIUM" | "HOT" | "EXTRA_HOT"
      stock_movement_kind:
        | "PURCHASE"
        | "CONSUMPTION"
        | "WASTAGE"
        | "ADJUSTMENT"
        | "RETURN"
        | "OPENING_BALANCE"
        | "TRANSFER"
      ticket_category:
        | "ORDER_DELAYED"
        | "MISSING_ITEM"
        | "WRONG_ITEM"
        | "FOOD_QUALITY"
        | "PAYMENT_PROBLEM"
        | "REFUND"
        | "DELIVERY_ISSUE"
        | "CANCELLATION"
        | "APP_ISSUE"
        | "OTHER"
      ticket_priority: "LOW" | "NORMAL" | "HIGH" | "URGENT"
      ticket_status:
        | "OPEN"
        | "IN_PROGRESS"
        | "WAITING_ON_CUSTOMER"
        | "ESCALATED"
        | "RESOLVED"
        | "CLOSED"
      unit_of_measure:
        | "GRAM"
        | "KILOGRAM"
        | "MILLILITRE"
        | "LITRE"
        | "PIECE"
        | "PACKET"
        | "DOZEN"
      vehicle_type: "BICYCLE" | "SCOOTER" | "MOTORCYCLE" | "CAR" | "ON_FOOT"
      wallet_entry_kind:
        | "CREDIT"
        | "DEBIT"
        | "REFUND"
        | "PROMOTION"
        | "CASHBACK"
        | "ADJUSTMENT"
        | "EXPIRY"
        | "REVERSAL"
      zone_kind: "RADIUS" | "POLYGON"
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
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      account_status: ["ACTIVE", "BLOCKED", "SUSPENDED", "DELETED"],
      actor_kind: ["USER", "SYSTEM", "WEBHOOK", "SCHEDULER"],
      app_role: [
        "CUSTOMER",
        "DELIVERY_PARTNER",
        "KITCHEN_STAFF",
        "MANAGER",
        "OPERATIONS",
        "FINANCE",
        "SUPPORT",
        "MARKETING",
        "ADMIN",
        "OWNER",
      ],
      assignment_mode: ["MANUAL", "AUTO", "SELF_ASSIGNED"],
      assignment_status: [
        "OFFERED",
        "ACCEPTED",
        "REJECTED",
        "EXPIRED",
        "CANCELLED",
        "AT_STORE",
        "PICKED_UP",
        "AT_CUSTOMER",
        "COMPLETED",
        "FAILED",
      ],
      audience_segment: [
        "ALL_CUSTOMERS",
        "NEW_CUSTOMERS",
        "INACTIVE_CUSTOMERS",
        "HIGH_VALUE_CUSTOMERS",
        "CATEGORY_BUYERS",
        "ABANDONED_CART",
        "CUSTOM_LIST",
      ],
      audit_action: [
        "CREATE",
        "UPDATE",
        "DELETE",
        "RESTORE",
        "LOGIN",
        "LOGOUT",
        "PERMISSION_GRANT",
        "PERMISSION_REVOKE",
        "ROLE_ASSIGN",
        "ROLE_REVOKE",
        "ORDER_STATUS_OVERRIDE",
        "ORDER_CANCEL",
        "PRICE_CHANGE",
        "REFUND_REQUEST",
        "REFUND_APPROVE",
        "REFUND_REJECT",
        "RIDER_ASSIGN",
        "RIDER_REASSIGN",
        "SETTINGS_CHANGE",
        "FEATURE_FLAG_CHANGE",
        "CUSTOMER_BLOCK",
        "CUSTOMER_UNBLOCK",
        "RIDER_SUSPEND",
        "MANUAL_DELIVERY_OVERRIDE",
        "WALLET_ADJUSTMENT",
        "COUPON_CHANGE",
        "BULK_UPDATE",
        "EXPORT",
      ],
      availability_state: [
        "AVAILABLE",
        "OUT_OF_STOCK",
        "TEMPORARILY_UNAVAILABLE",
      ],
      banner_link_kind: [
        "NONE",
        "CATEGORY",
        "PRODUCT",
        "COUPON",
        "COLLECTION",
        "EXTERNAL_URL",
        "IN_APP_ROUTE",
      ],
      branch_closure_reason: [
        "SCHEDULED_CLOSED",
        "TOO_BUSY",
        "TECHNICAL_ISSUE",
        "KITCHEN_ISSUE",
        "WEATHER",
        "HOLIDAY",
        "OTHER",
      ],
      branch_status: ["OPEN", "CLOSED", "PAUSED", "BUSY"],
      campaign_status: [
        "DRAFT",
        "SCHEDULED",
        "RUNNING",
        "PAUSED",
        "COMPLETED",
        "CANCELLED",
      ],
      cancellation_actor: ["CUSTOMER", "STORE", "ADMIN", "RIDER", "SYSTEM"],
      cancellation_reason: [
        "CUSTOMER_CHANGED_MIND",
        "ORDERED_BY_MISTAKE",
        "DELIVERY_TOO_LONG",
        "ADDRESS_WRONG",
        "ITEM_UNAVAILABLE",
        "KITCHEN_OVERLOADED",
        "RESTAURANT_CLOSED",
        "NO_DELIVERY_PARTNER",
        "PAYMENT_ISSUE",
        "DUPLICATE_ORDER",
        "CUSTOMER_UNREACHABLE",
        "WEATHER",
        "FRAUD_SUSPECTED",
        "OTHER",
      ],
      cod_status: ["COD_PENDING", "COD_COLLECTED", "COD_FAILED", "COD_WAIVED"],
      coupon_audience: [
        "ALL",
        "FIRST_ORDER",
        "SPECIFIC_CUSTOMERS",
        "SEGMENT",
        "INACTIVE_CUSTOMERS",
        "HIGH_VALUE_CUSTOMERS",
      ],
      day_part: [
        "BREAKFAST",
        "LUNCH",
        "SNACKS",
        "DINNER",
        "LATE_NIGHT",
        "ALL_DAY",
      ],
      device_platform: ["ANDROID", "IOS", "WEB"],
      discount_kind: [
        "PERCENTAGE",
        "FLAT",
        "FREE_DELIVERY",
        "PRODUCT_DISCOUNT",
        "CATEGORY_DISCOUNT",
        "BUY_X_GET_Y",
      ],
      document_status: ["PENDING", "APPROVED", "REJECTED", "EXPIRED"],
      food_type: ["VEG", "NON_VEG", "EGG", "VEGAN"],
      fulfilment_type: ["DELIVERY", "PICKUP"],
      home_section_kind: [
        "HERO_CAROUSEL",
        "CATEGORY_GRID",
        "CATEGORY_CAROUSEL",
        "PRODUCT_CAROUSEL",
        "BEST_SELLERS",
        "TODAYS_OFFERS",
        "RECOMMENDED_COMBOS",
        "NEW_ARRIVALS",
        "PRICE_BUCKET",
        "POPULAR_NOW",
        "BUY_AGAIN",
        "RECENTLY_ORDERED",
        "CUSTOMER_FAVOURITES",
        "CAMPAIGN_BANNER",
        "COUPON_STRIP",
        "RICH_TEXT",
      ],
      legal_document_kind: [
        "TERMS",
        "PRIVACY",
        "REFUND_POLICY",
        "CANCELLATION_POLICY",
        "DELIVERY_POLICY",
        "ABOUT",
        "FAQ",
        "SHIPPING_POLICY",
      ],
      loyalty_entry_kind: [
        "EARN",
        "REDEEM",
        "EXPIRE",
        "ADJUSTMENT",
        "REVERSAL",
      ],
      message_author: ["CUSTOMER", "AGENT", "SYSTEM"],
      modifier_selection: ["SINGLE", "MULTIPLE"],
      notification_channel: ["PUSH", "SMS", "EMAIL", "IN_APP", "WHATSAPP"],
      notification_event: [
        "OTP",
        "ORDER_PLACED",
        "PAYMENT_CONFIRMED",
        "PAYMENT_FAILED",
        "ORDER_ACCEPTED",
        "ORDER_REJECTED",
        "ORDER_PREPARING",
        "ORDER_READY",
        "RIDER_ASSIGNED",
        "ORDER_PICKED_UP",
        "RIDER_NEARBY",
        "ORDER_DELIVERED",
        "ORDER_CANCELLED",
        "REFUND_INITIATED",
        "REFUND_COMPLETED",
        "DELIVERY_OTP",
        "PICKUP_OTP",
        "NEW_ORDER_KITCHEN",
        "NEW_ASSIGNMENT_RIDER",
        "SUPPORT_REPLY",
        "REVIEW_REQUEST",
        "PROMOTION",
        "CAMPAIGN",
        "SYSTEM_ALERT",
        "RIDER_DOCUMENT_REVIEWED",
        "RIDER_APPROVED",
        "RIDER_SUSPENDED",
      ],
      notification_status: [
        "QUEUED",
        "SENDING",
        "SENT",
        "DELIVERED",
        "READ",
        "FAILED",
        "SUPPRESSED",
      ],
      order_channel: ["MOBILE_APP", "ADMIN_MANUAL", "PHONE", "WEB", "WALK_IN"],
      order_status: [
        "PENDING_PAYMENT",
        "PAYMENT_CONFIRMED",
        "ORDER_PLACED",
        "STORE_ACCEPTED",
        "PREPARING",
        "READY_FOR_PICKUP",
        "RIDER_ASSIGNED",
        "RIDER_ARRIVED_STORE",
        "PICKED_UP",
        "OUT_FOR_DELIVERY",
        "RIDER_ARRIVED_CUSTOMER",
        "DELIVERED",
        "COMPLETED",
        "PAYMENT_FAILED",
        "STORE_REJECTED",
        "CUSTOMER_CANCELLED",
        "ADMIN_CANCELLED",
        "DELIVERY_FAILED",
        "REFUND_PENDING",
        "PARTIALLY_REFUNDED",
        "REFUNDED",
      ],
      order_timing: ["NOW", "SCHEDULED"],
      payment_gateway: ["RAZORPAY", "CASH", "WALLET", "MANUAL"],
      payment_method: [
        "UPI",
        "CARD",
        "CREDIT_CARD",
        "DEBIT_CARD",
        "NETBANKING",
        "WALLET_PROVIDER",
        "EMI",
        "PAYLATER",
        "CASH",
        "STORE_CREDIT",
      ],
      payment_mode: [
        "ONLINE",
        "COD",
        "WALLET",
        "SPLIT_WALLET_ONLINE",
        "SPLIT_WALLET_COD",
      ],
      payment_status: [
        "CREATED",
        "PENDING",
        "AUTHORIZED",
        "CAPTURED",
        "FAILED",
        "CANCELLED",
        "EXPIRED",
        "REFUND_PENDING",
        "PARTIALLY_REFUNDED",
        "REFUNDED",
      ],
      promotion_trigger: ["AUTOMATIC", "COUPON_CODE"],
      refund_destination: [
        "ORIGINAL_PAYMENT_METHOD",
        "WALLET_CREDIT",
        "BANK_TRANSFER",
        "CASH",
      ],
      refund_kind: ["FULL_REFUND", "PARTIAL_REFUND", "ITEM_REFUND"],
      refund_reason: [
        "RESTAURANT_CANCELLED",
        "ITEM_UNAVAILABLE",
        "PAYMENT_ISSUE",
        "WRONG_ITEM",
        "MISSING_ITEM",
        "QUALITY_ISSUE",
        "DELIVERY_FAILURE",
        "LATE_DELIVERY",
        "CUSTOMER_CANCELLATION",
        "DUPLICATE_PAYMENT",
        "MANUAL_ADJUSTMENT",
        "GOODWILL",
      ],
      refund_status: [
        "REQUESTED",
        "APPROVAL_PENDING",
        "APPROVED",
        "REJECTED",
        "PROCESSING",
        "COMPLETED",
        "FAILED",
      ],
      review_status: ["PUBLISHED", "PENDING_MODERATION", "FLAGGED", "HIDDEN"],
      rider_document_type: [
        "DRIVING_LICENCE",
        "AADHAAR",
        "PAN",
        "VEHICLE_RC",
        "INSURANCE",
        "BANK_PASSBOOK",
        "PROFILE_PHOTO",
        "POLICE_VERIFICATION",
      ],
      rider_duty_state: ["OFFLINE", "AVAILABLE", "BUSY", "ON_BREAK"],
      rider_onboarding_status: [
        "PENDING",
        "DOCUMENTS_SUBMITTED",
        "VERIFIED",
        "ACTIVE",
        "SUSPENDED",
        "REJECTED",
      ],
      role_surface: [
        "MOBILE_CUSTOMER",
        "MOBILE_DELIVERY",
        "MOBILE_KITCHEN",
        "ADMIN_WEB",
      ],
      service_mode: ["DELIVERY", "PICKUP", "BOTH"],
      spice_level: ["NONE", "MILD", "MEDIUM", "HOT", "EXTRA_HOT"],
      stock_movement_kind: [
        "PURCHASE",
        "CONSUMPTION",
        "WASTAGE",
        "ADJUSTMENT",
        "RETURN",
        "OPENING_BALANCE",
        "TRANSFER",
      ],
      ticket_category: [
        "ORDER_DELAYED",
        "MISSING_ITEM",
        "WRONG_ITEM",
        "FOOD_QUALITY",
        "PAYMENT_PROBLEM",
        "REFUND",
        "DELIVERY_ISSUE",
        "CANCELLATION",
        "APP_ISSUE",
        "OTHER",
      ],
      ticket_priority: ["LOW", "NORMAL", "HIGH", "URGENT"],
      ticket_status: [
        "OPEN",
        "IN_PROGRESS",
        "WAITING_ON_CUSTOMER",
        "ESCALATED",
        "RESOLVED",
        "CLOSED",
      ],
      unit_of_measure: [
        "GRAM",
        "KILOGRAM",
        "MILLILITRE",
        "LITRE",
        "PIECE",
        "PACKET",
        "DOZEN",
      ],
      vehicle_type: ["BICYCLE", "SCOOTER", "MOTORCYCLE", "CAR", "ON_FOOT"],
      wallet_entry_kind: [
        "CREDIT",
        "DEBIT",
        "REFUND",
        "PROMOTION",
        "CASHBACK",
        "ADJUSTMENT",
        "EXPIRY",
        "REVERSAL",
      ],
      zone_kind: ["RADIUS", "POLYGON"],
    },
  },
} as const
