-- Raymond Gray IFM Platform - Base Schema Initialization
-- Run this script against your Neon database to create the required schemas.
-- Individual services will manage their own table migrations within these schemas.

-- Create schemas for each service domain
CREATE SCHEMA IF NOT EXISTS workorders;
CREATE SCHEMA IF NOT EXISTS cmms;
CREATE SCHEMA IF NOT EXISTS helpdesk;
CREATE SCHEMA IF NOT EXISTS reports;
CREATE SCHEMA IF NOT EXISTS auth_bridge;

-- Note: The auth_bridge schema is for mapping Supabase users to our internal entities if needed.
-- In a pure Supabase setup, 'auth' is the schema used by Supabase internally. 
-- Since we only use Supabase for issuing JWTs and store no app data there, our Neon DB 
-- does not need the Supabase 'auth' schema, but we may need a table to store user profiles.

CREATE TABLE IF NOT EXISTS auth_bridge.users (
    id UUID PRIMARY KEY, -- matches Supabase auth.users.id
    email VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(50),
    roles JSONB DEFAULT '[]', -- Mirrors app_metadata.roles
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Give usage access to schemas (assuming a single application user role for now, 
-- or adjust grants based on specific DB users per service)
-- GRANT USAGE ON SCHEMA workorders TO application_user;
-- GRANT USAGE ON SCHEMA cmms TO application_user;
-- GRANT USAGE ON SCHEMA helpdesk TO application_user;
-- GRANT USAGE ON SCHEMA reports TO application_user;
-- GRANT USAGE ON SCHEMA auth_bridge TO application_user;
