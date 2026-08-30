 ### Step 1: Create the Database in MariaDB

  Open your terminal and log into MariaDB as root:

    sudo mariadb -u root -p

  (or sudo mysql -u root -p)

Run these commands in your MariaDB prompt:

    -- 1. Grant privileges on the correctly spelled database for localhost
    GRANT ALL PRIVILEGES ON hotel_management.* TO 'admin_user'@'localhost';
    
    -- 2. Allow connection via TCP / IP (127.0.0.1 or remote)
    CREATE USER IF NOT EXISTS 'admin_user'@'%' IDENTIFIED BY 'StrongPassword123!';
    GRANT ALL PRIVILEGES ON hotel_management.* TO 'admin_user'@'%';
    
    -- 3. Reload privileges
    FLUSH PRIVILEGES;
  ──────

 ### In DBeaver:

  Now configure your connection in DBeaver:

  • Host: localhost (or 127.0.0.1 / Server IP)
  • Port: 3306
  • Database: hotel_management
  • Username: admin_user
  • Password: StrongPassword123!

  Click Test Connection, and it will connect successfully.
