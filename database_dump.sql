SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE FUNCTION public.log_computer_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    info TEXT;
    old_emp_name VARCHAR;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        info := 'Инв.№: ' || NEW.inventory_number || 
                '; Модель: ' || COALESCE(NEW.model, 'Н/Д');
        INSERT INTO audit_log (event_description) VALUES ('[+] ДОБАВЛЕН ПК. ' || info);
        RETURN NEW;

    ELSIF (TG_OP = 'UPDATE') THEN
        IF OLD.employee_id IS NOT NULL AND NEW.employee_id IS NULL THEN
            SELECT (last_name || ' ' || first_name) INTO old_emp_name 
            FROM employees WHERE employee_id = OLD.employee_id;
            
            INSERT INTO audit_log (event_description) 
            VALUES ('[!] ОТКРЕПЛЕНИЕ ПК. Компьютер: ' || NEW.inventory_number || 
                    ' отвязан от сотрудника: ' || COALESCE(old_emp_name, 'Неизвестно'));
        ELSE
            info := 'Инв.№: ' || NEW.inventory_number || 
                    '; Модель: ' || COALESCE(NEW.model, 'Н/Д');
            INSERT INTO audit_log (event_description) VALUES ('[*] ИЗМЕНЕН ПК (ID ' || NEW.computer_id || '). Новые данные: ' || info);
        END IF;
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        info := 'Инв.№: ' || OLD.inventory_number;
        INSERT INTO audit_log (event_description) VALUES ('[-] УДАЛЕН ПК. Бывшие данные: ' || info);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

CREATE FUNCTION public.log_employee_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    info TEXT;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        info := 'ФИО: ' || NEW.last_name || ' ' || NEW.first_name || ' ' || COALESCE(NEW.middle_name, '') || 
                '; Должность: ' || NEW.position || 
                '; Тел: ' || COALESCE(NEW.phone_number, 'Нет');
        
        INSERT INTO audit_log (event_description) VALUES ('[+] ДОБАВЛЕН СОТРУДНИК. ' || info);
        RETURN NEW;

    ELSIF (TG_OP = 'UPDATE') THEN
        info := 'ФИО: ' || NEW.last_name || ' ' || NEW.first_name || 
                '; Должность: ' || NEW.position || 
                '; Тел: ' || COALESCE(NEW.phone_number, 'Нет');
        
        INSERT INTO audit_log (event_description) VALUES ('[*] ИЗМЕНЕН СОТРУДНИК (ID ' || NEW.employee_id || '). Новые данные: ' || info);
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        info := 'ФИО: ' || OLD.last_name || ' ' || OLD.first_name || ' ' || COALESCE(OLD.middle_name, '') || 
                '; Должность: ' || OLD.position ||
                '; Тел: ' || COALESCE(OLD.phone_number, 'Нет');
        
        INSERT INTO audit_log (event_description) VALUES ('[-] УВОЛЕН СОТРУДНИК. Архивные данные: ' || info);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

CREATE FUNCTION public.log_software_installation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    comp_inv VARCHAR;
    soft_name VARCHAR;
    soft_ver VARCHAR;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        SELECT inventory_number INTO comp_inv FROM computers WHERE computer_id = NEW.computer_id;
        SELECT name, version INTO soft_name, soft_ver FROM software WHERE software_id = NEW.software_id;

        INSERT INTO audit_log (event_description)
        VALUES ('[+] УСТАНОВКА ПО. Программа: ' || soft_name || ' (' || COALESCE(soft_ver, '') || 
                '); Компьютер: ' || comp_inv || 
                '; Ключ: ' || COALESCE(NEW.license_key, 'Нет'));
        RETURN NEW;

    ELSIF (TG_OP = 'UPDATE') THEN
        SELECT inventory_number INTO comp_inv FROM computers WHERE computer_id = NEW.computer_id;
        SELECT name INTO soft_name FROM software WHERE software_id = NEW.software_id;

        INSERT INTO audit_log (event_description)
        VALUES ('[*] ОБНОВЛЕНИЕ ЛИЦЕНЗИИ/ПО. Программа: ' || soft_name || '; Компьютер: ' || comp_inv || 
                '; Новый ключ: ' || COALESCE(NEW.license_key, 'Нет'));
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        SELECT inventory_number INTO comp_inv FROM computers WHERE computer_id = OLD.computer_id;
        SELECT name INTO soft_name FROM software WHERE software_id = OLD.software_id;

        INSERT INTO audit_log (event_description)
        VALUES ('[-] УДАЛЕНИЕ ПО. Программа: ' || soft_name || '; С компьютера: ' || comp_inv);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

