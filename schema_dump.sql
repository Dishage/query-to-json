--
-- PostgreSQL database dump
--

-- Dumped from database version 15.1 (Ubuntu 15.1-1.pgdg20.04+1)
-- Dumped by pg_dump version 15.8 (Ubuntu 15.8-1.pgdg22.04+1)

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

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: app_permission; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.app_permission AS ENUM (
    'channels.delete',
    'messages.delete'
);


ALTER TYPE public.app_permission OWNER TO postgres;

--
-- Name: app_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.app_role AS ENUM (
    'admin',
    'moderator',
    'tutor',
    'student',
    'superadmin'
);


ALTER TYPE public.app_role OWNER TO postgres;

--
-- Name: role_permission; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.role_permission AS ENUM (
    'zoom_admin',
    'read_messages'
);


ALTER TYPE public.role_permission OWNER TO postgres;

--
-- Name: user_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_status AS ENUM (
    'ONLINE',
    'OFFLINE'
);


ALTER TYPE public.user_status OWNER TO postgres;

--
-- Name: authorize(public.app_permission, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.authorize(requested_permission public.app_permission, user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
  declare
    bind_permissions int;
  begin
    select
      count(*)
    from public.role_permissions
    inner join public.user_roles on role_permissions.role = user_roles.role
    where
      role_permissions.permission = authorize.requested_permission and
      user_roles.user_id = authorize.user_id
    into bind_permissions;

    return bind_permissions > 0;
  end;
$$;


ALTER FUNCTION public.authorize(requested_permission public.app_permission, user_id uuid) OWNER TO postgres;

--
-- Name: get_tutor_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_tutor_id() RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    tutor_id BIGINT;
BEGIN
    SELECT "TutorID" INTO tutor_id
    FROM "Tutors"
    WHERE user_id = auth.uid();
    
    RETURN tutor_id;
END;
$$;


ALTER FUNCTION public.get_tutor_id() OWNER TO postgres;

--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
  declare is_admin boolean;
  begin
    insert into public.users (id, username)
    values (new.id, new.email);

    select count(*) = 1 from auth.users into is_admin;

    if position('+supaadmin@' in new.email) > 0 then
      insert into public.user_roles (user_id, role) values (new.id, 'admin');
    elsif position('+supamod@' in new.email) > 0 then
      insert into public.user_roles (user_id, role) values (new.id, 'moderator');
    end if;

    return new;
  end;
$$;


ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

--
-- Name: sync_tutor_role(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sync_tutor_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert a new role if a new tutor is added or if the user_id changes
    IF (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id)) THEN
        INSERT INTO public.user_roles (user_id, role)
        VALUES (NEW.user_id, 'tutor')
        ON CONFLICT (user_id, role) DO NOTHING;
    END IF;

    -- Delete the old role if the user_id changes
    IF (TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
        DELETE FROM public.user_roles
        WHERE user_id = OLD.user_id
        AND role = 'tutor';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.sync_tutor_role() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ClassSessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ClassSessions" (
    "SessionID" bigint NOT NULL,
    "TutorID" bigint NOT NULL,
    "StartTime" timestamp with time zone NOT NULL,
    "FinishTime" timestamp with time zone NOT NULL,
    "Notes" text,
    "Students" text[]
);

ALTER TABLE ONLY public."ClassSessions" FORCE ROW LEVEL SECURITY;


ALTER TABLE public."ClassSessions" OWNER TO postgres;

--
-- Name: ClassSessions_SessionID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."ClassSessions_SessionID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."ClassSessions_SessionID_seq" OWNER TO postgres;

--
-- Name: ClassSessions_SessionID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ClassSessions_SessionID_seq" OWNED BY public."ClassSessions"."SessionID";


--
-- Name: Students; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Students" (
    "Student Full Name" text NOT NULL,
    "Parent Name" text,
    "School" text,
    "Student Mobile" text,
    "Student Email" text,
    "Parent Wechat ID" text,
    "Parent Mobile" text,
    "Parent Email" text,
    "Remark" text,
    "Student ID" bigint NOT NULL,
    "YearNumber" integer,
    "Current" boolean DEFAULT false
);


ALTER TABLE public."Students" OWNER TO postgres;

--
-- Name: Students_Student ID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."Students" ALTER COLUMN "Student ID" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."Students_Student ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: Tutors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Tutors" (
    "Email" text NOT NULL,
    "Name" text,
    "Number" text,
    "WWCC" text,
    "ABN" text,
    "TutorID" bigint NOT NULL,
    user_id uuid
);


ALTER TABLE public."Tutors" OWNER TO postgres;

--
-- Name: COLUMN "Tutors".user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public."Tutors".user_id IS 'Link to user auth';


--
-- Name: TutorsView; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public."TutorsView" WITH (security_invoker='true') AS
 SELECT "Tutors"."Name",
    "Tutors".user_id
   FROM public."Tutors";


ALTER TABLE public."TutorsView" OWNER TO postgres;

--
-- Name: Tutors_TutorID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Tutors_TutorID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."Tutors_TutorID_seq" OWNER TO postgres;

--
-- Name: Tutors_TutorID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Tutors_TutorID_seq" OWNED BY public."Tutors"."TutorID";


--
-- Name: id_name_pairs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.id_name_pairs (
    id uuid NOT NULL,
    name text
);


ALTER TABLE public.id_name_pairs OWNER TO postgres;

--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_roles (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    role public.app_role NOT NULL,
    email text
);


ALTER TABLE public.user_roles OWNER TO postgres;

--
-- Name: TABLE user_roles; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_roles IS 'Application roles for each user.';


--
-- Name: user_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.user_roles ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.user_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    username text,
    status public.user_status DEFAULT 'OFFLINE'::public.user_status,
    time_created timestamp with time zone DEFAULT now()
);

