BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist;

DROP SCHEMA IF EXISTS medbooking CASCADE;
CREATE SCHEMA medbooking;
SET search_path = medbooking, public;

CREATE TYPE sex_code AS ENUM ('female', 'male');

CREATE TYPE appointment_status AS ENUM (
    'booked',
    'confirmed',
    'completed',
    'cancelled_by_patient',
    'cancelled_by_clinic',
    'no_show'
);

CREATE TABLE specialties (
    specialty_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL UNIQUE,
    description text,
    CONSTRAINT specialties_code_format_chk
        CHECK (code ~ '^[a-z][a-z0-9_]{2,31}$'),
    CONSTRAINT specialties_name_not_blank_chk
        CHECK (length(trim(name)) >= 3)
);

CREATE TABLE patients (
    patient_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    last_name text NOT NULL,
    first_name text NOT NULL,
    middle_name text,
    birth_date date NOT NULL,
    sex sex_code NOT NULL,
    phone text NOT NULL,
    email text,
    oms_policy_number text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patients_last_name_not_blank_chk
        CHECK (length(trim(last_name)) >= 2),
    CONSTRAINT patients_first_name_not_blank_chk
        CHECK (length(trim(first_name)) >= 2),
    CONSTRAINT patients_birth_date_chk
        CHECK (birth_date < CURRENT_DATE),
    CONSTRAINT patients_phone_format_chk
        CHECK (phone ~ '^\+?[0-9]{10,15}$'),
    CONSTRAINT patients_email_format_chk
        CHECK (email IS NULL OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
    CONSTRAINT patients_phone_uq UNIQUE (phone),
    CONSTRAINT patients_oms_policy_uq UNIQUE (oms_policy_number)
);

CREATE UNIQUE INDEX patients_email_lower_uq
    ON patients (lower(email))
    WHERE email IS NOT NULL;

CREATE TABLE doctors (
    doctor_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    last_name text NOT NULL,
    first_name text NOT NULL,
    middle_name text,
    license_number text NOT NULL,
    phone text,
    email text,
    room text NOT NULL,
    hire_date date NOT NULL DEFAULT CURRENT_DATE,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT doctors_last_name_not_blank_chk
        CHECK (length(trim(last_name)) >= 2),
    CONSTRAINT doctors_first_name_not_blank_chk
        CHECK (length(trim(first_name)) >= 2),
    CONSTRAINT doctors_license_not_blank_chk
        CHECK (length(trim(license_number)) >= 4),
    CONSTRAINT doctors_room_not_blank_chk
        CHECK (length(trim(room)) >= 1),
    CONSTRAINT doctors_phone_format_chk
        CHECK (phone IS NULL OR phone ~ '^\+?[0-9]{10,15}$'),
    CONSTRAINT doctors_email_format_chk
        CHECK (email IS NULL OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
    CONSTRAINT doctors_license_uq UNIQUE (license_number),
    CONSTRAINT doctors_phone_uq UNIQUE (phone)
);

CREATE UNIQUE INDEX doctors_email_lower_uq
    ON doctors (lower(email))
    WHERE email IS NOT NULL;

CREATE TABLE doctor_specialties (
    doctor_id bigint NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    specialty_id bigint NOT NULL REFERENCES specialties(specialty_id) ON DELETE RESTRICT,
    experience_years smallint NOT NULL DEFAULT 0,
    is_primary boolean NOT NULL DEFAULT false,
    PRIMARY KEY (doctor_id, specialty_id),
    CONSTRAINT doctor_specialties_experience_chk
        CHECK (experience_years BETWEEN 0 AND 70)
);

CREATE UNIQUE INDEX doctor_specialties_one_primary_uq
    ON doctor_specialties (doctor_id)
    WHERE is_primary;

CREATE INDEX doctor_specialties_specialty_idx
    ON doctor_specialties (specialty_id, doctor_id);

CREATE TABLE doctor_work_periods (
    work_period_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doctor_id bigint NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    work_date date NOT NULL,
    starts_at time NOT NULL,
    ends_at time NOT NULL,
    slot_minutes smallint NOT NULL DEFAULT 30,
    room text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT doctor_work_periods_time_order_chk
        CHECK (starts_at < ends_at),
    CONSTRAINT doctor_work_periods_slot_minutes_chk
        CHECK (slot_minutes IN (10, 15, 20, 30, 45, 60)),
    CONSTRAINT doctor_work_periods_room_not_blank_chk
        CHECK (room IS NULL OR length(trim(room)) >= 1)
);

ALTER TABLE doctor_work_periods
    ADD CONSTRAINT doctor_work_periods_no_overlap
    EXCLUDE USING gist (
        doctor_id WITH =,
        tsrange(work_date + starts_at, work_date + ends_at, '[)') WITH &&
    );

CREATE INDEX doctor_work_periods_lookup_idx
    ON doctor_work_periods (doctor_id, work_date, starts_at);

CREATE TABLE doctor_time_off (
    time_off_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doctor_id bigint NOT NULL REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    starts_at timestamp without time zone NOT NULL,
    ends_at timestamp without time zone NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT doctor_time_off_time_order_chk
        CHECK (starts_at < ends_at),
    CONSTRAINT doctor_time_off_reason_not_blank_chk
        CHECK (length(trim(reason)) >= 3)
);

ALTER TABLE doctor_time_off
    ADD CONSTRAINT doctor_time_off_no_overlap
    EXCLUDE USING gist (
        doctor_id WITH =,
        tsrange(starts_at, ends_at, '[)') WITH &&
    );

CREATE INDEX doctor_time_off_lookup_idx
    ON doctor_time_off (doctor_id, starts_at, ends_at);

CREATE TABLE appointments (
    appointment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id bigint NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,
    doctor_id bigint NOT NULL REFERENCES doctors(doctor_id) ON DELETE RESTRICT,
    specialty_id bigint NOT NULL REFERENCES specialties(specialty_id) ON DELETE RESTRICT,
    starts_at timestamp without time zone NOT NULL,
    ends_at timestamp without time zone NOT NULL,
    status appointment_status NOT NULL DEFAULT 'booked',
    reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    cancelled_at timestamptz,
    cancellation_reason text,
    created_by text NOT NULL DEFAULT current_user,
    CONSTRAINT appointments_time_order_chk
        CHECK (starts_at < ends_at),
    CONSTRAINT appointments_duration_min_chk
        CHECK (ends_at >= starts_at + interval '10 minutes'),
    CONSTRAINT appointments_duration_max_chk
        CHECK (ends_at <= starts_at + interval '2 hours'),
    CONSTRAINT appointments_reason_not_blank_chk
        CHECK (length(trim(reason)) >= 3),
    CONSTRAINT appointments_cancelled_state_chk
        CHECK (
            (
                status IN ('cancelled_by_patient', 'cancelled_by_clinic')
                AND cancelled_at IS NOT NULL
                AND cancellation_reason IS NOT NULL
                AND length(trim(cancellation_reason)) >= 3
            )
            OR
            (
                status NOT IN ('cancelled_by_patient', 'cancelled_by_clinic')
                AND cancelled_at IS NULL
                AND cancellation_reason IS NULL
            )
        ),
    CONSTRAINT appointments_doctor_specialty_fk
        FOREIGN KEY (doctor_id, specialty_id)
        REFERENCES doctor_specialties(doctor_id, specialty_id)
        ON DELETE RESTRICT
);

ALTER TABLE appointments
    ADD CONSTRAINT appointments_no_doctor_overlap
    EXCLUDE USING gist (
        doctor_id WITH =,
        tsrange(starts_at, ends_at, '[)') WITH &&
    )
    WHERE (status IN ('booked', 'confirmed', 'completed', 'no_show'));

ALTER TABLE appointments
    ADD CONSTRAINT appointments_no_patient_overlap
    EXCLUDE USING gist (
        patient_id WITH =,
        tsrange(starts_at, ends_at, '[)') WITH &&
    )
    WHERE (status IN ('booked', 'confirmed', 'completed', 'no_show'));

CREATE INDEX appointments_doctor_starts_idx
    ON appointments (doctor_id, starts_at);

CREATE INDEX appointments_patient_starts_idx
    ON appointments (patient_id, starts_at);

CREATE INDEX appointments_specialty_status_idx
    ON appointments (specialty_id, status, starts_at);

CREATE INDEX appointments_active_idx
    ON appointments (starts_at, doctor_id, patient_id)
    WHERE status IN ('booked', 'confirmed');

CREATE TABLE appointment_status_history (
    status_history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id bigint NOT NULL REFERENCES appointments(appointment_id) ON DELETE CASCADE,
    old_status appointment_status,
    new_status appointment_status NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    actor text NOT NULL DEFAULT current_user,
    comment text
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointments_set_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION audit_appointment_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO appointment_status_history (
            appointment_id,
            old_status,
            new_status,
            comment
        )
        VALUES (
            NEW.appointment_id,
            NULL,
            NEW.status,
            'начальный статус'
        );
        RETURN NEW;
    END IF;

    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO appointment_status_history (
            appointment_id,
            old_status,
            new_status,
            comment
        )
        VALUES (
            NEW.appointment_id,
            OLD.status,
            NEW.status,
            'статус изменен'
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointments_audit_status
AFTER INSERT OR UPDATE OF status ON appointments
FOR EACH ROW
EXECUTE FUNCTION audit_appointment_status();

CREATE OR REPLACE FUNCTION validate_appointment_schedule()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IN ('booked', 'confirmed') THEN
        IF NOT EXISTS (
            SELECT 1
            FROM doctor_work_periods wp
            JOIN doctors d ON d.doctor_id = wp.doctor_id
            WHERE wp.doctor_id = NEW.doctor_id
              AND d.is_active
              AND wp.work_date = NEW.starts_at::date
              AND NEW.ends_at::date = NEW.starts_at::date
              AND NEW.starts_at::time >= wp.starts_at
              AND NEW.ends_at::time <= wp.ends_at
              AND EXTRACT(EPOCH FROM (NEW.ends_at - NEW.starts_at)) / 60 = wp.slot_minutes
              AND mod(
                    (EXTRACT(EPOCH FROM (NEW.starts_at::time - wp.starts_at)) / 60)::int,
                    wp.slot_minutes
                  ) = 0
        ) THEN
            RAISE EXCEPTION
                'Прием % находится вне рабочего периода врача или сетки слотов',
                NEW.appointment_id
                USING ERRCODE = '23514';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM doctor_time_off t
            WHERE t.doctor_id = NEW.doctor_id
              AND tsrange(t.starts_at, t.ends_at, '[)')
                  && tsrange(NEW.starts_at, NEW.ends_at, '[)')
        ) THEN
            RAISE EXCEPTION
                'Врач % недоступен в выбранный интервал',
                NEW.doctor_id
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_appointment_schedule
BEFORE INSERT OR UPDATE OF doctor_id, starts_at, ends_at, status ON appointments
FOR EACH ROW
EXECUTE FUNCTION validate_appointment_schedule();

CREATE OR REPLACE FUNCTION validate_time_off_has_no_active_appointments()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM appointments a
        WHERE a.doctor_id = NEW.doctor_id
          AND a.status IN ('booked', 'confirmed')
          AND tsrange(a.starts_at, a.ends_at, '[)')
              && tsrange(NEW.starts_at, NEW.ends_at, '[)')
    ) THEN
        RAISE EXCEPTION
            'Нельзя создать период отсутствия врача поверх активных приемов'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_time_off_has_no_active_appointments
BEFORE INSERT OR UPDATE OF doctor_id, starts_at, ends_at ON doctor_time_off
FOR EACH ROW
EXECUTE FUNCTION validate_time_off_has_no_active_appointments();

CREATE VIEW v_doctor_work_slots AS
SELECT
    wp.doctor_id,
    d.last_name || ' ' || d.first_name AS doctor_name,
    ds.specialty_id,
    s.name AS specialty_name,
    wp.work_date,
    gs.slot_start,
    gs.slot_start + make_interval(mins => wp.slot_minutes) AS slot_end,
    COALESCE(wp.room, d.room) AS room
FROM doctor_work_periods wp
JOIN doctors d ON d.doctor_id = wp.doctor_id
JOIN doctor_specialties ds ON ds.doctor_id = d.doctor_id
JOIN specialties s ON s.specialty_id = ds.specialty_id
CROSS JOIN LATERAL generate_series(
    wp.work_date + wp.starts_at,
    wp.work_date + wp.ends_at - make_interval(mins => wp.slot_minutes),
    make_interval(mins => wp.slot_minutes)
) AS gs(slot_start)
WHERE d.is_active
  AND NOT EXISTS (
      SELECT 1
      FROM appointments a
      WHERE a.doctor_id = wp.doctor_id
        AND a.status IN ('booked', 'confirmed')
        AND tsrange(a.starts_at, a.ends_at, '[)')
            && tsrange(gs.slot_start, gs.slot_start + make_interval(mins => wp.slot_minutes), '[)')
  )
  AND NOT EXISTS (
      SELECT 1
      FROM doctor_time_off t
      WHERE t.doctor_id = wp.doctor_id
        AND tsrange(t.starts_at, t.ends_at, '[)')
            && tsrange(gs.slot_start, gs.slot_start + make_interval(mins => wp.slot_minutes), '[)')
  );

COMMIT;
