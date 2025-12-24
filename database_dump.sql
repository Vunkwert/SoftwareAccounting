--
-- PostgreSQL database dump
--

\restrict cYN6eeKGZ03EQsOgoSdgnAelsc9LtlDA5CzCHoefIksopeKfAeaUEBlKpjB7ogS

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

-- Started on 2025-12-25 01:52:24

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

--
-- TOC entry 267 (class 1255 OID 17508)
-- Name: log_computer_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_computer_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    info TEXT;
    old_emp_name VARCHAR; -- Переменная для имени сотрудника
BEGIN
    -- 1. ВСТАВКА
    IF (TG_OP = 'INSERT') THEN
        info := 'Инв.№: ' || NEW.inventory_number || 
                '; Модель: ' || COALESCE(NEW.model, 'Н/Д');
        INSERT INTO audit_log (event_description) VALUES ('[+] ДОБАВЛЕН ПК. ' || info);
        RETURN NEW;

    -- 2. ОБНОВЛЕНИЕ
    ELSIF (TG_OP = 'UPDATE') THEN
        
        -- СПЕЦИАЛЬНАЯ ПРОВЕРКА: ОТКРЕПЛЕНИЕ СОТРУДНИКА
        -- Если раньше (OLD) кто-то был, а теперь (NEW) там NULL
        IF OLD.employee_id IS NOT NULL AND NEW.employee_id IS NULL THEN
            -- Ищем, кто это был
            SELECT (last_name || ' ' || first_name) INTO old_emp_name 
            FROM employees WHERE employee_id = OLD.employee_id;
            
            INSERT INTO audit_log (event_description) 
            VALUES ('[!] ОТКРЕПЛЕНИЕ ПК. Компьютер: ' || NEW.inventory_number || 
                    ' отвязан от сотрудника: ' || COALESCE(old_emp_name, 'Неизвестно'));
        
        ELSE
            -- Обычное обновление
            info := 'Инв.№: ' || NEW.inventory_number || 
                    '; Модель: ' || COALESCE(NEW.model, 'Н/Д');
            INSERT INTO audit_log (event_description) VALUES ('[*] ИЗМЕНЕН ПК (ID ' || NEW.computer_id || '). Новые данные: ' || info);
        END IF;
        
        RETURN NEW;

    -- 3. УДАЛЕНИЕ
    ELSIF (TG_OP = 'DELETE') THEN
        info := 'Инв.№: ' || OLD.inventory_number;
        INSERT INTO audit_log (event_description) VALUES ('[-] УДАЛЕН ПК. Бывшие данные: ' || info);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_computer_changes() OWNER TO postgres;

--
-- TOC entry 268 (class 1255 OID 17510)
-- Name: log_employee_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

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
        -- !!! ВОТ ТУТ МЫ ДОБАВИЛИ ТЕЛЕФОН !!!
        info := 'ФИО: ' || OLD.last_name || ' ' || OLD.first_name || ' ' || COALESCE(OLD.middle_name, '') || 
                '; Должность: ' || OLD.position ||
                '; Тел: ' || COALESCE(OLD.phone_number, 'Нет'); -- Теперь телефон сохранится
        
        INSERT INTO audit_log (event_description) VALUES ('[-] УВОЛЕН СОТРУДНИК. Архивные данные: ' || info);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_employee_changes() OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 17407)
-- Name: log_software_installation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_software_installation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    comp_inv VARCHAR; -- Сюда запишем номер компа
    soft_name VARCHAR; -- Сюда название программы
    soft_ver VARCHAR;  -- Сюда версию
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- 1. Ищем название компа и софта по ID
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
        -- Для удаления берем данные из OLD
        SELECT inventory_number INTO comp_inv FROM computers WHERE computer_id = OLD.computer_id;
        SELECT name INTO soft_name FROM software WHERE software_id = OLD.software_id;

        INSERT INTO audit_log (event_description)
        VALUES ('[-] УДАЛЕНИЕ ПО. Программа: ' || soft_name || '; С компьютера: ' || comp_inv);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_software_installation() OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 17461)