ALTER TABLE ONLY public.users REPLICA IDENTITY FULL;


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.users IS 'Profile data for each user.';


--
-- Name: COLUMN users.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.id IS 'References the internal Supabase Auth user.';


--
-- Name: z_channel_email; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.z_channel_email (
    email text NOT NULL,
    channel bigint NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE public.z_channel_email OWNER TO postgres;

--
-- Name: z_channel_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.z_channel_messages (
    id bigint NOT NULL,
    channel bigint NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid NOT NULL
);


ALTER TABLE public.z_channel_messages OWNER TO postgres;

--
-- Name: z_channel_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.z_channel_messages ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.z_channel_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: z_channels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.z_channels (
    id bigint NOT NULL,
    name text DEFAULT 'Parent-Teacher Communication Hub'::text,
    description text DEFAULT 'A dedicated space for parents and teachers to connect and collaborate. Use this channel to share updates on class schedules, important announcements, homework assignments, and school events. Let''s work together to ensure our children''s success!'::text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    "Participants" text DEFAULT 'Parent, Teacher, Support'::text
);


ALTER TABLE public.z_channels OWNER TO postgres;

--
-- Name: z_channels_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.z_channels ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.z_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: z_email_role; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.z_email_role (
    email text NOT NULL,
    role public.app_role
);


ALTER TABLE public.z_email_role OWNER TO postgres;

--
-- Name: z_role_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.z_role_permissions (
    role public.app_role NOT NULL,
    permission public.role_permission[],
    key text
);


ALTER TABLE public.z_role_permissions OWNER TO postgres;

--
-- Name: ClassSessions SessionID; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ClassSessions" ALTER COLUMN "SessionID" SET DEFAULT nextval('public."ClassSessions_SessionID_seq"'::regclass);


--
-- Name: Tutors TutorID; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Tutors" ALTER COLUMN "TutorID" SET DEFAULT nextval('public."Tutors_TutorID_seq"'::regclass);


--
-- Name: ClassSessions ClassSessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ClassSessions"
    ADD CONSTRAINT "ClassSessions_pkey" PRIMARY KEY ("SessionID");


--
-- Name: z_role_permissions Permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_role_permissions
    ADD CONSTRAINT "Permissions_pkey" PRIMARY KEY (role);


--
-- Name: Students Students_Student Full Name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Students"
    ADD CONSTRAINT "Students_Student Full Name_key" UNIQUE ("Student Full Name");


--
-- Name: Students Students_Student ID_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Students"
    ADD CONSTRAINT "Students_Student ID_key" UNIQUE ("Student ID");


--
-- Name: Students Students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Students"
    ADD CONSTRAINT "Students_pkey" PRIMARY KEY ("Student ID", "Student Full Name");


--
-- Name: Tutors Tutors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Tutors"
    ADD CONSTRAINT "Tutors_pkey" PRIMARY KEY ("TutorID");


--
-- Name: Tutors Tutors_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Tutors"
    ADD CONSTRAINT "Tutors_user_id_key" UNIQUE (user_id);


--
-- Name: z_channel_email channel_email_email_channel_no_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_email
    ADD CONSTRAINT channel_email_email_channel_no_unique UNIQUE (email, channel);


--
-- Name: z_channel_email channel_email_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_email
    ADD CONSTRAINT channel_email_id_key UNIQUE (id);


--
-- Name: z_channel_email channel_email_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_email
    ADD CONSTRAINT channel_email_pkey PRIMARY KEY (id);


--
-- Name: id_name_pairs key_value_pairs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.id_name_pairs
    ADD CONSTRAINT key_value_pairs_pkey PRIMARY KEY (id);


--
-- Name: z_email_role user_role_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_email_role
    ADD CONSTRAINT user_role_pkey PRIMARY KEY (email);


--
-- Name: user_roles user_roles_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_email_key UNIQUE (email);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id);


