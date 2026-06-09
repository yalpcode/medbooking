# MedBooking

Проект реляционной базы данных PostgreSQL для предметной области «запись к врачу»: пациенты, врачи, специальности, расписание и приемы.

Документы сохранены в `docs/`:

- `docs/README.md` — полный итоговый отчет;
- `docs/report.typ` — исходник PDF;
- `docs/MedBooking_Project_Report.pdf` — итоговый PDF после сборки.

## Запуск PostgreSQL

```bash
docker compose up -d
docker compose exec -T db psql -U postgres -d medbooking < sql/01_schema.sql
docker compose exec -T db psql -U postgres -d medbooking < sql/02_seed.sql
```

## Проверка запросов

```bash
docker compose exec -T db psql -U postgres -d medbooking < sql/03_queries.sql
docker compose exec -T db psql -U postgres -d medbooking < sql/04_transactions.sql
```

## Сборка PDF

```bash
typst compile --root . docs/report.typ docs/MedBooking_Project_Report.pdf
```
