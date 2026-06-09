SET search_path = medbooking, public;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCAL lock_timeout = '5s';

SELECT doctor_id
FROM doctors
WHERE doctor_id = 1
  AND is_active
FOR UPDATE;

SELECT slot_start, slot_end
FROM v_doctor_work_slots
WHERE doctor_id = 1
  AND specialty_id = 1
  AND slot_start = TIMESTAMP '2026-06-15 10:30';

INSERT INTO appointments (
    patient_id,
    doctor_id,
    specialty_id,
    starts_at,
    ends_at,
    status,
    reason
) VALUES (
    5,
    1,
    1,
    TIMESTAMP '2026-06-15 10:30',
    TIMESTAMP '2026-06-15 11:00',
    'booked',
    'Повторная консультация'
);

COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCAL lock_timeout = '5s';

SELECT appointment_id
FROM appointments
WHERE appointment_id = 3
  AND status IN ('booked', 'confirmed')
FOR UPDATE;

UPDATE appointments
SET starts_at = TIMESTAMP '2026-06-15 11:00',
    ends_at = TIMESTAMP '2026-06-15 11:30'
WHERE appointment_id = 3
  AND status IN ('booked', 'confirmed');

COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCAL lock_timeout = '5s';

SELECT doctor_id
FROM doctors
WHERE doctor_id = 2
FOR UPDATE;

UPDATE appointments
SET status = 'cancelled_by_clinic',
    cancelled_at = now(),
    cancellation_reason = 'Врач отсутствует по болезни'
WHERE doctor_id = 2
  AND status IN ('booked', 'confirmed')
  AND tsrange(starts_at, ends_at, '[)')
      && tsrange(TIMESTAMP '2026-06-16 10:00', TIMESTAMP '2026-06-16 13:00', '[)');

INSERT INTO doctor_time_off (
    doctor_id,
    starts_at,
    ends_at,
    reason
) VALUES (
    2,
    TIMESTAMP '2026-06-16 10:00',
    TIMESTAMP '2026-06-16 13:00',
    'Больничный'
);

COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCAL lock_timeout = '5s';

SELECT appointment_id
FROM appointments
WHERE appointment_id = 2
FOR UPDATE;

UPDATE appointments
SET status = 'completed'
WHERE appointment_id = 2
  AND status = 'confirmed';

COMMIT;
