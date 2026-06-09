SET search_path = medbooking, public;

INSERT INTO patients (
    last_name,
    first_name,
    middle_name,
    birth_date,
    sex,
    phone,
    email,
    oms_policy_number
) VALUES (
    'Никитина',
    'Ольга',
    'Павловна',
    DATE '1991-05-17',
    'female',
    '+79110000006',
    'nikitina@example.local',
    '7700000000000006'
);

SELECT
    slot_start,
    slot_end,
    doctor_id,
    doctor_name,
    room
FROM v_doctor_work_slots
WHERE specialty_id = (
    SELECT specialty_id
    FROM specialties
    WHERE code = 'therapy'
)
  AND work_date = DATE '2026-06-15'
ORDER BY slot_start, doctor_name;

SELECT
    a.starts_at,
    a.ends_at,
    a.status,
    p.last_name || ' ' || p.first_name AS patient_name,
    p.phone,
    s.name AS specialty,
    a.reason
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN specialties s ON s.specialty_id = a.specialty_id
WHERE a.doctor_id = 1
  AND a.starts_at::date = DATE '2026-06-15'
ORDER BY a.starts_at;

UPDATE patients
SET phone = '+79119990006',
    email = 'nikitina.new@example.local'
WHERE oms_policy_number = '7700000000000006';

UPDATE appointments
SET status = 'cancelled_by_patient',
    cancelled_at = now(),
    cancellation_reason = 'Пациент отказался от визита'
WHERE appointment_id = 1
  AND status IN ('booked', 'confirmed');

DELETE FROM patients p
WHERE p.oms_policy_number = '7700000000000006'
  AND NOT EXISTS (
      SELECT 1
      FROM appointments a
      WHERE a.patient_id = p.patient_id
  );

SELECT
    p.last_name || ' ' || p.first_name AS patient_name,
    a.starts_at,
    d.last_name || ' ' || d.first_name AS doctor_name,
    s.name AS specialty,
    a.status,
    row_number() OVER (
        PARTITION BY a.patient_id
        ORDER BY a.starts_at DESC
    ) AS visit_number_desc
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors d ON d.doctor_id = a.doctor_id
JOIN specialties s ON s.specialty_id = a.specialty_id
WHERE p.oms_policy_number = '7700000000000002'
ORDER BY a.starts_at DESC;

SELECT
    d.doctor_id,
    d.last_name || ' ' || d.first_name AS doctor_name,
    a.starts_at::date AS work_date,
    count(*) FILTER (WHERE a.status IN ('booked', 'confirmed', 'completed')) AS active_or_done_count,
    count(*) FILTER (WHERE a.status IN ('cancelled_by_patient', 'cancelled_by_clinic')) AS cancelled_count,
    round(
        100.0 * count(*) FILTER (WHERE a.status IN ('booked', 'confirmed', 'completed'))
        / NULLIF(count(*), 0),
        2
    ) AS useful_load_percent
FROM appointments a
JOIN doctors d ON d.doctor_id = a.doctor_id
GROUP BY d.doctor_id, doctor_name, a.starts_at::date
ORDER BY work_date, useful_load_percent DESC;

SELECT
    s.name AS specialty,
    count(a.appointment_id) AS total_appointments,
    count(*) FILTER (WHERE a.status = 'completed') AS completed_count,
    count(*) FILTER (WHERE a.status IN ('booked', 'confirmed')) AS future_active_count,
    count(DISTINCT a.patient_id) AS unique_patients
FROM specialties s
LEFT JOIN appointments a ON a.specialty_id = s.specialty_id
GROUP BY s.specialty_id, s.name
ORDER BY total_appointments DESC, specialty;

WITH doctor_stats AS (
    SELECT
        d.doctor_id,
        d.last_name || ' ' || d.first_name AS doctor_name,
        count(*) AS total_appointments,
        count(*) FILTER (WHERE a.status = 'no_show') AS no_show_count
    FROM doctors d
    LEFT JOIN appointments a ON a.doctor_id = d.doctor_id
    GROUP BY d.doctor_id, doctor_name
)
SELECT
    doctor_name,
    total_appointments,
    no_show_count,
    round(100.0 * no_show_count / NULLIF(total_appointments, 0), 2) AS no_show_percent,
    rank() OVER (
        ORDER BY 1.0 * no_show_count / NULLIF(total_appointments, 0) DESC NULLS LAST
    ) AS risk_rank
FROM doctor_stats
ORDER BY risk_rank, doctor_name;
