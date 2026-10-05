# Least-Privilege MySQL Database Setup

To protect your production database against potential privilege escalation or accidental administrative drops, create a dedicated application user with least privileges instead of using the `root` administrative account.

---

## 1. Create Dedicated Application User

Connect to your MySQL database server as `root` (or Cloud SQL admin) and run:

```sql
-- 1. Create dedicated application user (replace 'StrongPassword123!@#' with a generated secret)
CREATE USER IF NOT EXISTS 'advt_app_user'@'%' IDENTIFIED BY 'StrongPassword123!@#';

-- 2. Grant only necessary DML and specific DDL permissions on the application database
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, ALTER, LOCK TABLES ON `simple_advt`.* TO 'advt_app_user'@'%';

-- 3. Explicitly deny administrative DROP DATABASE / SUPER privileges
REVOKE DROP, SHUTDOWN, PROCESS, RELOAD, SUPER ON *.* FROM 'advt_app_user'@'%';

-- 4. Apply changes
FLUSH PRIVILEGES;
```

---

## 2. Update Production `.env`

Update your production `.env` configuration:

```env
DB_HOST=127.0.0.1  # or Cloud SQL Private IP / Socket
DB_PORT=3306
DB_USER=advt_app_user
DB_PASSWORD=StrongPassword123!@#
DB_NAME=simple_advt
```
