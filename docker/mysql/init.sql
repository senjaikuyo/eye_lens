-- Inisialisasi Hak Akses dan Least Privilege Database EyeLens (PBL-TRPL308 / ATS)
-- File ini otomatis dieksekusi oleh MariaDB Docker saat kontainer db pertama kali di-build.

-- 1. Berikan hak akses penuh skema db_eyelens untuk operasional Laravel (eyelens_app)
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, REFERENCES, CREATE VIEW, SHOW VIEW, TRIGGER, LOCK TABLES 
ON db_eyelens.* TO 'eyelens_app'@'%';

-- 2. Buat akun Auditor (eyelens_auditor) - Hanya bisa membaca log aktivitas dan view profil publik
CREATE USER IF NOT EXISTS 'eyelens_auditor'@'%' IDENTIFIED BY 'auditor123';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'eyelens_auditor'@'%';
GRANT SELECT ON db_eyelens.audit_log TO 'eyelens_auditor'@'%';
GRANT SELECT ON db_eyelens.v_public_users TO 'eyelens_auditor'@'%';

-- 3. Buat akun Backup (eyelens_backup) - Hanya bisa membaca skema/tabel untuk mariadb-dump
CREATE USER IF NOT EXISTS 'eyelens_backup'@'%' IDENTIFIED BY 'backup123';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'eyelens_backup'@'%';
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES ON db_eyelens.* TO 'eyelens_backup'@'%';

-- 4. Bersihkan akun anonim dan database pengujian default
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;

FLUSH PRIVILEGES;