-- Name: sp_add_computer(character varying, text, inet, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_add_computer(IN p_inv_number character varying, IN p_specs text, IN p_ip inet, IN p_usage character varying, IN p_location_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO computers (inventory_number, hardware_specs, ip_address, usage_type, location_id)
    VALUES (p_inv_number, p_specs, p_ip, p_usage, p_location_id);
END;
$$;


ALTER PROCEDURE public.sp_add_computer(IN p_inv_number character varying, IN p_specs text, IN p_ip inet, IN p_usage character varying, IN p_location_id integer) OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 17486)
-- Name: sp_add_computer(character varying, character varying, character varying, inet, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_add_computer(IN p_inv character varying, IN p_model character varying, IN p_spec character varying, IN p_ip inet, IN p_usage character varying, IN p_loc_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO computers (inventory_number, model, hardware_specs, ip_address, usage_type, location_id)
    VALUES (p_inv, p_model, p_spec, p_ip, p_usage, p_loc_id);
END;
$$;


ALTER PROCEDURE public.sp_add_computer(IN p_inv character varying, IN p_model character varying, IN p_spec character varying, IN p_ip inet, IN p_usage character varying, IN p_loc_id integer) OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 17503)
-- Name: sp_add_computer(character varying, character varying, character varying, inet, character varying, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_add_computer(IN p_inv character varying, IN p_model character varying, IN p_spec character varying, IN p_ip inet, IN p_usage character varying, IN p_loc_id integer, IN p_emp_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO computers (inventory_number, model, hardware_specs, ip_address, usage_type, location_id, employee_id)
    VALUES (p_inv, p_model, p_spec, p_ip, p_usage, p_loc_id, p_emp_id);
END;
$$;


ALTER PROCEDURE public.sp_add_computer(IN p_inv character varying, IN p_model character varying, IN p_spec character varying, IN p_ip inet, IN p_usage character varying, IN p_loc_id integer, IN p_emp_id integer) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 17531)
-- Name: sp_add_employee_full(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_add_employee_full(IN p_fname character varying, IN p_lname character varying, IN p_mname character varying, IN p_pos character varying, IN p_phone character varying, IN p_login character varying, IN p_pass character varying, IN p_role character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_emp_id INTEGER;
BEGIN
    -- Добавляем сотрудника
    INSERT INTO employees (first_name, last_name, middle_name, position, phone_number)
    VALUES (p_fname, p_lname, p_mname, p_pos, p_phone)
    RETURNING employee_id INTO v_emp_id;

    -- Если указан логин, создаем пользователя
    IF p_login IS NOT NULL AND p_login <> '' THEN
        INSERT INTO app_users (username, password, role, employee_id)
        VALUES (p_login, p_pass, p_role, v_emp_id);
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_add_employee_full(IN p_fname character varying, IN p_lname character varying, IN p_mname character varying, IN p_pos character varying, IN p_phone character varying, IN p_login character varying, IN p_pass character varying, IN p_role character varying) OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 17514)
-- Name: sp_add_software_def(character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_add_software_def(IN p_name character varying, IN p_ver character varying, IN p_cat_id integer, IN p_lic_type character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO software (name, version, category_id, license_type)
    VALUES (p_name, p_ver, p_cat_id, p_lic_type);
END;
$$;


ALTER PROCEDURE public.sp_add_software_def(IN p_name character varying, IN p_ver character varying, IN p_cat_id integer, IN p_lic_type character varying) OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 17463)
-- Name: sp_delete_computer(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_delete_computer(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM computers WHERE computer_id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_delete_computer(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 17507)
-- Name: sp_delete_employee(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_delete_employee(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Сначала отвязываем компьютеры от этого сотрудника (ставим NULL),
    -- иначе база не даст удалить человека, за которым числится техника.
    UPDATE computers SET employee_id = NULL WHERE employee_id = p_id;
    UPDATE app_users SET employee_id = NULL WHERE employee_id = p_id;
    
    -- Теперь удаляем самого сотрудника
    DELETE FROM employees WHERE employee_id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_delete_employee(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 17516)
-- Name: sp_delete_software_def(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_delete_software_def(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM software WHERE software_id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_delete_software_def(IN p_id integer) OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 17512)
-- Name: sp_install_software(integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_install_software(IN p_comp_id integer, IN p_soft_id integer, IN p_key character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO installed_software (computer_id, software_id, license_key, install_date)
    VALUES (p_comp_id, p_soft_id, p_key, CURRENT_DATE);
END;
$$;


ALTER PROCEDURE public.sp_install_software(IN p_comp_id integer, IN p_soft_id integer, IN p_key character varying) OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 17513)
-- Name: sp_uninstall_software(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_uninstall_software(IN p_install_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM installed_software WHERE installation_id = p_install_id;
END;
$$;


ALTER PROCEDURE public.sp_uninstall_software(IN p_install_id integer) OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 17487)
-- Name: sp_update_computer(integer, character varying, character varying, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_update_computer(IN p_id integer, IN p_inv character varying, IN p_model character varying, IN p_specs text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE computers 
    SET inventory_number = p_inv,
        model = p_model,
        hardware_specs = p_specs
    WHERE computer_id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_update_computer(IN p_id integer, IN p_inv character varying, IN p_model character varying, IN p_specs text) OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 17504)
-- Name: sp_update_computer(integer, character varying, character varying, text, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_update_computer(IN p_id integer, IN p_inv character varying, IN p_model character varying, IN p_specs text, IN p_emp_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE computers 
    SET inventory_number = p_inv,
        model = p_model,
        hardware_specs = p_specs,
        employee_id = p_emp_id
    WHERE computer_id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_update_computer(IN p_id integer, IN p_inv character varying, IN p_model character varying, IN p_specs text, IN p_emp_id integer) OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 17462)
-- Name: sp_update_computer(integer, character varying, text, inet, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_update_computer(IN p_id integer, IN p_inv_number character varying, IN p_specs text, IN p_ip inet, IN p_usage character varying, IN p_location_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE computers 
    SET inventory_number = p_inv_number,
        hardware_specs = p_specs,
        ip_address = p_ip,
        usage_type = p_usage,
        location_id = p_location_id
    WHERE computer_id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_update_computer(IN p_id integer, IN p_inv_number character varying, IN p_specs text, IN p_ip inet, IN p_usage character varying, IN p_location_id integer) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 17532)
-- Name: sp_update_employee_full(integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_update_employee_full(IN p_id integer, IN p_fname character varying, IN p_lname character varying, IN p_mname character varying, IN p_pos character varying, IN p_phone character varying, IN p_login character varying, IN p_pass character varying, IN p_role character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Обновляем личные данные
    UPDATE employees 
    SET first_name = p_fname,
        last_name = p_lname,
        middle_name = p_mname,
        position = p_pos,
        phone_number = p_phone
    WHERE employee_id = p_id;

    -- Логика обновления пользователя
    IF EXISTS (SELECT 1 FROM app_users WHERE employee_id = p_id) THEN
        -- Если логин уже был - обновляем
        UPDATE app_users 
        SET username = p_login,
            password = p_pass,
            role = p_role
        WHERE employee_id = p_id;
    ELSE
        -- Если логина не было, но теперь ввели - создаем
        IF p_login IS NOT NULL AND p_login <> '' THEN
            INSERT INTO app_users (username, password, role, employee_id)
            VALUES (p_login, p_pass, p_role, p_id);
        END IF;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_update_employee_full(IN p_id integer, IN p_fname character varying, IN p_lname character varying, IN p_mname character varying, IN p_pos character varying, IN p_phone character varying, IN p_login character varying, IN p_pass character varying, IN p_role character varying) OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 17515)
-- Name: sp_update_software_def(integer, character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_update_software_def(IN p_id integer, IN p_name character varying, IN p_ver character varying, IN p_cat_id integer, IN p_lic_type character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE software 
    SET name = p_name,
        version = p_ver,
        category_id = p_cat_id,
        license_type = p_lic_type
    WHERE software_id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_update_software_def(IN p_id integer, IN p_name character varying, IN p_ver character varying, IN p_cat_id integer, IN p_lic_type character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 233 (class 1259 OID 17447)
-- Name: app_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.app_users (
    user_id integer NOT NULL,
    username character varying(50) NOT NULL,
    password character varying(50) NOT NULL,
    role character varying(20),
    linked_computer_id integer,
    employee_id integer,
    CONSTRAINT app_users_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'user'::character varying])::text[])))
);


ALTER TABLE public.app_users OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 17446)
-- Name: app_users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.app_users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.app_users_user_id_seq OWNER TO postgres;

--
-- TOC entry 4973 (class 0 OID 0)
-- Dependencies: 232
-- Name: app_users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.app_users_user_id_seq OWNED BY public.app_users.user_id;


--
-- TOC entry 228 (class 1259 OID 17398)
-- Name: audit_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_log (
    log_id integer NOT NULL,
    event_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    event_description text
);


ALTER TABLE public.audit_log OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17397)
-- Name: audit_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_log_log_id_seq OWNER TO postgres;

--
-- TOC entry 4974 (class 0 OID 0)
-- Dependencies: 227
-- Name: audit_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_log_log_id_seq OWNED BY public.audit_log.log_id;


--
-- TOC entry 222 (class 1259 OID 17351)
-- Name: computers; Type: TABLE; Schema: public; Owner: postgres
--

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


ALTER TABLE public.computers OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17350)
-- Name: computers_computer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.computers_computer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.computers_computer_id_seq OWNER TO postgres;

--
-- TOC entry 4975 (class 0 OID 0)
-- Dependencies: 221
-- Name: computers_computer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.computers_computer_id_seq OWNED BY public.computers.computer_id;


--
-- TOC entry 235 (class 1259 OID 17465)
-- Name: employees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employees (
    employee_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    "position" character varying(100),
    middle_name character varying(50),
    phone_number character varying(20)
);


ALTER TABLE public.employees OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 17464)
-- Name: employees_employee_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.employees_employee_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employees_employee_id_seq OWNER TO postgres;

--
-- TOC entry 4976 (class 0 OID 0)
-- Dependencies: 234
-- Name: employees_employee_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.employees_employee_id_seq OWNED BY public.employees.employee_id;


--
-- TOC entry 226 (class 1259 OID 17380)
-- Name: installed_software; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.installed_software (
    installation_id integer NOT NULL,
    computer_id integer,
    software_id integer,
    license_key character varying(255),
    install_date date DEFAULT CURRENT_DATE
);


ALTER TABLE public.installed_software OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17379)
-- Name: installed_software_installation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.installed_software_installation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.installed_software_installation_id_seq OWNER TO postgres;

--
-- TOC entry 4977 (class 0 OID 0)
-- Dependencies: 225
-- Name: installed_software_installation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.installed_software_installation_id_seq OWNED BY public.installed_software.installation_id;


--
-- TOC entry 237 (class 1259 OID 17518)
-- Name: job_positions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.job_positions (
    position_id integer NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.job_positions OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 17517)
-- Name: job_positions_position_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.job_positions_position_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.job_positions_position_id_seq OWNER TO postgres;

--
-- TOC entry 4978 (class 0 OID 0)
-- Dependencies: 236
-- Name: job_positions_position_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.job_positions_position_id_seq OWNED BY public.job_positions.position_id;


--
-- TOC entry 218 (class 1259 OID 17337)
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.locations (
    location_id integer NOT NULL,
    name character varying(255) NOT NULL
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 17336)
-- Name: locations_location_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.locations_location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.locations_location_id_seq OWNER TO postgres;

--
-- TOC entry 4979 (class 0 OID 0)
-- Dependencies: 217
-- Name: locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.locations_location_id_seq OWNED BY public.locations.location_id;


--
-- TOC entry 224 (class 1259 OID 17368)
-- Name: software; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.software (
    software_id integer NOT NULL,
    name character varying(255) NOT NULL,
    version character varying(50),
    license_type character varying(100),
    category_id integer
);


ALTER TABLE public.software OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17344)
-- Name: software_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.software_categories (
    category_id integer NOT NULL,
    name character varying(255) NOT NULL
);


ALTER TABLE public.software_categories OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 17343)
-- Name: software_categories_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.software_categories_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.software_categories_category_id_seq OWNER TO postgres;

--
-- TOC entry 4980 (class 0 OID 0)
-- Dependencies: 219
-- Name: software_categories_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.software_categories_category_id_seq OWNED BY public.software_categories.category_id;


--
-- TOC entry 223 (class 1259 OID 17367)
-- Name: software_software_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.software_software_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.software_software_id_seq OWNER TO postgres;

--
-- TOC entry 4981 (class 0 OID 0)
-- Dependencies: 223
-- Name: software_software_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.software_software_id_seq OWNED BY public.software.software_id;


--
-- TOC entry 230 (class 1259 OID 17414)
-- Name: view_report_by_category; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.view_report_by_category AS
 SELECT cat.name AS "Категория",
    count(ins.installation_id) AS "Количество установок"
   FROM ((public.software s
     JOIN public.software_categories cat ON ((s.category_id = cat.category_id)))
     LEFT JOIN public.installed_software ins ON ((s.software_id = ins.software_id)))
  GROUP BY cat.name;


ALTER VIEW public.view_report_by_category OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 17524)
-- Name: view_report_by_employee; Type: VIEW; Schema: public; Owner: postgres
--

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


ALTER VIEW public.view_report_by_employee OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17409)
-- Name: view_report_by_location; Type: VIEW; Schema: public; Owner: postgres
--

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


ALTER VIEW public.view_report_by_location OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17418)
-- Name: view_report_by_usage; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.view_report_by_usage AS
 SELECT c.usage_type AS "Назначение ПК",
    s.name AS "Программа",
    count(*) AS "Количество"
   FROM ((public.installed_software ins
     JOIN public.computers c ON ((ins.computer_id = c.computer_id)))
     JOIN public.software s ON ((ins.software_id = s.software_id)))
  GROUP BY c.usage_type, s.name;


ALTER VIEW public.view_report_by_usage OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 17534)
-- Name: view_software_details; Type: VIEW; Schema: public; Owner: postgres
--

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


ALTER VIEW public.view_software_details OWNER TO postgres;

--
-- TOC entry 4781 (class 2604 OID 17450)
-- Name: app_users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_users ALTER COLUMN user_id SET DEFAULT nextval('public.app_users_user_id_seq'::regclass);


--
-- TOC entry 4779 (class 2604 OID 17401)
-- Name: audit_log log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN log_id SET DEFAULT nextval('public.audit_log_log_id_seq'::regclass);


--
-- TOC entry 4775 (class 2604 OID 17354)
-- Name: computers computer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computers ALTER COLUMN computer_id SET DEFAULT nextval('public.computers_computer_id_seq'::regclass);


--
-- TOC entry 4782 (class 2604 OID 17468)
-- Name: employees employee_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees ALTER COLUMN employee_id SET DEFAULT nextval('public.employees_employee_id_seq'::regclass);


--
-- TOC entry 4777 (class 2604 OID 17383)
-- Name: installed_software installation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.installed_software ALTER COLUMN installation_id SET DEFAULT nextval('public.installed_software_installation_id_seq'::regclass);


--
-- TOC entry 4783 (class 2604 OID 17521)
-- Name: job_positions position_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_positions ALTER COLUMN position_id SET DEFAULT nextval('public.job_positions_position_id_seq'::regclass);


--
-- TOC entry 4773 (class 2604 OID 17340)
-- Name: locations location_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations ALTER COLUMN location_id SET DEFAULT nextval('public.locations_location_id_seq'::regclass);


--
-- TOC entry 4776 (class 2604 OID 17371)
-- Name: software software_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software ALTER COLUMN software_id SET DEFAULT nextval('public.software_software_id_seq'::regclass);


--
-- TOC entry 4774 (class 2604 OID 17347)
-- Name: software_categories category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software_categories ALTER COLUMN category_id SET DEFAULT nextval('public.software_categories_category_id_seq'::regclass);


--
-- TOC entry 4801 (class 2606 OID 17453)
-- Name: app_users app_users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_users
    ADD CONSTRAINT app_users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4803 (class 2606 OID 17455)
-- Name: app_users app_users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_users
    ADD CONSTRAINT app_users_username_key UNIQUE (username);


--
-- TOC entry 4799 (class 2606 OID 17406)
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (log_id);


--
-- TOC entry 4791 (class 2606 OID 17361)
-- Name: computers computers_inventory_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computers
    ADD CONSTRAINT computers_inventory_number_key UNIQUE (inventory_number);


--
-- TOC entry 4793 (class 2606 OID 17359)
-- Name: computers computers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computers
    ADD CONSTRAINT computers_pkey PRIMARY KEY (computer_id);


--
-- TOC entry 4805 (class 2606 OID 17470)
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (employee_id);


--
-- TOC entry 4797 (class 2606 OID 17386)
-- Name: installed_software installed_software_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.installed_software
    ADD CONSTRAINT installed_software_pkey PRIMARY KEY (installation_id);


--
-- TOC entry 4807 (class 2606 OID 17523)
-- Name: job_positions job_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_positions
    ADD CONSTRAINT job_positions_pkey PRIMARY KEY (position_id);


--
-- TOC entry 4787 (class 2606 OID 17342)
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);


--
-- TOC entry 4789 (class 2606 OID 17349)
-- Name: software_categories software_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software_categories
    ADD CONSTRAINT software_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4795 (class 2606 OID 17373)
-- Name: software software_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software
    ADD CONSTRAINT software_pkey PRIMARY KEY (software_id);


--
-- TOC entry 4815 (class 2620 OID 17509)
-- Name: computers trg_audit_computers; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_audit_computers AFTER INSERT OR DELETE OR UPDATE ON public.computers FOR EACH ROW EXECUTE FUNCTION public.log_computer_changes();


--
-- TOC entry 4817 (class 2620 OID 17511)
-- Name: employees trg_audit_employees; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_audit_employees AFTER INSERT OR DELETE OR UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION public.log_employee_changes();


--
-- TOC entry 4816 (class 2620 OID 17533)
-- Name: installed_software trg_log_install; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_log_install AFTER INSERT OR DELETE OR UPDATE ON public.installed_software FOR EACH ROW EXECUTE FUNCTION public.log_software_installation();


--
-- TOC entry 4813 (class 2606 OID 17476)
-- Name: app_users app_users_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_users
    ADD CONSTRAINT app_users_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(employee_id) ON DELETE SET NULL;


--
-- TOC entry 4814 (class 2606 OID 17456)
-- Name: app_users app_users_linked_computer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_users
    ADD CONSTRAINT app_users_linked_computer_id_fkey FOREIGN KEY (linked_computer_id) REFERENCES public.computers(computer_id) ON DELETE SET NULL;


--
-- TOC entry 4808 (class 2606 OID 17471)
-- Name: computers computers_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computers
    ADD CONSTRAINT computers_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(employee_id) ON DELETE SET NULL;


--
-- TOC entry 4809 (class 2606 OID 17362)
-- Name: computers computers_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computers
    ADD CONSTRAINT computers_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE SET NULL;


--
-- TOC entry 4811 (class 2606 OID 17387)
-- Name: installed_software installed_software_computer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.installed_software
    ADD CONSTRAINT installed_software_computer_id_fkey FOREIGN KEY (computer_id) REFERENCES public.computers(computer_id) ON DELETE CASCADE;


--
-- TOC entry 4812 (class 2606 OID 17392)
-- Name: installed_software installed_software_software_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.installed_software
    ADD CONSTRAINT installed_software_software_id_fkey FOREIGN KEY (software_id) REFERENCES public.software(software_id) ON DELETE CASCADE;


--
-- TOC entry 4810 (class 2606 OID 17374)
-- Name: software software_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software
    ADD CONSTRAINT software_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.software_categories(category_id) ON DELETE SET NULL;


-- Completed on 2025-12-25 01:52:25

--
-- PostgreSQL database dump complete
--

\unrestrict cYN6eeKGZ03EQsOgoSdgnAelsc9LtlDA5CzCHoefIksopeKfAeaUEBlKpjB7ogS