--
-- Name: user_roles user_roles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_key UNIQUE (user_id);


--
-- Name: user_roles user_roles_user_id_role_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_role_key UNIQUE (user_id, role);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: z_channel_messages z_channel_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_messages
    ADD CONSTRAINT z_channel_messages_pkey PRIMARY KEY (id);


--
-- Name: z_channels z_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channels
    ADD CONSTRAINT z_channels_pkey PRIMARY KEY (id);


--
-- Name: Tutors after_tutor_insert_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_tutor_insert_update AFTER INSERT OR UPDATE ON public."Tutors" FOR EACH ROW WHEN ((new.user_id IS NOT NULL)) EXECUTE FUNCTION public.sync_tutor_role();


--
-- Name: Tutors Tutors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Tutors"
    ADD CONSTRAINT "Tutors_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: ClassSessions fk_Tutor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ClassSessions"
    ADD CONSTRAINT "fk_Tutor" FOREIGN KEY ("TutorID") REFERENCES public."Tutors"("TutorID");


--
-- Name: id_name_pairs key_value_pairs_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.id_name_pairs
    ADD CONSTRAINT key_value_pairs_id_fkey FOREIGN KEY (id) REFERENCES public.users(id);


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: z_channel_email z_channel_email_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_email
    ADD CONSTRAINT z_channel_email_channel_fkey FOREIGN KEY (channel) REFERENCES public.z_channels(id);


--
-- Name: z_channel_email z_channel_email_email_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_email
    ADD CONSTRAINT z_channel_email_email_fkey FOREIGN KEY (email) REFERENCES public.z_email_role(email);


--
-- Name: z_channel_messages z_channel_messages_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_messages
    ADD CONSTRAINT z_channel_messages_channel_fkey FOREIGN KEY (channel) REFERENCES public.z_channels(id);


--
-- Name: z_channel_messages z_channel_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_channel_messages
    ADD CONSTRAINT z_channel_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: Students Admin access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Admin access" ON public."Students" USING ((auth.uid() = ANY (ARRAY['1bbc4b7a-ede1-4f99-8800-7dd2ec9a3ce8'::uuid, '1f3e71c2-2101-4869-add3-6dab615f1c76'::uuid, 'eb13ba1b-d976-419a-8d76-dc164d77bda7'::uuid, '0488d287-4460-49f2-824d-fbb512b574c9'::uuid])));


--
-- Name: user_roles Allow individual read access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow individual read access" ON public.user_roles FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: users Allow logged-in read access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow logged-in read access" ON public.users FOR SELECT TO authenticated USING ((auth.uid() = id));


--
-- Name: ClassSessions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public."ClassSessions" ENABLE ROW LEVEL SECURITY;

--
-- Name: ClassSessions Edit policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Edit policy" ON public."ClassSessions" USING ((auth.uid() = ANY (ARRAY['1bbc4b7a-ede1-4f99-8800-7dd2ec9a3ce8'::uuid, '1f3e71c2-2101-4869-add3-6dab615f1c76'::uuid, '0488d287-4460-49f2-824d-fbb512b574c9'::uuid])));


