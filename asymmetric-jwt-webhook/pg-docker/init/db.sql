
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA users;
CREATE SCHEMA utils;
CREATE SCHEMA vendors;

ALTER SCHEMA users OWNER TO master;
ALTER SCHEMA utils OWNER TO master;
ALTER SCHEMA vendors OWNER TO master;

GRANT USAGE ON SCHEMA public TO anon;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


CREATE FUNCTION public.generate_id(length integer) RETURNS text
    LANGUAGE sql
    AS $$

  select translate(encode(gen_random_bytes(length), 'base64'), '+/=', '');

$$;


ALTER FUNCTION public.generate_id(length integer) OWNER TO master;


SET default_tablespace = '';

SET default_with_oids = false;

CREATE FUNCTION utils.prepare_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

begin

  new.city = trim(new.city);
  new.line1 = trim(new.line1);
  new.line2 = trim(new.line2);
  new.state = trim(new.state);
  new.zip = trim(new.zip);

  new.search_terms := concat_ws(
    ' ',
    new.line1,
    new.line2,
    new.city,
    new.state,
    new.country,
    new.zip
    );
  return new;
end
$$;


ALTER FUNCTION utils.prepare_address() OWNER TO master;


CREATE FUNCTION public.set_modified_on() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare

begin

  new.modified_on = now();

  return new;
end
$$;


ALTER FUNCTION public.set_modified_on() OWNER TO master;


CREATE FUNCTION utils.prepare_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin


  if tg_op = 'INSERT' or new.email <> old.email then
    new.email = trim(lower(new.email),  ' .');
  end if;

  new.first_name = trim(new.first_name);
  new.last_name = trim(new.last_name);
  new.phone = trim(regexp_replace(new.phone, '[^\d]', '', 'g'));

  new.search_terms := concat_ws(
    ' ',
    new.email,
    new.first_name,
    new.last_name,
    new.phone,
    new.id
    );

  return new;
end
$$;


ALTER FUNCTION utils.prepare_user() OWNER TO master;

CREATE TABLE users.profile (
    id text DEFAULT public.generate_id(8) NOT NULL,
    email text,
    role text DEFAULT 'patient' NOT NULL,
    first_name text,
    last_name text,
    created_at timestamp with time zone DEFAULT now(),
    modified_on timestamp with time zone,
    medical_record_id text,
    verification_code integer,
    status text DEFAULT 'active' NOT NULL,
    patient_id integer,
    dob date,
    phone text,
    payment_token text,
    card_details json,
    male boolean DEFAULT true NOT NULL,
    sms boolean DEFAULT true NOT NULL,
    email_tx boolean DEFAULT true NOT NULL,
    email_marketing boolean DEFAULT true NOT NULL,
    phone_sanitized text,
    search_terms text,
    CONSTRAINT users_email_check CHECK ((email ~* '^.+@.+\..+$'::text)),
    CONSTRAINT users_role_check CHECK ((length((role)::text) < 512))
);


ALTER TABLE users.profile OWNER TO master;

ALTER TABLE users.profile
    ADD CONSTRAINT users_first_name_check CHECK (((length(first_name) > 1) AND (length(first_name) < 55))) NOT VALID;
ALTER TABLE users.profile
    ADD CONSTRAINT users_last_name_check CHECK (((length(last_name) > 1) AND (length(last_name) < 55))) NOT VALID;
ALTER TABLE ONLY users.profile ADD CONSTRAINT users_patient_id_key UNIQUE (patient_id);
ALTER TABLE ONLY users.profile ADD CONSTRAINT users_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX users_email_key ON users.profile USING btree (lower(email));
CREATE INDEX users_greatest_created_at_modified_on_idx ON users.profile USING btree ((GREATEST(created_at, modified_on)));
CREATE UNIQUE INDEX users_id_role_key ON users.profile USING btree (id, role);
CREATE INDEX users_payment_token_idx ON users.profile USING btree (payment_token) WHERE (payment_token IS NOT NULL);
CREATE INDEX users_phone_idx ON users.profile USING btree (regexp_replace(phone, '[^\d]'::text, ''::text, 'g'::text));
CREATE UNIQUE INDEX webuser_phone_key ON users.profile USING btree (phone) WHERE ((role = 'patient') AND (phone ~ '^\d+$'::text));
CREATE TRIGGER prepare_user BEFORE INSERT OR UPDATE ON users.profile FOR EACH ROW EXECUTE PROCEDURE utils.prepare_user();
CREATE TRIGGER set_modified_on BEFORE INSERT OR UPDATE ON users.profile FOR EACH ROW EXECUTE PROCEDURE public.set_modified_on();

CREATE TYPE users.address_type_enum AS ENUM (
    'billing',
    'shipping',
    'medical_practice'
);

ALTER TYPE users.address_type_enum OWNER TO master;

CREATE TABLE users.address (
    id text DEFAULT public.generate_id(8) NOT NULL,
    address_type users.address_type_enum DEFAULT 'shipping'::users.address_type_enum NOT NULL,
    user_id text NOT NULL,
    line1 text NOT NULL,
    line2 text,
    city text NOT NULL,
    state text NOT NULL,
    county text,
    zip text NOT NULL,
    country text DEFAULT 'USA'::text NOT NULL,
    latitude integer,
    longitude integer,
    created_at timestamp with time zone DEFAULT now(),
    search_terms text,
    modified_on timestamp with time zone,
    CONSTRAINT address_city_check CHECK ((length(city) < 50)),
    CONSTRAINT address_county_check CHECK ((length(county) < 50)),
    CONSTRAINT address_state_check CHECK ((length(state) < 50))
);


ALTER TABLE users.address OWNER TO master;

ALTER TABLE ONLY users.address ADD CONSTRAINT address_pkey PRIMARY KEY (id);
CREATE INDEX address_modified_on_idx ON users.address USING btree (modified_on) WHERE (modified_on IS NOT NULL);
CREATE INDEX address_search_terms_idx ON users.address USING gin (search_terms public.gin_trgm_ops);
CREATE INDEX address_user_id_idx ON users.address USING btree (user_id);
CREATE TRIGGER prepare_address BEFORE INSERT OR UPDATE ON users.address FOR EACH ROW EXECUTE PROCEDURE utils.prepare_address();
CREATE TRIGGER set_modified_on BEFORE INSERT OR UPDATE ON users.address FOR EACH ROW EXECUTE PROCEDURE public.set_modified_on();
ALTER TABLE ONLY users.address ADD CONSTRAINT address_user_id_fkey FOREIGN KEY (user_id) REFERENCES users.profile(id);

CREATE TABLE vendors.public_key (
    vendor_id text NOT NULL,
    pk text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    modified_on timestamp with time zone
);

ALTER TABLE vendors.public_key OWNER TO master;
ALTER TABLE ONLY vendors.public_key ADD CONSTRAINT vendor_id_pkey PRIMARY KEY (vendor_id);
CREATE TRIGGER set_modified_on BEFORE INSERT OR UPDATE ON vendors.public_key FOR EACH ROW EXECUTE PROCEDURE public.set_modified_on();