CREATE PROCEDURE public.sp_add_computer(IN p_inv_number character varying, IN p_specs text, IN p_ip inet, IN p_usage character varying, IN p_location_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO computers (inventory_number, hardware_specs, ip_address, usage_type, location_id)
    VALUES (p_inv_number, p_specs, p_ip, p_usage, p_location_id);
END;
$$;

CREATE PROCEDURE public.sp_add_employee_full(IN p_fname character varying, IN p_lname character varying, IN p_mname character varying, IN p_pos character varying, IN p_phone character varying, IN p_login character varying, IN p_pass character varying, IN p_role character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_emp_id INTEGER;
BEGIN
    INSERT INTO employees (first_name, last_name, middle_name, position, phone_number)
    VALUES (p_fname, p_lname, p_mname, p_pos, p_phone)
    RETURNING employee_id INTO v_emp_id;

    IF p_login IS NOT NULL AND p_login <> '' THEN
        INSERT INTO app_users (username, password, role, employee_id)
        VALUES (p_login, p_pass, p_role, v_emp_id);
    END IF;
END;
$$;

CREATE PROCEDURE public.sp_add_software_def(IN p_name character varying, IN p_ver character varying, IN p_cat_id integer, IN p_lic_type character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO software (name, version, category_id, license_type)
    VALUES (p_name, p_ver, p_cat_id, p_lic_type);
END;
$$;

CREATE PROCEDURE public.sp_delete_computer(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM computers WHERE computer_id = p_id;
END;
$$;

CREATE PROCEDURE public.sp_delete_employee(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE computers SET employee_id = NULL WHERE employee_id = p_id;
    UPDATE app_users SET employee_id = NULL WHERE employee_id = p_id;
    DELETE FROM employees WHERE employee_id = p_id;
END;
$$;

CREATE PROCEDURE public.sp_delete_software_def(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM software WHERE software_id = p_id;
END;
$$;

CREATE PROCEDURE public.sp_install_software(IN p_comp_id integer, IN p_soft_id integer, IN p_key character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO installed_software (computer_id, software_id, license_key, install_date)
    VALUES (p_comp_id, p_soft_id, p_key, CURRENT_DATE);
END;
$$;

CREATE PROCEDURE public.sp_uninstall_software(IN p_install_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM installed_software WHERE installation_id = p_install_id;
END;
$$;

CREATE PROCEDURE public.sp_update_employee_full(IN p_id integer, IN p_fname character varying, IN p_lname character varying, IN p_mname character varying, IN p_pos character varying, IN p_phone character varying, IN p_login character varying, IN p_pass character varying, IN p_role character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE employees 
    SET first_name = p_fname,
        last_name = p_lname,
        middle_name = p_mname,
        position = p_pos,
        phone_number = p_phone
    WHERE employee_id = p_id;

    IF EXISTS (SELECT 1 FROM app_users WHERE employee_id = p_id) THEN
        UPDATE app_users 
        SET username = p_login,
            password = p_pass,
            role = p_role
        WHERE employee_id = p_id;
    ELSE
        IF p_login IS NOT NULL AND p_login <> '' THEN
            INSERT INTO app_users (username, password, role, employee_id)
            VALUES (p_login, p_pass, p_role, p_id);
        END IF;
    END IF;
END;
$$;

CREATE TABLE public.app_users (
    user_id integer NOT NULL,
    username character varying(50) NOT NULL,
    password character varying(50) NOT NULL,
    role character varying(20),
    linked_computer_id integer,
    employee_id integer,
    CONSTRAINT app_users_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'user'::character varying])::text[])))
);

CREATE SEQUENCE public.app_users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.app_users_user_id_seq OWNED BY public.app_users.user_id;

CREATE TABLE public.audit_log (
    log_id integer NOT NULL,
    event_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    event_description text
);

CREATE SEQUENCE public.audit_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.audit_log_log_id_seq OWNED BY public.audit_log.log_id;

CREATE TABLE public.computers (
    computer_id integer NOT NULL,
    inventory_number character varying(100) NOT NULL,
    hardware_specs text,
    ip_address inet,
    computer_image bytea,
    usage_type character varying(50),
    location_id integer,
    employee_id integer,
    model character varying(100),
    CONSTRAINT computers_usage_type_check CHECK (((usage_type)::text = ANY ((ARRAY['Учебный'::character varying, 'Служебный'::character varying, 'Личный'::character varying])::text[])))
);

CREATE SEQUENCE public.computers_computer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.computers_computer_id_seq OWNED BY public.computers.computer_id;

CREATE TABLE public.employees (
    employee_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    "position" character varying(100),
    middle_name character varying(50),
    phone_number character varying(20)
);

CREATE SEQUENCE public.employees_employee_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.employees_employee_id_seq OWNED BY public.employees.employee_id;

CREATE TABLE public.installed_software (
    installation_id integer NOT NULL,
    computer_id integer,
    software_id integer,
    license_key character varying(255),
    install_date date DEFAULT CURRENT_DATE
);

CREATE SEQUENCE public.installed_software_installation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.installed_software_installation_id_seq OWNED BY public.installed_software.installation_id;

CREATE TABLE public.job_positions (
    position_id integer NOT NULL,
    name character varying(100) NOT NULL
);

CREATE SEQUENCE public.job_positions_position_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.job_positions_position_id_seq OWNED BY public.job_positions.position_id;

CREATE TABLE public.locations (
    location_id integer NOT NULL,
    name character varying(255) NOT NULL
);

CREATE SEQUENCE public.locations_location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.locations_location_id_seq OWNED BY public.locations.location_id;

CREATE TABLE public.software (
    software_id integer NOT NULL,
    name character varying(255) NOT NULL,
    version character varying(50),
    license_type character varying(100),
    category_id integer
);

CREATE TABLE public.software_categories (
    category_id integer NOT NULL,
    name character varying(255) NOT NULL
);

CREATE SEQUENCE public.software_categories_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.software_categories_category_id_seq OWNED BY public.software_categories.category_id;

CREATE SEQUENCE public.software_software_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.software_software_id_seq OWNED BY public.software.software_id;

CREATE VIEW public.view_report_by_category AS
 SELECT cat.name AS "Категория",
    count(ins.installation_id) AS "Количество установок"
   FROM ((public.software s
     JOIN public.software_categories cat ON ((s.category_id = cat.category_id)))
     LEFT JOIN public.installed_software ins ON ((s.software_id = ins.software_id)))
  GROUP BY cat.name;

CREATE VIEW public.view_report_by_employee AS
 SELECT (((((e.last_name)::text || ' '::text) || (e.first_name)::text) || ' '::text) || (COALESCE(e.middle_name, ''::character varying))::text) AS "Сотрудник",
    e.phone_number AS "Телефон",
    e."position" AS "Должность",
    c.inventory_number AS "Инв. номер ПК",
    c.hardware_specs AS "Характеристики ПК",
    l.name AS "Месторасположение"
   FROM ((public.employees e
     JOIN public.computers c ON ((e.employee_id = c.employee_id)))
     LEFT JOIN public.locations l ON ((c.location_id = l.location_id)))
  ORDER BY e.last_name;

CREATE VIEW public.view_report_by_location AS
 SELECT l.name AS "Аудитория",
    c.inventory_number AS "Инв. номер ПК",
    s.name AS "Программа",
    s.version AS "Версия",
    ins.install_date AS "Дата установки"
   FROM (((public.installed_software ins
     JOIN public.computers c ON ((ins.computer_id = c.computer_id)))
     JOIN public.locations l ON ((c.location_id = l.location_id)))
     JOIN public.software s ON ((ins.software_id = s.software_id)));

CREATE VIEW public.view_report_by_usage AS
 SELECT c.usage_type AS "Назначение ПК",
    s.name AS "Программа",
    count(*) AS "Количество"
   FROM ((public.installed_software ins
     JOIN public.computers c ON ((ins.computer_id = c.computer_id)))
     JOIN public.software s ON ((ins.software_id = s.software_id)))
  GROUP BY c.usage_type, s.name;

CREATE VIEW public.view_software_details AS
 SELECT cat.name AS "Категория",
    s.name AS "Программа",
    s.version AS "Версия",
    c.inventory_number AS "Компьютер",
    l.name AS "Аудитория"
   FROM ((((public.installed_software ins
     JOIN public.software s ON ((ins.software_id = s.software_id)))
     JOIN public.software_categories cat ON ((s.category_id = cat.category_id)))
     JOIN public.computers c ON ((ins.computer_id = c.computer_id)))
     LEFT JOIN public.locations l ON ((c.location_id = l.location_id)));

ALTER TABLE ONLY public.app_users ALTER COLUMN user_id SET DEFAULT nextval('public.app_users_user_id_seq'::regclass);
ALTER TABLE ONLY public.audit_log ALTER COLUMN log_id SET DEFAULT nextval('public.audit_log_log_id_seq'::regclass);
ALTER TABLE ONLY public.computers ALTER COLUMN computer_id SET DEFAULT nextval('public.computers_computer_id_seq'::regclass);
ALTER TABLE ONLY public.employees ALTER COLUMN employee_id SET DEFAULT nextval('public.employees_employee_id_seq'::regclass);
ALTER TABLE ONLY public.installed_software ALTER COLUMN installation_id SET DEFAULT nextval('public.installed_software_installation_id_seq'::regclass);
ALTER TABLE ONLY public.job_positions ALTER COLUMN position_id SET DEFAULT nextval('public.job_positions_position_id_seq'::regclass);
ALTER TABLE ONLY public.locations ALTER COLUMN location_id SET DEFAULT nextval('public.locations_location_id_seq'::regclass);
ALTER TABLE ONLY public.software ALTER COLUMN software_id SET DEFAULT nextval('public.software_software_id_seq'::regclass);
ALTER TABLE ONLY public.software_categories ALTER COLUMN category_id SET DEFAULT nextval('public.software_categories_category_id_seq'::regclass);

ALTER TABLE ONLY public.app_users ADD CONSTRAINT app_users_pkey PRIMARY KEY (user_id);
ALTER TABLE ONLY public.app_users ADD CONSTRAINT app_users_username_key UNIQUE (username);
ALTER TABLE ONLY public.audit_log ADD CONSTRAINT audit_log_pkey PRIMARY KEY (log_id);
ALTER TABLE ONLY public.computers ADD CONSTRAINT computers_inventory_number_key UNIQUE (inventory_number);
ALTER TABLE ONLY public.computers ADD CONSTRAINT computers_pkey PRIMARY KEY (computer_id);
ALTER TABLE ONLY public.employees ADD CONSTRAINT employees_pkey PRIMARY KEY (employee_id);
ALTER TABLE ONLY public.installed_software ADD CONSTRAINT installed_software_pkey PRIMARY KEY (installation_id);
ALTER TABLE ONLY public.job_positions ADD CONSTRAINT job_positions_pkey PRIMARY KEY (position_id);
ALTER TABLE ONLY public.locations ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);
ALTER TABLE ONLY public.software_categories ADD CONSTRAINT software_categories_pkey PRIMARY KEY (category_id);
ALTER TABLE ONLY public.software ADD CONSTRAINT software_pkey PRIMARY KEY (software_id);

CREATE TRIGGER trg_audit_computers AFTER INSERT OR DELETE OR UPDATE ON public.computers FOR EACH ROW EXECUTE FUNCTION public.log_computer_changes();
CREATE TRIGGER trg_audit_employees AFTER INSERT OR DELETE OR UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION public.log_employee_changes();
CREATE TRIGGER trg_log_install AFTER INSERT OR DELETE OR UPDATE ON public.installed_software FOR EACH ROW EXECUTE FUNCTION public.log_software_installation();

ALTER TABLE ONLY public.app_users ADD CONSTRAINT app_users_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(employee_id) ON DELETE SET NULL;
ALTER TABLE ONLY public.app_users ADD CONSTRAINT app_users_linked_computer_id_fkey FOREIGN KEY (linked_computer_id) REFERENCES public.computers(computer_id) ON DELETE SET NULL;
ALTER TABLE ONLY public.computers ADD CONSTRAINT computers_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(employee_id) ON DELETE SET NULL;
ALTER TABLE ONLY public.computers ADD CONSTRAINT computers_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE SET NULL;
ALTER TABLE ONLY public.installed_software ADD CONSTRAINT installed_software_computer_id_fkey FOREIGN KEY (computer_id) REFERENCES public.computers(computer_id) ON DELETE CASCADE;
ALTER TABLE ONLY public.installed_software ADD CONSTRAINT installed_software_software_id_fkey FOREIGN KEY (software_id) REFERENCES public.software(software_id) ON DELETE CASCADE;
ALTER TABLE ONLY public.software ADD CONSTRAINT software_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.software_categories(category_id) ON DELETE SET NULL;