--
-- Name: Tutors See Tutors; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "See Tutors" ON public."Tutors" USING ((auth.uid() = ANY (ARRAY['1bbc4b7a-ede1-4f99-8800-7dd2ec9a3ce8'::uuid, '1f3e71c2-2101-4869-add3-6dab615f1c76'::uuid, 'eb13ba1b-d976-419a-8d76-dc164d77bda7'::uuid, '0488d287-4460-49f2-824d-fbb512b574c9'::uuid])));


--
-- Name: Students; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public."Students" ENABLE ROW LEVEL SECURITY;

--
-- Name: Tutors; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public."Tutors" ENABLE ROW LEVEL SECURITY;

--
-- Name: z_channel_messages Users see messages in their channel; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users see messages in their channel" ON public.z_channel_messages FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.z_channel_email
  WHERE (z_channel_email.channel = z_channel_messages.channel))));


--
-- Name: z_channel_email Users see their channel; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users see their channel" ON public.z_channel_email FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE (users.username = z_channel_email.email))));


--
-- Name: z_email_role Users see their role; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users see their role" ON public.z_email_role FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE (users.username = z_email_role.email))));


--
-- Name: z_channel_email admin_access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admin_access ON public.z_channel_email USING ((EXISTS ( SELECT 1
   FROM public.z_email_role
  WHERE (z_email_role.role = 'admin'::public.app_role))));


--
-- Name: z_channel_messages admin_access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admin_access ON public.z_channel_messages USING ((EXISTS ( SELECT 1
   FROM public.z_email_role
  WHERE (z_email_role.role = 'admin'::public.app_role))));


--
-- Name: z_channel_messages delete_channel_messages_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY delete_channel_messages_policy ON public.z_channel_messages FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.z_channel_email
  WHERE ((z_channel_email.channel = z_channel_messages.channel) AND (auth.uid() = z_channel_messages.user_id)))));


--
-- Name: z_role_permissions get user roles; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "get user roles" ON public.z_role_permissions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.z_email_role
  WHERE (z_email_role.role = z_role_permissions.role))));


--
-- Name: id_name_pairs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.id_name_pairs ENABLE ROW LEVEL SECURITY;

--
-- Name: z_channel_messages insert_channel_messages_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY insert_channel_messages_policy ON public.z_channel_messages FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM public.z_channel_email
  WHERE ((z_channel_email.channel = z_channel_messages.channel) AND (auth.uid() = z_channel_messages.user_id)))) AND (id IS NULL) AND (created_at IS NULL)));


--
-- Name: id_name_pairs read_access; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY read_access ON public.id_name_pairs FOR SELECT TO authenticated USING (true);


--
-- Name: z_channels read_channel_information; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY read_channel_information ON public.z_channels FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.z_channel_email
  WHERE (z_channel_email.channel = z_channels.id))));


--
-- Name: ClassSessions select_class_sessions_for_tutors; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY select_class_sessions_for_tutors ON public."ClassSessions" FOR SELECT USING (("TutorID" = public.get_tutor_id()));


--
-- Name: z_channel_messages update_channel_messages_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY update_channel_messages_policy ON public.z_channel_messages FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.z_channel_email
  WHERE ((z_channel_email.channel = z_channel_messages.channel) AND (auth.uid() = z_channel_messages.user_id))))) WITH CHECK ((message = message));


--
-- Name: user_roles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: z_channel_email; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.z_channel_email ENABLE ROW LEVEL SECURITY;

--
-- Name: z_channel_messages; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.z_channel_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: z_channels; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.z_channels ENABLE ROW LEVEL SECURITY;

--
-- Name: z_email_role; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.z_email_role ENABLE ROW LEVEL SECURITY;

