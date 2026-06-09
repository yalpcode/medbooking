BEGIN;

SET search_path = medbooking, public;

TRUNCATE TABLE
    appointment_status_history,
    appointments,
    doctor_time_off,
    doctor_work_periods,
    doctor_specialties,
    doctors,
    patients,
    specialties
RESTART IDENTITY CASCADE;

INSERT INTO specialties (code, name, description) VALUES
    ('therapy', 'Терапия', 'Первичный прием взрослых пациентов'),
    ('cardiology', 'Кардиология', 'Диагностика и лечение сердечно-сосудистых заболеваний'),
    ('neurology', 'Неврология', 'Диагностика заболеваний нервной системы'),
    ('pediatrics', 'Педиатрия', 'Прием детей и подростков'),
    ('dermatology', 'Дерматология', 'Заболевания кожи');

INSERT INTO doctors (
    last_name,
    first_name,
    middle_name,
    license_number,
    phone,
    email,
    room,
    hire_date
) VALUES
    ('Соколова', 'Анна', 'Петровна', 'LIC-THER-001', '+79001001001', 'sokolova@medbooking.local', '201', DATE '2020-02-10'),
    ('Орлов', 'Дмитрий', 'Игоревич', 'LIC-CARD-002', '+79001001002', 'orlov@medbooking.local', '305', DATE '2018-09-03'),
    ('Лебедева', 'Мария', 'Сергеевна', 'LIC-NEUR-003', '+79001001003', 'lebedeva@medbooking.local', '214', DATE '2021-01-15'),
    ('Кузнецов', 'Алексей', 'Викторович', 'LIC-PED-004', '+79001001004', 'kuznetsov@medbooking.local', '118', DATE '2019-06-20');

INSERT INTO doctor_specialties (doctor_id, specialty_id, experience_years, is_primary) VALUES
    (1, 1, 11, true),
    (1, 5, 4, false),
    (2, 2, 15, true),
    (3, 3, 9, true),
    (4, 4, 13, true),
    (4, 1, 7, false);

INSERT INTO patients (
    last_name,
    first_name,
    middle_name,
    birth_date,
    sex,
    phone,
    email,
    oms_policy_number
) VALUES
    ('Иванов', 'Павел', 'Олегович', DATE '1988-04-12', 'male', '+79110000001', 'ivanov@example.local', '7700000000000001'),
    ('Петрова', 'Елена', 'Андреевна', DATE '1994-11-03', 'female', '+79110000002', 'petrova@example.local', '7700000000000002'),
    ('Смирнов', 'Илья', 'Максимович', DATE '1979-01-25', 'male', '+79110000003', 'smirnov@example.local', '7700000000000003'),
    ('Морозова', 'Алина', 'Романовна', DATE '2015-07-09', 'female', '+79110000004', 'morozova@example.local', '7700000000000004'),
    ('Волкова', 'Наталья', 'Ильинична', DATE '1968-02-18', 'female', '+79110000005', 'volkova@example.local', '7700000000000005');

INSERT INTO doctor_work_periods (
    doctor_id,
    work_date,
    starts_at,
    ends_at,
    slot_minutes,
    room
) VALUES
    (1, DATE '2026-06-15', TIME '09:00', TIME '15:00', 30, '201'),
    (1, DATE '2026-06-16', TIME '09:00', TIME '15:00', 30, '201'),
    (2, DATE '2026-06-15', TIME '10:00', TIME '16:00', 30, '305'),
    (2, DATE '2026-06-16', TIME '10:00', TIME '16:00', 30, '305'),
    (3, DATE '2026-06-15', TIME '09:00', TIME '13:00', 30, '214'),
    (4, DATE '2026-06-15', TIME '08:30', TIME '14:30', 30, '118'),
    (4, DATE '2026-06-16', TIME '08:30', TIME '14:30', 30, '118');

INSERT INTO doctor_time_off (
    doctor_id,
    starts_at,
    ends_at,
    reason
) VALUES
    (1, TIMESTAMP '2026-06-15 13:00', TIMESTAMP '2026-06-15 14:00', 'Совещание отделения');

INSERT INTO appointments (
    patient_id,
    doctor_id,
    specialty_id,
    starts_at,
    ends_at,
    status,
    reason
) VALUES
    (1, 1, 1, TIMESTAMP '2026-06-15 09:00', TIMESTAMP '2026-06-15 09:30', 'booked', 'Первичный прием'),
    (2, 1, 1, TIMESTAMP '2026-06-15 09:30', TIMESTAMP '2026-06-15 10:00', 'confirmed', 'Контроль анализов'),
    (3, 2, 2, TIMESTAMP '2026-06-15 10:00', TIMESTAMP '2026-06-15 10:30', 'booked', 'Боль в груди'),
    (4, 4, 4, TIMESTAMP '2026-06-15 08:30', TIMESTAMP '2026-06-15 09:00', 'confirmed', 'Профилактический осмотр'),
    (5, 2, 2, TIMESTAMP '2026-06-16 10:00', TIMESTAMP '2026-06-16 10:30', 'booked', 'Плановая консультация');

INSERT INTO appointments (
    patient_id,
    doctor_id,
    specialty_id,
    starts_at,
    ends_at,
    status,
    reason,
    cancelled_at,
    cancellation_reason
) VALUES
    (5, 3, 3, TIMESTAMP '2026-06-15 09:00', TIMESTAMP '2026-06-15 09:30',
     'cancelled_by_patient', 'Головные боли', now(), 'Пациент выбрал другую дату');

COMMIT;