--
-- Name: z_role_permissions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.z_role_permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION authorize(requested_permission public.app_permission, user_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.authorize(requested_permission public.app_permission, user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.authorize(requested_permission public.app_permission, user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.authorize(requested_permission public.app_permission, user_id uuid) TO service_role;


--
-- Name: FUNCTION get_tutor_id(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_tutor_id() TO anon;
GRANT ALL ON FUNCTION public.get_tutor_id() TO authenticated;
GRANT ALL ON FUNCTION public.get_tutor_id() TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_new_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION sync_tutor_role(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.sync_tutor_role() TO anon;
GRANT ALL ON FUNCTION public.sync_tutor_role() TO authenticated;
GRANT ALL ON FUNCTION public.sync_tutor_role() TO service_role;


--
-- Name: TABLE "ClassSessions"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."ClassSessions" TO anon;
GRANT ALL ON TABLE public."ClassSessions" TO authenticated;
GRANT ALL ON TABLE public."ClassSessions" TO service_role;


--
-- Name: SEQUENCE "ClassSessions_SessionID_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."ClassSessions_SessionID_seq" TO anon;
GRANT ALL ON SEQUENCE public."ClassSessions_SessionID_seq" TO authenticated;
GRANT ALL ON SEQUENCE public."ClassSessions_SessionID_seq" TO service_role;


--
-- Name: TABLE "Students"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Students" TO anon;
GRANT ALL ON TABLE public."Students" TO authenticated;
GRANT ALL ON TABLE public."Students" TO service_role;


--
-- Name: SEQUENCE "Students_Student ID_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Students_Student ID_seq" TO anon;
GRANT ALL ON SEQUENCE public."Students_Student ID_seq" TO authenticated;
GRANT ALL ON SEQUENCE public."Students_Student ID_seq" TO service_role;


--
-- Name: TABLE "Tutors"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Tutors" TO anon;
GRANT ALL ON TABLE public."Tutors" TO authenticated;
GRANT ALL ON TABLE public."Tutors" TO service_role;


--
-- Name: TABLE "TutorsView"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."TutorsView" TO anon;
GRANT ALL ON TABLE public."TutorsView" TO authenticated;
GRANT ALL ON TABLE public."TutorsView" TO service_role;


--
-- Name: SEQUENCE "Tutors_TutorID_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Tutors_TutorID_seq" TO anon;
GRANT ALL ON SEQUENCE public."Tutors_TutorID_seq" TO authenticated;
GRANT ALL ON SEQUENCE public."Tutors_TutorID_seq" TO service_role;


--
-- Name: TABLE id_name_pairs; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.id_name_pairs TO anon;
GRANT ALL ON TABLE public.id_name_pairs TO authenticated;
GRANT ALL ON TABLE public.id_name_pairs TO service_role;


--
-- Name: TABLE user_roles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_roles TO anon;
GRANT ALL ON TABLE public.user_roles TO authenticated;
GRANT ALL ON TABLE public.user_roles TO service_role;


--
-- Name: SEQUENCE user_roles_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.user_roles_id_seq TO anon;
GRANT ALL ON SEQUENCE public.user_roles_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.user_roles_id_seq TO service_role;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;


--
-- Name: TABLE z_channel_email; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.z_channel_email TO anon;
GRANT ALL ON TABLE public.z_channel_email TO authenticated;
GRANT ALL ON TABLE public.z_channel_email TO service_role;


--
-- Name: TABLE z_channel_messages; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.z_channel_messages TO anon;
GRANT ALL ON TABLE public.z_channel_messages TO authenticated;
GRANT ALL ON TABLE public.z_channel_messages TO service_role;


--
-- Name: SEQUENCE z_channel_messages_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.z_channel_messages_id_seq TO anon;
GRANT ALL ON SEQUENCE public.z_channel_messages_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.z_channel_messages_id_seq TO service_role;


--
-- Name: TABLE z_channels; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.z_channels TO anon;
GRANT ALL ON TABLE public.z_channels TO authenticated;
GRANT ALL ON TABLE public.z_channels TO service_role;


--
-- Name: SEQUENCE z_channels_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.z_channels_id_seq TO anon;
GRANT ALL ON SEQUENCE public.z_channels_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.z_channels_id_seq TO service_role;


--
-- Name: TABLE z_email_role; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.z_email_role TO anon;
GRANT ALL ON TABLE public.z_email_role TO authenticated;
GRANT ALL ON TABLE public.z_email_role TO service_role;


--
-- Name: TABLE z_role_permissions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.z_role_permissions TO anon;
GRANT ALL ON TABLE public.z_role_permissions TO authenticated;
GRANT ALL ON TABLE public.z_role_permissions TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES  TO service_role;


--
-- PostgreSQL database dump complete
--

